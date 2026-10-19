#!/usr/bin/env bash
set -euo pipefail

# Set the protocol fee taken from every tip, in basis points (#79).
#
# Required env (see .env.example):
#   NETWORK      testnet | mainnet | local
#   SOURCE       Stellar CLI identity used to sign (must be the contract admin)
#   FEE_BPS      optional; fee in basis points, 0..=500. Defaults to 100 (1%),
#                the configured value the fee was introduced with. 0 turns the
#                fee off.
#   CONTRACT_ID  optional; defaults to .contract-id.<NETWORK>
#
# Usage:  set -a; source .env; set +a; ./scripts/set-fee.sh
#         FEE_BPS=0 ./scripts/set-fee.sh   # stop charging
#
# The contract defaults to 0, so a fresh or upgraded deployment charges nothing
# until this runs. Values above 500 (5%) are rejected by the contract with
# FeeTooHigh; this script refuses them first, before paying for a network call.

. "$(dirname "${BASH_SOURCE[0]}")/lib/env.sh"

: "${NETWORK:?set NETWORK}"
: "${SOURCE:?set SOURCE}"
FEE_BPS="${FEE_BPS:-100}"
require_contract_id

if [[ ! "${FEE_BPS}" =~ ^[0-9]+$ ]]; then
  echo "error: FEE_BPS must be a non-negative integer number of basis points (got '${FEE_BPS}')" >&2
  exit 1
fi
# Strip leading zeros so "0100" is read as 100, not as octal.
FEE_BPS=$((10#${FEE_BPS}))
if [ "${FEE_BPS}" -gt 500 ]; then
  echo "error: FEE_BPS=${FEE_BPS} is above the 500 bps (5%) cap; the contract would reject it with FeeTooHigh" >&2
  exit 1
fi

echo "==> Setting the protocol fee to ${FEE_BPS} bps"
stellar contract invoke \
  --id "${CONTRACT_ID}" \
  --source "${SOURCE}" \
  --network "${NETWORK}" \
  -- \
  set_fee_bps \
  --fee_bps "${FEE_BPS}"

# The CLI prints nothing on success, so read the value back.
echo "==> Reading back the configured fee"
stellar contract invoke \
  --id "${CONTRACT_ID}" \
  --source "${SOURCE}" \
  --network "${NETWORK}" \
  -- \
  get_fee_bps
