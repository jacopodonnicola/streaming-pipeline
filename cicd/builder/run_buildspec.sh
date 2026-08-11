#!/usr/bin/env bash
set -euo pipefail

# Questo script gioca il ruolo dell'agente CodeBuild: in AWS reale è un
# binario già incluso nel build environment, che sa parsare buildspec.yml
# nativamente. Qui lo facciamo a mano con `yq`.

BUILDSPEC="/repo/cicd/builder/buildspec.yml"

if [ ! -f "$BUILDSPEC" ]; then
  echo "ERRORE: buildspec.yml non trovato in $BUILDSPEC" >&2
  exit 1
fi

# L'ordine delle fasi è fisso e rispecchia CodeBuild reale: le fasi
# successive presuppongono lo stato lasciato da quelle precedenti
# (es. IMAGE_TAG esportata in pre_build, usata in build e post_build).
PHASES=("install" "pre_build" "build" "post_build")

for phase in "${PHASES[@]}"; do
  # Quante righe di comandi ha questa fase nel buildspec
  count=$(yq -r ".phases.${phase}.commands | length" "$BUILDSPEC")

  echo ""
  echo "===== FASE: ${phase} (${count} comandi) ====="

  for i in $(seq 0 $((count - 1))); do
    cmd=$(yq -r ".phases.${phase}.commands[${i}]" "$BUILDSPEC")
    echo "+ ${cmd}"
    # eval necessario per interpretare correttamente export/variabili
    # (es. IMAGE_TAG) all'interno della stessa shell, fase dopo fase.
    eval "$cmd"
  done
done

echo ""
echo "===== BUILD COMPLETATA CON SUCCESSO ====="