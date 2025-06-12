#!/bin/bash
set -e

# Crea la directory dist se non esiste
mkdir -p dist

# Array dei contratti
contracts=(
  "Brands"
  "Memberships"
  "Payments"
  "Roles"
  "Sales"
  "Wrappers"
  "Whitelist"
)

# Funzione per generare artefatti completi
generate_artifacts() {
  local contract=$1
  echo "Generando artefatti per $contract"

  # Genera ABI completo
  if forge build --via-ir && forge inspect "$contract" abi > "dist/${contract}.json"; then
    # Genera anche bytecode e altri metadati
    forge inspect "$contract" bytecode >> "dist/${contract}.json"
    forge inspect "$contract" deployedBytecode >> "dist/${contract}.json"
    forge inspect "$contract" methodIdentifiers >> "dist/${contract}.json"

    echo "Artefatti generati con successo per $contract"
  else
    echo "ERRORE: Impossibile generare artefatti per $contract"
    return 1
  fi
}

# Ciclo per generare artefatti
for contract in "${contracts[@]}"; do
  generate_artifacts "$contract"
done

echo "Generazione artefatti completata"
