import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'role_permissions.dart';

class OperationsPage extends StatelessWidget {
  const OperationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IdTokenResult>(
      future: FirebaseAuth.instance.currentUser!.getIdTokenResult(true),
      builder: (context, tokenSnapshot) {
        if (tokenSnapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Could not load your staff permissions.')),
          );
        }
        if (!tokenSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final role = tokenSnapshot.data!.claims?['role'] as String?;
        if (!hasRolePermission(role, 'dispatch.viewAll') &&
            !hasRolePermission(role, 'dispatch.viewAssigned') &&
            !hasRolePermission(role, 'returns.record') &&
            !hasRolePermission(role, 'returns.approve')) {
          return const Scaffold(
            body: Center(child: Text('You do not have access to Operations.')),
          );
        }
        return _OperationsTabs(role: role ?? '');
      },
    );
  }
}

class _OperationsTabs extends StatelessWidget {
  const _OperationsTabs({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final canViewDispatch =
        hasRolePermission(role, 'dispatch.viewAll') ||
        hasRolePermission(role, 'dispatch.viewAssigned');
    final canViewReturns =
        hasRolePermission(role, 'returns.record') ||
        hasRolePermission(role, 'returns.approve');
    final canViewAudit = hasRolePermission(role, 'audit.view');
    final tabs = <Widget>[
      if (canViewDispatch)
        const Tab(text: 'Dispatch', icon: Icon(Icons.local_shipping_outlined)),
      if (canViewReturns)
        const Tab(
          text: 'Returns',
          icon: Icon(Icons.assignment_return_outlined),
        ),
      if (canViewAudit) const Tab(text: 'Audit', icon: Icon(Icons.history)),
    ];
    final pages = <Widget>[
      if (canViewDispatch) const _DispatchList(),
      if (canViewReturns) _ReturnsList(role: role),
      if (canViewAudit) const _AuditList(),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Operations'),
          bottom: tabs.length > 1 ? TabBar(tabs: tabs) : null,
        ),
        body: pages.length > 1 ? TabBarView(children: pages) : pages.single,
      ),
    );
  }
}

