Actions = slot/unità di lavoro di CodePipeline (orchestratore)
Esempi:
- Source (GitHub provider)
- Build (CodeBuild provider)
- Deploy (CodeDeploy provider)

PIPELINE: SOURCE -> BUILD -> DEPLOY 

SOURCE:

CodePipeline riceve il webhook(URL) da GitHub e trigger l'action Source(GitHub Provider)

Il provider Github scarica il repo, crea l’artifact.zip e lo mette in S3.

BUILD: 

CodePipeline triggera quindi l'action Build(CodeBuild provider), chiamando l'API di CodeBuild(Start Build) e fornendo:
- il nome dell’artifact
- il bucket S3
- la chiave del file ZIP

CodeBuild provider(servizio gestito) crea quindi il container effimero, ci copia dentro l’artifact da S3 ed esegue ciò che è scritto nel buildspec.yml, ovvero:
- install
- pre_build
- build
- post_build

1. install: 
- installazioni pacchetti e dipendenze del container docker

2. pre_build:
- login a ECR
- verifica del client Docker
- calcolo del tag dell’immagine

3. build:
- build dei servizi della pipeline (Producer, Consumer)

4. post_build
- push delle immagini su ECR
- generazione dell'artifact salvato su S3, contenente:
    image_tag.json (puntatore) per sapere quale immagine deployare 
    appspec.yml + scripts hook per sapere come e cosa deployare

DEPLOY:

CodePipeline triggera l'action Deploy(provider CodeDeploy) e chiama l'API di CodeDeploy(Create Deployment).
CodeDeploy registra quindi il deployment (metadati + riferimento allo ZIP su S3):
- il nome dell’artifact.zip
- il bucket S3
- la chiave dell'artifact.zip

L'agente CodeDeploy(installato su EC2/ECS) fa polling sull'API di CodeDeploy e verifica il nuovo deployment.
Esegue quindi il ciclo di vita definito in appspec.yml:
- application stop -> ferma la versione precedente 
- download budle(interno) -> scarica l'artifact.zip da S3 (appspec.yml, scripts hook, image_tag.json)
- before install(se presente) -> prepara ambiente per installazione
- install/after install -> copia file, prepara immagine da ECR, esegue scripts hook
- application start -> avvia la nuova versione
- validate service -> verifica la nuova versione

* Il modello di deployment può essere:
- In-place deployment (EC2) -> il servizio viene fermato e la nuova versione sostituisce la precedente
- Blue/Green deployment (EC2 o ECS) -> il servizio non viene fermato e la nuova versione viene creata in parallelo


DIAGRAMMA CI/CD AWS

                         ┌──────────────────────────┐
                         │        GitHub Repo        │
                         │  (Producer / Consumer)    │
                         └──────────────┬────────────┘
                                        │ Webhook
                                        ▼
                         ┌──────────────────────────┐
                         │      CodePipeline         │
                         │        (Orchestrator)     │
                         └──────────────┬────────────┘
                                        │
                                        ▼
                    ┌───────────────────────────────┐
                    │        Source Action           │
                    │      (GitHub Provider)         │
                    └────────────────┬───────────────┘
                                     │ artifact.zip
                                     ▼
                    ┌───────────────────────────────┐
                    │        Build Action            │
                    │     (CodeBuild Provider)       │
                    └────────────────┬───────────────┘
                                     │ StartBuild API
                                     ▼
                    ┌───────────────────────────────┐
                    │         CodeBuild              │
                    │   Container Effimero Docker    │
                    │  buildspec.yml: install/pre/build/post
                    └────────────────┬───────────────┘
                                     │
                                     │  Output:
                                     │   - image su ECR
                                     │   - artifact.zip su S3:
                                     │       • image_tag.json
                                     │       • appspec.yml
                                     │       • scripts hook
                                     ▼
                    ┌───────────────────────────────┐
                    │        Deploy Action           │
                    │     (CodeDeploy Provider)      │
                    └────────────────┬───────────────┘
                                     │ CreateDeployment API
                                     ▼
                    ┌───────────────────────────────┐
                    │           CodeDeploy           │
                    │  Registra deployment + ZIP S3  │
                    └────────────────┬───────────────┘
                                     │
                                     ▼ Polling
                    ┌───────────────────────────────┐
                    │      CodeDeploy Agent          │
                    │     (EC2 o ECS Target)         │
                    └────────────────┬───────────────┘
                                     │
                                     ▼
                    ┌───────────────────────────────┐
                    │   Ciclo di Vita Deployment     │
                    │  (definito in appspec.yml)     │
                    │   - ApplicationStop            │
                    │   - DownloadBundle             │
                    │   - BeforeInstall              │
                    │   - Install / AfterInstall     │
                    │   - ApplicationStart           │
                    │   - ValidateService            │
                    └───────────────────────────────┘

