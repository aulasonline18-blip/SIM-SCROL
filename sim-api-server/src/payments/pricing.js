const SIM_PRICING = {
  currency: 'brl',
  packs: {
    credits_100: {credits: 100, amountCents: 790, lookupKey: 'credits_100'},
    credits_200: {credits: 200, amountCents: 1580, lookupKey: 'credits_200'},
    credits_500: {credits: 500, amountCents: 3950, lookupKey: 'credits_500'},
  },
};

function getCreditPackOrThrow(packId) {
  const pack = SIM_PRICING.packs[String(packId || '')];
  if (!pack) {
    const error = new Error('invalid_pack');
    error.statusCode = 400;
    throw error;
  }
  return {id: String(packId), ...pack};
}

module.exports = {SIM_PRICING, getCreditPackOrThrow};
