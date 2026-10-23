import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

/// A shortage: a piece of equipment whose reserved quantity exceeds or nearly
/// exhausts available stock during a given booking's date window.
class _Shortage {
  _Shortage({
    required this.equipmentId,
    required this.equipmentName,
    required this.category,
    required this.totalAvailable,
    required this.totalReserved,
    required this.bookingEventName,
    required this.bookingId,
    required this.start,
    required this.end,
    required this.requested,
  });

  final String equipmentId;
  final String equipmentName;
  final String category;
  final int totalAvailable;
  final int totalReserved;
  final String bookingEventName;
  final String bookingId;
  final DateTime start;
  final DateTime end;
  final int requested;

  int get deficit => totalReserved - totalAvailable;
  bool get isCritical => deficit > 0;
}

/// A pair of bookings that conflict (overlap in time AND share equipment).
class _BookingConflict {
  _BookingConflict({
    required this.bookingAId,
    required this.bookingAName,
    required this.bookingAStart,
    required this.bookingAEnd,
    required this.bookingBId,
    required this.bookingBName,
    required this.bookingBStart,
    required this.bookingBEnd,
    required this.sharedEquipment,
  });

  final String bookingAId;
  final String bookingAName;
  final DateTime bookingAStart;
  final DateTime bookingAEnd;
  final String bookingBId;
  final String bookingBName;
  final DateTime bookingBStart;
  final DateTime bookingBEnd;
  final List<_SharedItem> sharedEquipment;
}

class _SharedItem {
  _SharedItem({
    required this.name,
    required this.reservedByA,
    required this.reservedByB,
    required this.available,
  });
  final String name;
  final int reservedByA;
  final int reservedByB;
  final int available;
  int get totalReserved => reservedByA + reservedByB;
}

/// A window during which a piece of equipment is fully reserved.
class _UnavailableWindow {
  _UnavailableWindow({
    required this.equipmentId,
    required this.equipmentName,
    required this.category,
    required this.available,
    required this.intervals,
    required this.alternatives,
  });
  final String equipmentId;
  final String equipmentName;
  final String category;
  final int available;
  final List<_Interval> intervals;
  final List<DateTimeRange> alternatives;
}

class _Interval {
  _Interval({required this.start, required this.end, required this.bookingName});
  final DateTime start;
  final DateTime end;
  final String bookingName;
}

// ---------------------------------------------------------------------------
// Analysis engine (pure Dart, no network calls after initial data load)
// ---------------------------------------------------------------------------

class _ConflictEngine {
  static _ConflictResult analyse({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> equipment,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings,
  }) {
    final activeBookings = bookings.where((doc) {
      final status = (doc.data()['status'] as String? ?? '').toLowerCase();
      return !const {'cancelled', 'rejected', 'declined'}.contains(status);
    }).toList();

    final shortages = _findShortages(equipment, activeBookings);
    final conflicts = _findConflicts(equipment, activeBookings);
    final windows = _findUnavailableWindows(equipment, activeBookings);

    return _ConflictResult(
      shortages: shortages,
      conflicts: conflicts,
      unavailableWindows: windows,
    );
  }

  // ---- Shortages: bookings requesting more than stock allows ----------------

  static List<_Shortage> _findShortages(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> equipment,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> activeBookings,
  ) {
    final equipmentMap = {for (final e in equipment) e.id: e.data()};
    final shortages = <_Shortage>[];

    for (final booking in activeBookings) {
      final data = booking.data();
      final start = _readDate(data['startDate']);
      final end = _readDate(data['endDate']);
      if (start == null || end == null) continue;

      final items = data['items'];
      if (items is! List) continue;

      for (final raw in items) {
        if (raw is! Map) continue;
        final eqId = (raw['equipmentId'] ?? raw['id'])?.toString();
        final requested = (raw['quantity'] as num?)?.toInt() ?? 0;
        if (eqId == null || requested <= 0) continue;

        final eqData = equipmentMap[eqId];
        if (eqData == null) continue;

        final usable = (eqData['availableQuantity'] as num?)?.toInt() ??
            (eqData['totalQuantity'] as num?)?.toInt() ??
            0;

        // Count total reserved for this equipment across ALL overlapping bookings.
        var totalReserved = 0;
        for (final other in activeBookings) {
          final oData = other.data();
          final oStart = _readDate(oData['startDate']);
          final oEnd = _readDate(oData['endDate']);
          if (oStart == null || oEnd == null) continue;
          if (!_overlaps(start, end, oStart, oEnd)) continue;

          final oItems = oData['items'];
          if (oItems is! List) continue;
          for (final oi in oItems) {
            if (oi is! Map) continue;
            final oId = (oi['equipmentId'] ?? oi['id'])?.toString();
            if (oId == eqId) {
              totalReserved += (oi['quantity'] as num?)?.toInt() ?? 0;
            }
          }
        }

        if (totalReserved >= usable) {
          // Only add if this booking is the one contributing to the overflow.
          final alreadyAdded = shortages.any((s) =>
              s.equipmentId == eqId &&
              s.bookingId == booking.id);
          if (!alreadyAdded) {
            shortages.add(_Shortage(
              equipmentId: eqId,
              equipmentName:
                  (raw['name'] ?? eqData['name'] ?? eqId).toString(),
              category: (eqData['category'] as String? ?? 'Other'),
              totalAvailable: usable,
              totalReserved: totalReserved,
              bookingEventName:
                  (data['eventName'] as String? ?? 'Unknown event'),
              bookingId: booking.id,
              start: start,
              end: end,
              requested: requested,
            ));
          }
        }
      }
    }
    shortages.sort((a, b) => b.deficit.compareTo(a.deficit));
    return shortages;
  }

