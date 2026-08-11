# 1. Build puntuale, una tantum, quando c'è una nuova revisione da rilasciare
docker compose -f cicd/docker-compose.cicd.yml run --rm builder

# 2. Lancia la pipeline completa (Source → Build → segnalazione deploy)
./cicd/pipeline.sh

# 3. Avvia almeno l'infrastruttura di base prima di validare il producer funzionalmente:
docker compose up -d redpanda minio redpanda-init minio-init
docker network inspect pipeline-net --format '{{json .Containers}}' | jq   # ricontrolla che redpanda sia ora nella rete

# 4. Se arriva in fondo senza errori, avvia il deployer
docker compose -f cicd/docker-compose.cicd.yml up -d deployer

# 5. Segui i log — dovresti vedere i 4 hook in sequenza
docker compose -f cicd/docker-compose.cicd.yml logs -f deployer

# 6. Verifica finale
docker ps -f name=producer
docker logs producer --tail 30
ls cicd/deployer/deployments_queue/   # dovrebbe essere vuota a fine deploy

