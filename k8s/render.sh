#!/bin/sh
set -eu

APP_NAME="${APP_NAME:-app}"
KUBE_NAMESPACE="${KUBE_NAMESPACE:-$APP_NAME}"
IMAGE_SERVER="${IMAGE_SERVER:-ghcr.io/dommmin/${APP_NAME}-server:latest}"
IMAGE_CLIENT="${IMAGE_CLIENT:-ghcr.io/dommmin/${APP_NAME}-client:latest}"
REVISION="${REVISION:-latest}"
MINIO_BUCKET="${MINIO_BUCKET:-$APP_NAME}"

if [ "$#" -eq 0 ]; then
  echo "Usage: APP_NAME=app KUBE_NAMESPACE=app $0 <manifest.yaml> [manifest.yaml...]" >&2
  exit 64
fi

sed_escape() {
  printf '%s' "$1" | sed 's/[\/&]/\\&/g'
}

app_name=$(sed_escape "$APP_NAME")
kube_namespace=$(sed_escape "$KUBE_NAMESPACE")
image_server=$(sed_escape "$IMAGE_SERVER")
image_client=$(sed_escape "$IMAGE_CLIENT")
revision=$(sed_escape "$REVISION")
minio_bucket=$(sed_escape "$MINIO_BUCKET")

first=1
for manifest in "$@"; do
  if [ ! -f "$manifest" ]; then
    echo "Manifest not found: $manifest" >&2
    exit 66
  fi

  if [ "$first" -eq 1 ]; then
    first=0
  else
    printf '%s\n' '---'
  fi

  sed \
    -e "s/\${APP_NAME}/$app_name/g" \
    -e "s/\${KUBE_NAMESPACE}/$kube_namespace/g" \
    -e "s/\${IMAGE_SERVER}/$image_server/g" \
    -e "s/\${IMAGE_CLIENT}/$image_client/g" \
    -e "s/\${REVISION}/$revision/g" \
    -e "s/\${MINIO_BUCKET}/$minio_bucket/g" \
    "$manifest"
done
