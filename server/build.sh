#!/usr/bin/env bash
# Exports the headless Linux server and builds the Docker image.
#   server/build.sh              -> image for this machine's architecture
#   PLATFORM=linux/amd64 server/build.sh   -> image for a typical x86 cloud VM
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
IMAGE="${IMAGE:-arena-brawler-server}"
mkdir -p build/server
"$GODOT" --path . --headless --export-release "Linux Server x86_64" build/server/arena-server.amd64
"$GODOT" --path . --headless --export-release "Linux Server arm64" build/server/arena-server.arm64
if [[ -n "${PLATFORM:-}" ]]; then
  docker build --platform "$PLATFORM" -f server/Dockerfile -t "$IMAGE" .
else
  docker build -f server/Dockerfile -t "$IMAGE" .
fi
echo "Built $IMAGE. Run: docker run --rm -p 7777:7777/udp $IMAGE --bots 2"
