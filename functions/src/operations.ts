import {FieldValue, Timestamp, Transaction} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/https";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {auth, db} from "./admin";
import {
  DashboardBooking,
  DashboardDispatch,
  DashboardEquipment,
  DashboardItem,
  DashboardReturn,
  summarizeOperations,
} from "./operationsDashboard";
import {hasPermission} from "./roles";

const dispatchStatuses = [
  "pending",
  "preparing",
  "ready",
  "dispatched",
  "delivered",
  "returned",
  "completed",
] as const;

const nextDispatchStatus: Record<string, string> = {
  pending: "preparing",
  preparing: "ready",
  ready: "dispatched",
  dispatched: "delivered",
  delivered: "returned",
  returned: "completed",
};

type BookingItem = {
  equipmentId: string;
  name: string;
  quantity: number;
};

const isNonEmptyString = (value: unknown): value is string =>
  typeof value === "string" && value.trim().length > 0 && value.length <= 200;

const requireCaller = (request: {
  auth?: {uid: string; token: Record<string, unknown>} | undefined;
}, permission: Parameters<typeof hasPermission>[1]): string => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  if (!hasPermission(request.auth.token.role, permission)) {
    throw new HttpsError("permission-denied", "You do not have permission.");
  }
  return request.auth.uid;
};

const requireSignedIn = (request: {
  auth?: {uid: string} | undefined;
}): string => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  return request.auth.uid;
};

const writeAudit = (
  transaction: Transaction,
  id: string,
  uid: string,
  action: string,
  resourceId: string,
  details: Record<string, unknown> = {},
) => {
  transaction.set(db().collection("auditLogs").doc(id), {
    action,
    actorUid: uid,
    resourceId,
    details,
    createdAt: FieldValue.serverTimestamp(),
  });
};

const confirmed = (data: FirebaseFirestore.DocumentData): boolean =>
  typeof data.status === "string" &&
  data.status.toLowerCase() === "confirmed";

const bookingItems = (data: FirebaseFirestore.DocumentData): BookingItem[] => {
  if (!Array.isArray(data.items)) return [];
  return data.items.flatMap((item: unknown) => {
    if (typeof item !== "object" || item === null) return [];
    const value = item as Record<string, unknown>;
    if (
      !isNonEmptyString(value.equipmentId) ||
      typeof value.quantity !== "number" ||
      !Number.isInteger(value.quantity) ||
      value.quantity < 1
    ) {
      return [];
    }
    return [{
      equipmentId: value.equipmentId,
      name: typeof value.name === "string" ?
        value.name.slice(0, 200) :
        "Equipment",
      quantity: value.quantity,
    }];
  });
};

const ensureDispatch = async (bookingId: string) => {
  const bookingRef = db().collection("bookings").doc(bookingId);
  const dispatchRef = db().collection("dispatches").doc(bookingId);
  await db().runTransaction(async (transaction) => {
    const [bookingSnapshot, dispatchSnapshot] = await Promise.all([
      transaction.get(bookingRef),
      transaction.get(dispatchRef),
    ]);
    if (!bookingSnapshot.exists || dispatchSnapshot.exists) return;
    const booking = bookingSnapshot.data();
    if (!booking || !confirmed(booking)) return;

    const items = bookingItems(booking);
    transaction.create(dispatchRef, {
      bookingId,
      eventName: typeof booking.eventName === "string" ?
        booking.eventName :
        "Event booking",
      venue: typeof booking.venue === "string" ? booking.venue : "",
      dispatchDate: booking.startDate ?? null,
      items: items.map((item) => ({
        ...item,
        packed: false,
        missing: false,
      })),
      assignedStaffUid: null,
      transportReference: "",
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    writeAudit(
      transaction,
      `dispatch-created-${bookingId}`,
      booking.updatedBy ?? booking.createdBy ?? "system",
      "dispatch.created",
      bookingId,
    );
  });
};

export const createDispatchForBooking = onDocumentCreated(
  "bookings/{bookingId}",
  async (event) => {
    const booking = event.data?.data();
    if (booking && confirmed(booking)) {
      await ensureDispatch(event.params.bookingId);
    }
  },
);

export const syncDispatchForBooking = onDocumentUpdated(
  "bookings/{bookingId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (after && confirmed(after) && (!before || !confirmed(before))) {
      await ensureDispatch(event.params.bookingId);
    }
  },
);

