FROM rocm/pytorch:latest

# Install Rust toolchain
RUN apt-get update && apt-get install -y --no-install-recommends curl git build-essential openssl libssl-dev pkg-config && \
    curl https://sh.rustup.rs -sSf | bash -s -- -y && \
    rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.cargo/bin:${PATH}"
RUN TORCH_PATH="$(python3 -c 'import os, torch; print(os.path.dirname(torch.__file__))')" && \
    ln -s "$TORCH_PATH" /opt/libtorch

ENV LIBTORCH=/opt/libtorch
ENV LD_LIBRARY_PATH=${LIBTORCH}/lib:$LD_LIBRARY_PATH

WORKDIR /workspace

RUN git clone https://github.com/guillaume-be/rust-bert.git

WORKDIR /workspace/rust-bert

CMD ["cargo", "run", "--example", "sentence_embeddings"]
