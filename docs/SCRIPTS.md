# Скрипты

Скрипты в `scripts/` покрывают сборку и проверку базовых образов. Пакеты собираются через CI или вручную (`docker buildx`, см. [Добавление нового пакета](ADDING_PACKAGES.md)); отдельных скриптов для них нет.

## build-local.sh

Локальная сборка базовых образов (`docker/base/Dockerfile.ros2`).

```bash
usage: build-local.sh [OPTIONS]
  -p, --platform PLATFORM   Платформа: x86_64-ros2 | jetson-agx-ros2 | jetson-nano-ros2
  -t, --tag TAG             Тег (по умолчанию: latest)
  -r, --registry REGISTRY   Регистр (по умолчанию: ghcr.io)
      --push                Запушить после сборки
```

Env-переменные:

| Переменная | По умолчанию | Назначение |
|---|---|---|
| `REGISTRY` | `ghcr.io` | Префикс репозитория образа |
| `IMAGE_PREFIX` | `local/ros-cuda-base` (или `$GITHUB_REPOSITORY_OWNER/ros-cuda-base`) | Имя репозитория образа |

Тег результата: `<REGISTRY>/<IMAGE_PREFIX>:<platform>-ros2-<tag>`, например `ghcr.io/local/ros-cuda-base:jetson-agx-ros2-latest`.

Примеры:

```bash
./scripts/build-local.sh                          # все три платформы
./scripts/build-local.sh -p jetson-agx-ros2       # только AGX
./scripts/build-local.sh -p x86_64-ros2 -t v1     # x86 с тегом v1
IMAGE_PREFIX=acider19/ros-cuda-base ./scripts/build-local.sh --push   # требует логина ghcr.io
```

Предусловия для Jetson-таргетов: логин в `nvcr.io` (`docker login nvcr.io -u '$oauthtoken' -p "$NGC_API_TOKEN"`), иначе pull `l4t-jetpack` вернёт `manifest unknown`. Флаг `--push` также требует `docker login ghcr.io` (или другого `REGISTRY`). На arm64-хосте (Apple Silicon) ARM-сборка идёт нативно; на x86-хосте нужен QEMU, скрипт регистрирует `binfmt` сам, но может выдать предупреждение.

## verify-cuda.sh

Проверка собранного образа: архитектура, версия ОС, CUDA (`nvcc`, каталоги библиотек), компиляция тестового `.cu`, наличие ROS2 Humble.

```bash
usage: verify-cuda.sh [--platform linux/amd64|linux/arm64] <image:tag>
```

Примеры:

```bash
./scripts/verify-cuda.sh ghcr.io/acider19/ros-cuda-base:x86_64-ros2-latest
./scripts/verify-cuda.sh --platform linux/arm64 ros-cuda-base:jetson-agx-local
```

Тест CUDA только компилируется (`nvcc`), а не запускается: запуск ядра требует GPU на хосте, а в l4t-контейнерах нет `nvidia-smi`, драйверы монтируются с хоста.

## push-images.sh

Публикация собранных базовых образов в registry. Пушит только базовые образы (`*-latest` трёх платформ).

```bash
usage: push-images.sh [OPTIONS]
  -i, --image TAG   Конкретный образ (x86_64-ros2-latest | jetson-agx-ros2-latest | jetson-nano-ros2-latest)
  -a, --all         Все базовые образы
```

Env-переменные те же, что у `build-local.sh` (`REGISTRY`, `IMAGE_PREFIX`). Предусловие: `docker login ghcr.io` (образ уйдёт в `ghcr.io/local/...`, если не задан `IMAGE_PREFIX`).

Примеры:

```bash
./scripts/push-images.sh -a
IMAGE_PREFIX=acider19/ros-cuda-base ./scripts/push-images.sh -i jetson-agx-ros2-latest
```

Примечание: для публичного доступа к образам переключите видимость пакета в *Packages → Change visibility → Public*.