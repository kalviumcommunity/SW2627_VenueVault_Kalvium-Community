import {test} from "node:test";
import * as assert from "node:assert/strict";
import {checkRoleChange} from "./roleChange";

const admin = {callerUid: "a1", callerRole: "admin"};

test("signed-out callers are rejected", () => {
  const r = checkRoleChange({
    callerUid: undefined, callerRole: undefined,
    targetUid: "u2", newRole: "booking_staff",
  });
  assert.deepEqual(r.ok, false);
  if (!r.ok) assert.equal(r.code, "unauthenticated");
});

test("non-admin roles are rejected", () => {
  for (const callerRole of [
    "booking_staff", "warehouse_staff", "dispatch_staff",
    "operations_manager", undefined, "customer",
  ]) {
    const r = checkRoleChange({
      callerUid: "u1", callerRole, targetUid: "u2", newRole: "admin",
    });
    assert.equal(r.ok, false);
    if (!r.ok) assert.equal(r.code, "permission-denied");
  }
});

test("admin can assign any valid role", () => {
  const r = checkRoleChange({
    ...admin, targetUid: "u2", newRole: "dispatch_staff",
  });
  assert.deepEqual(r, {
    ok: true, targetUid: "u2", newRole: "dispatch_staff",
  });
});

test("invalid role or target is rejected", () => {
  const badRole = checkRoleChange({...admin, targetUid: "u2", newRole: "boss"});
  const noTarget = checkRoleChange({...admin, targetUid: "", newRole: "admin"});
  const numTarget = checkRoleChange({...admin, targetUid: 5, newRole: "admin"});
  for (const r of [badRole, noTarget, numTarget]) {
    assert.equal(r.ok, false);
    if (!r.ok) assert.equal(r.code, "invalid-argument");
  }
});

test("admin cannot remove their own admin role", () => {
  const r = checkRoleChange({
    ...admin, targetUid: "a1", newRole: "booking_staff",
  });
  assert.equal(r.ok, false);
  if (!r.ok) assert.equal(r.code, "failed-precondition");
});

test("admin may re-assign themselves admin", () => {
  const r = checkRoleChange({...admin, targetUid: "a1", newRole: "admin"});
  assert.equal(r.ok, true);
});
