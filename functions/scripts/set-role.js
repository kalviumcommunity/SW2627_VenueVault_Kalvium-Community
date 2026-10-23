// Emulator-only helper to make the first Admin.
// Usage: node scripts/set-role.js <email> <role>
// Refuses to run unless FIREBASE_AUTH_EMULATOR_HOST is set.
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {isRole} = require("../lib/roles");

const main = async () => {
  if (!process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    throw new Error("Set FIREBASE_AUTH_EMULATOR_HOST (emulator only).");
  }
  const [email, role] = process.argv.slice(2);
  if (!email || !isRole(role)) {
    throw new Error("Usage: node scripts/set-role.js <email> <role>");
  }
  initializeApp({projectId: "venue-vault-kalvium-community"});
  const auth = getAuth();
  const user = await auth.getUserByEmail(email);
  await auth.setCustomUserClaims(user.uid, {role});
  console.log(`Set role "${role}" on ${email} (${user.uid})`);
};

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});