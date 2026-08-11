#!/bin/bash
set -e
if [ "$(docker ps -aq -f name=producer-cicd)" ]; then
  echo "[stop_container] Fermo e rimuovo il container producer-cicd esistente"
  docker stop producer-cicd || true
  docker rm producer-cicd || true
else
  echo "[stop_container] Nessun container producer-cicd in esecuzione"
fi