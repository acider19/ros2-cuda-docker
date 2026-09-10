#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

REGISTRY="${REGISTRY:-ghcr.io}"
IMAGE_PREFIX="${IMAGE_PREFIX:-${GITHUB_REPOSITORY_OWNER:-local}/ros-cuda-base}"

IMAGES=(
    "x86_64-ros2-latest"
    "jetson-agx-ros2-latest"
    "jetson-nano-ros2-latest"
)

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -i, --image TAG    Push specific image tag"
    echo "  -a, --all          Push all base images"
    echo "  -h, --help         Show this help"
    echo ""
    echo "Available base images:"
    for img in "${IMAGES[@]}"; do
        echo "  ${REGISTRY}/${IMAGE_PREFIX}:${img}"
    done
}

PUSH_ALL=false
SELECTED_IMAGES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--image)
            SELECTED_IMAGES+=("$2")
            shift 2
            ;;
        -a|--all)
            PUSH_ALL=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [ "$PUSH_ALL" = true ]; then
    SELECTED_IMAGES=("${IMAGES[@]}")
fi

if [ ${#SELECTED_IMAGES[@]} -eq 0 ]; then
    echo "No images specified. Use -a to push all or -i to specify."
    usage
    exit 1
fi

echo "Logging in to ${REGISTRY}..."
docker login "${REGISTRY}"

for img in "${SELECTED_IMAGES[@]}"; do
    FULL_TAG="${REGISTRY}/${IMAGE_PREFIX}:${img}"
    echo "Pushing: ${FULL_TAG}"
    docker push "${FULL_TAG}" || echo "Warning: Failed to push ${FULL_TAG}"
done

echo ""
echo "Push complete!"