  // ---- Conflicting booking pairs --------------------------------------------

  static List<_BookingConflict> _findConflicts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> equipment,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> activeBookings,
  ) {
    final equipmentMap = {
      for (final e in equipment) e.id: e.data()['name'] as String? ?? e.id,
    };
    final equipmentAvail = {
      for (final e in equipment)
        e.id: ((e.data()['availableQuantity'] as num?)?.toInt() ??
            (e.data()['totalQuantity'] as num?)?.toInt() ??
            0),
    };

    final conflicts = <_BookingConflict>[];
    final seen = <String>{};

    for (var i = 0; i < activeBookings.length; i++) {
      for (var j = i + 1; j < activeBookings.length; j++) {
        final aDoc = activeBookings[i];
        final bDoc = activeBookings[j];
        final aData = aDoc.data();
        final bData = bDoc.data();

        final aStart = _readDate(aData['startDate']);
        final aEnd = _readDate(aData['endDate']);
        final bStart = _readDate(bData['startDate']);
        final bEnd = _readDate(bData['endDate']);

        if (aStart == null || aEnd == null || bStart == null || bEnd == null) {
          continue;
        }
        if (!_overlaps(aStart, aEnd, bStart, bEnd)) continue;

        // Find shared equipment where combined reservation > available stock.
        final aItems = _itemsMap(aData['items']);
        final bItems = _itemsMap(bData['items']);
        final sharedIds = aItems.keys.toSet().intersection(bItems.keys.toSet());

        final sharedList = <_SharedItem>[];
        for (final eqId in sharedIds) {
          final reservedByA = aItems[eqId]!;
          final reservedByB = bItems[eqId]!;
          final available = equipmentAvail[eqId] ?? 0;
          if (reservedByA + reservedByB > available) {
            sharedList.add(_SharedItem(
              name: equipmentMap[eqId] ?? eqId,
              reservedByA: reservedByA,
              reservedByB: reservedByB,
              available: available,
            ));
          }
        }

        if (sharedList.isEmpty) continue;

        // Deduplicate using sorted pair key.
        final pairKey = [aDoc.id, bDoc.id]..sort();
        final key = pairKey.join(':');
        if (seen.contains(key)) continue;
        seen.add(key);

        conflicts.add(_BookingConflict(
          bookingAId: aDoc.id,
          bookingAName: aData['eventName'] as String? ?? 'Event A',
          bookingAStart: aStart,
          bookingAEnd: aEnd,
          bookingBId: bDoc.id,
          bookingBName: bData['eventName'] as String? ?? 'Event B',
          bookingBStart: bStart,
          bookingBEnd: bEnd,
          sharedEquipment: sharedList,
        ));
      }
    }
    return conflicts;
  }

  // ---- Unavailable time windows + alternatives ------------------------------

  static List<_UnavailableWindow> _findUnavailableWindows(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> equipment,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> activeBookings,
  ) {
    final result = <_UnavailableWindow>[];

    for (final eqDoc in equipment) {
      final eqData = eqDoc.data();
      final statusStr =
          (eqData['status'] as String? ?? 'Available').toLowerCase();
      if (const {'retired', 'damaged', 'under maintenance'}
          .contains(statusStr)) {
        continue;
      }
      final usable = (eqData['availableQuantity'] as num?)?.toInt() ??
          (eqData['totalQuantity'] as num?)?.toInt() ??
          0;
      if (usable == 0) continue;

      final intervals = <_Interval>[];
      for (final booking in activeBookings) {
        final bData = booking.data();
        final bStart = _readDate(bData['startDate']);
        final bEnd = _readDate(bData['endDate']);
        if (bStart == null || bEnd == null) continue;

        final items = bData['items'];
        if (items is! List) continue;
        for (final item in items) {
          if (item is! Map) continue;
          final id = (item['equipmentId'] ?? item['id'])?.toString();
          if (id != eqDoc.id) continue;
          final qty = (item['quantity'] as num?)?.toInt() ?? 0;
          if (qty >= usable) {
            intervals.add(_Interval(
              start: bStart,
              end: bEnd,
              bookingName: bData['eventName'] as String? ?? 'Booking',
            ));
          }
        }
      }

      if (intervals.isEmpty) continue;

      // Sort and merge overlapping intervals to find gap alternatives.
      intervals.sort((a, b) => a.start.compareTo(b.start));

      // Find 2-week windows before, between and after busy blocks.
      final alternatives = _suggestAlternatives(intervals);

      result.add(_UnavailableWindow(
        equipmentId: eqDoc.id,
        equipmentName: eqData['name'] as String? ?? eqDoc.id,
        category: eqData['category'] as String? ?? 'Other',
        available: usable,
        intervals: intervals,
        alternatives: alternatives,
      ));
    }

    result.sort((a, b) => a.equipmentName.compareTo(b.equipmentName));
    return result;
  }

  /// Suggest up to 3 free 7-day windows outside of the busy intervals.
  static List<DateTimeRange> _suggestAlternatives(List<_Interval> busy) {
    final now = _dateOnly(DateTime.now());
    final alternatives = <DateTimeRange>[];

    // Candidate start points: today, and 1 day after each interval ends.
    final candidates = [now, ...busy.map((b) => _dateOnly(b.end).add(const Duration(days: 1)))];

    for (final start in candidates) {
      if (start.isBefore(now)) continue;
      final end = start.add(const Duration(days: 6));
      final overlapsAny = busy.any(
        (b) => _overlaps(start, end, _dateOnly(b.start), _dateOnly(b.end)),
      );
      if (!overlapsAny) {
        alternatives.add(DateTimeRange(start: start, end: end));
        if (alternatives.length >= 3) break;
      }
    }
    return alternatives;
  }

  // ---- Helpers --------------------------------------------------------------

  static Map<String, int> _itemsMap(Object? items) {
    final result = <String, int>{};
    if (items is! List) return result;
    for (final item in items) {
      if (item is! Map) continue;
      final id = (item['equipmentId'] ?? item['id'])?.toString();
      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
      if (id != null && qty > 0) result[id] = (result[id] ?? 0) + qty;
    }
    return result;
  }

  static bool _overlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    final as_ = _dateOnly(aStart);
    final ae = _dateOnly(aEnd);
    final bs = _dateOnly(bStart);
    final be = _dateOnly(bEnd);
    return !as_.isAfter(be) && !ae.isBefore(bs);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class _ConflictResult {
  _ConflictResult({
    required this.shortages,
    required this.conflicts,
    required this.unavailableWindows,
  });
  final List<_Shortage> shortages;
  final List<_BookingConflict> conflicts;
  final List<_UnavailableWindow> unavailableWindows;

  bool get hasIssues =>
      shortages.isNotEmpty ||
      conflicts.isNotEmpty ||
      unavailableWindows.isNotEmpty;
}

