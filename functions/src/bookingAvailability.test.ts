import {test} from "node:test";
import * as assert from "node:assert/strict";
import {
  bookingDatesOverlap,
  bookingReservesStock,
  remainingStock,
} from "./bookingAvailability";

test("confirmed bookings reserve stock; cancelled and returned do not", () => {
  assert.equal(bookingReservesStock("confirmed"), true);
  assert.equal(bookingReservesStock("CONFIRMED"), true);
  assert.equal(bookingReservesStock("cancelled"), false);
  assert.equal(bookingReservesStock("returned"), false);
});

test("booking dates overlap inclusively at a shared event day", () => {
  assert.equal(
    bookingDatesOverlap(
      new Date("2026-10-01T00:00:00Z"),
      new Date("2026-10-03T00:00:00Z"),
      new Date("2026-10-03T00:00:00Z"),
      new Date("2026-10-05T00:00:00Z"),
    ),
    true,
  );
  assert.equal(
    bookingDatesOverlap(
      new Date("2026-10-01T00:00:00Z"),
      new Date("2026-10-02T00:00:00Z"),
      new Date("2026-10-03T00:00:00Z"),
      new Date("2026-10-05T00:00:00Z"),
    ),
    false,
  );
});

test(
  "remaining stock accounts for holds and reservations",
  () => {
    assert.equal(remainingStock(10, 2, 5), 3);
    assert.equal(remainingStock(10, 2, 12), 0);
    assert.equal(remainingStock(10, 11, 0), 0);
    assert.equal(remainingStock(-1, 0, 0), 0);
  },
);
