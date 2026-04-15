#!/usr/bin/env bash
set -euo pipefail

# Export variables from `.env` so Foundry (and child processes) can read them.
set -a
source .env
set +a

# usage:
#   ./script/upgrade-uups.sh base|monad|arbitrum upgradeLiquidityVault 0xProxy
#   ./script/upgrade-uups.sh base|monad|arbitrum upgradeOperator 0xProxy
#   ./script/upgrade-uups.sh base|monad|arbitrum upgradeSimpleOracleStrategy 0xProxy
#   ./script/upgrade-uups.sh base|monad|arbitrum upgradeDatastreamOracle 0xProxy
NETWORK="${1:-}"
FUNC="${2:-}"
PROXY="${3:-}"

if [[ -z "$NETWORK" || -z "$FUNC" || -z "$PROXY" ]]; then
  echo "Usage: $0 [base|monad|arbitrum] [upgradeLiquidityVault|upgradeOperator|upgradeSimpleOracleStrategy|upgradeDatastreamOracle] [proxy]"
  exit 1
fi

case "$NETWORK" in
  base|monad|arbitrum)
    ;;
  *)
    echo "Usage: $0 [base|monad|arbitrum] ..."
    exit 1
    ;;
esac

VERIFY_FLAGS=(--verify)
if [[ "$NETWORK" == "monad" ]]; then
  VERIFY_FLAGS+=(--verifier sourcify --verifier-url "https://sourcify-api-monad.blockvision.org/")
fi

ACCOUNT_NAME="${FOUNDRY_ACCOUNT_NAME:-clober-deployer}"

# Export the actual signer address for scripts that need it.
# Even if `Upgrade.s.sol` doesn't currently consume it, keeping this consistent avoids future footguns.
export DEPLOYER
# NOTE: If the password starts with '-', clap may interpret it as a flag unless we use `--password=...`.
DEPLOYER="$(cast wallet address --account "$ACCOUNT_NAME" --password="$KEYSTORE_PASSWORD")"

forge script ./script/Upgrade.s.sol:UpgradeScript \
  --sig "${FUNC}(address)" "$PROXY" \
  --rpc-url "$NETWORK" \
  --account "$ACCOUNT_NAME" \
  --password="$KEYSTORE_PASSWORD" \
  "${VERIFY_FLAGS[@]}" \
  --broadcast

