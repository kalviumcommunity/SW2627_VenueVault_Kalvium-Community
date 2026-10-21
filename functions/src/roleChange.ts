import {Role, hasPermission, isRole} from "./roles";

export type RoleChangeCode =
  | "unauthenticated"
  | "permission-denied"
  | "invalid-argument"
  | "failed-precondition";

export interface RoleChangeInput {
  callerUid: string | undefined;
  callerRole: unknown;
  targetUid: unknown;
  newRole: unknown;
}

export type RoleChangeResult =
  | {ok: true; targetUid: string; newRole: Role}
  | {ok: false; code: RoleChangeCode; message: string};

const fail = (code: RoleChangeCode, message: string): RoleChangeResult =>
  ({ok: false, code, message});

export const checkRoleChange = (input: RoleChangeInput): RoleChangeResult => {
  if (!input.callerUid) {
    return fail("unauthenticated", "Sign in first.");
  }
  if (!hasPermission(input.callerRole, "users.manage")) {
    return fail("permission-denied", "Only an Admin can change roles.");
  }
  if (typeof input.targetUid !== "string" || input.targetUid.trim() === "") {
    return fail("invalid-argument", "A target user id is required.");
  }
  if (!isRole(input.newRole)) {
    return fail("invalid-argument", "Unknown role.");
  }
  if (input.targetUid === input.callerUid && input.newRole !== "admin") {
    return fail(
      "failed-precondition",
      "Admins cannot remove their own admin role.",
    );
  }
  return {ok: true, targetUid: input.targetUid, newRole: input.newRole};
};
