const Map<String, Set<String>> _rolePermissions = {
  'booking_staff': {
    'inventory.view',
    'bookings.view',
    'bookings.create',
    'bookings.edit',
    'bookings.cancel',
    'reports.viewLimited',
  },
  'warehouse_staff': {
    'inventory.view',
    'bookings.view',
    'dispatch.viewAll',
    'checklist.manage',
    'stock.update',
    'returns.record',
    'maintenance.manage',
    'issues.report',
  },
  'dispatch_staff': {
    'dispatch.viewAssigned',
    'dispatch.updateStatus',
    'issues.report',
  },
  'operations_manager': {
    'inventory.view',
    'bookings.view',
    'conflicts.resolve',
    'approvals.decide',
    'dispatch.viewAll',
    'dispatch.assign',
    'returns.approve',
    'dashboard.view',
    'reports.viewFull',
    'audit.view',
  },
};

bool hasRolePermission(String? role, String permission) {
  if (role == 'admin') return true;
  if (role == null) return false;
  return _rolePermissions[role]?.contains(permission) ?? false;
}
