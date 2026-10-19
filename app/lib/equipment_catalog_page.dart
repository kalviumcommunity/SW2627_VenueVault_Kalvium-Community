import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const _categories = <String>[
  'Audio systems',
  'Speakers',
  'Microphones',
  'Amplifiers',
  'LED lights',
  'Stage lighting',
  'Tables',
  'Chairs',
  'Sofas',
  'Projectors',
  'Generators',
  'Accessories and cables',
  'Other',
];

const _statuses = <String>[
  'Available',
  'Reserved',
  'Dispatched',
  'In use',
  'Under maintenance',
  'Damaged',
  'Retired',
];

const _conditions = <String>['Excellent', 'Good', 'Fair', 'Poor'];

class EquipmentItem {
  const EquipmentItem({
    required this.id,
    required this.name,
    required this.category,
    required this.totalQuantity,
    required this.availableQuantity,
    required this.condition,
    required this.status,
    required this.warehouseLocation,
    required this.rentalPrice,
    required this.description,
    required this.maintenanceNotes,
  });

  final String id;
  final String name;
  final String category;
  final int totalQuantity;
  final int availableQuantity;
  final String condition;
  final String status;
  final String warehouseLocation;
  final double rentalPrice;
  final String description;
  final String maintenanceNotes;

  factory EquipmentItem.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return EquipmentItem(
      id: document.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? 'Other',
      totalQuantity: (data['totalQuantity'] as num?)?.toInt() ?? 0,
      availableQuantity: (data['availableQuantity'] as num?)?.toInt() ?? 0,
      condition: data['condition'] as String? ?? 'Good',
      status: data['status'] as String? ?? 'Available',
      warehouseLocation: data['warehouseLocation'] as String? ?? '',
      rentalPrice: (data['rentalPrice'] as num?)?.toDouble() ?? 0,
      description: data['description'] as String? ?? '',
      maintenanceNotes: data['maintenanceNotes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'category': category,
    'totalQuantity': totalQuantity,
    'availableQuantity': availableQuantity,
    'condition': condition,
    'status': status,
    'warehouseLocation': warehouseLocation,
    'rentalPrice': rentalPrice,
    'description': description,
    'maintenanceNotes': maintenanceNotes,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class EquipmentCatalogPage extends StatefulWidget {
  const EquipmentCatalogPage({super.key});

  @override
  State<EquipmentCatalogPage> createState() => _EquipmentCatalogPageState();
}

class _EquipmentCatalogPageState extends State<EquipmentCatalogPage> {
  final _items = FirebaseFirestore.instance.collection('equipment');
  final _searchController = TextEditingController();
  String _categoryFilter = 'All categories';
  String _statusFilter = 'All statuses';
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEditor([EquipmentItem? item]) async {
    final result = await showDialog<EquipmentItem>(
      context: context,
      builder: (_) => _EquipmentEditor(item: item),
    );
    if (result == null) return;

    try {
      if (item == null) {
        await _items.add(result.toFirestore());
      } else {
        await _items.doc(item.id).update(result.toFirestore());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item == null ? 'Equipment added.' : 'Equipment updated.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      _showError(error);
    }
  }

  Future<void> _retire(EquipmentItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retire equipment?'),
        content: Text(
          '${item.name} will be marked retired and excluded from availability.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retire item'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _items.doc(item.id).update({
        'status': 'Retired',
        'availableQuantity': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      _showError(error);
    }
  }

  void _showError(FirebaseException error) {
    if (!mounted) return;
    final message = error.code == 'permission-denied'
        ? 'You do not have permission to manage equipment.'
        : error.code == 'unavailable'
        ? 'Could not reach Firestore. Check your connection and database setup.'
        : 'Could not save equipment: ${error.message ?? error.code}';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Equipment catalog',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Add equipment'),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _items.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _CatalogMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load equipment',
              subtitle:
                  snapshot.error is FirebaseException &&
                      (snapshot.error as FirebaseException).code ==
                          'permission-denied'
                  ? 'Firestore access was denied. Check the project’s Firestore security rules.'
                  : 'Check that Firestore is enabled for the connected Firebase project, then try again.',
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allItems =
              (snapshot.data?.docs ?? [])
                  .map(EquipmentItem.fromDocument)
                  .toList()
                ..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                );
          final items = allItems.where(_matchesFilters).toList();
          return Column(
            children: [
              _overview(allItems),
              _filters(),
              Expanded(
                child: items.isEmpty
                    ? _CatalogMessage(
                        icon: allItems.isEmpty
                            ? Icons.inventory_2_outlined
                            : Icons.search_off,
                        title: allItems.isEmpty
                            ? 'Your catalog is empty'
                            : 'No matching equipment',
                        subtitle: allItems.isEmpty
                            ? 'Add equipment to start tracking inventory and rental details.'
                            : 'Try changing the search or filters.',
                        action: allItems.isEmpty
                            ? FilledButton.icon(
                                onPressed: () => _openEditor(),
                                icon: const Icon(Icons.add),
                                label: const Text('Add first item'),
                              )
                            : null,
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) => ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => _EquipmentTile(
                            item: items[index],
                            compact: constraints.maxWidth < 650,
                            onEdit: () => _openEditor(items[index]),
                            onRetire: () => _retire(items[index]),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _matchesFilters(EquipmentItem item) {
    final query = _searchText.toLowerCase();
    final matchesQuery =
        query.isEmpty ||
        item.name.toLowerCase().contains(query) ||
        item.category.toLowerCase().contains(query) ||
        item.warehouseLocation.toLowerCase().contains(query);
    return matchesQuery &&
        (_categoryFilter == 'All categories' ||
            item.category == _categoryFilter) &&
        (_statusFilter == 'All statuses' || item.status == _statusFilter);
  }

  Widget _overview(List<EquipmentItem> items) {
    final total = items.fold<int>(
      0,
      (totalCount, item) => totalCount + item.totalQuantity,
    );
    final available = items.fold<int>(
      0,
      (totalCount, item) => totalCount + item.availableQuantity,
    );
    final attention = items
        .where(
          (item) =>
              item.status == 'Damaged' || item.status == 'Under maintenance',
        )
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 700;
          final cards = [
            _MetricCard(
              label: 'Catalog items',
              value: '${items.length}',
              icon: Icons.inventory_2_outlined,
              tint: const Color(0xff4f46e5),
            ),
            _MetricCard(
              label: 'Units in stock',
              value: '$total',
              icon: Icons.widgets_outlined,
              tint: const Color(0xff0284c7),
            ),
            _MetricCard(
              label: 'Available now',
              value: '$available',
              icon: Icons.check_circle_outline,
              tint: const Color(0xff059669),
            ),
            _MetricCard(
              label: 'Need attention',
              value: '$attention',
              icon: Icons.build_outlined,
              tint: const Color(0xffd97706),
            ),
          ];
          return wide
              ? Row(
                  children: cards
                      .map(
                        (card) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: card,
                          ),
                        ),
                      )
                      .toList(),
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: cards
                      .map(
                        (card) => SizedBox(
                          width: (constraints.maxWidth - 10) / 2,
                          child: card,
                        ),
                      )
                      .toList(),
                );
        },
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchText = value.trim()),
            decoration: const InputDecoration(
              hintText: 'Search name, category, or location',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          );
          final category = DropdownButtonFormField<String>(
            initialValue: _categoryFilter,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Category',
            ),
            items: ['All categories', ..._categories]
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => _categoryFilter = value ?? 'All categories'),
          );
          final status = DropdownButtonFormField<String>(
            initialValue: _statusFilter,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Status',
            ),
            items: ['All statuses', ..._statuses]
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => _statusFilter = value ?? 'All statuses'),
          );
          if (constraints.maxWidth < 700) {
            return Column(
              children: [
                search,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: category),
                    const SizedBox(width: 10),
                    Expanded(child: status),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 3, child: search),
              const SizedBox(width: 10),
              Expanded(child: category),
              const SizedBox(width: 10),
              Expanded(child: status),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: tint.withValues(alpha: 0.1),
            child: Icon(icon, color: tint, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: const Color(0xff667085)),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _EquipmentTile extends StatelessWidget {
  const _EquipmentTile({
    required this.item,
    required this.compact,
    required this.onEdit,
    required this.onRetire,
  });
  final EquipmentItem item;
  final bool compact;
  final VoidCallback onEdit;
  final VoidCallback onRetire;

  Color get _statusColor => switch (item.status) {
    'Available' => const Color(0xff047857),
    'Damaged' || 'Under maintenance' => const Color(0xffb45309),
    'Retired' => const Color(0xff667085),
    _ => const Color(0xff4338ca),
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xffeef2ff),
              child: Icon(
                _categoryIcon(item.category),
                color: const Color(0xff4f46e5),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      _StatusBadge(label: item.status, color: _statusColor),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${item.category}  ·  ${item.condition}',
                    style: const TextStyle(color: Color(0xff667085)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      _Detail(
                        icon: Icons.inventory_outlined,
                        text:
                            '${item.availableQuantity} available / ${item.totalQuantity} total',
                      ),
                      if (item.warehouseLocation.isNotEmpty)
                        _Detail(
                          icon: Icons.location_on_outlined,
                          text: item.warehouseLocation,
                        ),
                      _Detail(
                        icon: Icons.payments_outlined,
                        text: '${item.rentalPrice.toStringAsFixed(2)} / day',
                      ),
                    ],
                  ),
                  if (!compact && item.maintenanceNotes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Maintenance: ${item.maintenanceNotes}',
                      style: const TextStyle(
                        color: Color(0xff667085),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff667085),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Equipment actions',
              onSelected: (value) => value == 'edit' ? onEdit() : onRetire(),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (item.status != 'Retired')
                  const PopupMenuItem(
                    value: 'retire',
                    child: ListTile(
                      leading: Icon(Icons.inventory_2_outlined),
                      title: Text('Retire'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    if (category.contains('Speaker') ||
        category.contains('Audio') ||
        category.contains('Microphone') ||
        category.contains('Amplifier')) {
      return Icons.speaker_group_outlined;
    }
    if (category.contains('light') || category.contains('lighting')) {
      return Icons.light_mode_outlined;
    }
    if (category.contains('Chair') ||
        category.contains('Table') ||
        category.contains('Sofa')) {
      return Icons.chair_outlined;
    }
    if (category.contains('Projector')) return Icons.videocam_outlined;
    return Icons.inventory_2_outlined;
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: const Color(0xff98a2b3)),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(fontSize: 12, color: Color(0xff475467)),
      ),
    ],
  );
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xff667085)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xff667085), height: 1.5),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    ),
  );
}

