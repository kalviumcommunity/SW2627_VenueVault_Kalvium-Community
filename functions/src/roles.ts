// The five internal staff roles from PRD.md.
export const ROLES = [
  "admin",
  "booking_staff",
  "warehouse_staff",
  "dispatch_staff",
  "operations_manager",
] as const;

export type Role = typeof ROLES[number];

export const PERMISSIONS = [
  "users.manage",
  "settings.manage",
  "equipment.manage",
  "inventory.view",
  "bookings.view",
  "bookings.create",
  "bookings.edit",
  "bookings.cancel",
  "conflicts.resolve",
  "approvals.decide",
  "dispatch.viewAll",
  "dispatch.viewAssigned",
  "dispatch.assign",
  "dispatch.updateStatus",
  "checklist.manage",
  "stock.update",
  "returns.record",
  "returns.approve",
  "maintenance.manage",
  "issues.report",
  "dashboard.view",
  "reports.viewFull",
  "reports.viewLimited",
  "audit.view",
] as const;

export type Permission = typeof PERMISSIONS[number];

// Dispatch staff are limited to their own assigned jobs. That "assigned
// only" check belongs in the function or rule that uses these permissions.
export const ROLE_PERMISSIONS: Record<Role, readonly Permission[]> = {
  admin: PERMISSIONS,
  booking_staff: [
    "inventory.view",
    "bookings.view",
    "bookings.create",
    "bookings.edit",
    "bookings.cancel",
    "reports.viewLimited",
  ],
  warehouse_staff: [
    "inventory.view",
    "bookings.view",
    "dispatch.viewAll",
    "checklist.manage",
    "stock.update",
    "returns.record",
    "maintenance.manage",
    "issues.report",
  ],
  dispatch_staff: [
    "dispatch.viewAssigned",
    "dispatch.updateStatus",
    "issues.report",
  ],
  operations_manager: [
    "inventory.view",
    "bookings.view",
    "conflicts.resolve",
    "approvals.decide",
    "dispatch.viewAll",
    "dispatch.assign",
    "returns.approve",
    "dashboard.view",
    "reports.viewFull",
    "audit.view",
  ],
};

export const isRole = (value: unknown): value is Role =>
  typeof value === "string" && (ROLES as readonly string[]).includes(value);

// Unknown, missing or malformed roles get no permissions.
export const hasPermission = (
  role: unknown,
  permission: Permission,
): boolean => isRole(role) && ROLE_PERMISSIONS[role].includes(permission);
