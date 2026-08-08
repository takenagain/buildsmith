FROM ubuntu:latest

ADD ../scripts ./scripts
ADD install.sh .

RUN chmod +x install.sh && chmod -R +x ./scripts/*.sh && \
    apt-get update && apt-get upgrade -y && sh install.sh

CMD ["bash"]
