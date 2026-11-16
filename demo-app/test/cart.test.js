import assert from "node:assert/strict";
import { test } from "node:test";
import { calculateTotal } from "../src/cart.js";

test("adds item quantities in integer cents", () => {
  assert.equal(
    calculateTotal([
      { sku: "coffee", unitPriceCents: 450, quantity: 2 },
      { sku: "tea", unitPriceCents: 325, quantity: 1 },
    ]),
    1225,
  );
});

test("discounts items before adding shipping", () => {
  assert.equal(
    calculateTotal([{ unitPriceCents: 1000, quantity: 2 }], {
      discountPercent: 10,
      shippingCents: 500,
    }),
    2300,
  );
});

test("rounds a discount to the nearest cent", () => {
  assert.equal(
    calculateTotal([{ unitPriceCents: 999, quantity: 1 }], {
      discountPercent: 10,
    }),
    899,
  );
});

test("an empty cart has no items but can have shipping", () => {
  assert.equal(calculateTotal([]), 0);
  assert.equal(calculateTotal([], { shippingCents: 200 }), 200);
});

test("rejects fractional, negative and invalid inputs", () => {
  for (const item of [
    { unitPriceCents: -1, quantity: 1 },
    { unitPriceCents: 1.5, quantity: 1 },
    { unitPriceCents: 100, quantity: 0 },
    { unitPriceCents: 100, quantity: 1.5 },
  ]) {
    assert.throws(() => calculateTotal([item]), RangeError);
  }
  assert.throws(() => calculateTotal(null), TypeError);
  assert.throws(() => calculateTotal([null]), TypeError);
  assert.throws(() => calculateTotal([], { discountPercent: 101 }), RangeError);
  assert.throws(() => calculateTotal([], { shippingCents: -1 }), RangeError);
});

test("rejects totals outside the safe integer range", () => {
  assert.throws(
    () =>
      calculateTotal([
        { unitPriceCents: Number.MAX_SAFE_INTEGER, quantity: 2 },
      ]),
    RangeError,
  );
});
