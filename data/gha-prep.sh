#!/bin/bash
set -eu
set -x

sudo apt-get update
DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC sudo apt-get install \
  --no-install-recommends \
  build-essential \
  curl \
  git \
  libssl-dev \
  pipx \
  unzip \
  zip \
  zlib1g-dev \
  --assume-yes


curl https://pyenv.run | bash

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

pyenv install 3.12
pyenv global 3.12

python --version

pipx install poetry