export const updateDispatch = onCall(async (request) => {
  const uid = requireSignedIn(request);
  const {dispatchId, requestId} = request.data ?? {};
  if (!isNonEmptyString(dispatchId) || !isNonEmptyString(requestId)) {
    throw new HttpsError(
      "invalid-argument",
      "A dispatch and request id are required.",
    );
  }

  const dispatchRef = db().collection("dispatches").doc(dispatchId);
  const auditRef = db().collection("auditLogs").doc(`dispatch-${requestId}`);
  const data = request.data as Record<string, unknown>;
  const hasChecklist =
    Object.prototype.hasOwnProperty.call(data, "checklistIndex");
  const hasStatus = Object.prototype.hasOwnProperty.call(data, "status");
  const hasAssignment =
    Object.prototype.hasOwnProperty.call(data, "assignedStaffUid");
  const hasTransport =
    Object.prototype.hasOwnProperty.call(data, "transportReference");
  if (
    [hasChecklist, hasStatus, hasAssignment, hasTransport]
      .filter(Boolean).length !== 1
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Provide exactly one dispatch update.",
    );
  }
  if (hasAssignment && typeof data.assignedStaffUid === "string") {
    const assignedUser = await auth().getUser(data.assignedStaffUid);
    if (assignedUser.customClaims?.role !== "dispatch_staff") {
      throw new HttpsError(
        "failed-precondition",
        "Only Dispatch Staff can be assigned to dispatch tasks.",
      );
    }
  }

  await db().runTransaction(async (transaction) => {
    const [dispatchSnapshot, auditSnapshot] = await Promise.all([
      transaction.get(dispatchRef),
      transaction.get(auditRef),
    ]);
    if (!dispatchSnapshot.exists) {
      throw new HttpsError("not-found", "Dispatch not found.");
    }
    if (auditSnapshot.exists) return;
    const dispatch = dispatchSnapshot.data()!;
    const callerRole = request.auth?.token.role;
    const canManage = hasPermission(callerRole, "dispatch.assign");

    const changes: Record<string, unknown> = {
      updatedAt: FieldValue.serverTimestamp(),
    };
    let action: string;
    if (hasChecklist) {
      if (!hasPermission(callerRole, "checklist.manage")) {
        throw new HttpsError("permission-denied", "Checklist access denied.");
      }
      const index = data.checklistIndex;
      const packed = data.packed;
      const missing = data.missing;
      const items = dispatch.items;
      if (
        !Array.isArray(items) ||
        typeof index !== "number" ||
        !Number.isInteger(index) ||
        index < 0 ||
        index >= items.length ||
        (typeof packed !== "boolean" && typeof missing !== "boolean") ||
        (typeof packed === "boolean" && typeof missing === "boolean")
      ) {
        throw new HttpsError("invalid-argument", "Invalid checklist update.");
      }
      const nextItems = [...items];
      nextItems[index] = {
        ...nextItems[index],
        ...(typeof packed === "boolean" ?
          {packed, ...(packed ? {missing: false} : {})} :
          {missing, ...(missing ? {packed: false} : {})}),
      };
      changes.items = nextItems;
      action = "dispatch.checklist_updated";
    } else if (hasStatus) {
      const next = data.status;
      if (
        typeof next !== "string" ||
        !(dispatchStatuses as readonly string[]).includes(next) ||
        nextDispatchStatus[dispatch.status] !== next
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Invalid dispatch status transition.",
        );
      }
      const isWarehousePreparation =
        hasPermission(callerRole, "checklist.manage") &&
        ["preparing", "ready"].includes(next);
      if (
        !canManage &&
        !isWarehousePreparation &&
        !hasPermission(callerRole, "dispatch.updateStatus")
      ) {
        throw new HttpsError(
          "permission-denied",
          "Status updates are not allowed.",
        );
      }
      if (
        !canManage &&
        !isWarehousePreparation &&
        dispatch.assignedStaffUid !== uid
      ) {
        throw new HttpsError(
          "permission-denied",
          "This dispatch is not assigned to you.",
        );
      }
      if (
        next === "ready" &&
        Array.isArray(dispatch.items) &&
        dispatch.items.some((item: {packed?: unknown}) => item.packed !== true)
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Pack every item before marking ready.",
        );
      }
      changes.status = next;
      action = "dispatch.status_updated";
    } else if (hasAssignment) {
      if (!hasPermission(callerRole, "dispatch.assign")) {
        throw new HttpsError(
          "permission-denied",
          "Dispatch assignment is not allowed.",
        );
      }
      const assignedStaffUid = data.assignedStaffUid;
      if (assignedStaffUid !== null && !isNonEmptyString(assignedStaffUid)) {
        throw new HttpsError("invalid-argument", "Invalid staff assignment.");
      }
      changes.assignedStaffUid = assignedStaffUid;
      action = "dispatch.assigned";
    } else {
      if (!hasPermission(callerRole, "dispatch.assign")) {
        throw new HttpsError(
          "permission-denied",
          "Transport details are not allowed.",
        );
      }
      if (
        typeof data.transportReference !== "string" ||
        data.transportReference.length > 100
      ) {
        throw new HttpsError(
          "invalid-argument",
          "Invalid transport reference.",
        );
      }
      changes.transportReference = data.transportReference;
      action = "dispatch.transport_updated";
    }

    transaction.update(dispatchRef, changes);
    writeAudit(transaction, `dispatch-${requestId}`, uid, action, dispatchId);
  });

  return {dispatchId, updated: true};
});

