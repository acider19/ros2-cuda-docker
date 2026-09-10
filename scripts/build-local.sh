#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

REGISTRY="${REGISTRY:-ghcr.io}"
IMAGE_PREFIX="${IMAGE_PREFIX:-${GITHUB_REPOSITORY_OWNER:-local}/ros-cuda-base}"

PLATFORMS=(
    "x86_64-ros2:docker/base/Dockerfile.ros2:linux/amd64:nvidia/cuda:12.6.3-devel-ubuntu22.04"
    "jetson-agx-ros2:docker/base/Dockerfile.ros2:linux/arm64:nvcr.io/nvidia/l4t-jetpack:r36.4.0"
    "jetson-nano-ros2:docker/base/Dockerfile.ros2:linux/arm64:nvcr.io/nvidia/l4t-jetpack:r36.4.0"
)

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --platform PLATFORM   Build specific platform (e.g., x86_64-ros2)"
    echo "  -t, --tag TAG             Image tag (default: latest)"
    echo "  -r, --registry REGISTRY   Docker registry (default: ghcr.io)"
    echo "  --push                    Push images after build"
    echo "  -h, --help                Show this help"
    echo ""
    echo "Available platforms:"
    for entry in "${PLATFORMS[@]}"; do
        IFS=':' read -r tag dockerfile platform base_image <<< "$entry"
        echo "  $tag ($platform, BASE_IMAGE=$base_image)"
    done
}

TAG="latest"
PUSH=false
SELECTED_PLATFORMS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--platform)
            SELECTED_PLATFORMS+=("$2")
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        --push)
            PUSH=true
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

if [ ${#SELECTED_PLATFORMS[@]} -eq 0 ]; then
    SELECTED_PLATFORMS=("${PLATFORMS[@]%%:*}")
fi

setup_buildx() {
    if ! docker buildx inspect multiarch-builder &>/dev/null; then
        echo "Creating buildx builder..."
        docker buildx create --name multiarch-builder --driver docker-container --use
        docker buildx inspect --bootstrap
    else
        docker buildx use multiarch-builder
    fi
}

setup_qemu() {
    if ! docker run --rm --privileged multiarch/qemu-user-static --reset -p yes &>/dev/null; then
        echo "Warning: QEMU setup failed. ARM64 builds may not work."
    fi
}

build_image() {
    local tag="$1"
    local dockerfile="$2"
    local platform="$3"
    local base_image="$4"
    local full_tag="${REGISTRY}/${IMAGE_PREFIX}:${tag}-${TAG}"

    echo "============================================"
    echo "Building: ${full_tag}"
    echo "Platform: ${platform}"
    echo "Dockerfile: ${dockerfile}"
    echo "BASE_IMAGE: ${base_image}"
    echo "============================================"

    local push_flag=""
    if [ "$PUSH" = true ]; then
        push_flag="--push"
    fi

    docker buildx build \
        --platform "${platform}" \
        -f "${PROJECT_DIR}/${dockerfile}" \
        --build-arg "BASE_IMAGE=${base_image}" \
        -t "${full_tag}" \
        ${push_flag} \
        "${PROJECT_DIR}"
}

echo "Setting up build environment..."
setup_qemu
setup_buildx

for entry in "${PLATFORMS[@]}"; do
    IFS=':' read -r tag dockerfile platform base_image <<< "$entry"

    for selected in "${SELECTED_PLATFORMS[@]}"; do
        if [ "${selected}" = "${tag}" ]; then
            build_image "$tag" "$dockerfile" "$platform" "$base_image"
            break
        fi
    done
done

echo ""
echo "Build complete!"