class _DispatchList extends StatelessWidget {
  const _DispatchList();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FutureBuilder<IdTokenResult>(
      future: FirebaseAuth.instance.currentUser!.getIdTokenResult(true),
      builder: (context, tokenSnapshot) {
        if (tokenSnapshot.hasError) {
          return const Center(child: Text('Could not load dispatch permissions.'));
        }
        if (!tokenSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final role = tokenSnapshot.data!.claims?['role'] as String? ?? '';
        final canManageChecklist =
            hasRolePermission(role, 'checklist.manage');
        final canAssign = hasRolePermission(role, 'dispatch.assign');
        final canUpdateStatus =
            hasRolePermission(role, 'dispatch.updateStatus');
        final query = FirebaseFirestore.instance.collection('dispatches');
        final stream = hasRolePermission(role, 'dispatch.viewAssigned') &&
                !hasRolePermission(role, 'dispatch.viewAll')
            ? query.where('assignedStaffUid', isEqualTo: uid).snapshots()
            : query.snapshots();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Could not load dispatches.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final dispatches = [...snapshot.data!.docs]
              ..sort(
                (a, b) =>
                    _statusRank(a.data()['status'])
                        .compareTo(_statusRank(b.data()['status'])),
              );
            if (dispatches.isEmpty) {
              return const Center(child: Text('No dispatches yet.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: dispatches.length,
              itemBuilder: (context, index) {
                final document = dispatches[index];
                final data = document.data();
                final items = data['items'] is List
                    ? data['items'] as List
                    : const [];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['eventName'] as String? ?? 'Event dispatch',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(data['venue'] as String? ?? 'Venue not set'),
                        const SizedBox(height: 8),
                        Text('Status: ${data['status'] ?? 'pending'}'),
                        if (data['transportReference'] is String &&
                            (data['transportReference'] as String).isNotEmpty)
                          Text('Transport: ${data['transportReference']}'),
                        const Divider(),
                        ...items.indexed.map((entry) {
                          final item = entry.$2;
                          if (item is! Map) return const SizedBox.shrink();
                          final packed = item['packed'] == true;
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: packed,
                            secondary:
                                canManageChecklist
                                ? IconButton(
                                    tooltip: item['missing'] == true
                                        ? 'Clear missing status'
                                        : 'Mark as missing',
                                    icon: Icon(
                                      item['missing'] == true
                                          ? Icons.report_gmailerrorred
                                          : Icons.help_outline,
                                    ),
                                    onPressed: () =>
                                        _dispatchUpdate(context, document.id, {
                                          'checklistIndex': entry.$1,
                                          'missing': item['missing'] != true,
                                        }),
                                  )
                                : null,
                            title: Text(
                              '${item['name'] ?? 'Equipment'} × ${item['quantity'] ?? 0}',
                            ),
                            subtitle: item['missing'] == true
                                ? const Text(
                                    'Missing item — report before dispatch',
                                  )
                                : null,
                            onChanged:
                                canManageChecklist
                                ? (value) =>
                                      _dispatchUpdate(context, document.id, {
                                        'checklistIndex': entry.$1,
                                        'packed': value ?? false,
                                      })
                                : null,
                          );
                        }),
                        if (canAssign)
                          _AssignmentControls(
                            dispatchId: document.id,
                            data: data,
                          ),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (canAssign)
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _updateTransport(context, document.id),
                                icon: const Icon(Icons.directions_bus_outlined),
                                label: const Text('Transport'),
                              ),
                            if (data['status'] != 'completed' &&
                                _canAdvance(
                                  uid,
                                  data,
                                  canManageChecklist: canManageChecklist,
                                  canUpdateStatus: canUpdateStatus,
                                  canAssign: canAssign,
                                ))
                              FilledButton(
                                onPressed: () => _advanceStatus(
                                  context,
                                  document.id,
                                  data['status'] as String? ?? 'pending',
                                ),
                                child: Text(_nextAction(data['status'])),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AssignmentControls extends StatelessWidget {
  const _AssignmentControls({required this.dispatchId, required this.data});

  final String dispatchId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => _assignDispatch(context, dispatchId),
    icon: const Icon(Icons.person_add_alt_1),
    label: Text(data['assignedStaffUid'] == null ? 'Assign staff' : 'Reassign'),
  );
}

class _ReturnsList extends StatelessWidget {
  const _ReturnsList({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('returns')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Could not load returns.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No returns recorded yet.'));
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: snapshot.data!.docs.map((document) {
                  final data = document.data();
                  final items = data['items'] is List
                      ? data['items'] as List
                      : const [];
                  final needsResolution = items.whereType<Map>().any(
                    (item) =>
                        (item['damagedQuantity'] as num? ?? 0) > 0 ||
                        (item['missingQuantity'] as num? ?? 0) > 0,
                  );
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['eventName'] as String? ?? 'Return',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text('Inspection: ${data['status'] ?? 'pending'}'),
                          if (needsResolution)
                            const Text(
                              'Damaged/missing quantities remain unavailable.',
                            ),
                          ...items.whereType<Map>().map((item) {
                            final issueQuantity =
                                (item['damagedQuantity'] as num? ?? 0).toInt() +
                                (item['missingQuantity'] as num? ?? 0).toInt();
                            final resolved =
                                (item['resolvedQuantity'] as num? ?? 0).toInt();
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                item['name'] as String? ?? 'Equipment',
                              ),
                              subtitle: Text(
                                'Returned ${item['returnedQuantity'] ?? 0}'
                                ' · Damaged ${item['damagedQuantity'] ?? 0}'
                                ' · Missing ${item['missingQuantity'] ?? 0}'
                                ' · Resolved $resolved/$issueQuantity',
                              ),
                              trailing:
                                  data['status'] == 'approved' &&
                                      issueQuantity > resolved &&
                                      hasRolePermission(
                                        role,
                                        'maintenance.manage',
                                      )
                                  ? TextButton(
                                      onPressed: () => _resolveIssue(
                                        context,
                                        document.id,
                                        item,
                                        issueQuantity - resolved,
                                      ),
                                      child: const Text('Resolve'),
                                    )
                                  : null,
                            );
                          }),
                          if (data['status'] == 'pending_inspection' &&
                              hasRolePermission(role, 'returns.approve'))
                            FilledButton(
                              onPressed: () =>
                                  _approveReturn(context, document.id),
                              child: const Text('Approve inspection'),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        if (hasRolePermission(role, 'returns.record')) _EndedBookings(),
      ],
    );
  }
}

bool _canAdvance(
  String uid,
  Map<String, dynamic> dispatch, {
  required bool canManageChecklist,
  required bool canUpdateStatus,
  required bool canAssign,
}) {
  if (canAssign) return true;
  if (canManageChecklist) {
    return dispatch['status'] == 'pending' || dispatch['status'] == 'preparing';
  }
  return canUpdateStatus && dispatch['assignedStaffUid'] == uid;
}

class _EndedBookings extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 190,
    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final due = snapshot.data!.docs.where((document) {
          final data = document.data();
          final end = data['endDate'];
          return data['status'] == 'confirmed' &&
              end is Timestamp &&
              end.toDate().isBefore(DateTime.now());
        }).toList();
        if (due.isEmpty) return const SizedBox.shrink();
        return ListView(
          children: due.map((document) {
            final data = document.data();
            return ListTile(
              title: Text('Record return: ${data['eventName'] ?? 'Event'}'),
              trailing: TextButton(
                onPressed: () => _showRecordReturn(context, document.id, data),
                child: const Text('Inspect'),
              ),
            );
          }).toList(),
        );
      },
    ),
  );
}

class _AuditList extends StatelessWidget {
  const _AuditList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('auditLogs').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load audit history.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final events = [...snapshot.data!.docs]
          ..sort((a, b) {
            final aTime = a.data()['createdAt'];
            final bTime = b.data()['createdAt'];
            if (aTime is! Timestamp || bTime is! Timestamp) return 0;
            return bTime.compareTo(aTime);
          });
        if (events.isEmpty) {
          return const Center(child: Text('No operational actions recorded.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final data = events[index].data();
            final createdAt = data['createdAt'];
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(data['action'] as String? ?? 'Action'),
              subtitle: Text(
                'By ${data['actorUid'] ?? 'Unknown'}'
                ' · ${data['resourceId'] ?? ''}',
              ),
              trailing: createdAt is Timestamp
                  ? Text(_dateTimeLabel(createdAt.toDate()))
                  : null,
            );
          },
        );
      },
    );
  }
}

