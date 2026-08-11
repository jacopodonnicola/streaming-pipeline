#!/bin/bash
set -e
sleep 3
STATUS=$(docker inspect -f '{{.State.Running}}' producer-cicd 2>/dev/null || echo "false")
if [ "$STATUS" != "true" ]; then
  echo "[validate_service] ERRORE: producer-cicd non è in esecuzione"
  docker logs producer-cicd --tail 20
  exit 1
fi
echo "[validate_service] producer-cicd avviato correttamente"