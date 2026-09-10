# Добавление нового ROS2-пакета

Система собирает ROS2 (Humble) пакеты через `Dockerfile.ros2` (`colcon build`).

## Шаг 1: Выберите базовый образ

| Платформа | Базовый образ (ghcr.io/acider19/ros-cuda-base) |
|---|---|
| x86_64 | `x86_64-ros2-latest` |
| AGX Orin | `jetson-agx-ros2-latest` |
| Orin Nano | `jetson-nano-ros2-latest` |

## Шаг 2: Соберите образ локально

```bash
# x86_64
docker buildx build \
    --platform linux/amd64 \
    -f docker/package/Dockerfile.ros2 \
    --build-arg BASE_IMAGE=ghcr.io/acider19/ros-cuda-base:x86_64-ros2-latest \
    --build-arg PACKAGE_REPO=https://github.com/user/repo.git \
    --build-arg PACKAGE_BRANCH=main \
    --build-arg PACKAGE_NAME=my_package \
    --build-arg CUDA_ARCH="70;75;80;86" \
    -t my-package:x86_64 \
    .

# Jetson (пример для AGX): меняются платформа, база и CUDA_ARCH
docker buildx build \
    --platform linux/arm64 \
    -f docker/package/Dockerfile.ros2 \
    --build-arg BASE_IMAGE=ghcr.io/acider19/ros-cuda-base:jetson-agx-ros2-latest \
    --build-arg PACKAGE_REPO=https://github.com/user/repo.git \
    --build-arg PACKAGE_BRANCH=main \
    --build-arg PACKAGE_NAME=my_package \
    --build-arg CUDA_ARCH=87 \
    -t my-package:jetson-agx \
    .
```

Для локальной ARM64-сборки на хосте должны быть зарегистрированы `binfmt`-обработчики QEMU (`docker run --privileged --rm multiarch/qemu-user-static --reset -p yes`).

## Шаг 3: Добавьте пакет в CI/CD

В `.github/workflows/ci.yml` **добавьте джобу** `pkg-<пакет>` по образцу `pkg-fast-livo-x86`:

- `needs`: `base-x86-ros2` (Jetson: `base-jetson-agx`/`base-jetson-nano`)
- контекст: `docker/package/Dockerfile.ros2`
- передайте `PACKAGE_REPO`, `PACKAGE_BRANCH`, `PACKAGE_NAME`, `CUDA_ARCH`
- тег: `type=raw,value=<имя>-<platform>-ros2-latest`

Гейтинг Jetson устроен на уровне базовых джоб: `base-jetson-*` имеют `needs: gate` и `if: needs.gate.outputs.ngc == 'true'`. Пакетным джобам добавлять `gate`/`if` не нужно, достаточно `needs: base-jetson-*`: если база скипнута (нет токена), зависимая джоба скипается автоматически, следом и её `smoke-*`.

## Шаг 4: Smoke-проверка

Добавьте `smoke-*` джобу (образец `smoke-fast-livo-*`) с `needs: pkg-<пакет>`. Она запускает опубликованный образ и проверяет артефакты сборки:

```bash
docker run --rm --entrypoint bash ghcr.io/acider19/ros-pkg:<package>-<platform>-ros2-latest -c '
    set -e
    test -x /colcon_ws/install/<package>/lib/<package>/<binary>
    test -x /colcon_ws/install/livox_ros_driver2/lib/livox_ros_driver2/livox_ros_driver2_node
    python3 -c "import gtsam"
'
```

Jetson-образы запускаются с `--platform linux/arm64` и `docker/setup-qemu-action` (архитектура проверяется через `dpkg --print-architecture`).

## Параметры Dockerfile.ros2

| Параметр | Описание | По умолчанию |
|---|---|---|
| `BASE_IMAGE` | Базовый Docker-образ | `ghcr.io/acider19/ros-cuda-base:x86_64-ros2-latest` |
| `PACKAGE_REPO` | URL репозитория пакета | `https://github.com/v4rl-ucy/FAST-LIVO2-ROS2.git` |
| `PACKAGE_BRANCH` | Ветка репозитория | `main` |
| `PACKAGE_NAME` | Имя пакета (colcon) | `fast_livo` |
| `CUDA_ARCH` | Архитектуры CUDA | `70;75;80;86` |
| `ROS_DISTRO` | Версия ROS | `humble` |

Сборка включает системные зависимости (Sophus, `Livox-SDK2`, `livox_ros_driver2`, vikit), симлинк Eigen (`/usr/include/Eigen`), необходимый для PCL из l4t-базы Jetson, и `libssl-dev` (OpenSSL, который требует Fast-DDS при конфигурации ROS2-пакета).

## Архитектуры CUDA

| Платформа | CUDA_ARCH |
|---|---|
| x86_64 (Volta+) | `70;75;80;86` |
| Jetson Orin (SM 8.7) | `87` |

## Пример: FAST-LIVO2-ROS2

```bash
docker buildx build \
    --platform linux/amd64 \
    -f docker/package/Dockerfile.ros2 \
    --build-arg BASE_IMAGE=ghcr.io/acider19/ros-cuda-base:x86_64-ros2-latest \
    --build-arg PACKAGE_REPO=https://github.com/v4rl-ucy/FAST-LIVO2-ROS2.git \
    --build-arg CUDA_ARCH="70;75;80;86" \
    -t fast-livo2-ros2:x86_64 .
```