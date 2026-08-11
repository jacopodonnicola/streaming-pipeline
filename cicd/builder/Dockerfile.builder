FROM docker:24-cli

# Nessun daemon interno (questo è DooD, non DinD): questa immagine contiene
# solo il client `docker`, che parlerà con il daemon dell'host tramite il
# socket montato a runtime (/var/run/docker.sock).

RUN apk add --no-cache bash yq git

WORKDIR /repo

COPY cicd/builder/run_buildspec.sh /usr/local/bin/run_buildspec.sh
RUN chmod +x /usr/local/bin/run_buildspec.sh

ENTRYPOINT ["/usr/local/bin/run_buildspec.sh"]
