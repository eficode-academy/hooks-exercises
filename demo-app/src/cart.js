function requireInteger(value, name, minimum = 0) {
  if (!Number.isSafeInteger(value) || value < minimum) {
    throw new RangeError(
      `${name} must be a safe integer of at least ${minimum}`,
    );
  }
}

export function calculateTotal(
  items,
  { discountPercent = 0, shippingCents = 0 } = {},
) {
  if (!Array.isArray(items)) {
    throw new TypeError("items must be an array");
  }
  requireInteger(discountPercent, "discountPercent");
  if (discountPercent > 100) {
    throw new RangeError("discountPercent cannot exceed 100");
  }
  requireInteger(shippingCents, "shippingCents");

  const subtotalCents = items.reduce((total, item) => {
    if (item === null || typeof item !== "object") {
      throw new TypeError("each item must be an object");
    }
    requireInteger(item.unitPriceCents, "unitPriceCents");
    requireInteger(item.quantity, "quantity", 1);
    const next = total + item.unitPriceCents * item.quantity;
    requireInteger(next, "subtotalCents");
    return next;
  }, 0);

  const discountedCents = Math.round(
    (subtotalCents * (100 - discountPercent)) / 100,
  );
  const totalCents = discountedCents + shippingCents;
  requireInteger(totalCents, "totalCents");
  return totalCents;
}
