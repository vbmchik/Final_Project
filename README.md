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

## Data sources

### Course data

The course downloaded the data on **8 November 2026**. We use the files in `data.zip`, not newer versions of the online tables. The full source notes are in `data/SOURCE.txt` inside the archive.

| Project file | Public source |
|---|---|
| `vehicle_registry_2024_2026.csv` | [Ministry of Transport: vehicle registry](https://data.gov.il/he/datasets/ministry_of_transport/private-and-commercial-vehicles) |
| `wltp_models_2024_2026.csv` | [Ministry of Transport: WLTP models](https://data.gov.il/he/datasets/ministry_of_transport/degem-rechev-wltp) |
| `ev_by_district.csv` | [Ministry of Transport: EV counts by district and subdistrict](https://data.gov.il/he/datasets/ministry_of_transport/rechavim_hashmalim) |

All **10 CSV files** in `data/` are loaded into the `dfs` dictionary as separate pandas DataFrames. Their roles are listed below.

| File in `data/` | Role in the notebook |
|---|---|
| `vehicle_registry_2024_2026.csv` | Base vehicle DataFrame (`vehicles`). |
| `wltp_models_2024_2026.csv` | WLTP model DataFrame (`wltp`), joined to vehicles for model specifications and emissions. |
| `ev_by_district.csv` | EV counts by district, subdistrict and ownership (`districts`). |
| `lookup_fuel.csv` | English fuel labels joined to vehicles. |
| `lookup_ownership.csv` | English ownership labels joined to vehicles and district EV counts. |
| `lookup_makers.csv` | Maker and production-country labels joined to vehicles. |
| `lookup_districts.csv` | English district and subdistrict labels; also used for the charging tables. |
| `lookup_wltp_body_type.csv` | English body-type labels joined to WLTP models. |
| `lookup_wltp_technology.csv` | English drive-technology labels joined to WLTP models. |
| `columns_vehicle_registry_en.csv` | English descriptions of registry columns; loaded as a reference DataFrame, without a join to vehicles. |

The course supplied the six `lookup_*.csv` files and `columns_vehicle_registry_en.csv`. They are helper tables, not extra public datasets. The course kept vehicles made in 2024-2026 and removed VINs. See `SOURCE.txt` for the licence and other course changes.

Course attribution for the last slide:

> Source: Israel Ministry of Transport and Road Safety, vehicle registry and WLTP model data, data.gov.il (8 Nov 2026).

### Added charging data

We use `current_data/charging-cities.csv` and `current_data/charging-districts.csv`. They were first added to Git on **20 November 2026**, in commit `1a1a76f`. This is not the date of the data.

The source labels inside the files name:

- [Ministry of Transport: charging stations](https://data.gov.il/he/datasets/ministry_of_transport/agg_charge_stations). Both files say the charging data is dated **13 November 2025**.
- [Ministry of Transport: EV counts by district](https://data.gov.il/he/datasets/ministry_of_transport/rechavim_hashmalim). The district file says its private EV counts were retrieved on **30 September 2026**.

**Source details still missing:** the exact download URLs for these two summary files are not recorded in Git or in the available conversation history. The city file labels its population as CBS 2023, but it has no exact population source URL. The links above identify the named public datasets; they do not prove where the summary files were made or downloaded.

The city file counts charging sites within 3 km of each city centre. We do not know the full method used to make these summaries. Nearby city areas may overlap.

### Population used in A4

[CBS, Table 2.12: Localities and Population, by District, Sub-District and Population Group](https://www.cbs.gov.il/he/publications/DocLib/2026/2.ShnatonPopulation/st02_12x.xlsx).

- Population date: **31 December 2025**. Published: **8 October 2026**.
- Sheet `ST02-12x`, column B, rows 10, 11, 17, 20, 25, 26 and 29.
- The source uses thousands. We converted the seven district totals to people and entered them in A4.
- These totals include foreign residents. The Judea and Samaria value covers Israeli localities.

### Road traffic: extra support for the recommendation

[Local copy of CBS Table 37](current_data/traffic_cbs_2026q1_table37.pdf).

Source: [CBS, Transport Statistics Quarterly No. 1, 2026, Table 37](https://www.cbs.gov.il/he/publications/DocLib/2026/rt0126/h_print.pdf#page=58). Downloaded **21 November 2026**. The local PDF contains the two original pages, printed pages **58-59**, without changes to the table. The full publication has 67 pages.

The table covers **35 selected road sections**. For 26 sections, the last count was in 2025; for eight, in 2024; for one, in 2023. It gives annual average daily traffic and details of the last count. Values marked as thousands must be multiplied by 1,000. Annual daily averages and weekday averages are different measures.

We use this as extra support when discussing road corridors in priority districts. Registered EVs may charge away from their home district. Road traffic can help us choose corridors to study next, alongside EVs per charging point.

This is not total traffic by district or city. The table has no district column, covers only selected sections and counts all vehicle types, not EVs alone. Daily averages cover both directions. Do not add section flows and call the result unique vehicles in a district. The same vehicle can pass several sections. The table does not show charging demand or site profit. It is not used in A1-A4 or loaded into PostgreSQL.

### Files checked but not used in the calculations

On **21 November 2026**, we downloaded the [official charging station records](https://data.gov.il/he/datasets/ministry_of_transport/agg_charge_stations/528482f2-d410-4d62-8b17-566ab23a1c52) through the [official API](https://data.gov.il/api/3/action/datastore_search?resource_id=528482f2-d410-4d62-8b17-566ab23a1c52&limit=10000). Resource ID: `528482f2-d410-4d62-8b17-566ab23a1c52`. The catalogue gives **19 March 2026** as the file update date.

We checked all 2,261 records. Their totals match our charging summary: 8,460 charging points, including 1,600 fast points. Matching totals do not prove that every district or city count matches. We did not replace our files or use these downloaded records in the tests. An older CBS population table for 2024 was also checked; A4 now uses the 2025 table linked above.
