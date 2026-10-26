import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/https";
import {db} from "./admin";
import {
  bookingDatesOverlap,
  bookingReservesStock,
  remainingStock,
} from "./bookingAvailability";
import {hasPermission} from "./roles";

type BookingItem = {
  equipmentId: string;
  name: string;
  quantity: number;
};

type BookingInput = {
  customerName: string;
  customerPhone: string;
  eventName: string;
  venue: string;
  staffName: string;
  notes: string;
  startDate: Timestamp;
  endDate: Timestamp;
  items: BookingItem[];
};

const validText = (
  value: unknown,
  max: number,
  allowEmpty = false,
): value is string =>
  typeof value === "string" && value.length <= max &&
  (allowEmpty || value.trim().length > 0);

const parseBooking = (value: unknown): BookingInput => {
  if (typeof value !== "object" || value === null) {
    throw new HttpsError("invalid-argument", "Booking details are required.");
  }
  const data = value as Record<string, unknown>;
  if (
    !validText(data.customerName, 120) ||
    !validText(data.customerPhone, 40, true) ||
    !validText(data.eventName, 120) ||
    !validText(data.venue, 200) ||
    !validText(data.staffName, 120) ||
    !validText(data.notes, 1000, true) ||
    typeof data.startDate !== "number" ||
    !Number.isSafeInteger(data.startDate) ||
    typeof data.endDate !== "number" ||
    !Number.isSafeInteger(data.endDate) ||
    !Array.isArray(data.items) ||
    data.items.length === 0 ||
    data.items.length > 50
  ) {
    throw new HttpsError("invalid-argument", "Invalid booking details.");
  }

  const startDate = Timestamp.fromMillis(data.startDate);
  const endDate = Timestamp.fromMillis(data.endDate);
  const start = startDate.toDate();
  const end = endDate.toDate();
  const days = Math.floor((end.getTime() - start.getTime()) / 86400000);
  if (days < 0 || days > 365) {
    throw new HttpsError("invalid-argument", "Booking dates are invalid.");
  }

  const seen = new Set<string>();
  const items = data.items.map((raw): BookingItem => {
    if (typeof raw !== "object" || raw === null) {
      throw new HttpsError("invalid-argument", "Invalid booking item.");
    }
    const item = raw as Record<string, unknown>;
    if (
      typeof item.equipmentId !== "string" ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(item.equipmentId) ||
      seen.has(item.equipmentId) ||
      !validText(item.name, 200) ||
      typeof item.quantity !== "number" ||
      !Number.isInteger(item.quantity) ||
      item.quantity < 1 ||
      item.quantity > 10000
    ) {
      throw new HttpsError("invalid-argument", "Invalid booking item.");
    }
    seen.add(item.equipmentId);
    return {
      equipmentId: item.equipmentId,
      name: item.name,
      quantity: item.quantity,
    };
  });
  return {
    customerName: data.customerName.trim(),
    customerPhone: data.customerPhone.trim(),
    eventName: data.eventName.trim(),
    venue: data.venue.trim(),
    staffName: data.staffName.trim(),
    notes: data.notes.trim(),
    startDate,
    endDate,
    items,
  };
};

const bookingLockId = (equipmentId: string): string => equipmentId;