String _dateTimeLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

Future<void> _showRecordReturn(
  BuildContext context,
  String bookingId,
  Map<String, dynamic> booking,
) async {
  final rawItems = booking['items'];
  if (rawItems is! List || rawItems.isEmpty) return;
  final inputs = <Map<String, dynamic>>[];
  for (final raw in rawItems) {
    if (raw is! Map) continue;
    final quantity = (raw['quantity'] as num?)?.toInt() ?? 0;
    final returned = TextEditingController(text: '$quantity');
    final damaged = TextEditingController(text: '0');
    final missing = TextEditingController(text: '0');
    inputs.add({
      'equipmentId': raw['equipmentId'],
      'name': raw['name'] ?? 'Equipment',
      'bookedQuantity': quantity,
      'returned': returned,
      'damaged': damaged,
      'missing': missing,
    });
  }
  final submit = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Inspect ${booking['eventName'] ?? 'return'}'),
      content: SizedBox(
        width: 480,
        child: ListView(
          shrinkWrap: true,
          children: inputs.map((item) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item['name']} · booked ${item['bookedQuantity']}'),
                Row(
                  children: [
                    _QuantityField(
                      label: 'Returned',
                      controller: item['returned'] as TextEditingController,
                    ),
                    _QuantityField(
                      label: 'Damaged',
                      controller: item['damaged'] as TextEditingController,
                    ),
                    _QuantityField(
                      label: 'Missing',
                      controller: item['missing'] as TextEditingController,
                    ),
                  ],
                ),
              ],
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Record for inspection'),
        ),
      ],
    ),
  );
  if (submit == true) {
    try {
      final items = inputs.map((item) {
        final returned =
            int.tryParse((item['returned'] as TextEditingController).text) ??
            -1;
        final damaged =
            int.tryParse((item['damaged'] as TextEditingController).text) ?? -1;
        final missing =
            int.tryParse((item['missing'] as TextEditingController).text) ?? -1;
        if (returned < 0 ||
            damaged < 0 ||
            missing < 0 ||
            returned + missing > (item['bookedQuantity'] as int) ||
            damaged > returned) {
          throw const FormatException('Check quantities for each item.');
        }
        return {
          'equipmentId': item['equipmentId'],
          'name': item['name'],
          'bookedQuantity': item['bookedQuantity'],
          'returnedQuantity': returned,
          'damagedQuantity': damaged,
          'missingQuantity': missing,
          'condition': damaged > 0 ? 'damaged' : 'good',
        };
      }).toList();
      final requestId = FirebaseFirestore.instance
          .collection('returns')
          .doc()
          .id;
      await FirebaseFunctions.instance.httpsCallable('recordReturn').call({
        'bookingId': bookingId,
        'requestId': requestId,
        'items': items,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Return recorded for inspection.')),
        );
      }
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on FirebaseFunctionsException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Could not record return.')),
        );
      }
    }
  }
  for (final item in inputs) {
    (item['returned'] as TextEditingController).dispose();
    (item['damaged'] as TextEditingController).dispose();
    (item['missing'] as TextEditingController).dispose();
  }
}

