#!/bin/bash
set -eu
set -x

rm -fr terraform-aws-dengo.zip

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "${BASE_DIR}"

DEPLOY_DIR=$(mktemp -d .package.XXX)

cp ${BASE_DIR}/*.tf "${DEPLOY_DIR}/"
cp ${BASE_DIR}/*.md "${DEPLOY_DIR}/"
mkdir -p "${DEPLOY_DIR}/data"
cp ${BASE_DIR}/data/*.html ${BASE_DIR}/data/lambda_handler.zip "${DEPLOY_DIR}/data/"

find "${DEPLOY_DIR}" -type f -exec chmod 0644 {} +
find "${DEPLOY_DIR}" -type d -exec chmod 0755 {} +
find "${DEPLOY_DIR}" -type f -exec touch -c -t 0101010101 {} +

cd "${DEPLOY_DIR}"
rm -f "${BASE_DIR}/terraform-aws-dengo.zip"
zip -9rXDv "${BASE_DIR}/terraform-aws-dengo.zip" .
cd "${BASE_DIR}"

mkdir -p release
cp ${BASE_DIR}/data/lambda_handler.zip "${BASE_DIR}/release/"
cp ${BASE_DIR}/terraform-aws-dengo.zip "${BASE_DIR}/release/"

cd release

sha256sum terraform-aws-dengo.zip > "terraform-aws-dengo.zip.sha256"
echo "" >> "terraform-aws-dengo.zip.sha256"
echo "# Check with \"sha256sum --check --status terraform-aws-dengo.zip.sha256\"" >> "terraform-aws-dengo.zip.sha256"
echo "" >> "terraform-aws-dengo.zip.sha256"
unzip -lv terraform-aws-dengo.zip | sed 's/^/# /g' >> "terraform-aws-dengo.zip.sha256"


sha256sum lambda_handler.zip > "lambda_handler.zip.sha256"
echo "#" >> "lambda_handler.zip.sha256"
echo "# Check with \"sha256sum --check --status lambda_handler.zip.sha256\"" >> "lambda_handler.zip.sha256"
echo "# source_code_hash = \"$(openssl dgst -binary -sha256 lambda_handler.zip | openssl base64 -A)\"" >> "lambda_handler.zip.sha256"
echo "#" >> "lambda_handler.zip.sha256"
unzip -lv lambda_handler.zip | sed 's/^/# /g' >> "lambda_handler.zip.sha256"
