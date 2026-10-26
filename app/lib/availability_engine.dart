import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Calculates equipment stock for an inclusive event date range.
///
/// Booking documents should store `startDate` and `endDate` timestamps and an
/// `items` list containing `{equipmentId, quantity}` entries. Cancelled
/// bookings are ignored. The engine also accepts `equipment` as the item list
/// field for compatibility with early booking documents.
class AvailabilityEngine {
  const AvailabilityEngine._();

  static Map<String, int> calculate({
    required DateTimeRange dates,
    required Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> equipment,
    required Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> bookings,
    String? ignoreBookingId,
  }) {
    final reserved = <String, int>{};
    final requestedStart = _dateOnly(dates.start);
    final requestedEnd = _dateOnly(dates.end);

    for (final booking in bookings) {
      if (booking.id == ignoreBookingId) continue;
      final data = booking.data();
      final status = (data['status'] as String? ?? '').toLowerCase();
      if (const {
        'cancelled',
        'rejected',
        'declined',
        'returned',
        'completed',
      }.contains(status)) {
        continue;
      }
      final start = _readDate(data['startDate'] ?? data['eventStart']);
      final end = _readDate(data['endDate'] ?? data['eventEnd']);
      if (start == null || end == null || end.isBefore(start)) continue;

      // Date ranges are inclusive because the booking form selects event days.
      if (_dateOnly(start).isAfter(requestedEnd) ||
          _dateOnly(end).isBefore(requestedStart)) {
        continue;
      }

      final items = data['items'] ?? data['equipment'];
      if (items is! List) continue;
      for (final item in items) {
        if (item is! Map) continue;
        final id = (item['equipmentId'] ?? item['id'])?.toString();
        final quantity = item['quantity'];
        if (id == null || quantity is! num || quantity <= 0) continue;
        reserved.update(id, (current) => current + quantity.toInt(),
            ifAbsent: () => quantity.toInt());
      }
    }

    return {
      for (final item in equipment)
        item.id: _availableCount(item.data(), reserved[item.id] ?? 0),
    };
  }

  static int _availableCount(Map<String, dynamic> data, int reserved) {
    final status = (data['status'] as String? ?? 'Available').toLowerCase();
    if (const {'damaged', 'under maintenance', 'retired'}.contains(status)) {
      return 0;
    }
    // availableQuantity is the catalog's usable stock; fall back to total for
    // older records that do not have the field.
    final available = (data['availableQuantity'] as num?)?.toInt() ??
        (data['totalQuantity'] as num?)?.toInt() ??
        0;
    final unavailable =
        (data['unavailableQuantity'] as num?)?.toInt() ?? 0;
    final usable = (available - unavailable).clamp(0, available);
    return (usable - reserved).clamp(0, usable);
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
