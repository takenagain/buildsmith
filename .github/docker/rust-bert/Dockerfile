FROM docker.io/rocm/pytorch:latest

# Install Rust toolchain
RUN apt-get update && apt-get install -y --no-install-recommends curl git build-essential && \
    curl https://sh.rustup.rs -sSf | bash -s -- -y && \
    rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.cargo/bin:${PATH}"
ENV LIBTORCH=/opt/conda/envs/py_3.12/lib/python3.12/site-packages/torch
ENV LD_LIBRARY_PATH=${LIBTORCH}/lib:$LD_LIBRARY_PATH

WORKDIR /workspace

RUN git clone https://github.com/guillaume-be/rust-bert.git

WORKDIR /workspace/rust-bert

CMD ["bash", "-lc", "cargo run --example sentence_embeddings"]
