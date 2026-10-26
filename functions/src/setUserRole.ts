import {HttpsError, onCall} from "firebase-functions/https";
import {FieldValue} from "firebase-admin/firestore";
import {auth, db} from "./admin";
import {checkRoleChange} from "./roleChange";

export const setUserRole = onCall(async (request) => {
  const result = checkRoleChange({
    callerUid: request.auth?.uid,
    callerRole: request.auth?.token.role,
    targetUid: request.data?.uid,
    newRole: request.data?.role,
  });
  if (!result.ok) {
    throw new HttpsError(result.code, result.message);
  }
  const {targetUid, newRole} = result;

  try {
    await auth().getUser(targetUid);
  } catch {
    throw new HttpsError("not-found", "No user with that id.");
  }

  await auth().setCustomUserClaims(targetUid, {role: newRole});
  await db().doc(`users/${targetUid}`).set({
    role: newRole,
    updatedBy: request.auth?.uid,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  await db().collection("auditLogs").add({
    action: "user.role_changed",
    actorUid: request.auth?.uid,
    resourceId: targetUid,
    details: {role: newRole},
    createdAt: FieldValue.serverTimestamp(),
  });
  // Force the user to sign in again so the new role takes effect.
  await auth().revokeRefreshTokens(targetUid);

  return {uid: targetUid, role: newRole};
});