class _EquipmentEditor extends StatefulWidget {
  const _EquipmentEditor({this.item});
  final EquipmentItem? item;
  @override
  State<_EquipmentEditor> createState() => _EquipmentEditorState();
}

class _EquipmentEditorState extends State<_EquipmentEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _total;
  late final TextEditingController _available;
  late final TextEditingController _location;
  late final TextEditingController _price;
  late final TextEditingController _description;
  late final TextEditingController _maintenance;
  late String _category;
  late String _condition;
  late String _status;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _total = TextEditingController(text: item?.totalQuantity.toString() ?? '1');
    _available = TextEditingController(
      text: item?.availableQuantity.toString() ?? '1',
    );
    _location = TextEditingController(text: item?.warehouseLocation ?? '');
    _price = TextEditingController(
      text: item?.rentalPrice.toStringAsFixed(2) ?? '0.00',
    );
    _description = TextEditingController(text: item?.description ?? '');
    _maintenance = TextEditingController(text: item?.maintenanceNotes ?? '');
    _category = item?.category ?? _categories.first;
    _condition = item?.condition ?? 'Good';
    _status = item?.status ?? 'Available';
  }

  @override
  void dispose() {
    _name.dispose();
    _total.dispose();
    _available.dispose();
    _location.dispose();
    _price.dispose();
    _description.dispose();
    _maintenance.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
  String? _quantity(String? value) {
    final quantity = int.tryParse(value ?? '');
    return quantity == null || quantity < 0
        ? 'Enter a whole number (0 or more)'
        : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final total = int.parse(_total.text.trim());
    final available = int.parse(_available.text.trim());
    if (available > total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Available quantity cannot exceed total quantity.'),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      EquipmentItem(
        id: widget.item?.id ?? '',
        name: _name.text.trim(),
        category: _category,
        totalQuantity: total,
        availableQuantity:
            _status == 'Damaged' ||
                _status == 'Under maintenance' ||
                _status == 'Retired'
            ? 0
            : available,
        condition: _condition,
        status: _status,
        warehouseLocation: _location.text.trim(),
        rentalPrice: double.parse(_price.text.trim()),
        description: _description.text.trim(),
        maintenanceNotes: _maintenance.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add equipment' : 'Edit equipment'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Equipment name *',
                  ),
                  validator: _required,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _categories.contains(_category)
                      ? _category
                      : 'Other',
                  decoration: const InputDecoration(labelText: 'Category *'),
                  items: _categories
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _category = value ?? 'Other'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _total,
                        decoration: const InputDecoration(
                          labelText: 'Total quantity *',
                        ),
                        keyboardType: TextInputType.number,
                        validator: _quantity,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _available,
                        decoration: const InputDecoration(
                          labelText: 'Available quantity *',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final base = _quantity(value);
                          if (base != null) return base;
                          if (int.parse(value!) >
                              (int.tryParse(_total.text) ?? 0)) {
                            return 'Cannot exceed total';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _condition,
                        decoration: const InputDecoration(
                          labelText: 'Condition',
                        ),
                        items: _conditions
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _condition = value ?? 'Good'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: _statuses
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _status = value ?? 'Available'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(
                    labelText: 'Warehouse location *',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _price,
                  decoration: const InputDecoration(
                    labelText: 'Rental price per day *',
                    prefixText: '₹ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final price = double.tryParse(value ?? '');
                    return price == null || price < 0
                        ? 'Enter a valid non-negative price'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _maintenance,
                  decoration: const InputDecoration(
                    labelText: 'Maintenance notes',
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.item == null ? 'Add item' : 'Save changes'),
        ),
      ],
    );
  }
}
