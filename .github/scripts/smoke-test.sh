#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${SMOKE_IMAGE_TAG:-koreader-everywhere:smoke}"
CONTAINER_NAME="${SMOKE_CONTAINER_NAME:-koreader-smoke}"
HOST_PORT="${SMOKE_PORT:-8080}"
KOREADER_VERSION="${KOREADER_VERSION:-$(tr -d '[:space:]' < KOREADER_VERSION)}"

cleanup() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}

dump_logs() {
  echo "--- container logs ---"
  docker logs "$CONTAINER_NAME" 2>&1 || true
}

trap cleanup EXIT

cleanup

echo "Building smoke-test image with KOReader ${KOREADER_VERSION}"
docker build \
  --build-arg KOREADER_VERSION="$KOREADER_VERSION" \
  --tag "$IMAGE_TAG" \
  .

echo "Starting smoke-test container"
docker run -d \
  --name "$CONTAINER_NAME" \
  -e VNC_PASSWORD=ci-smoke-password \
  -p "127.0.0.1:${HOST_PORT}:8080" \
  "$IMAGE_TAG" >/dev/null

healthy=false
for _ in {1..60}; do
  state="$(docker inspect --format '{{.State.Status}}' "$CONTAINER_NAME")"
  health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$CONTAINER_NAME")"

  if [ "$health" = "healthy" ]; then
    healthy=true
    break
  fi

  if [ "$state" = "exited" ] || [ "$state" = "dead" ]; then
    echo "Container stopped before becoming healthy."
    dump_logs
    exit 1
  fi

  sleep 2
done

if [ "$healthy" != "true" ]; then
  echo "Container did not become healthy."
  docker inspect "$CONTAINER_NAME" || true
  dump_logs
  exit 1
fi

if ! curl --fail --silent --show-error "http://127.0.0.1:${HOST_PORT}/" | grep -q 'KOReader Everywhere'; then
  echo "noVNC web UI did not return the expected KOReader Everywhere page."
  dump_logs
  exit 1
fi

echo "Smoke test passed."