export const saveBooking = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  const editing = request.data?.bookingId !== undefined;
  const permission = editing ? "bookings.edit" : "bookings.create";
  if (!hasPermission(request.auth.token.role, permission)) {
    throw new HttpsError("permission-denied", "You do not have permission.");
  }
  const bookingId = editing ? request.data.bookingId : request.data?.requestId;
  const requestId = request.data?.requestId;
  if (
    typeof bookingId !== "string" ||
    !/^[A-Za-z0-9_-]{1,128}$/.test(bookingId) ||
    typeof requestId !== "string" ||
    !/^[A-Za-z0-9_-]{1,128}$/.test(requestId)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "A valid booking and request id are required.",
    );
  }
  const input = parseBooking(request.data.booking);
  const bookingRef = db().collection("bookings").doc(bookingId);
  const lockRefs = input.items.map((item) =>
    db().collection("availabilityLocks").doc(bookingLockId(item.equipmentId)),
  );
  const equipmentRefs = input.items.map((item) =>
    db().collection("equipment").doc(item.equipmentId),
  );
  const auditId = `booking-saved-${requestId}`;
  const auditRef = db().collection("auditLogs").doc(auditId);

  await db().runTransaction(async (transaction) => {
    const [bookingSnapshot, auditSnapshot, allBookings] = await Promise.all([
      transaction.get(bookingRef),
      transaction.get(auditRef),
      transaction.get(db().collection("bookings")),
    ]);
    if (auditSnapshot.exists && bookingSnapshot.exists) return;
    if (editing && !bookingSnapshot.exists) {
      throw new HttpsError("not-found", "Booking not found.");
    }

    const [equipmentSnapshots, lockSnapshots] = await Promise.all([
      transaction.getAll(...equipmentRefs),
      transaction.getAll(...lockRefs),
    ]);
    const existing = bookingSnapshot.data();
    const overlaps = allBookings.docs.filter((document) => {
      if (document.id === bookingId) return false;
      const data = document.data();
      return bookingReservesStock(data.status) &&
        data.startDate instanceof Timestamp &&
        data.endDate instanceof Timestamp &&
        bookingDatesOverlap(
          input.startDate.toDate(),
          input.endDate.toDate(),
          data.startDate.toDate(),
          data.endDate.toDate(),
        );
    });

    for (let index = 0; index < input.items.length; index++) {
      const item = input.items[index];
      const equipment = equipmentSnapshots[index];
      if (!equipment.exists) {
        throw new HttpsError(
          "failed-precondition",
          `${item.name} is no longer in inventory.`,
        );
      }
      const data = equipment.data()!;
      const status = typeof data.status === "string" ?
        data.status.toLowerCase() :
        "";
      const availableQuantity = data.availableQuantity;
      const unavailable = data.unavailableQuantity ?? 0;
      if (
        typeof availableQuantity !== "number" ||
        !Number.isInteger(availableQuantity) ||
        availableQuantity < 0 ||
        typeof unavailable !== "number" ||
        !Number.isInteger(unavailable) ||
        unavailable < 0 ||
        unavailable > availableQuantity ||
        ["damaged", "under maintenance", "retired"].includes(status)
      ) {
        throw new HttpsError(
          "failed-precondition",
          `${item.name} is unavailable.`,
        );
      }
      const reserved = overlaps.reduce((sum, document) => {
        const data = document.data();
        const currentItems = data.items;
        if (!Array.isArray(currentItems)) return sum;
        const matched = currentItems.find(
          (current: {equipmentId?: string}) =>
            current.equipmentId === item.equipmentId,
        );
        return sum + (
          typeof matched?.quantity === "number" ? matched.quantity : 0
        );
      }, 0);
      const available = remainingStock(
        availableQuantity,
        unavailable,
        reserved,
      );
      if (item.quantity > available) {
        throw new HttpsError(
          "failed-precondition",
          `${item.name}: ${available} available for the selected dates.`,
        );
      }
    }

    const bookingData: Record<string, unknown> = {
      ...input,
      status: existing?.status ?? "confirmed",
      updatedBy: request.auth!.uid,
      updatedAt: FieldValue.serverTimestamp(),
      ...(existing ? {} : {
        createdAt: FieldValue.serverTimestamp(),
        createdBy: request.auth!.uid,
      }),
    };
    if (existing) {
      transaction.update(bookingRef, bookingData);
    } else {
      transaction.create(bookingRef, bookingData);
    }
    lockSnapshots.forEach((snapshot, index) => {
      const version = snapshot.data()?.version;
      transaction.set(lockRefs[index], {
        version: typeof version === "number" ? version + 1 : 1,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    transaction.create(auditRef, {
      action: editing ? "booking.updated" : "booking.created",
      actorUid: request.auth!.uid,
      resourceId: bookingId,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  return {bookingId, saved: true};
});

export const cancelBooking = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  if (!hasPermission(request.auth.token.role, "bookings.cancel")) {
    throw new HttpsError("permission-denied", "You do not have permission.");
  }
  const {bookingId, requestId} = request.data ?? {};
  if (
    typeof bookingId !== "string" ||
    !/^[A-Za-z0-9_-]{1,128}$/.test(bookingId) ||
    typeof requestId !== "string" ||
    !/^[A-Za-z0-9_-]{1,128}$/.test(requestId)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "A valid booking and request id are required.",
    );
  }
  const bookingRef = db().collection("bookings").doc(bookingId);
  const auditRef = db()
    .collection("auditLogs")
    .doc(`booking-cancelled-${requestId}`);
  await db().runTransaction(async (transaction) => {
    const [bookingSnapshot, auditSnapshot] = await Promise.all([
      transaction.get(bookingRef),
      transaction.get(auditRef),
    ]);
    if (!bookingSnapshot.exists) {
      throw new HttpsError("not-found", "Booking not found.");
    }
    if (auditSnapshot.exists) return;
    const booking = bookingSnapshot.data()!;
    if (!bookingReservesStock(booking.status)) {
      throw new HttpsError(
        "failed-precondition",
        "Only confirmed bookings can be cancelled.",
      );
    }
    const items = Array.isArray(booking.items) ?
      booking.items as BookingItem[] :
      [];
    const lockRefs = items.map((item) =>
      db().collection("availabilityLocks").doc(bookingLockId(item.equipmentId)),
    );
    const lockSnapshots = await transaction.getAll(...lockRefs);
    transaction.update(bookingRef, {
      status: "cancelled",
      cancelledAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    lockSnapshots.forEach((snapshot, index) => {
      const version = snapshot.data()?.version;
      transaction.set(lockRefs[index], {
        version: typeof version === "number" ? version + 1 : 1,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    transaction.create(auditRef, {
      action: "booking.cancelled",
      actorUid: request.auth!.uid,
      resourceId: bookingId,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  return {bookingId, cancelled: true};
});
