export type DashboardItem = {
  equipmentId: string;
  quantity: number;
};

export type DashboardBooking = {
  id: string;
  status: string;
  eventName: string;
  venue: string;
  startDateMillis: number | null;
  endDateMillis: number | null;
  items: DashboardItem[];
};

export type DashboardEquipment = {
  id: string;
  status: string;
  totalQuantity: number;
  availableQuantity: number;
  unavailableQuantity: number;
};

export type DashboardDispatch = {
  bookingId: string;
  status: string;
};

export type DashboardReturn = {
  bookingId: string;
  status: string;
};

type DashboardEvent = {
  id: string;
  eventName: string;
  venue: string;
  startDateMillis: number;
  endDateMillis: number;
};

type OverdueReturn = {
  bookingId: string;
  eventName: string;
  venue: string;
  endDateMillis: number;
};

type BookingInterval = {
  bookingId: string;
  startDateMillis: number;
  endDateMillis: number;
  quantity: number;
};

type StockEvent = {
  time: number;
  bookingId: string;
  quantity: number;
};

const activeBooking = (booking: DashboardBooking): boolean =>
  booking.status.toLowerCase() === "confirmed";

const equipmentCapacity = (equipment: DashboardEquipment): number => {
  if (
    ["damaged", "under maintenance", "retired"].includes(
      equipment.status.toLowerCase(),
    )
  ) {
    return 0;
  }
  if (
    !Number.isInteger(equipment.totalQuantity) ||
    !Number.isInteger(equipment.availableQuantity) ||
    !Number.isInteger(equipment.unavailableQuantity) ||
    equipment.totalQuantity < 0 ||
    equipment.availableQuantity < 0 ||
    equipment.unavailableQuantity < 0
  ) {
    return 0;
  }
  return Math.max(
    0,
    Math.min(
      equipment.totalQuantity,
      equipment.availableQuantity - equipment.unavailableQuantity,
    ),
  );
};

const findConflictingBookings = (
  bookings: DashboardBooking[],
  equipment: DashboardEquipment[],
): Set<string> => {
  const capacityByEquipment = new Map(
    equipment.map((item) => [item.id, equipmentCapacity(item)]),
  );
  const intervalsByEquipment = new Map<string, BookingInterval[]>();
  const conflicts = new Set<string>();

  for (const booking of bookings) {
    if (
      !activeBooking(booking) ||
      booking.startDateMillis === null ||
      booking.endDateMillis === null ||
      booking.endDateMillis < booking.startDateMillis
    ) {
      continue;
    }

    for (const item of booking.items) {
      if (!capacityByEquipment.has(item.equipmentId)) {
        conflicts.add(booking.id);
        continue;
      }
      if (!Number.isInteger(item.quantity) || item.quantity < 1) continue;

      const intervals = intervalsByEquipment.get(item.equipmentId) ?? [];
      intervals.push({
        bookingId: booking.id,
        startDateMillis: booking.startDateMillis,
        endDateMillis: booking.endDateMillis,
        quantity: item.quantity,
      });
      intervalsByEquipment.set(item.equipmentId, intervals);
    }
  }

  for (const [equipmentId, intervals] of intervalsByEquipment) {
    const capacity = capacityByEquipment.get(equipmentId) ?? 0;
    const events: StockEvent[] = intervals.flatMap((interval) => [
      {
        time: interval.startDateMillis,
        bookingId: interval.bookingId,
        quantity: interval.quantity,
      },
      {
        time: interval.endDateMillis + 1,
        bookingId: interval.bookingId,
        quantity: -interval.quantity,
      },
    ]);
    events.sort((left, right) => left.time - right.time);

    const activeQuantities = new Map<string, number>();
    const overCapacityIntervals: {start: number; end: number}[] = [];
    let activeQuantity = 0;
    let eventIndex = 0;
    while (eventIndex < events.length) {
      const eventTime = events[eventIndex].time;
      while (
        eventIndex < events.length &&
        events[eventIndex].time === eventTime
      ) {
        const event = events[eventIndex];
        activeQuantity += event.quantity;
        const quantity =
          (activeQuantities.get(event.bookingId) ?? 0) + event.quantity;
        if (quantity > 0) {
          activeQuantities.set(event.bookingId, quantity);
        } else {
          activeQuantities.delete(event.bookingId);
        }
        eventIndex += 1;
      }

      const nextEventTime = events[eventIndex]?.time;
      if (activeQuantity > capacity && nextEventTime !== undefined) {
        const last = overCapacityIntervals[overCapacityIntervals.length - 1];
        const end = nextEventTime - 1;
        if (last && last.end + 1 >= eventTime) {
          last.end = end;
        } else {
          overCapacityIntervals.push({start: eventTime, end});
        }
      }
    }

    intervals.sort(
      (left, right) => left.startDateMillis - right.startDateMillis,
    );
    let overCapacityIndex = 0;
    for (const interval of intervals) {
      while (
        overCapacityIndex < overCapacityIntervals.length &&
        overCapacityIntervals[overCapacityIndex].end <
          interval.startDateMillis
      ) {
        overCapacityIndex += 1;
      }
      if (
        overCapacityIndex < overCapacityIntervals.length &&
        overCapacityIntervals[overCapacityIndex].start <=
          interval.endDateMillis
      ) {
        conflicts.add(interval.bookingId);
      }
    }
  }

  return conflicts;
};