type ReturnItem = {
  equipmentId: string;
  name: string;
  bookedQuantity: number;
  returnedQuantity: number;
  damagedQuantity: number;
  missingQuantity: number;
  condition: string;
  notes: string;
};

const parseReturnItems = (value: unknown): ReturnItem[] => {
  if (!Array.isArray(value) || value.length === 0 || value.length > 100) {
    throw new HttpsError("invalid-argument", "Return items are required.");
  }
  const seen = new Set<string>();
  return value.map((raw) => {
    if (typeof raw !== "object" || raw === null) {
      throw new HttpsError("invalid-argument", "Invalid return item.");
    }
    const item = raw as Record<string, unknown>;
    const {
      equipmentId,
      returnedQuantity,
      damagedQuantity,
      missingQuantity,
    } = item;
    if (
      !isNonEmptyString(equipmentId) ||
      seen.has(equipmentId) ||
      !isNonEmptyString(item.name) ||
      ![returnedQuantity, damagedQuantity, missingQuantity].every(
        (quantity) =>
          typeof quantity === "number" &&
          Number.isInteger(quantity) &&
          quantity >= 0,
      ) ||
      typeof item.bookedQuantity !== "number" ||
      !Number.isInteger(item.bookedQuantity) ||
      item.bookedQuantity < 1 ||
      (returnedQuantity as number) + (missingQuantity as number) !==
        item.bookedQuantity ||
      (damagedQuantity as number) > (returnedQuantity as number) ||
      typeof item.condition !== "string" ||
      !["excellent", "good", "fair", "poor", "damaged", "missing"]
        .includes(item.condition.toLowerCase()) ||
      (item.notes !== undefined &&
        (typeof item.notes !== "string" || item.notes.length > 500))
    ) {
      throw new HttpsError("invalid-argument", "Invalid return item details.");
    }
    seen.add(equipmentId);
    return {
      equipmentId,
      name: item.name,
      bookedQuantity: item.bookedQuantity,
      returnedQuantity: returnedQuantity as number,
      damagedQuantity: damagedQuantity as number,
      missingQuantity: missingQuantity as number,
      condition: item.condition,
      notes: typeof item.notes === "string" ? item.notes : "",
    };
  });
};

