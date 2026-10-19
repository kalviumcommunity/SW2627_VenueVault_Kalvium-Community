import {test} from "node:test";
import * as assert from "node:assert/strict";
import {PERMISSIONS, ROLES, hasPermission} from "./roles";

test("admin has every permission", () => {
  for (const permission of PERMISSIONS) {
    assert.equal(hasPermission("admin", permission), true);
  }
});

test("booking staff manage bookings but not users or returns", () => {
  assert.equal(hasPermission("booking_staff", "bookings.create"), true);
  assert.equal(hasPermission("booking_staff", "bookings.cancel"), true);
  assert.equal(hasPermission("booking_staff", "users.manage"), false);
  assert.equal(hasPermission("booking_staff", "returns.record"), false);
  assert.equal(hasPermission("booking_staff", "equipment.manage"), false);
});

test("warehouse staff handle stock but not bookings", () => {
  assert.equal(hasPermission("warehouse_staff", "checklist.manage"), true);
  assert.equal(hasPermission("warehouse_staff", "returns.record"), true);
  assert.equal(hasPermission("warehouse_staff", "bookings.create"), false);
  assert.equal(hasPermission("warehouse_staff", "returns.approve"), false);
});

test("dispatch staff only update dispatch status", () => {
  assert.equal(hasPermission("dispatch_staff", "dispatch.updateStatus"), true);
  assert.equal(hasPermission("dispatch_staff", "bookings.view"), false);
  assert.equal(hasPermission("dispatch_staff", "equipment.manage"), false);
  assert.equal(hasPermission("dispatch_staff", "maintenance.manage"), false);
});

test("operations manager approves but does not manage users", () => {
  assert.equal(hasPermission("operations_manager", "returns.approve"), true);
  assert.equal(hasPermission("operations_manager", "conflicts.resolve"), true);
  assert.equal(hasPermission("operations_manager", "users.manage"), false);
  assert.equal(hasPermission("operations_manager", "settings.manage"), false);
});

test("unknown or missing roles get nothing", () => {
  for (const permission of PERMISSIONS) {
    assert.equal(hasPermission(undefined, permission), false);
    assert.equal(hasPermission("customer", permission), false);
  }
});

test("every role is defined", () => {
  assert.equal(ROLES.length, 5);
});
