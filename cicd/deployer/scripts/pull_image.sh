#!/bin/bash
set -e
# In AWS: qui avverrebbe il vero `docker pull` da ECR.
# In locale: immagine già presente nel daemon condiviso, verifichiamo solo
# che esista, per intercettare l'errore presto se il tag è sbagliato.
IMAGE_TAG=$(jq -r .IMAGE_TAG "${ARTIFACT_PATH}/image_tag.json")
IMAGE="streaming-pipeline/producer:${IMAGE_TAG}"

if ! docker image inspect "$IMAGE" > /dev/null 2>&1; then
  echo "[pull_image] ERRORE: immagine $IMAGE non trovata nel daemon locale"
  exit 1
fi
echo "[pull_image] Immagine $IMAGE presente, ok"