// ---------------------------------------------------------------------------
// UI
// ---------------------------------------------------------------------------

class ConflictDetectionPage extends StatelessWidget {
  const ConflictDetectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Conflict Detection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              // Firestore streams update automatically; this just re-triggers
              // a visual rebuild by pushing a new identical route.
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => const ConflictDetectionPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('equipment').snapshots(),
        builder: (context, eqSnap) {
          if (eqSnap.hasError) {
            return _errorState('Could not load equipment data.');
          }
          if (eqSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance.collection('bookings').snapshots(),
            builder: (context, bkSnap) {
              if (bkSnap.hasError) {
                return _errorState('Could not load booking data.');
              }
              if (bkSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final result = _ConflictEngine.analyse(
                equipment: eqSnap.data?.docs ?? [],
                bookings: bkSnap.data?.docs ?? [],
              );

              if (!result.hasIssues) {
                return _allClearState();
              }

              return _ConflictReport(result: result);
            },
          );
        },
      ),
    );
  }

  Widget _errorState(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 48, color: Color(0xff667085)),
              const SizedBox(height: 14),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xff667085))),
            ],
          ),
        ),
      );

  Widget _allClearState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xffd1fae5),
                  borderRadius: BorderRadius.circular(36),
                ),
                child: const Icon(Icons.check_circle_outline_rounded,
                    size: 40, color: Color(0xff059669)),
              ),
              const SizedBox(height: 18),
              const Text(
                'All Clear!',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff059669)),
              ),
              const SizedBox(height: 8),
              const Text(
                'No shortages, overlapping bookings, or unavailable '
                'time windows were detected.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xff667085), height: 1.5),
              ),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Report body — tabs
