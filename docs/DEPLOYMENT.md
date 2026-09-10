# Развёртывание пайплайна

Пошаговая инструкция: поднять пайплайн в своём GitHub-репозитории, подключить Jetson-сборку и проверить, что всё работает.

## Предварительные требования

| Компонент | Требование |
|---|---|
| GitHub-репозиторий | Права на создание секретов и пермишены Actions |
| Net-доступ | CI-раннеры ubuntu-latest (Docker, Buildx, QEMU ставятся автоматически) |
| `NGC_API_TOKEN` (для Jetson) | Секрет репозитория; создаётся бесплатно на nvidia.com/ngc |

## Шаг 1. Подготовка репозитория

1. Скопируйте содержимое проекта (workflow, `docker/`, `scripts/`, `docs/`) в репозиторий.
2. Убедитесь, что GitHub Actions включены: **Settings → Actions → General → Allow all actions**.
3. Проверьте пермишены workflow (заданы в `ci.yml`, менять не обязательно):

```yaml
permissions:
  contents: read
  packages: write
```

## Шаг 2. Секрет `NGC_API_TOKEN`

`nvcr.io` не отдаёт `l4t-jetpack` без авторизации. Это единственный секрет, без которого Jetson-сборки невозможны.

1. Создайте API-ключ на https://catalog.ngc.nvidia.com → **Settings → API Keys → Generate API Key**.
2. Добавьте секрет: **Settings → Secrets and variables → Actions → New repository secret**:
   - **Name:** `NGC_API_TOKEN`
   - **Value:** скопированный ключ (логин на nvcr.io: `$oauthtoken`).
3. Без секрета workflow продолжает работать: джоба `gate` выставляет `ngc=false`, Jetson-джобы скипаются.

## Шаг 3. Запуск и публикация

1. Запушьте изменения в `main`, и workflow `CI` стартует автоматически. Либо запустите вручную: **Actions → CI → Run workflow**.
2. После сборки базовые образы и пакеты попадут в ghcr под владельцем пакета репозитория.
3. Если пакет нужен публично (pull без авторизации): **Settings → Packages → ros-cuda-base/ros-pkg → Change visibility → Public** (потребуется подтверждение).

## Шаг 4. Валидация

```bash
# Публичные образы доступны без логина
docker pull ghcr.io/<owner>/ros-cuda-base:x86_64-ros2-latest

# Базовый образ: CUDA, ROS
./scripts/verify-cuda.sh ghcr.io/<owner>/ros-cuda-base:x86_64-ros2-latest

# Пакет: запуск из опубликованного образа
docker run -it --rm ghcr.io/<owner>/ros-pkg:fast_livo-x86_64-ros2-latest \
    bash -lc 'source /opt/ros/humble/setup.bash && source /colcon_ws/install/setup.bash && ros2 pkg list | grep fast_livo'
```

Для Jetson-образов на хосте с arm64 или с зарегистрированным `binfmt` добавьте `--platform linux/arm64`.
GPU-доступ: на x86 укажите `--gpus all`; на Jetson используйте NVIDIA Container Toolkit (`--runtime nvidia`, драйверы монтируются с хоста).

## Настройка триггеров

Текущее поведение в `ci.yml`:

```yaml
on:
  push:
    branches: [main]
  workflow_dispatch:
```

### Дополнительно: теги версий и pull request

```yaml
on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:
    branches: [main]
```

> Для полного прогона на PR требуется секрет `NGC_API_TOKEN` (секреты в PR из форков не прокидываются).

## Troubleshooting

| Симптом | Причина | Решение |
|---|---|---|
| Джобы `base-jetson-*`/`pkg-*-jetson-*` (и их `smoke-*`) в статусе **skipped** | Нет `NGC_API_TOKEN` | Добавить секрет (Шаг 2); повторный прогон |
| `manifest unknown` при pull `l4t-jetpack:<tag>` | Тег не существует в nvcr.io или нет авторизации | Проверить доступные теги (`docker manifest inspect`); убедиться в `NGC_API_TOKEN` |
| Сборка Jetson идёт 40-60+ минут | Холодный прогон под QEMU (нет кеша) | Это норма; повторные прогоны ускоряются кешем `type=gha` |
| `smoke-*` завершилась с ошибкой | Бинарник пакета отсутствует в опубликованном образе | Проверить путь установки в `Dockerfile.ros2` (colcon ставит в `/colcon_ws/install/<pkg>/lib/<pkg>/`) |
| Ошибка `source: not found` в Dockerfile RUN | RUN выполняется в `/bin/sh`, а не `bash` | В Dockerfile должен быть `SHELL ["/bin/bash", "-c"]` |
| `Eigen/Core: No such file` на Jetson-базе | У NVIDIA PCL нет eigen в include-path | Симлинк `/usr/include/Eigen → /usr/include/eigen3/Eigen` (уже в `Dockerfile.ros2`) |
| `ngc=true`, но джоба скипнута | Условие `if` на джобе не совпадает с output `gate` | Сверить `needs.gate.outputs.ngc` у джобы и имя джобы `gate` |