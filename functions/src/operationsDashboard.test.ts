import assert from "node:assert/strict";
import test from "node:test";
import {
  DashboardBooking,
  DashboardEquipment,
  summarizeOperations,
} from "./operationsDashboard";

const booking = (
  id: string,
  startDateMillis: number,
  endDateMillis: number,
  quantity = 1,
): DashboardBooking => ({
  id,
  status: "confirmed",
  eventName: `Event ${id}`,
  venue: "Main hall",
  startDateMillis,
  endDateMillis,
  items: [{equipmentId: "speaker", quantity}],
});

const equipment: DashboardEquipment[] = [{
  id: "speaker",
  status: "Available",
  totalQuantity: 5,
  availableQuantity: 5,
  unavailableQuantity: 1,
}];

test("summarizes operations dashboard metrics", () => {
  const now = Date.UTC(2026, 9, 27, 12);
  const today = Date.UTC(2026, 9, 27);
  const nextWeek = today + 7 * 24 * 60 * 60 * 1000;
  const result = summarizeOperations(
    now,
    0,
    [
      booking("upcoming", nextWeek, nextWeek),
      booking(
        "overdue",
        today - 4 * 24 * 60 * 60 * 1000,
        today - 2 * 24 * 60 * 60 * 1000,
      ),
      {...booking("cancelled", nextWeek, nextWeek), status: "cancelled"},
    ],
    equipment,
    [
      {bookingId: "pending", status: "preparing"},
      {bookingId: "overdue", status: "delivered"},
    ],
    [],
  );

  assert.equal(result.upcomingEventCount, 1);
  assert.equal(result.upcomingEvents[0].id, "upcoming");
  assert.equal(result.totalUnits, 5);
  assert.equal(result.availableUnits, 4);
  assert.equal(result.unavailableUnits, 1);
  assert.equal(result.pendingDispatchCount, 1);
  assert.equal(result.overdueReturnCount, 1);
  assert.equal(result.overdueReturns[0].bookingId, "overdue");
});

test("excludes returned bookings and counts pending inspections", () => {
  const today = Date.UTC(2026, 9, 27);
  const result = summarizeOperations(
    today,
    0,
    [booking("returned", today - 4, today - 2)],
    equipment,
    [{bookingId: "returned", status: "delivered"}],
    [
      {bookingId: "returned", status: "pending_inspection"},
      {bookingId: "other", status: "approved"},
    ],
  );

  assert.equal(result.overdueReturnCount, 0);
  assert.equal(result.returnsPendingInspectionCount, 1);
});

test("counts bookings participating in simultaneous stock conflicts", () => {
  const today = Date.UTC(2026, 9, 27);
  const day = 24 * 60 * 60 * 1000;
  const bookings: DashboardBooking[] = [
    booking("first", today, today + day, 3),
    booking("second", today + day, today + 2 * day, 2),
    booking("separate", today + 3 * day, today + 4 * day, 4),
  ];
  const result = summarizeOperations(
    today,
    0,
    bookings,
    equipment,
    [],
    [],
  );

  assert.equal(result.conflictCount, 2);
});

test("does not treat non-simultaneous bookings as a conflict", () => {
  const today = Date.UTC(2026, 9, 27);
  const day = 24 * 60 * 60 * 1000;
  const bookings = [
    booking("left", today, today + day, 3),
    booking("middle", today, today + 2 * day, 1),
    booking("right", today + 2 * day, today + 3 * day, 3),
  ];
  const result = summarizeOperations(today, 0, bookings, equipment, [], []);

  assert.equal(result.conflictCount, 0);
});

test("marks bookings referencing missing equipment", () => {
  const today = Date.UTC(2026, 9, 27);
  const result = summarizeOperations(
    today,
    0,
    [{
      ...booking("orphaned", today, today),
      items: [{equipmentId: "missing", quantity: 1}],
    }],
    equipment,
    [],
    [],
  );

  assert.equal(result.conflictCount, 1);
});

test("uses the caller's local offset for date-only event boundaries", () => {
  const now = Date.UTC(2026, 9, 27, 0, 30);
  const localStartOfToday = Date.UTC(2026, 9, 26, 18, 30);
  const result = summarizeOperations(
    now,
    330,
    [booking("local-today", localStartOfToday, localStartOfToday)],
    equipment,
    [],
    [],
  );

  assert.equal(result.upcomingEventCount, 1);
});