// ---------------------------------------------------------------------------

class _ConflictReport extends StatefulWidget {
  const _ConflictReport({required this.result});
  final _ConflictResult result;

  @override
  State<_ConflictReport> createState() => _ConflictReportState();
}

class _ConflictReportState extends State<_ConflictReport>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return Column(
      children: [
        _SummaryBanner(result: r),
        TabBar(
          controller: _tabs,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: [
            Tab(
              child: _TabLabel(
                'Shortages',
                count: r.shortages.length,
                color: r.shortages.isEmpty
                    ? Colors.green
                    : const Color(0xffdc2626),
              ),
            ),
            Tab(
              child: _TabLabel(
                'Conflicts',
                count: r.conflicts.length,
                color: r.conflicts.isEmpty
                    ? Colors.green
                    : const Color(0xffea580c),
              ),
            ),
            Tab(
              child: _TabLabel(
                'Time Windows',
                count: r.unavailableWindows.length,
                color: r.unavailableWindows.isEmpty
                    ? Colors.green
                    : const Color(0xff7c3aed),
              ),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _ShortagesTab(shortages: r.shortages),
              _ConflictsTab(conflicts: r.conflicts),
              _UnavailableWindowsTab(windows: r.unavailableWindows),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Summary banner
// ---------------------------------------------------------------------------

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.result});
  final _ConflictResult result;

  @override
  Widget build(BuildContext context) {
    final hasCritical = result.shortages.any((s) => s.isCritical) ||
        result.conflicts.isNotEmpty;

    return Container(
      width: double.infinity,
      color: hasCritical
          ? const Color(0xfffff1f2)
          : const Color(0xfffff7ed),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          Icon(
            hasCritical
                ? Icons.warning_amber_rounded
                : Icons.info_outline_rounded,
            color: hasCritical
                ? const Color(0xffdc2626)
                : const Color(0xffea580c),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasCritical
                  ? '${result.shortages.length} shortage${result.shortages.length == 1 ? '' : 's'}, '
                      '${result.conflicts.length} booking conflict${result.conflicts.length == 1 ? '' : 's'} '
                      'require immediate attention.'
                  : '${result.unavailableWindows.length} equipment item${result.unavailableWindows.length == 1 ? '' : 's'} '
                      'have fully-booked time windows. Review alternatives below.',
              style: TextStyle(
                color: hasCritical
                    ? const Color(0xff991b1b)
                    : const Color(0xff9a3412),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel(this.label, {required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1 — Shortages
// ---------------------------------------------------------------------------

class _ShortagesTab extends StatelessWidget {
  const _ShortagesTab({required this.shortages});
  final List<_Shortage> shortages;

  @override
  Widget build(BuildContext context) {
    if (shortages.isEmpty) {
      return _emptyTab(
        Icons.check_circle_outline,
        'No shortages detected',
        'All equipment has sufficient stock for existing bookings.',
        Colors.green,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: shortages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _ShortageCard(shortage: shortages[i]),
    );
  }
}

class _ShortageCard extends StatelessWidget {
  const _ShortageCard({required this.shortage});
  final _Shortage shortage;

  @override
  Widget build(BuildContext context) {
    final critical = shortage.isCritical;
    final borderColor =
        critical ? const Color(0xffdc2626) : const Color(0xffea580c);
    final bgColor =
        critical ? const Color(0xfffff1f2) : const Color(0xfffff7ed);

    return Card(
      elevation: 0,
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  critical ? Icons.error_outline : Icons.warning_amber_outlined,
                  color: borderColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shortage.equipmentName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: borderColor,
                      fontSize: 15,
                    ),
                  ),
                ),
                _badge(shortage.category, const Color(0xff4f46e5)),
              ],
            ),
            const SizedBox(height: 10),
            _row(Icons.calendar_today_outlined,
                '${_fmt(shortage.start)} → ${_fmt(shortage.end)}'),
            const SizedBox(height: 4),
            _row(Icons.event_outlined,
                'Booking: ${shortage.bookingEventName}'),
            const SizedBox(height: 4),
            _row(
              Icons.inventory_2_outlined,
              'Available: ${shortage.totalAvailable}  ·  '
              'Reserved across all bookings: ${shortage.totalReserved}',
            ),
            if (shortage.isCritical) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xffdc2626).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'DEFICIT: ${shortage.deficit} unit${shortage.deficit == 1 ? '' : 's'} over stock',
                  style: const TextStyle(
                    color: Color(0xffdc2626),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2 — Conflicting bookings
// ---------------------------------------------------------------------------

class _ConflictsTab extends StatelessWidget {
  const _ConflictsTab({required this.conflicts});
  final List<_BookingConflict> conflicts;

  @override
  Widget build(BuildContext context) {
    if (conflicts.isEmpty) {
      return _emptyTab(
        Icons.check_circle_outline,
        'No booking conflicts',
        'No two active bookings share the same equipment beyond available stock.',
        Colors.green,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: conflicts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _ConflictCard(conflict: conflicts[i]),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.conflict});
  final _BookingConflict conflict;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xfffff7ed),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side:
            BorderSide(color: const Color(0xffea580c).withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.compare_arrows_rounded,
                    color: Color(0xffea580c), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Booking Conflict',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xffea580c),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Booking A
            _bookingChip(
              conflict.bookingAName,
              conflict.bookingAStart,
              conflict.bookingAEnd,
              const Color(0xff4f46e5),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: Icon(Icons.swap_vert, color: Color(0xffea580c)),
              ),
            ),
            // Booking B
            _bookingChip(
              conflict.bookingBName,
              conflict.bookingBStart,
              conflict.bookingBEnd,
              const Color(0xff0891b2),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Text(
              'Contested equipment:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Color(0xff374151),
              ),
            ),
            const SizedBox(height: 6),
            ...conflict.sharedEquipment.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 14, color: Color(0xff667085)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        '${item.reservedByA} + ${item.reservedByB} = '
                        '${item.totalReserved} / ${item.available} avail',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xffdc2626),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _bookingChip(
      String name, DateTime start, DateTime end, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.event_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: color,
                        fontSize: 13)),
                Text('${_fmt(start)} – ${_fmt(end)}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xff667085))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3 — Unavailable time windows
// ---------------------------------------------------------------------------

class _UnavailableWindowsTab extends StatelessWidget {
  const _UnavailableWindowsTab({required this.windows});
  final List<_UnavailableWindow> windows;

  @override
  Widget build(BuildContext context) {
    if (windows.isEmpty) {
      return _emptyTab(
        Icons.check_circle_outline,
        'No fully-booked windows',
        'All equipment has open availability in current booking periods.',
        Colors.green,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: windows.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _WindowCard(window: windows[i]),
    );
  }
}

class _WindowCard extends StatelessWidget {
  const _WindowCard({required this.window});
  final _UnavailableWindow window;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xfff5f3ff),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side:
            BorderSide(color: const Color(0xff7c3aed).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.block_outlined,
                    color: Color(0xff7c3aed), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    window.equipmentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xff7c3aed),
                      fontSize: 15,
                    ),
                  ),
                ),
                _badge(window.category, const Color(0xff7c3aed)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${window.available} unit${window.available == 1 ? '' : 's'} total',
              style: const TextStyle(fontSize: 12, color: Color(0xff667085)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Fully-booked periods:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Color(0xff374151),
              ),
            ),
            const SizedBox(height: 6),
            ...window.intervals.map((interval) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.do_not_disturb_alt_outlined,
                          size: 14, color: Color(0xff7c3aed)),
                      const SizedBox(width: 6),
                      Text(
                        '${_fmt(interval.start)} – ${_fmt(interval.end)}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '(${interval.bookingName})',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xff667085)),
                        ),
                      ),
                    ],
                  ),
                )),
            if (window.alternatives.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.tips_and_updates_outlined,
                      size: 15, color: Color(0xff059669)),
                  const SizedBox(width: 6),
                  const Text(
                    'Available windows (alternatives):',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Color(0xff059669),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...window.alternatives.map((alt) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 13, color: Color(0xff059669)),
                        const SizedBox(width: 6),
                        Text(
                          '${_fmt(alt.start)} – ${_fmt(alt.end)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xff059669),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xffd1fae5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Available',
                            style: TextStyle(
                                fontSize: 10,
                                color: Color(0xff059669),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

Widget _emptyTab(
    IconData icon, String title, String message, Color color) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: color),
          const SizedBox(height: 14),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xff667085), height: 1.5),
          ),
        ],
      ),
    ),
  );
}

Widget _badge(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );

Widget _row(IconData icon, String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xff98a2b3)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xff374151))),
        ),
      ],
    );

String _fmt(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
