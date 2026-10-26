import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/https";
import {db} from "./admin";
import {hasPermission} from "./roles";

const categories = [
  "Audio systems",
  "Speakers",
  "Microphones",
  "Amplifiers",
  "LED lights",
  "Stage lighting",
  "Tables",
  "Chairs",
  "Sofas",
  "Projectors",
  "Generators",
  "Accessories and cables",
  "Other",
];
const statuses = [
  "Available",
  "Reserved",
  "Dispatched",
  "In use",
  "Under maintenance",
  "Damaged",
  "Retired",
];
const conditions = ["Excellent", "Good", "Fair", "Poor"];

type EquipmentInput = {
  name: string;
  category: string;
  totalQuantity: number;
  availableQuantity: number;
  condition: string;
  status: string;
  warehouseLocation: string;
  rentalPrice: number;
  description: string;
  maintenanceNotes: string;
};

const isText = (
  value: unknown,
  max: number,
  emptyAllowed = true,
): value is string =>
  typeof value === "string" &&
  value.length <= max &&
  (emptyAllowed || value.trim().length > 0);

const parseEquipment = (value: unknown): EquipmentInput => {
  if (typeof value !== "object" || value === null) {
    throw new HttpsError("invalid-argument", "Equipment details are required.");
  }
  const data = value as Record<string, unknown>;
  if (
    !isText(data.name, 120, false) ||
    !isText(data.category, 80, false) ||
    !categories.includes(data.category) ||
    typeof data.totalQuantity !== "number" ||
    !Number.isInteger(data.totalQuantity) ||
    data.totalQuantity < 0 ||
    typeof data.availableQuantity !== "number" ||
    !Number.isInteger(data.availableQuantity) ||
    data.availableQuantity < 0 ||
    data.availableQuantity > data.totalQuantity ||
    !isText(data.condition, 20, false) ||
    !conditions.includes(data.condition) ||
    !isText(data.status, 30, false) ||
    !statuses.includes(data.status) ||
    !isText(data.warehouseLocation, 160) ||
    typeof data.rentalPrice !== "number" ||
    !Number.isFinite(data.rentalPrice) ||
    data.rentalPrice < 0 ||
    data.rentalPrice > 1000000 ||
    !isText(data.description, 1000) ||
    !isText(data.maintenanceNotes, 1000)
  ) {
    throw new HttpsError("invalid-argument", "Invalid equipment details.");
  }
  return {
    name: data.name.trim(),
    category: data.category,
    totalQuantity: data.totalQuantity,
    availableQuantity: data.availableQuantity,
    condition: data.condition,
    status: data.status,
    warehouseLocation: data.warehouseLocation.trim(),
    rentalPrice: data.rentalPrice,
    description: data.description.trim(),
    maintenanceNotes: data.maintenanceNotes.trim(),
  };
};

export const saveEquipment = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  const isAdmin = hasPermission(request.auth.token.role, "equipment.manage");
  const isWarehouse = hasPermission(request.auth.token.role, "stock.update");
  if (!isAdmin && !isWarehouse) {
    throw new HttpsError("permission-denied", "You do not have permission.");
  }
  const {requestId, equipmentId} = request.data ?? {};
  if (
    typeof requestId !== "string" ||
    !/^[A-Za-z0-9_-]{1,128}$/.test(requestId) ||
    (equipmentId !== undefined &&
      (typeof equipmentId !== "string" ||
        !/^[A-Za-z0-9_-]{1,128}$/.test(equipmentId)))
  ) {
    throw new HttpsError("invalid-argument", "Invalid equipment request.");
  }
  const equipment = parseEquipment(request.data.equipment);
  const id = typeof equipmentId === "string" ? equipmentId : requestId;
  const equipmentRef = db().collection("equipment").doc(id);
  const auditRef = db()
    .collection("auditLogs")
    .doc(`equipment-saved-${requestId}`);
  await db().runTransaction(async (transaction) => {
    const [equipmentSnapshot, auditSnapshot] = await Promise.all([
      transaction.get(equipmentRef),
      transaction.get(auditRef),
    ]);
    if (auditSnapshot.exists) return;
    if (!equipmentSnapshot.exists && !isAdmin) {
      throw new HttpsError(
        "permission-denied",
        "Warehouse staff cannot add equipment.",
      );
    }
    const current = equipmentSnapshot.data();
    if (current) {
      if (!isAdmin) {
        const allowed = new Set([
          "availableQuantity",
          "condition",
          "status",
          "maintenanceNotes",
        ]);
        const changed = Object.keys(equipment).filter(
          (key) => equipment[key as keyof EquipmentInput] !== current[key],
        );
        if (changed.some((key) => !allowed.has(key))) {
          throw new HttpsError(
            "permission-denied",
            "Warehouse staff can only update stock condition and status.",
          );
        }
      }
      transaction.update(equipmentRef, {
        ...equipment,
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else {
      transaction.create(equipmentRef, {
        ...equipment,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    transaction.create(auditRef, {
      action: current ? "equipment.updated" : "equipment.created",
      actorUid: request.auth!.uid,
      resourceId: id,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  return {equipmentId: id, saved: true};
});

export const retireEquipment = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  if (!hasPermission(request.auth.token.role, "equipment.manage")) {
    throw new HttpsError(
      "permission-denied",
      "Only Admins can retire equipment.",
    );
  }
  const {equipmentId, requestId} = request.data ?? {};
  if (
    typeof equipmentId !== "string" ||
    !/^[A-Za-z0-9_-]{1,128}$/.test(equipmentId) ||
    typeof requestId !== "string" ||
    !/^[A-Za-z0-9_-]{1,128}$/.test(requestId)
  ) {
    throw new HttpsError("invalid-argument", "Invalid retirement request.");
  }
  const equipmentRef = db().collection("equipment").doc(equipmentId);
  const auditRef = db()
    .collection("auditLogs")
    .doc(`equipment-retired-${requestId}`);
  await db().runTransaction(async (transaction) => {
    const [equipmentSnapshot, auditSnapshot] = await Promise.all([
      transaction.get(equipmentRef),
      transaction.get(auditRef),
    ]);
    if (!equipmentSnapshot.exists) {
      throw new HttpsError("not-found", "Equipment not found.");
    }
    if (auditSnapshot.exists) return;
    transaction.update(equipmentRef, {
      status: "Retired",
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(auditRef, {
      action: "equipment.retired",
      actorUid: request.auth!.uid,
      resourceId: equipmentId,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  return {equipmentId, retired: true};
});