export const summarizeOperations = (
  nowMillis: number,
  timeZoneOffsetMinutes: number,
  bookings: DashboardBooking[],
  equipment: DashboardEquipment[],
  dispatches: DashboardDispatch[],
  returns: DashboardReturn[],
) => {
  const offsetMillis = timeZoneOffsetMinutes * 60 * 1000;
  const today = new Date(nowMillis + offsetMillis);
  today.setUTCHours(0, 0, 0, 0);
  const todayMillis = today.getTime() - offsetMillis;
  const upcomingLimit = todayMillis + 30 * 24 * 60 * 60 * 1000;
  const confirmedBookings = bookings.filter(activeBooking);
  const upcomingEvents: DashboardEvent[] = confirmedBookings
    .filter((booking) =>
      booking.startDateMillis !== null &&
      booking.startDateMillis >= todayMillis &&
      booking.startDateMillis <= upcomingLimit &&
      booking.endDateMillis !== null &&
      booking.endDateMillis >= booking.startDateMillis,
    )
    .map((booking) => ({
      id: booking.id,
      eventName: booking.eventName,
      venue: booking.venue,
      startDateMillis: booking.startDateMillis!,
      endDateMillis: booking.endDateMillis!,
    }))
    .sort((left, right) => left.startDateMillis - right.startDateMillis);

  const equipmentById = new Map(equipment.map((item) => [item.id, item]));
  const totalUnits = equipment.reduce(
    (total, item) =>
      total + (Number.isInteger(item.totalQuantity) ? item.totalQuantity : 0),
    0,
  );
  const availableUnits = equipment.reduce(
    (total, item) => total + equipmentCapacity(item),
    0,
  );
  const unavailableUnits = Math.max(0, totalUnits - availableUnits);
  const pendingDispatchCount = dispatches.filter((dispatch) =>
    ["pending", "preparing", "ready"].includes(dispatch.status.toLowerCase()),
  ).length;
  const dispatchByBooking = new Map(
    dispatches.map((dispatch) => [dispatch.bookingId, dispatch.status]),
  );
  const returnsByBooking = new Map(
    returns.map((record) => [record.bookingId, record.status]),
  );
  const overdueReturns: OverdueReturn[] = confirmedBookings
    .filter((booking) => {
      const status = dispatchByBooking.get(booking.id)?.toLowerCase();
      return (
        booking.endDateMillis !== null &&
        booking.endDateMillis < todayMillis &&
        (status === "dispatched" || status === "delivered") &&
        !returnsByBooking.has(booking.id)
      );
    })
    .map((booking) => ({
      bookingId: booking.id,
      eventName: booking.eventName,
      venue: booking.venue,
      endDateMillis: booking.endDateMillis!,
    }))
    .sort((left, right) => left.endDateMillis - right.endDateMillis);
  const conflicts = findConflictingBookings(confirmedBookings, equipment);

  return {
    upcomingEventCount: upcomingEvents.length,
    upcomingEvents: upcomingEvents.slice(0, 5),
    equipmentCount: equipmentById.size,
    totalUnits,
    availableUnits,
    unavailableUnits,
    pendingDispatchCount,
    overdueReturnCount: overdueReturns.length,
    overdueReturns: overdueReturns.slice(0, 5),
    conflictCount: conflicts.size,
    returnsPendingInspectionCount: returns.filter(
      (record) => record.status === "pending_inspection",
    ).length,
  };
};
