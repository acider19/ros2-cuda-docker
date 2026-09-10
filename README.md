# ROS2 CUDA Cross-Platform Docker Build System

[![CI](https://github.com/acider19/ros2-cuda-docker/actions/workflows/ci.yml/badge.svg)](https://github.com/acider19/ros2-cuda-docker/actions/workflows/ci.yml)

Автоматизированная система сборки и публикации Docker-образов с ROS2 Humble и CUDA для **x86_64** и **платформ NVIDIA Jetson** (Orin AGX, Orin Nano). Сборка выполняется в GitHub Actions и публикуется в GitHub Container Registry (`ghcr.io`).

## Возможности

- **Multi-platform сборка.** `linux/amd64` собирается нативно, `linux/arm64` через QEMU, из одного пайплайна.
- **Единый workflow.** Один `ci.yml` с явным графом зависимостей (`gate` → `base-*` → `pkg-*` → `smoke-*`) вместо связки отдельных workflow через события.
- **Гейтинг по секрету.** Jetson-джобы идут только при наличии `NGC_API_TOKEN`, который `nvcr.io` требует для доступа. Без токена они скипаются, сборка x86 не затрагивается.
- **Кеширование слоёв.** `type=gha` на базовых образах и пакетах: повторные прогоны занимают минуты вместо десятков.
- **Публикация с историей.** Базовые образы выходят как `*-latest` и SHA-теги, пакеты: только `*-latest`. По SHA-тегу проще откатиться к известной версии.
- **Smoke-проверка в CI.** После публикации каждый образ запускается, наличие бинарников пакета проверяется.
- **Единый шаблон базы.** Три таргета собираются из одного `docker/base/Dockerfile.ros2`; различие задаётся `ARG BASE_IMAGE` (CUDA для x86, L4T JetPack для Jetson).
- **Единый шаблон пакета.** Один `Dockerfile.ros2` (`colcon build`) на все три платформы; различия передаются `build-args` (CUDA_ARCH и т.п.).

## Поддерживаемые платформы

| Платформа | Архитектура | Базовый образ | CUDA |
|---|---|---|---|
| x86_64 + NVIDIA GPU | `linux/amd64` | `nvidia/cuda:12.6.3-devel-ubuntu22.04` | 12.6.3 |
| Jetson AGX Orin (JP 6.2) | `linux/arm64` | `nvcr.io/nvidia/l4t-jetpack:r36.4.0` | из JetPack |
| Jetson Orin Nano (JP 6.2) | `linux/arm64` | `nvcr.io/nvidia/l4t-jetpack:r36.4.0` | из JetPack |

## Публикуемые образы

**Базовые образы** (`ghcr.io/acider19/ros-cuda-base`):

| Тег | Содержимое |
|---|---|
| `x86_64-ros2-latest` | CUDA 12.6.3 + ROS2 Humble + PCL/Eigen/OpenCV |
| `jetson-agx-ros2-latest` | L4T r36.4.0 (JP 6.2) + ROS2 Humble + PCL/Eigen/OpenCV |
| `jetson-nano-ros2-latest` | L4T r36.4.0 (JP 6.2) + ROS2 Humble + PCL/Eigen/OpenCV |

**Пакеты** (`ghcr.io/acider19/ros-pkg`):

| Тег | Содержимое |
|---|---|
| `fast_livo-x86_64-ros2-latest` | FAST-LIVO2-ROS2 (x86_64) |
| `fast_livo-jetson-agx-ros2-latest` | FAST-LIVO2-ROS2 (Jetson AGX, `CUDA_ARCH=87`) |
| `fast_livo-jetson-nano-ros2-latest` | FAST-LIVO2-ROS2 (Jetson Nano, `CUDA_ARCH=87`) |

## Быстрый старт

### 1. Локальная сборка базовых образов

```bash
./scripts/build-local.sh            # все три платформы
./scripts/build-local.sh -p x86_64-ros2   # только x86_64
```

Jetson-образы собираются через `docker buildx` с QEMU; на хосте должны быть зарегистрированы `binfmt`-обработчики (скрипт делает это сам). Для Jetson-таргетов предварительно войдите в `nvcr.io`:

```bash
docker login nvcr.io -u '$oauthtoken' -p "$NGC_API_TOKEN"
```

### 2. Сборка пакета на базе

```bash
docker buildx build \
    --platform linux/amd64 \
    -f docker/package/Dockerfile.ros2 \
    --build-arg BASE_IMAGE=ghcr.io/acider19/ros-cuda-base:x86_64-ros2-latest \
    --build-arg PACKAGE_REPO=https://github.com/v4rl-ucy/FAST-LIVO2-ROS2.git \
    --build-arg PACKAGE_NAME=fast_livo \
    --build-arg CUDA_ARCH="70;75;80;86" \
    -t fast-livo2:x86_64 .
```

### 3. Запуск опубликованного образа

```bash
docker pull ghcr.io/acider19/ros-pkg:fast_livo-x86_64-ros2-latest

docker run -it --rm ghcr.io/acider19/ros-pkg:fast_livo-x86_64-ros2-latest \
    bash -lc 'source /opt/ros/humble/setup.bash && source /colcon_ws/install/setup.bash && ros2 run fast_livo fastlivo_mapping'
```

На хосте с GPU добавьте `--gpus all`. Для Jetson требуется NVIDIA Container Toolkit (`--runtime nvidia`): драйверы монтируются с хоста (в l4t-контейнере нет `nvidia-smi`).

### 4. Диагностика образа

```bash
./scripts/verify-cuda.sh ghcr.io/acider19/ros-cuda-base:x86_64-ros2-latest
```

## CI/CD пайплайн

Единый workflow `.github/workflows/ci.yml`. Триггеры: push в `main`, ручной запуск (`workflow_dispatch`).

Стадии:

1. `gate`: проверка наличия секрета `NGC_API_TOKEN`; результат (`ngc=true/false`) уходит в output джобы.
2. `base-*`: сборка и публикация базовых образов. Jetson выполняется только при `ngc=true`.
3. `pkg-*`: сборка и публикация пакета поверх базовых образов (`needs: base-*`).
4. `smoke-*`: запуск опубликованных образов и проверка бинарников пакета (`fastlivo_mapping`, `livox_ros_driver2_node`, импорт `gtsam`).

Зависимости между джобами прописаны явно через `needs:`; ветки x86 и Jetson идут параллельно и не блокируют друг друга.

Детали в [Архитектура системы](docs/ARCHITECTURE.md).

## Требования для сборки Jetson

- Секрет репозитория **`NGC_API_TOKEN`** (бесплатно на nvidia.com/ngc; логин на nvcr.io: `$oauthtoken`). Заводится в *Settings → Secrets and variables → Actions*.
- Без него Jetson-джобы пропускаются, x86-часть продолжает работать.

Пошагово в [Развёртывание пайплайна](docs/DEPLOYMENT.md).

## Документация

- [Архитектура системы](docs/ARCHITECTURE.md)
- [CI/CD пайплайн: детальный разбор](docs/CI_PIPELINE.md)
- [Развёртывание пайплайна](docs/DEPLOYMENT.md)
- [Добавление нового пакета](docs/ADDING_PACKAGES.md)
- [Скрипты](docs/SCRIPTS.md)
- [Известные ограничения](docs/KNOWN_LIMITATIONS.md)