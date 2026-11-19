# VoltWay — очистка данных

Исходные данные хранятся в репозитории в архиве `data.zip`, код обработки — в ноутбуке `VoltWay_Cleaning.ipynb`.

## Подготовка данных

После клонирования или скачивания репозитория распакуйте `data.zip` в корне проекта перед запуском ноутбука:

```bash
python -m zipfile -e data.zip .
```

На macOS / Linux при необходимости используйте `python3` вместо `python`.
Архив уже содержит папку `data/`: после распаковки CSV должны находиться непосредственно в `data/`, например `data/vehicle_registry_2024_2026.csv`.

Распакованная папка `data/` исключена из Git. В репозиторий добавляется только архив, содержащий все исходные CSV и `SOURCE.txt`.

## Установка пакетов

Откройте терминал в папке проекта и создайте виртуальное окружение:

```bash
python3 -m venv .venv
```

Активируйте его на macOS / Linux:

```bash
source .venv/bin/activate
```

На Windows (PowerShell):

```powershell
.venv\Scripts\Activate.ps1
```

Установите пакеты из `requirements.txt`:

```bash
python -m pip install -r requirements.txt
```

## Запуск ноутбука

Из папки проекта выполните:

```bash
jupyter lab VoltWay_Cleaning.ipynb
```

При выполнении ноутбука обработанные CSV сохраняются в `clean_data/`. Эта папка исключена из Git.

Для ячеек загрузки данных в PostgreSQL нужен отдельно установленный и запущенный сервер PostgreSQL и база `voltway_israel`. Параметры подключения задаются в ноутбуке; пароль вводится при запуске соответствующей ячейки.
