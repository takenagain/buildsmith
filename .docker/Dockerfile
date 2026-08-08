FROM ubuntu:latest

COPY scripts ./scripts
COPY install.sh .
COPY Makefile .
COPY runner ./runner

RUN chmod +x install.sh && chmod -R +x ./scripts && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash build-essential ca-certificates curl && \
    rm -rf /var/lib/apt/lists/* && \
    CI=1 bash ./install.sh

CMD ["bash"]
