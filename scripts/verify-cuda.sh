#!/bin/bash
set -euo pipefail

PLATFORM=""
IMAGE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--platform <linux/amd64|linux/arm64>] <image:tag>"
            exit 0
            ;;
        *)
            IMAGE="$1"
            shift
            ;;
    esac
done

if [[ -z "${IMAGE}" ]]; then
    echo "Error: image tag is required" >&2
    echo "Usage: $0 [--platform <linux/amd64|linux/arm64>] <image:tag>" >&2
    exit 1
fi

DOCKER_OPTS=()
if [[ -n "${PLATFORM}" ]]; then
    DOCKER_OPTS+=(--platform "${PLATFORM}")
fi

echo "============================================"
echo "Verifying CUDA in image: ${IMAGE}"
[[ -n "${PLATFORM}" ]] && echo "Platform: ${PLATFORM}"
echo "============================================"

echo ""
echo "--- Architecture ---"
docker run --rm "${DOCKER_OPTS[@]}" "${IMAGE}" uname -m

echo ""
echo "--- OS Info ---"
docker run --rm "${DOCKER_OPTS[@]}" "${IMAGE}" cat /etc/os-release | head -5

echo ""
echo "--- CUDA Version ---"
docker run --rm "${DOCKER_OPTS[@]}" "${IMAGE}" nvcc --version 2>/dev/null || echo "nvcc not found"

echo ""
echo "--- CUDA Libraries ---"
docker run --rm "${DOCKER_OPTS[@]}" "${IMAGE}" bash -c 'if [ -d /usr/local/cuda/lib64 ]; then ls /usr/local/cuda/lib64/ | grep -i cuda | head -10; elif [ -d /usr/local/cuda/targets/aarch64-linux/lib ]; then ls /usr/local/cuda/targets/aarch64-linux/lib/ | grep -i cuda | head -10; else echo "CUDA lib directory not found"; fi'

echo ""
echo "--- CUDA Runtime Check ---"
docker run --rm "${DOCKER_OPTS[@]}" "${IMAGE}" bash -c 'cat > /tmp/cuda_test.cu << "EOF"
#include <stdio.h>
__global__ void hello() {
printf("CUDA thread %d OK\n", threadIdx.x);
}
int main() {
hello<<<1, 3>>>();
cudaDeviceSynchronize();
printf("CUDA test PASSED\n");
return 0;
}
EOF
nvcc /tmp/cuda_test.cu -o /tmp/cuda_test 2>&1 && echo "Compilation: OK" || echo "Compilation: FAILED (nvcc may not be available in this image)"'

echo ""
echo "--- ROS Info ---"
docker run --rm "${DOCKER_OPTS[@]}" "${IMAGE}" bash -c 'if [ -f /opt/ros/humble/setup.bash ]; then source /opt/ros/humble/setup.bash; echo "ROS2 Humble detected"; ros2 --version 2>/dev/null || echo "ros2 CLI not available"; else echo "No ROS installation found"; fi'

echo ""
echo "============================================"
echo "Verification complete for: ${IMAGE}"
echo "============================================"