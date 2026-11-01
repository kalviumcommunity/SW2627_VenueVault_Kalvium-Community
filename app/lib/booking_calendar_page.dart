import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'new_booking_page.dart';
import 'role_permissions.dart';

class BookingCalendarPage extends StatefulWidget {
  const BookingCalendarPage({super.key});

  @override
  State<BookingCalendarPage> createState() => _BookingCalendarPageState();
}

class _BookingCalendarPageState extends State<BookingCalendarPage> {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _compactWeekdays = ['M', 'Tu', 'W', 'Th', 'F', 'Sa', 'Su'];

  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  bool _showCancelled = false;
  late final Future<IdTokenResult?> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = _loadRole();
  }

  Future<IdTokenResult?> _loadRole() async {
    final user = FirebaseAuth.instance.currentUser;
    return user?.getIdTokenResult(true);
  }

  void _changeMonth(int amount) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + amount);
      _selectedDate = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IdTokenResult?>(
      future: _roleFuture,
      builder: (context, tokenSnapshot) {
        if (tokenSnapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Could not load calendar permissions.')),
          );
        }
        if (!tokenSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final role = tokenSnapshot.data?.claims?['role'] as String?;
        if (!hasRolePermission(role, 'bookings.view')) {
          return const Scaffold(
            body: Center(child: Text('You do not have access to bookings.')),
          );
        }
        return _buildCalendar(
          context,
          canCreate: hasRolePermission(role, 'bookings.create'),
          canEdit: hasRolePermission(role, 'bookings.edit'),
        );
      },
    );
  }

  Widget _buildCalendar(
    BuildContext context, {
    required bool canCreate,
    required bool canEdit,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking calendar'),
        actions: [
          IconButton(
            tooltip: _showCancelled ? 'Hide cancelled bookings' : 'Show cancelled bookings',
            onPressed: () => setState(() => _showCancelled = !_showCancelled),
            icon: Icon(_showCancelled ? Icons.event_busy : Icons.event_available_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NewBookingPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New booking'),
      )
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load calendar bookings.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookings = (snapshot.data?.docs ?? []).map(_CalendarBooking.fromDocument)
              .where((booking) => booking.start != null && booking.end != null)
              .where((booking) => _showCancelled || !booking.isCancelled)
              .toList()
            ..sort((a, b) => a.start!.compareTo(b.start!));

          return LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final days = _monthDays(_visibleMonth);
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(compact ? 12 : 24, 16, compact ? 12 : 24, 100),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CalendarHeader(
                          month: _visibleMonth,
                          activeCount: bookings.where((b) => !b.isCancelled).length,
                          showCancelled: _showCancelled,
                          onPrevious: () => _changeMonth(-1),
                          onNext: () => _changeMonth(1),
                          onToday: () => setState(() {
                            _visibleMonth = DateTime.now();
                            _selectedDate = DateUtils.dateOnly(DateTime.now());
                          }),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 0,
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              Row(
                                children: _weekdays
                                    .map((day) => Expanded(
                                          child: SizedBox(
                                            height: 42,
                                            child: Center(
                                              child: Text(
                                                compact ? _compactWeekdays[_weekdays.indexOf(day)] : day,
                                                style: const TextStyle(
                                                  color: Color(0xff667085),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                              const Divider(height: 1, thickness: 1),
                              for (var week = 0; week < days.length ~/ 7; week++)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    for (var weekday = 0; weekday < 7; weekday++)
                                      Expanded(
                                        child: _CalendarDayCell(
                                          date: days[week * 7 + weekday],
                                          visibleMonth: _visibleMonth,
                                          selectedDate: _selectedDate,
                                          bookings: bookings
                                              .where((booking) => booking.includes(days[week * 7 + weekday]))
                                              .toList(),
                                          compact: compact,
                                          onTap: () => setState(() {
                                            _selectedDate = days[week * 7 + weekday];
                                            if (days[week * 7 + weekday].month != _visibleMonth.month ||
                                                days[week * 7 + weekday].year != _visibleMonth.year) {
                                              _visibleMonth = DateTime(days[week * 7 + weekday].year, days[week * 7 + weekday].month);
                                            }
                                          }),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _SelectedDayBookings(
                          date: _selectedDate,
                          bookings: bookings.where((booking) => booking.includes(_selectedDate)).toList(),
                          compact: compact,
                          canEdit: canEdit,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.month,
    required this.activeCount,
    required this.showCancelled,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime month;
  final int activeCount;
  final bool showCancelled;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 560;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reservations and events',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('$activeCount active reservation${activeCount == 1 ? '' : 's'}${showCancelled ? ' · cancelled included' : ''}',
            style: const TextStyle(color: Color(0xff667085))),
        const SizedBox(height: 14),
        Row(
          children: [
            IconButton.filledTonal(onPressed: onPrevious, tooltip: 'Previous month', icon: const Icon(Icons.chevron_left)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _monthName(month),
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(onPressed: onToday, child: const Text('Today')),
            const SizedBox(width: 4),
            IconButton.filledTonal(onPressed: onNext, tooltip: 'Next month', icon: const Icon(Icons.chevron_right)),
          ],
        ),
      ],
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.visibleMonth,
    required this.selectedDate,
    required this.bookings,
    required this.compact,
    required this.onTap,
  });

  final DateTime date;
  final DateTime visibleMonth;
  final DateTime selectedDate;
  final List<_CalendarBooking> bookings;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = DateUtils.isSameDay(date, selectedDate);
    final today = DateUtils.isSameDay(date, DateTime.now());
    final inMonth = date.month == visibleMonth.month && date.year == visibleMonth.year;
    final active = bookings.where((b) => !b.isCancelled).length;
    final cancelled = bookings.length - active;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: compact ? 58 : 92,
        decoration: BoxDecoration(
          color: selected ? const Color(0xffeef2ff) : Colors.white,
          border: Border(
            right: const BorderSide(color: Color(0xffeaecf0)),
            bottom: const BorderSide(color: Color(0xffeaecf0)),
            left: selected ? const BorderSide(color: Color(0xff4f46e5), width: 2) : BorderSide.none,
          ),
        ),
        padding: EdgeInsets.all(compact ? 4 : 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: compact ? 22 : 26,
                  height: compact ? 22 : 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: today ? const Color(0xff4f46e5) : Colors.transparent,
                  ),
                  child: Text('${date.day}', style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: selected || today ? FontWeight.bold : FontWeight.w500,
                    color: today ? Colors.white : inMonth ? const Color(0xff344054) : const Color(0xffb0b6c1),
                  )),
                ),
                const Spacer(),
                if (compact && bookings.isNotEmpty)
                  Text('$active${cancelled > 0 ? '+$cancelled' : ''}',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                          color: cancelled > 0 && active == 0 ? const Color(0xff98a2b3) : const Color(0xff4f46e5))),
              ],
            ),
            if (!compact && bookings.isNotEmpty) ...[
              const SizedBox(height: 3),
              ...bookings.take(2).map((booking) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: booking.isCancelled ? const Color(0xfff2f4f7) : const Color(0xffeef2ff),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        booking.eventName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, height: 1.2,
                            color: booking.isCancelled ? const Color(0xff667085) : const Color(0xff4338ca),
                            fontWeight: FontWeight.w600,
                            decoration: booking.isCancelled ? TextDecoration.lineThrough : null),
                      ),
                    ),
                  )),
              if (bookings.length > 2)
                Text('+${bookings.length - 2} more', style: const TextStyle(fontSize: 9, color: Color(0xff667085))),
            ],
            if (compact && bookings.isNotEmpty) ...[
              const Spacer(),
              Row(children: [
                if (active > 0) _bookingDot(const Color(0xff4f46e5)),
                if (cancelled > 0) ...[
                  if (active > 0) const SizedBox(width: 3),
                  _bookingDot(const Color(0xff98a2b3)),
                ],
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _SelectedDayBookings extends StatelessWidget {
  const _SelectedDayBookings({required this.date, required this.bookings, required this.compact, required this.canEdit});

  final DateTime date;
  final List<_CalendarBooking> bookings;
  final bool compact;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.event_note_outlined, color: Color(0xff4f46e5)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_longDate(date), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ),
            Text('${bookings.length} event${bookings.length == 1 ? '' : 's'}', style: const TextStyle(color: Color(0xff667085))),
          ],
        ),
        const SizedBox(height: 12),
        if (bookings.isEmpty)
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(children: [
                const Icon(Icons.event_available_outlined, color: Color(0xff98a2b3)),
                const SizedBox(width: 12),
                Expanded(child: Text('Nothing scheduled for ${_shortDate(date)}.', style: const TextStyle(color: Color(0xff667085)))),
              ]),
            ),
          )
        else
          ...bookings.map((booking) => _BookingCard(booking: booking, compact: compact, canEdit: canEdit)),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.compact, required this.canEdit});
  final _CalendarBooking booking;
  final bool compact;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final color = booking.isCancelled ? const Color(0xff98a2b3) : const Color(0xff4f46e5);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showBookingDetails(context, booking, canEdit: canEdit),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 4, height: 42, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(booking.eventName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text('${booking.customerName} · ${booking.venue}', style: const TextStyle(color: Color(0xff667085))),
                ])),
                _StatusBadge(status: booking.status),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Color(0xff98a2b3)),
              ]),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _InfoLabel(icon: Icons.date_range_outlined, text: '${_shortDate(booking.start!)} – ${_shortDate(booking.end!)}'),
                  _InfoLabel(icon: Icons.inventory_2_outlined, text: '${booking.items.length} equipment item${booking.items.length == 1 ? '' : 's'}'),
                  if (booking.staffName.isNotEmpty) _InfoLabel(icon: Icons.badge_outlined, text: booking.staffName),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 6),
                const Text('View booking details', style: TextStyle(fontSize: 12, color: Color(0xff4f46e5), fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLabel extends StatelessWidget {
  const _InfoLabel({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: const Color(0xff98a2b3)),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 12, color: Color(0xff475467))),
      ]);
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cancelled = const {'cancelled', 'rejected', 'declined'}
        .contains(status.toLowerCase());
    final color = cancelled ? const Color(0xff667085) : const Color(0xff027a48);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _CalendarBooking {
  const _CalendarBooking({required this.id, required this.data, required this.start, required this.end});

  final String id;
  final Map<String, dynamic> data;
  final DateTime? start;
  final DateTime? end;

  factory _CalendarBooking.fromDocument(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    return _CalendarBooking(
      id: document.id,
      data: data,
      start: _readDate(data['startDate'] ?? data['eventStart']),
      end: _readDate(data['endDate'] ?? data['eventEnd']),
    );
  }

  String get eventName => (data['eventName'] as String? ?? '').trim().isEmpty ? 'Event booking' : data['eventName'] as String;
  String get customerName => (data['customerName'] as String? ?? '').trim().isEmpty ? 'Customer not set' : data['customerName'] as String;
  String get venue => (data['venue'] as String? ?? '').trim().isEmpty ? 'Venue not set' : data['venue'] as String;
  String get staffName => data['staffName'] as String? ?? '';
  String get status => data['status'] as String? ?? 'confirmed';
  bool get isCancelled => const {'cancelled', 'rejected', 'declined'}.contains(status.toLowerCase());
  List<Map<String, dynamic>> get items {
    final raw = data['items'] ?? data['equipment'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  bool includes(DateTime date) {
    if (start == null || end == null) return false;
    final day = DateUtils.dateOnly(date);
    return !day.isBefore(DateUtils.dateOnly(start!)) && !day.isAfter(DateUtils.dateOnly(end!));
  }
}

void _showBookingDetails(BuildContext context, _CalendarBooking booking, {required bool canEdit}) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(booking.eventName),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            _detail('Status', booking.status),
            _detail('Customer', booking.customerName),
            if ((booking.data['customerPhone'] as String? ?? '').isNotEmpty) _detail('Phone', booking.data['customerPhone']),
            _detail('Venue', booking.venue),
            _detail('Dates', '${_shortDate(booking.start!)} – ${_shortDate(booking.end!)}'),
            _detail('Assigned staff', booking.staffName.isEmpty ? 'Not assigned' : booking.staffName),
            const SizedBox(height: 14),
            const Text('Reserved equipment', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (booking.items.isEmpty)
              const Text('No equipment listed', style: TextStyle(color: Color(0xff667085)))
            else
              ...booking.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text('• ${item['name'] ?? item['equipmentId'] ?? 'Equipment'} × ${item['quantity'] ?? 1}'),
                  )),
            if ((booking.data['notes'] as String? ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _detail('Notes', booking.data['notes']),
            ],
          ]),
        ),
      ),
      actions: [
        if (canEdit && !booking.isCancelled)
          TextButton.icon(
            onPressed: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(MaterialPageRoute<void>(
                builder: (_) => NewBookingPage(initialBookingId: booking.id, initialBooking: booking.data),
              ));
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit booking'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    ),
  );
}

Widget _detail(String label, Object? value) => Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text('$label: ${value ?? '—'}'),
    );

List<DateTime> _monthDays(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  final mondayOffset = first.weekday - DateTime.monday;
  final dayCount = DateTime(month.year, month.month + 1, 0).day;
  final weeks = ((mondayOffset + dayCount) / 7).ceil();
  final gridStart = first.subtract(Duration(days: mondayOffset));
  return List.generate(weeks * 7, (index) => DateUtils.dateOnly(gridStart.add(Duration(days: index))));
}

DateTime? _readDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _monthName(DateTime date) => '${_monthNames[date.month - 1]} ${date.year}';
String _shortDate(DateTime? date) => date == null ? 'Date not set' : '${date.day} ${_monthNames[date.month - 1].substring(0, 3)} ${date.year}';
String _longDate(DateTime date) => '${_weekdayNames[date.weekday - 1]}, ${date.day} ${_monthNames[date.month - 1]} ${date.year}';

Widget _bookingDot(Color color) => Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle));

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
