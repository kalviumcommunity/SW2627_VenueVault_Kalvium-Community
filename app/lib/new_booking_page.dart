import 'package:flutter/material.dart';

class NewBookingPage extends StatefulWidget {
  const NewBookingPage({super.key});

  @override
  State<NewBookingPage> createState() => _NewBookingPageState();
}

class _NewBookingPageState extends State<NewBookingPage> {
  DateTimeRange? _selectedDates;
  final Set<String> _selectedInventory = {};

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
                : _InventoryReadyState(
                    selectedInventory: _selectedInventory,
                    onToggleItem: (itemName) {
                      setState(() {
                        if (!_selectedInventory.add(itemName)) {
                          _selectedInventory.remove(itemName);
                        }
                      });
                    },
                  ),
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
  const _InventoryReadyState({
    required this.selectedInventory,
    required this.onToggleItem,
  });

  final Set<String> selectedInventory;
  final ValueChanged<String> onToggleItem;

  @override
  Widget build(BuildContext context) {
    final inventory = [
      (
        name: 'Banquet Table',
        category: 'Furniture',
        details: '6 ft rectangular table',
        available: 24,
        icon: Icons.table_restaurant_outlined,
        color: const Color(0xff4f46e5),
      ),
      (
        name: 'Chiavari Chair',
        category: 'Seating',
        details: 'Natural wood, padded seat',
        available: 120,
        icon: Icons.chair_outlined,
        color: const Color(0xff0f766e),
      ),
      (
        name: 'LED Uplight',
        category: 'Lighting',
        details: 'Wireless RGB uplight',
        available: 36,
        icon: Icons.lightbulb_outline_rounded,
        color: const Color(0xffc2410c),
      ),
      (
        name: 'Portable Speaker',
        category: 'Audio',
        details: 'Battery-powered PA speaker',
        available: 8,
        icon: Icons.speaker_group_outlined,
        color: const Color(0xff7e22ce),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available inventory',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reserve what you need for your selected dates.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (selectedInventory.isNotEmpty)
              Chip(
                avatar: const Icon(Icons.check_circle_outline, size: 18),
                label: Text('${selectedInventory.length} added'),
                backgroundColor: const Color(0xffe0e7ff),
                side: BorderSide.none,
              ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          decoration: InputDecoration(
            hintText: 'Search equipment',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Filter inventory',
            ),
          ),
        ),
        const SizedBox(height: 20),
        ...inventory.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _InventoryCard(
              name: item.name,
              category: item.category,
              details: item.details,
              available: item.available,
              icon: item.icon,
              color: item.color,
              isSelected: selectedInventory.contains(item.name),
              onToggle: () => onToggleItem(item.name),
            ),
          ),
        ),
      ],
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.name,
    required this.category,
    required this.details,
    required this.available,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onToggle,
  });

  final String name;
  final String category;
  final String details;
  final int available;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? color : const Color(0xffe5e7eb),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 27),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$category  •  $details',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '$available available',
                    style: TextStyle(
                      color: available < 10
                          ? Colors.orange.shade800
                          : Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onToggle,
              tooltip: isSelected ? 'Remove from booking' : 'Add to booking',
              icon: Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                color: isSelected ? color : Colors.grey.shade600,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
