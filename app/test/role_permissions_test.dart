import 'package:flutter_test/flutter_test.dart';

import 'package:app/role_permissions.dart';

void main() {
  test('Admin has every defined application permission', () {
    for (final permission in [
      'users.manage',
      'settings.manage',
      'equipment.manage',
      'inventory.view',
      'bookings.view',
      'bookings.create',
      'bookings.edit',
      'bookings.cancel',
      'conflicts.resolve',
      'approvals.decide',
      'dispatch.viewAll',
      'dispatch.viewAssigned',
      'dispatch.assign',
      'dispatch.updateStatus',
      'checklist.manage',
      'stock.update',
      'returns.record',
      'returns.approve',
      'maintenance.manage',
      'issues.report',
      'dashboard.view',
      'reports.viewFull',
      'reports.viewLimited',
      'audit.view',
    ]) {
      expect(hasRolePermission('admin', permission), isTrue);
    }
  });

  test('each staff role receives only its assigned operations access', () {
    expect(hasRolePermission('booking_staff', 'bookings.create'), isTrue);
    expect(hasRolePermission('booking_staff', 'bookings.cancel'), isTrue);
    expect(hasRolePermission('booking_staff', 'dispatch.assign'), isFalse);
    expect(hasRolePermission('booking_staff', 'returns.record'), isFalse);

    expect(hasRolePermission('warehouse_staff', 'checklist.manage'), isTrue);
    expect(hasRolePermission('warehouse_staff', 'stock.update'), isTrue);
    expect(hasRolePermission('warehouse_staff', 'returns.record'), isTrue);
    expect(hasRolePermission('warehouse_staff', 'bookings.create'), isFalse);
    expect(hasRolePermission('warehouse_staff', 'returns.approve'), isFalse);

    expect(
      hasRolePermission('dispatch_staff', 'dispatch.viewAssigned'),
      isTrue,
    );
    expect(
      hasRolePermission('dispatch_staff', 'dispatch.updateStatus'),
      isTrue,
    );
    expect(hasRolePermission('dispatch_staff', 'dispatch.viewAll'), isFalse);
    expect(hasRolePermission('dispatch_staff', 'bookings.view'), isFalse);

    expect(hasRolePermission('operations_manager', 'dispatch.assign'), isTrue);
    expect(hasRolePermission('operations_manager', 'returns.approve'), isTrue);
    expect(hasRolePermission('operations_manager', 'dashboard.view'), isTrue);
    expect(hasRolePermission('operations_manager', 'returns.record'), isFalse);
    expect(hasRolePermission('operations_manager', 'users.manage'), isFalse);
  });

  test('missing and unknown roles receive no permissions', () {
    expect(hasRolePermission(null, 'inventory.view'), isFalse);
    expect(hasRolePermission('unknown', 'inventory.view'), isFalse);
  });
}
