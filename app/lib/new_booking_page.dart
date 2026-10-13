import 'package:flutter/material.dart';

class NewBookingPage extends StatefulWidget {
  const NewBookingPage({super.key});

  @override
  State<NewBookingPage> createState() => _NewBookingPageState();
}

class _NewBookingPageState extends State<NewBookingPage> {
  DateTimeRange? _selectedDates;

  Future<void> _selectDates() async {
    final now = DateTime.now();
    final selectedDates = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: _selectedDates,
      helpText: 'Select event dates',
      saveText: 'Done',
    );

    if (selectedDates != null && mounted) {
      setState(() => _selectedDates = selectedDates);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'New Booking',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: 'Booking cart',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _DateSelectionPanel(
            selectedDates: _selectedDates,
            onSelectDates: _selectDates,
          ),
          Expanded(
            child: _selectedDates == null
                ? const _InventoryHiddenState()
                : const _InventoryReadyState(),
          ),
        ],
      ),
    );
  }
}

class _DateSelectionPanel extends StatelessWidget {
  const _DateSelectionPanel({
    required this.selectedDates,
    required this.onSelectDates,
  });

  final DateTimeRange? selectedDates;
  final VoidCallback onSelectDates;

  @override
  Widget build(BuildContext context) {
    final dateLabel = selectedDates == null
        ? 'Tap to select dates...'
        : '${_formatDate(selectedDates!.start)} - '
              '${_formatDate(selectedDates!.end)}';

    return Container(
      width: double.infinity,
      color: const Color(0xFFEFF1FF),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.indigo,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '1',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Event Dates First',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.indigo,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Dates must be selected to calculate accurate inventory '
                      'and prevent double-booking.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 240,
              child: OutlinedButton.icon(
                onPressed: onSelectDates,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(dateLabel),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryHiddenState extends StatelessWidget {
  const _InventoryHiddenState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey.shade200,
              child: Icon(
                Icons.inventory_2_outlined,
                size: 30,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Inventory Hidden',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Select dates above to see what equipment is actually '
              'available for your event timeframe.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryReadyState extends StatelessWidget {
  const _InventoryReadyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Available inventory will appear here.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
