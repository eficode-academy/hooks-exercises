// Deliberate bug for disposable test copies; never part of the baseline app.
export function calculateTotal(items) {
  return items.reduce(
    (total, item) => total + item.unitPriceCents * item.quantity,
    0,
  );
}
