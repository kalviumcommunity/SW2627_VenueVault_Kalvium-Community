import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'new_booking_page.dart';

class BookingManagementPage extends StatelessWidget {
  const BookingManagementPage({super.key});

  CollectionReference<Map<String, dynamic>> get _bookings =>
      FirebaseFirestore.instance.collection('bookings');

  Future<void> _cancel(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: const Text(
          'Its equipment will become available for those dates again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final requestId = _bookings.doc().id;
      await FirebaseFunctions.instance.httpsCallable('cancelBooking').call({
        'bookingId': id,
        'requestId': requestId,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Booking cancelled. Its equipment is available for those dates again.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not cancel booking: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const NewBookingPage())),
        icon: const Icon(Icons.add),
        label: const Text('New booking'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _bookings.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load bookings.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = [...?snapshot.data?.docs];
          docs.sort((a, b) {
            final aDate = _date(a.data()['startDate']);
            final bDate = _date(b.data()['startDate']);
            return (aDate ?? DateTime(1900)).compareTo(bDate ?? DateTime(1900));
          });
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No bookings yet. Create one to get started.'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final document = docs[index];
              final data = document.data();
              final status = (data['status'] as String? ?? 'confirmed');
              final cancelled = status.toLowerCase() == 'cancelled';
              final start = _date(data['startDate']);
              final end = _date(data['endDate']);
              final items = data['items'] is List
                  ? (data['items'] as List).length
                  : 0;
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showDetails(context, data),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data['eventName'] as String? ?? 'Event booking',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            _StatusChip(status: status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data['customerName'] as String? ?? 'Customer not set',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatDate(start)} – ${_formatDate(end)}  ·  '
                          '${data['venue'] as String? ?? 'Venue not set'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text('$items equipment item${items == 1 ? '' : 's'}'),
                        if (!cancelled) ...[
                          const Divider(height: 24),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => NewBookingPage(
                                      initialBookingId: document.id,
                                      initialBooking: data,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text('Edit'),
                              ),
                              TextButton.icon(
                                onPressed: () => _cancel(context, document.id),
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  size: 18,
                                ),
                                label: const Text('Cancel booking'),
                              ),
                            ],
                          ),
                        ],
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

  void _showDetails(BuildContext context, Map<String, dynamic> data) {
    final rawItems = data['items'];
    final items = rawItems is List ? rawItems : const [];
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['eventName'] as String? ?? 'Booking details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detail('Customer', data['customerName']),
              _detail('Phone', data['customerPhone']),
              _detail('Venue', data['venue']),
              _detail(
                'Dates',
                '${_formatDate(_date(data['startDate']))} – ${_formatDate(_date(data['endDate']))}',
              ),
              _detail('Staff', data['staffName']),
              const SizedBox(height: 10),
              const Text(
                'Equipment',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...items.map((item) {
                if (item is! Map) return const SizedBox.shrink();
                return Text(
                  '• ${item['name'] ?? item['equipmentId'] ?? 'Equipment'} × ${item['quantity'] ?? 1}',
                );
              }),
              if ((data['notes'] as String? ?? '').isNotEmpty)
                _detail('Notes', data['notes']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, Object? value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text('$label: ${value ?? '—'}'),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cancelled = status.toLowerCase() == 'cancelled';
    return Chip(
      label: Text(status),
      visualDensity: VisualDensity.compact,
      backgroundColor: cancelled ? Colors.grey.shade200 : Colors.green.shade50,
      side: BorderSide.none,
    );
  }
}

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Date not set';
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}
