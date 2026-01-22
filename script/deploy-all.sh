#!/usr/bin/env bash
set -euo pipefail

# Export variables from `.env` so Foundry (and child processes) can read them.
# Without this, `${BASE_RPC_URL}`, `${BASESCAN_API_KEY}`, etc. are often "missing" at runtime.
set -a
source .env
set +a

# usage: ./script/deploy-all.sh base|monad
NETWORK="${1:-}"
if [[ -z "$NETWORK" ]]; then
  echo "Usage: $0 [base|monad]"
  exit 1
fi

case "$NETWORK" in
  base|monad)
    ;;
  *)
    echo "Usage: $0 [base|monad]"
    exit 1
    ;;
esac

VERIFY_FLAGS=(--verify)
if [[ "$NETWORK" == "monad" ]]; then
  VERIFY_FLAGS+=(--verifier sourcify --verifier-url "https://sourcify-api-monad.blockvision.org/")
fi

# `forge script --account ... --broadcast` uses the keystore account as the actual tx signer,
# but inside the Solidity script `msg.sender` is NOT the broadcaster.
# We explicitly pass the broadcaster EOA address so initializer calldata can set correct ownership.
ACCOUNT_NAME="${FOUNDRY_ACCOUNT_NAME:-clober-deployer}"
export DEPLOYER
# NOTE: If the password starts with '-', clap may interpret it as a flag unless we use `--password=...`.
DEPLOYER="$(cast wallet address --account "$ACCOUNT_NAME" --password="$KEYSTORE_PASSWORD")"

forge script ./script/Deploy.s.sol:DeployScript \
  --sig "deployAll()" \
  --rpc-url "$NETWORK" \
  --account "$ACCOUNT_NAME" \
  --password="$KEYSTORE_PASSWORD" \
  "${VERIFY_FLAGS[@]}" \
  --broadcast

