#!/bin/bash
set -e
IMAGE_TAG=$(jq -r .IMAGE_TAG "${ARTIFACT_PATH}/image_tag.json")
IMAGE="streaming-pipeline/producer:${IMAGE_TAG}"

echo "[start_container] Avvio container producer-cicd da $IMAGE"
docker run -d \
  --name producer-cicd \
  --restart unless-stopped \
  --network pipeline-net \
  --env-file /repo/.env \
  "$IMAGE"