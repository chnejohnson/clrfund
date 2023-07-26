FROM ubuntu:22.04 as clrfund

# install dependency
RUN apt-get update \
    && apt-get install -y curl wget git jq\
    && apt-get install -y build-essential libgmp-dev libsodium-dev nasm \ 
    && apt-get install -y libgmp-dev nlohmann-json3-dev nasm g++ 

# install nvm and nodejs
ENV NODE_VERSION=18.14.2

RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash
ENV NVM_DIR=/root/.nvm
RUN . "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm use v${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm alias default v${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm install-latest-npm
ENV PATH="/root/.nvm/versions/node/v${NODE_VERSION}/bin/:${PATH}"

# install rust
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# install zkutil
RUN cargo install zkutil --version 0.3.2

# install yarn
RUN npm install -g yarn

# install clrfund 
COPY . ./root/clrfund
RUN cd ~ \
    && cd clrfund \
    && yarn install