class _QuantityField extends StatelessWidget {
  const _QuantityField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(right: 8, top: 8, bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      ),
    ),
  );
}

Future<void> _dispatchUpdate(
  BuildContext context,
  String dispatchId,
  Map<String, dynamic> update,
) async {
  try {
    await FirebaseFunctions.instance.httpsCallable('updateDispatch').call({
      'dispatchId': dispatchId,
      'requestId': FirebaseFirestore.instance.collection('auditLogs').doc().id,
      ...update,
    });
  } on FirebaseFunctionsException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Dispatch update failed.')),
      );
    }
  }
}

Future<void> _advanceStatus(
  BuildContext context,
  String dispatchId,
  String current,
) async {
  const next = {
    'pending': 'preparing',
    'preparing': 'ready',
    'ready': 'dispatched',
    'dispatched': 'delivered',
    'delivered': 'returned',
    'returned': 'completed',
  };
  final status = next[current];
  if (status == null) return;
  await _dispatchUpdate(context, dispatchId, {'status': status});
}

Future<void> _updateTransport(BuildContext context, String dispatchId) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Transport reference'),
      content: TextField(
        controller: controller,
        maxLength: 100,
        decoration: const InputDecoration(
          labelText: 'Vehicle or transport ref',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (value != null && context.mounted) {
    await _dispatchUpdate(context, dispatchId, {'transportReference': value});
  }
}

Future<void> _assignDispatch(BuildContext context, String dispatchId) async {
  final controller = TextEditingController();
  final uid = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Assign dispatch'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: 'Staff user UID'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Assign'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (uid != null && uid.isNotEmpty && context.mounted) {
    await _dispatchUpdate(context, dispatchId, {'assignedStaffUid': uid});
  }
}

Future<void> _approveReturn(BuildContext context, String returnId) async {
  try {
    await FirebaseFunctions.instance.httpsCallable('approveReturn').call({
      'returnId': returnId,
      'requestId': FirebaseFirestore.instance.collection('auditLogs').doc().id,
    });
  } on FirebaseFunctionsException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not approve inspection.'),
        ),
      );
    }
  }
}

Future<void> _resolveIssue(
  BuildContext context,
  String returnId,
  Map item,
  int unresolved,
) async {
  final controller = TextEditingController(text: '$unresolved');
  final quantity = await showDialog<int>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Resolve ${item['name'] ?? 'equipment'}'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Quantity resolved (up to $unresolved)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            dialogContext,
            int.tryParse(controller.text.trim()),
          ),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (quantity == null ||
      quantity < 1 ||
      quantity > unresolved ||
      !context.mounted) {
    return;
  }
  try {
    await FirebaseFunctions.instance
        .httpsCallable('resolveUnavailableEquipment')
        .call({
          'returnId': returnId,
          'equipmentId': item['equipmentId'],
          'quantity': quantity,
          'requestId': FirebaseFirestore.instance
              .collection('auditLogs')
              .doc()
              .id,
        });
  } on FirebaseFunctionsException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not resolve issue.')),
      );
    }
  }
}

int _statusRank(Object? status) => switch (status) {
  'pending' => 0,
  'preparing' => 1,
  'ready' => 2,
  'dispatched' => 3,
  'delivered' => 4,
  'returned' => 5,
  'completed' => 6,
  _ => 7,
};

String _nextAction(Object? status) => switch (status) {
  'pending' => 'Start preparing',
  'preparing' => 'Mark ready',
  'ready' => 'Dispatch',
  'dispatched' => 'Mark delivered',
  'delivered' => 'Mark returned',
  'returned' => 'Complete',
  _ => 'Update',
};
