#!/bin/bash
set -eu
set -x

rm -fr lambda_handler.zip

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${BASE_DIR}"

DEPLOY_DIR=$(mktemp -d .deploy.XXX)

trap 'rm -r "${BASE_DIR}/${DEPLOY_DIR}"' EXIT

# in a container, pipx-installed poetry is /root/.local/bin/poetry
export PATH="${PATH}:/root/.local/bin"

# activate pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
pyenv global 3.12

poetry export \
  --format=requirements.txt \
  --without-hashes | \
  pip install \
    -r /dev/stdin \
    --target "${DEPLOY_DIR}" \
    --platform manylinux2014_aarch64 \
    --implementation cp \
    --python-version 3.12 \
    --only-binary=:all: \
    --upgrade

rm -fr "${DEPLOY_DIR}/"*.dist-info
# Populate our stuff - use cat to avoid owner/permission problems
cat lambda_handler.py > "${DEPLOY_DIR}/lambda_handler.py"
find "${DEPLOY_DIR}" -type f -name '*.pyc' -delete
find "${DEPLOY_DIR}" -type d -name '__pycache__' -delete
# poetry adds fully-resolved shebangs for scripts, i.e.
#  #!/opt/homebrew/opt/python@3.12/bin/python3.12
#  #!/root/.pyenv/versions/3.12.7/bin/python3.12
# vs
#   #!/usr/bin/env python
# so these break idempotency of the build. they're also wrong for a lambda.
# we're not calling via binary, so we can just remove them.
rm -fr "${DEPLOY_DIR}/bin"
find "${DEPLOY_DIR}" -type f -exec chmod 0644 {} +
find "${DEPLOY_DIR}" -type d -exec chmod 0755 {} +

find "${DEPLOY_DIR}" -type f -exec touch -c -t 0101010101 {} +

cd "${DEPLOY_DIR}"
rm -f "${BASE_DIR}/lambda_handler.zip"
zip -9rXDv "${BASE_DIR}/lambda_handler.zip" .
cd "${BASE_DIR}"

# checks / debugging info for idempotency
unzip -lv lambda_handler.zip
ls -l lambda_handler.zip
md5sum lambda_handler.zip
