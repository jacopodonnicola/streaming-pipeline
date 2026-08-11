#!/bin/bash
# cicd/pipeline.sh
# Simula CodePipeline: orchestratore puro, Source → Build → segnalazione
# deployment pronto. Non esegue mai lavoro computazionale in proprio —
# delega tutto ad action provider (qui: il container builder), esattamente
# come CodePipeline reale delega a CodeBuild/CodeDeploy senza mai eseguire
# comandi lui stesso.
#
# Non chiama MAI run_appspec.sh direttamente: il deployer scopre il lavoro
# da solo via polling sulla queue. Il disaccoppiamento è voluto (vedi
# discussione: build e deploy comunicano solo tramite artifact_store +
# deployments_queue, mai con una chiamata diretta).

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

COMPOSE_FILE="cicd/docker-compose.cicd.yml"
QUEUE_DIR="cicd/deployer/deployments_queue"
ARTIFACT_STORE="cicd/artifact_store"

echo "=================================================="
echo "[pipeline] Stage: Source"
echo "=================================================="
# AWS: qui CodePipeline scaricherebbe la revisione da CodeCommit/GitHub
# a fronte del webhook che ha fatto scattare l'esecuzione. In locale il
# "checkout" è implicito: il builder monta la working copy dell'host in
# bind-mount (vedi docker-compose.cicd.yml), quindi non c'è un vero step
# di download qui — lo lasciamo solo come marcatore di stage, per fedeltà
# alla sequenza concettuale.
IMAGE_TAG_PRE=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
echo "[pipeline] Revisione corrente: ${IMAGE_TAG_PRE}"

echo ""
echo "=================================================="
echo "[pipeline] Stage: Build"
echo "=================================================="
# Lancia il builder come job puntuale (run --rm, non un servizio persistente).
# Il builder esegue install/pre_build/build/post_build da buildspec.yml,
# e in post_build prepara già da solo l'artifact bundle in artifact_store/
# (vedi run_buildspec.sh) — pipeline.sh non lo fa per lui.
if ! docker compose -f "$COMPOSE_FILE" run --rm builder; then
  echo "[pipeline] Stage Build FALLITO. Pipeline interrotta, nessun deployment segnalato."
  exit 1
fi

# Il builder calcola IMAGE_TAG internamente (git rev-parse); qui lo
# ricalcoliamo identico per sapere quale cartella artifact_store cercare.
# In un sistema reale questo valore verrebbe passato come output di stage,
# non ricalcolato: approssimazione accettata perché builder e pipeline.sh
# girano sullo stesso commit nello stesso momento.
IMAGE_TAG="$IMAGE_TAG_PRE"
ARTIFACT_PATH="${ARTIFACT_STORE}/build_${IMAGE_TAG}"

if [ ! -d "$ARTIFACT_PATH" ]; then
  echo "[pipeline] ERRORE: artifact bundle atteso non trovato in ${ARTIFACT_PATH}"
  echo "[pipeline] Il builder ha dichiarato successo ma non ha prodotto l'artifact atteso."
  exit 1
fi
echo "[pipeline] Artifact bundle trovato: ${ARTIFACT_PATH}"

echo ""
echo "=================================================="
echo "[pipeline] Stage: Deploy (segnalazione)"
echo "=================================================="
# AWS: CodePipeline chiama CreateDeployment sull'API CodeDeploy, puntando
# allo zip appena caricato su S3. Locale: scriviamo il puntatore nella
# queue — il deployer (già in polling, avviato separatamente) lo scoprirà
# al giro successivo. Non lanciamo run_appspec.sh da qui: il disaccoppiamento
# builder/deployer è intenzionale.
mkdir -p "$QUEUE_DIR"
DEPLOY_FILE="${QUEUE_DIR}/deploy_${IMAGE_TAG}.json"
echo "{\"artifact_path\": \"${ARTIFACT_PATH}\"}" > "$DEPLOY_FILE"

echo "[pipeline] Deployment segnalato: ${DEPLOY_FILE}"
echo "[pipeline] -> { \"artifact_path\": \"${ARTIFACT_PATH}\" }"
echo ""
echo "[pipeline] Pipeline completata. Il deployer (se in polling) processerà"
echo "[pipeline] questo deployment entro il prossimo ciclo."