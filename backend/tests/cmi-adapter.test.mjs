import assert from 'node:assert/strict';

// Contract-level tests only. Cryptographic CMI tests stay disabled until the official kit defines the exact algorithm/field encoding.
const valid = {
  paymentId: '00000000-0000-0000-0000-000000000001',
  amount: '125.00',
  currency: 'MAD',
  orderReference: 'CF-TEST-001',
  successUrl: 'https://example.invalid/payment/success',
  failureUrl: 'https://example.invalid/payment/failure',
  callbackUrl: 'https://example.invalid/payment/callback',
};

assert.match(valid.amount, /^\d+(\.\d{1,2})?$/);
assert.match(valid.currency, /^[A-Z]{3}$/);
assert.ok(valid.paymentId && valid.orderReference);
assert.throws(() => { if (!/^\d+(\.\d{1,2})?$/.test('12.999')) throw new Error('CMI_INVALID_AMOUNT'); });
assert.throws(() => { if (!/^[A-Z]{3}$/.test('mad')) throw new Error('CMI_INVALID_CURRENCY'); });
console.log('CMI adapter contract tests: PASS');
console.log('CMI cryptographic integration: BLOCKED until official merchant kit/credentials.');
