import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'availability_engine.dart';

class NewBookingPage extends StatefulWidget {
  const NewBookingPage({super.key});

  @override
  State<NewBookingPage> createState() => _NewBookingPageState();
}

class _NewBookingPageState extends State<NewBookingPage> {
  DateTimeRange? _selectedDates;
  final Set<String> _selectedInventory = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _equipmentStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _bookingStream;

  @override
  void initState() {
    super.initState();
    _equipmentStream = FirebaseFirestore.instance
        .collection('equipment')
        .snapshots();
    _bookingStream = FirebaseFirestore.instance
        .collection('bookings')
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
                    equipmentStream: _equipmentStream,
                    bookingStream: _bookingStream,
                    selectedDates: _selectedDates!,
                    selectedInventory: _selectedInventory,
                    searchController: _searchController,
                    searchText: _searchText,
                    onSearchChanged: (value) =>
                        setState(() => _searchText = value.trim()),
                    onToggleItem: (equipmentId) {
                      setState(() {
                        if (!_selectedInventory.add(equipmentId)) {
                          _selectedInventory.remove(equipmentId);
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
    required this.equipmentStream,
    required this.bookingStream,
    required this.selectedDates,
    required this.selectedInventory,
    required this.searchController,
    required this.searchText,
    required this.onSearchChanged,
    required this.onToggleItem,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> equipmentStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> bookingStream;
  final DateTimeRange selectedDates;
  final Set<String> selectedInventory;
  final TextEditingController searchController;
  final String searchText;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onToggleItem;

  @override
  Widget build(BuildContext context) {
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
                    'Stock remaining after reservations for the selected dates.',
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
          controller: searchController,
          onChanged: onSearchChanged,
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
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: equipmentStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _InventoryMessage(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load equipment',
                message: 'Check Firestore access rules and your internet connection, then try again.',
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: bookingStream,
              builder: (context, bookingSnapshot) {
                if (bookingSnapshot.hasError) {
                  return _InventoryMessage(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not check reservations',
                    message: 'Check Firestore access rules and try again.',
                  );
                }
                if (bookingSnapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                final availability = AvailabilityEngine.calculate(
                  dates: selectedDates,
                  equipment: docs,
                  bookings: bookingSnapshot.data?.docs ?? [],
                );
                final query = searchText.toLowerCase();
                final equipment = docs.where((document) {
                  final data = document.data();
                  final available = availability[document.id] ?? 0;
                  if (available <= 0) {
                    return false;
                  }
                  if (query.isEmpty) return true;
                  return (data['name'] as String? ?? '').toLowerCase().contains(
                        query,
                      ) ||
                      (data['category'] as String? ?? '')
                          .toLowerCase()
                          .contains(query) ||
                      (data['description'] as String? ?? '')
                          .toLowerCase()
                          .contains(query);
                }).toList()..sort((a, b) {
                  final aName = a.data()['name'] as String? ?? '';
                  final bName = b.data()['name'] as String? ?? '';
                  return aName.toLowerCase().compareTo(bName.toLowerCase());
                });

            if (equipment.isEmpty) {
              return _InventoryMessage(
                icon: query.isEmpty
                    ? Icons.inventory_2_outlined
                    : Icons.search_off,
                title: query.isEmpty
                    ? 'No available equipment'
                    : 'No matching equipment',
                message: query.isEmpty
                    ? 'Add equipment to the catalog or update its available quantity.'
                    : 'Try another search term.',
              );
            }

            return Column(
              children: equipment.map((document) {
                final data = document.data();
                final name = data['name'] as String? ?? 'Unnamed equipment';
                final category = data['category'] as String? ?? 'Other';
                final description = data['description'] as String? ?? '';
                final available = availability[document.id] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _InventoryCard(
                    name: name,
                    category: category,
                    details: description.isEmpty
                        ? (data['warehouseLocation'] as String? ?? '')
                        : description,
                    available: available,
                    icon: _iconForCategory(category),
                    color: _colorForCategory(category),
                    isSelected: selectedInventory.contains(document.id),
                    onToggle: () => onToggleItem(document.id),
                  ),
                );
              }).toList(),
            );
              },
            );
          },
        ),
      ],
    );
  }

  IconData _iconForCategory(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('speaker') ||
        normalized.contains('audio') ||
        normalized.contains('microphone') ||
        normalized.contains('amplifier')) {
      return Icons.speaker_group_outlined;
    }
    if (normalized.contains('light')) return Icons.lightbulb_outline_rounded;
    if (normalized.contains('chair') ||
        normalized.contains('table') ||
        normalized.contains('sofa')) {
      return Icons.chair_outlined;
    }
    if (normalized.contains('projector')) return Icons.videocam_outlined;
    if (normalized.contains('generator')) return Icons.bolt_outlined;
    return Icons.inventory_2_outlined;
  }

  Color _colorForCategory(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('audio') || normalized.contains('speaker')) {
      return const Color(0xff7e22ce);
    }
    if (normalized.contains('light')) return const Color(0xffc2410c);
    if (normalized.contains('chair') || normalized.contains('table')) {
      return const Color(0xff0f766e);
    }
    return const Color(0xff4f46e5);
  }
}

class _InventoryMessage extends StatelessWidget {
  const _InventoryMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 18),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
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
