export const bookingReservesStock = (status: unknown): boolean =>
  typeof status === "string" && status.toLowerCase() === "confirmed";

export const bookingDatesOverlap = (
  leftStart: Date,
  leftEnd: Date,
  rightStart: Date,
  rightEnd: Date,
): boolean =>
  leftStart.getTime() <= rightEnd.getTime() &&
  rightStart.getTime() <= leftEnd.getTime();

export const remainingStock = (
  availableQuantity: number,
  unavailableQuantity: number,
  reservedQuantity: number,
): number => {
  if (
    ![availableQuantity, unavailableQuantity, reservedQuantity].every(
      (quantity) => Number.isInteger(quantity) && quantity >= 0,
    ) ||
    unavailableQuantity > availableQuantity
  ) {
    return 0;
  }
  return Math.max(
    0,
    availableQuantity - unavailableQuantity - reservedQuantity,
  );
};
