#!/bin/bash
# cicd/deployer/run_appspec.sh

docker network inspect pipeline-net > /dev/null 2>&1 || docker network create pipeline-net

QUEUE_DIR="cicd/deployer/deployments_queue"
POLL_INTERVAL=5

echo "[agent] Avvio polling su ${QUEUE_DIR} (intervallo ${POLL_INTERVAL}s)"

while true; do
  for deploy_file in "${QUEUE_DIR}"/deploy_*.json; do
    [ -e "$deploy_file" ] || continue

    echo "[agent] Trovato deployment: $deploy_file"
    ARTIFACT_PATH=$(jq -r .artifact_path "$deploy_file")
    export ARTIFACT_PATH   # gli hook script lo leggono (vedi pull_image.sh/start_container.sh)

    # Ordine hook fisso, come da ciclo di vita CodeDeploy reale.
    HOOKS=(ApplicationStop AfterInstall ApplicationStart ValidateService)

    DEPLOY_FAILED=0
    for hook in "${HOOKS[@]}"; do
      SCRIPT_REL=$(yq -r ".hooks.${hook}[0].location" "${ARTIFACT_PATH}/appspec.yml")
      SCRIPT_PATH="${ARTIFACT_PATH}/${SCRIPT_REL}"

      echo "[agent] Eseguo hook ${hook} -> ${SCRIPT_PATH}"
      if ! bash "$SCRIPT_PATH"; then
        echo "[agent] Hook ${hook} fallito, interrompo il deployment"
        DEPLOY_FAILED=1
        break
      fi
    done

    if [ "$DEPLOY_FAILED" -eq 0 ]; then
      echo "[agent] Deployment completato con successo"
    else
      echo "[agent] Deployment FALLITO"
      # in AWS qui scatterebbe un automatic rollback; per ora solo log
    fi

    echo "[agent] Rimuovo dalla coda"
    rm "$deploy_file"
  done
  sleep "$POLL_INTERVAL"
done