export const recordReturn = onCall(async (request) => {
  const uid = requireCaller(request, "returns.record");
  const {bookingId, requestId} = request.data ?? {};
  if (!isNonEmptyString(bookingId) || !isNonEmptyString(requestId)) {
    throw new HttpsError(
      "invalid-argument",
      "A booking and request id are required.",
    );
  }
  const items = parseReturnItems(request.data.items);
  const returnRef = db().collection("returns").doc(bookingId);
  const returnAuditId = `return-recorded-${bookingId}`;
  const returnAuditRef = db().collection("auditLogs").doc(returnAuditId);
  const bookingRef = db().collection("bookings").doc(bookingId);
  await db().runTransaction(async (transaction) => {
    const [bookingSnapshot, returnSnapshot, auditSnapshot] = await Promise.all([
      transaction.get(bookingRef),
      transaction.get(returnRef),
      transaction.get(returnAuditRef),
    ]);
    if (!bookingSnapshot.exists) {
      throw new HttpsError("not-found", "Booking not found.");
    }
    if (returnSnapshot.exists || auditSnapshot.exists) return;
    const booking = bookingSnapshot.data()!;
    if (booking.status !== "confirmed") {
      throw new HttpsError(
        "failed-precondition",
        "Only confirmed bookings can be returned.",
      );
    }
    const bookedItems = bookingItems(booking);
    if (items.length !== bookedItems.length) {
      throw new HttpsError(
        "invalid-argument",
        "Every booked item must be inspected.",
      );
    }
    for (const item of items) {
      const booked = bookedItems.find(
        (entry) => entry.equipmentId === item.equipmentId,
      );
      if (!booked || item.bookedQuantity !== booked.quantity) {
        throw new HttpsError(
          "invalid-argument",
          "Return items do not match the booking.",
        );
      }
    }
    const equipmentRefs = items.map((item) =>
      db().collection("equipment").doc(item.equipmentId),
    );
    const equipmentSnapshots = await transaction.getAll(...equipmentRefs);
    equipmentSnapshots.forEach((snapshot, index) => {
      if (!snapshot.exists) {
        throw new HttpsError(
          "failed-precondition",
          "Equipment no longer exists.",
        );
      }
      const equipment = snapshot.data()!;
      const availableQuantity = equipment.availableQuantity;
      const unavailable =
        (equipment.unavailableQuantity as number | undefined) ?? 0;
      const newlyHeld =
        items[index].returnedQuantity + items[index].missingQuantity;
      if (
        typeof availableQuantity !== "number" ||
        !Number.isInteger(availableQuantity) ||
        availableQuantity < 0 ||
        typeof unavailable !== "number" ||
        !Number.isInteger(unavailable) ||
        unavailable < 0 ||
        unavailable + newlyHeld > availableQuantity
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Return quantities exceed tracked stock.",
        );
      }
      const nextUnavailable = unavailable + newlyHeld;
      transaction.update(equipmentRefs[index], {
        unavailableQuantity: nextUnavailable,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    transaction.create(returnRef, {
      bookingId,
      eventName: booking.eventName ?? "Event booking",
      items,
      status: "pending_inspection",
      recordedBy: uid,
      recordedAt: FieldValue.serverTimestamp(),
      approvedBy: null,
      approvedAt: null,
    });
    writeAudit(transaction, returnAuditId, uid, "return.recorded", bookingId);
  });
  return {returnId: bookingId, recorded: true};
});

export const approveReturn = onCall(async (request) => {
  const uid = requireCaller(request, "returns.approve");
  const {returnId, requestId} = request.data ?? {};
  if (!isNonEmptyString(returnId) || !isNonEmptyString(requestId)) {
    throw new HttpsError(
      "invalid-argument",
      "A return and request id are required.",
    );
  }
  const returnRef = db().collection("returns").doc(returnId);
  const auditRef = db()
    .collection("auditLogs")
    .doc(`return-approved-${requestId}`);
  await db().runTransaction(async (transaction) => {
    const [returnSnapshot, auditSnapshot] = await Promise.all([
      transaction.get(returnRef),
      transaction.get(auditRef),
    ]);
    if (!returnSnapshot.exists) {
      throw new HttpsError("not-found", "Return record not found.");
    }
    if (auditSnapshot.exists) return;
    const returnData = returnSnapshot.data()!;
    if (
      returnData.status !== "pending_inspection" ||
      !Array.isArray(returnData.items)
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Return is not awaiting inspection.",
      );
    }
    const linkedBookingRef = db()
      .collection("bookings")
      .doc(returnData.bookingId);
    const dispatchRef = db().collection("dispatches").doc(returnData.bookingId);
    const [bookingSnapshot, dispatchSnapshot] = await Promise.all([
      transaction.get(linkedBookingRef),
      transaction.get(dispatchRef),
    ]);
    if (!bookingSnapshot.exists) {
      throw new HttpsError(
        "failed-precondition",
        "The linked booking no longer exists.",
      );
    }
    const items = returnData.items as ReturnItem[];
    const equipmentRefs = items.map((item) =>
      db().collection("equipment").doc(item.equipmentId),
    );
    const equipmentSnapshots = await Promise.all(
      equipmentRefs.map((ref) => transaction.get(ref)),
    );
    equipmentSnapshots.forEach((snapshot, index) => {
      if (!snapshot.exists) {
        throw new HttpsError(
          "failed-precondition",
          "Equipment no longer exists.",
        );
      }
      const item = items[index];
      const data = snapshot.data()!;
      const unavailable = (data.unavailableQuantity as number | undefined) ?? 0;
      const releaseInspected = item.returnedQuantity - item.damagedQuantity;
      const nextUnavailable = unavailable - releaseInspected;
      if (nextUnavailable < item.damagedQuantity + item.missingQuantity) {
        throw new HttpsError(
          "failed-precondition",
          "Inventory inspection state is inconsistent.",
        );
      }
      transaction.update(equipmentRefs[index], {
        unavailableQuantity: nextUnavailable,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    transaction.update(returnRef, {
      status: "approved",
      items: items.map((item) => ({...item, resolvedQuantity: 0})),
      approvedBy: uid,
      approvedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(linkedBookingRef, {
      status: "returned",
      returnedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (dispatchSnapshot.exists) {
      transaction.update(dispatchRef, {
        status: "completed",
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    writeAudit(
      transaction,
      `return-approved-${requestId}`,
      uid,
      "return.approved",
      returnId,
    );
  });
  return {returnId, approved: true};
});

export const resolveUnavailableEquipment = onCall(async (request) => {
  const uid = requireCaller(request, "maintenance.manage");
  const {returnId, equipmentId, quantity, requestId} = request.data ?? {};
  if (
    !isNonEmptyString(returnId) ||
    !isNonEmptyString(equipmentId) ||
    !isNonEmptyString(requestId) ||
    typeof quantity !== "number" ||
    !Number.isInteger(quantity) ||
    quantity < 1
  ) {
    throw new HttpsError("invalid-argument", "Invalid equipment resolution.");
  }
  const returnRef = db().collection("returns").doc(returnId);
  const equipmentRef = db().collection("equipment").doc(equipmentId);
  const auditRef = db()
    .collection("auditLogs")
    .doc(`equipment-resolved-${requestId}`);
  await db().runTransaction(async (transaction) => {
    const [returnSnapshot, equipmentSnapshot, auditSnapshot] =
      await Promise.all([
        transaction.get(returnRef),
        transaction.get(equipmentRef),
        transaction.get(auditRef),
      ]);
    if (
      !returnSnapshot.exists ||
      returnSnapshot.data()?.status !== "approved"
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Only approved return issues can be resolved.",
      );
    }
    if (!equipmentSnapshot.exists) {
      throw new HttpsError("not-found", "Equipment not found.");
    }
    if (auditSnapshot.exists) return;
    const returnData = returnSnapshot.data()!;
    const items = returnData.items;
    if (!Array.isArray(items)) {
      throw new HttpsError(
        "failed-precondition",
        "Return issue details are missing.",
      );
    }
    const itemIndex = items.findIndex(
      (item: {equipmentId?: string}) => item.equipmentId === equipmentId,
    );
    if (itemIndex < 0) {
      throw new HttpsError(
        "not-found",
        "Equipment is not part of this return.",
      );
    }
    const item = items[itemIndex] as ReturnItem & {resolvedQuantity?: number};
    const resolved = item.resolvedQuantity ?? 0;
    const unresolved = item.damagedQuantity + item.missingQuantity - resolved;
    if (quantity > unresolved) {
      throw new HttpsError(
        "failed-precondition",
        "Resolution exceeds this return's unresolved quantity.",
      );
    }
    const data = equipmentSnapshot.data()!;
    const unavailable = (data.unavailableQuantity as number | undefined) ?? 0;
    if (quantity > unavailable) {
      throw new HttpsError(
        "failed-precondition",
        "Resolution exceeds unavailable stock.",
      );
    }
    transaction.update(equipmentRef, {
      unavailableQuantity: unavailable - quantity,
      updatedAt: FieldValue.serverTimestamp(),
    });
    const updatedItems = [...items];
    updatedItems[itemIndex] = {...item, resolvedQuantity: resolved + quantity};
    transaction.update(returnRef, {items: updatedItems});
    writeAudit(
      transaction,
      `equipment-resolved-${requestId}`,
      uid,
      "equipment.issue_resolved",
      equipmentId,
      {quantity, returnId},
    );
  });
  return {equipmentId, resolved: quantity};
});

const dashboardReadLimit = 5000;

const timestampMillis = (value: unknown): number | null => {
  if (value instanceof Timestamp) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return typeof value === "number" && Number.isFinite(value) ?
    value :
    null;
};

const dashboardBooking = (
  id: string,
  data: FirebaseFirestore.DocumentData,
): DashboardBooking => ({
  id,
  status: typeof data.status === "string" ? data.status : "",
  eventName: typeof data.eventName === "string" ? data.eventName : "Event",
  venue: typeof data.venue === "string" ? data.venue : "",
  startDateMillis: timestampMillis(data.startDate),
  endDateMillis: timestampMillis(data.endDate),
  items: Array.isArray(data.items) ?
    data.items.flatMap((raw: unknown): DashboardItem[] => {
      if (typeof raw !== "object" || raw === null) return [];
      const item = raw as Record<string, unknown>;
      return typeof item.equipmentId === "string" &&
        typeof item.quantity === "number" &&
        Number.isInteger(item.quantity) &&
        item.quantity > 0 ?
        [{equipmentId: item.equipmentId, quantity: item.quantity}] :
        [];
    }) :
    [],
});

export const getOperationsDashboard = onCall(async (request) => {
  requireCaller(request, "dashboard.view");
  const timeZoneOffsetMinutes =
    request.data?.timeZoneOffsetMinutes === undefined ?
      0 :
      request.data.timeZoneOffsetMinutes;
  if (
    typeof timeZoneOffsetMinutes !== "number" ||
    !Number.isInteger(timeZoneOffsetMinutes) ||
    Math.abs(timeZoneOffsetMinutes) > 14 * 60
  ) {
    throw new HttpsError("invalid-argument", "Invalid dashboard time zone.");
  }
  const [
    bookingsSnapshot,
    equipmentSnapshot,
    dispatchesSnapshot,
    pendingReturnsSnapshot,
  ] = await Promise.all([
    db().collection("bookings")
      .where("status", "==", "confirmed")
      .limit(dashboardReadLimit + 1)
      .get(),
    db().collection("equipment")
      .limit(dashboardReadLimit + 1)
      .get(),
    db().collection("dispatches")
      .where("status", "in", [
        "pending",
        "preparing",
        "ready",
        "dispatched",
        "delivered",
      ])
      .limit(dashboardReadLimit + 1)
      .get(),
    db().collection("returns")
      .where("status", "==", "pending_inspection")
      .limit(dashboardReadLimit + 1)
      .get(),
  ]);

  if (
    bookingsSnapshot.size > dashboardReadLimit ||
    equipmentSnapshot.size > dashboardReadLimit ||
    dispatchesSnapshot.size > dashboardReadLimit ||
    pendingReturnsSnapshot.size > dashboardReadLimit
  ) {
    throw new HttpsError(
      "resource-exhausted",
      "The dashboard data exceeds the supported summary size.",
    );
  }

  const bookings = bookingsSnapshot.docs.map((document) =>
    dashboardBooking(document.id, document.data()),
  );
  const equipment: DashboardEquipment[] = equipmentSnapshot.docs.map(
    (document) => {
      const data = document.data();
      return {
        id: document.id,
        status: typeof data.status === "string" ? data.status : "",
        totalQuantity:
          typeof data.totalQuantity === "number" ? data.totalQuantity : 0,
        availableQuantity:
          typeof data.availableQuantity === "number" ?
            data.availableQuantity :
            0,
        unavailableQuantity:
          typeof data.unavailableQuantity === "number" ?
            data.unavailableQuantity :
            0,
      };
    },
  );
  const dispatches: DashboardDispatch[] = dispatchesSnapshot.docs.map(
    (document) => ({
      bookingId: document.id,
      status: typeof document.data().status === "string" ?
        document.data().status :
        "",
    }),
  );
  const nowMillis = Date.now();
  const offsetMillis = timeZoneOffsetMinutes * 60 * 1000;
  const startOfToday = new Date(nowMillis + offsetMillis);
  startOfToday.setUTCHours(0, 0, 0, 0);
  const todayMillis = startOfToday.getTime() - offsetMillis;
  const bookingById = new Map(bookings.map((booking) => [booking.id, booking]));
  const overdueCandidateIds = dispatches
    .filter((dispatch) => {
      const booking = bookingById.get(dispatch.bookingId);
      return (
        (dispatch.status === "dispatched" || dispatch.status === "delivered") &&
        booking?.endDateMillis !== null &&
        booking?.endDateMillis !== undefined &&
        booking.endDateMillis < todayMillis
      );
    })
    .map((dispatch) => dispatch.bookingId);
  const returnRecordsById = new Map<string, DashboardReturn>();
  pendingReturnsSnapshot.docs.forEach((snapshot) => {
    returnRecordsById.set(snapshot.id, {
      bookingId: snapshot.id,
      status: "pending_inspection",
    });
  });
  const returnRefs = overdueCandidateIds.map((id) =>
    db().collection("returns").doc(id),
  );
  for (let index = 0; index < returnRefs.length; index += 250) {
    const batch = returnRefs.slice(index, index + 250);
    const snapshots = await db().getAll(...batch);
    snapshots.forEach((snapshot) => {
      if (!snapshot.exists) return;
      const status = snapshot.data()?.status;
      returnRecordsById.set(snapshot.id, {
        bookingId: snapshot.id,
        status: typeof status === "string" ? status : "",
      });
    });
  }

  return {
    ...summarizeOperations(
      nowMillis,
      timeZoneOffsetMinutes,
      bookings,
      equipment,
      dispatches,
      [...returnRecordsById.values()],
    ),
    generatedAtMillis: nowMillis,
  };
});
