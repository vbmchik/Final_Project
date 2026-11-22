-- Loading the clean tables (pandas -> PostgreSQL voltway_israel, VoltWay_Cleaning.ipynb):
--   Sections 29-36: vehicle_registry (861,136), wltp_models_2024_2026 (19,847),
--                   ev_by_district (90) + 7 lookup tables; CSV copies in clean_data/.
--   Sections 37-39: charging_districts (7), charging_cities (143) from current_data/.

-- Query 1 (Question 1): Vehicle counts by fuel type.
SELECT v.sug_delek_nm AS fuel_he, f.fuel_en, COUNT(*) AS vehicle_count
FROM public.vehicle_registry AS v
    LEFT JOIN public.lookup_fuel AS f ON v.sug_delek_nm = f.sug_delek_nm
GROUP BY
    v.sug_delek_nm,
    f.fuel_en
ORDER BY vehicle_count DESC;

-- Query 2 (Question 1): Electric vehicle registrations by quarter (full quarters only).
SELECT
    EXTRACT(YEAR FROM v.first_registration_date)::INT AS registration_year,
    EXTRACT(QUARTER FROM v.first_registration_date)::INT AS registration_quarter,
    COUNT(*) AS ev_count
FROM public.vehicle_registry AS v
    JOIN public.lookup_fuel AS f ON v.sug_delek_nm = f.sug_delek_nm
WHERE
    f.fuel_en = 'Electric'
    AND v.first_registration_date < (SELECT DATE_TRUNC('quarter', MAX(mivchan_acharon_dt) + INTERVAL '1 day') FROM public.vehicle_registry)
GROUP BY
    1,
    2
ORDER BY 1, 2;

-- Query 3 (Question 1): Total vehicles, total EVs and EV share up to each year.
WITH
    yearly AS (
        SELECT
            EXTRACT(YEAR FROM v.first_registration_date)::INT AS registration_year,
            COUNT(*) AS total_vehicles,
            COUNT(*) FILTER (
                WHERE
                    f.fuel_en = 'Electric'
            ) AS electric_vehicles
        FROM public.vehicle_registry AS v
            LEFT JOIN public.lookup_fuel AS f ON v.sug_delek_nm = f.sug_delek_nm
        WHERE
            v.first_registration_date IS NOT NULL
        GROUP BY
            1
    )
SELECT
    registration_year,
    CASE
        WHEN MAKE_DATE(registration_year, 12, 31) <= (SELECT MAX(mivchan_acharon_dt) FROM public.vehicle_registry) THEN 'Full year'
        ELSE 'YTD (incomplete)'
    END AS period_status,
    SUM(total_vehicles) OVER (
        ORDER BY registration_year
    ) AS cumulative_vehicles,
    SUM(electric_vehicles) OVER (
        ORDER BY registration_year
    ) AS cumulative_ev,
    ROUND(
        100.0 * SUM(electric_vehicles) OVER (
            ORDER BY registration_year
        ) / NULLIF(
            SUM(total_vehicles) OVER (
                ORDER BY registration_year
            ),
            0
        ),
        2
    ) AS cumulative_ev_share_pct
FROM yearly
ORDER BY registration_year;

-- Query 4 (Question 2): Top 10 EV brands and their market shares.
SELECT
    m.maker_en,
    COUNT(*) AS electric_vehicles,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS market_share_pct,
    DENSE_RANK() OVER (
        ORDER BY COUNT(*) DESC
    ) AS brand_rank
FROM public.vehicle_registry AS v
    JOIN public.lookup_fuel AS f ON v.sug_delek_nm = f.sug_delek_nm
    LEFT JOIN public.lookup_makers AS m ON v.tozeret_cd = m.tozeret_cd
WHERE
    f.fuel_en = 'Electric'
GROUP BY
    m.maker_en
ORDER BY electric_vehicles DESC
LIMIT 10;

-- Query 5 (Question 2): Top 5 EV brands in each quarter (full quarters only).
WITH
    quarterly AS (
        SELECT
            EXTRACT(YEAR FROM v.first_registration_date)::INT AS registration_year,
            EXTRACT(QUARTER FROM v.first_registration_date)::INT AS registration_quarter,
            m.maker_en,
            COUNT(*) AS electric_vehicles
        FROM public.vehicle_registry AS v
            JOIN public.lookup_fuel AS f ON v.sug_delek_nm = f.sug_delek_nm
            LEFT JOIN public.lookup_makers AS m ON v.tozeret_cd = m.tozeret_cd
        WHERE
            f.fuel_en = 'Electric'
            AND v.first_registration_date < (SELECT DATE_TRUNC('quarter', MAX(mivchan_acharon_dt) + INTERVAL '1 day') FROM public.vehicle_registry)
        GROUP BY
            1,
            2,
            3
    ),
    ranked AS (
        SELECT
            *,
            ROUND(
                100.0 * electric_vehicles / SUM(electric_vehicles) OVER (
                    PARTITION BY
                        registration_year,
                        registration_quarter
                ),
                2
            ) AS market_share_pct,
            DENSE_RANK() OVER (
                PARTITION BY
                    registration_year,
                    registration_quarter
                ORDER BY electric_vehicles DESC
            ) AS brand_rank
        FROM quarterly
    )
SELECT
    registration_year,
    registration_quarter,
    brand_rank,
    maker_en,
    electric_vehicles,
    market_share_pct
FROM ranked
WHERE
    brand_rank <= 5
ORDER BY
    registration_year,
    registration_quarter,
    brand_rank,
    maker_en;


-- Query 6 (Question 1): EV share among registrations in each quarter (full quarters only).

SELECT
    TO_CHAR(
        v.first_registration_date,
        'YYYY-"Q"Q'
    ) AS registration_quarter,
    COUNT(*) AS total_vehicles,
    COUNT(*) FILTER (
        WHERE
            f.fuel_en = 'Electric'
    ) AS electric_vehicles,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE
                f.fuel_en = 'Electric'
        ) / COUNT(*),
        2
    ) AS electric_share_pct
FROM public.vehicle_registry AS v
    LEFT JOIN public.lookup_fuel AS f ON v.sug_delek_nm = f.sug_delek_nm
WHERE
    v.first_registration_date IS NOT NULL
    AND v.first_registration_date < (SELECT DATE_TRUNC('quarter', MAX(mivchan_acharon_dt) + INTERVAL '1 day') FROM public.vehicle_registry)
GROUP BY
    1
ORDER BY 1;

-- Query 7 (Question 2): Top 10 countries that produce EVs.
SELECT
    m.production_country_en,
    COUNT(*) AS electric_vehicles,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS market_share_pct,
    DENSE_RANK() OVER (
        ORDER BY COUNT(*) DESC
    ) AS country_rank
FROM public.vehicle_registry AS v
    JOIN public.lookup_fuel AS f ON v.sug_delek_nm = f.sug_delek_nm
    LEFT JOIN public.lookup_makers AS m ON v.tozeret_cd = m.tozeret_cd
WHERE
    f.fuel_en = 'Electric'
GROUP BY
    m.production_country_en
ORDER BY electric_vehicles DESC
LIMIT 10;

-- Query 8 (Question 2): EV counts and shares by owner type.
SELECT
    v.ownership_en,
    COUNT(*) AS electric_vehicles,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS market_share_pct,
    DENSE_RANK() OVER (
        ORDER BY COUNT(*) DESC
    ) AS ownership_rank
FROM public.vehicle_registry AS v
    JOIN public.lookup_fuel AS f ON v.sug_delek_nm = f.sug_delek_nm
WHERE
    f.fuel_en = 'Electric'
GROUP BY
    v.ownership_en
ORDER BY electric_vehicles DESC;

-- Query 9 (Question 3): EV counts and shares by district.
SELECT
    COALESCE(district_en, 'Unknown') AS district_en,
    SUM(car_num) AS EV,
    ROUND(
        100.0 * SUM(car_num) / SUM(SUM(car_num)) OVER (),
        2
    ) AS EV_share_pct
FROM public.ev_by_district
GROUP BY
    1
ORDER BY EV DESC;


-- Query 10 (Question 3): EVs per charging point (all and fast) in each district.
-- Limitation: charging data is from 13.11.2025, private_ev_reported from 30.09.2026,
-- ev_by_district downloaded 08.11.2026; fast kW threshold is not specified.
WITH
    district_ev AS (
        SELECT
            mahoz_nm,
            SUM(car_num) AS all_ev
        FROM public.ev_by_district
        WHERE
            mahoz_nm IS NOT NULL
        GROUP BY
            mahoz_nm
    )
SELECT
    c.district_en,
    c.private_ev_reported,
    d.all_ev,
    c.charging_points,
    c.fast_points_reported,
    ROUND(
        1.0 * c.private_ev_reported / NULLIF(c.charging_points, 0),
        2
    ) AS ev_per_charging_point,
    ROUND(
        1.0 * c.private_ev_reported / NULLIF(c.fast_points_reported, 0),
        2
    ) AS private_ev_per_fast_point,
    ROUND(
        1.0 * d.all_ev / NULLIF(c.fast_points_reported, 0),
        2
    ) AS all_ev_per_fast_point
FROM public.charging_districts AS c
    LEFT JOIN district_ev AS d ON c.mahoz_nm = d.mahoz_nm
ORDER BY all_ev_per_fast_point DESC;

-- Query 11 (Question 1): Quarterly shares by WLTP drive technology — BEV, PHEV, HEV, ICE (full quarters only).
SELECT
    v.registration_quarter,
    COUNT(*) AS matched_vehicles,
    ROUND(100.0 * COUNT(*) FILTER (WHERE v.drive_technology_en = 'Electric (BEV)') / COUNT(*), 2) AS bev_share_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE v.drive_technology_en = 'Plug-in hybrid') / COUNT(*), 2) AS phev_share_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE v.drive_technology_en = 'Hybrid (self-charging)') / COUNT(*), 2) AS hev_share_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE v.drive_technology_en = 'Conventional engine') / COUNT(*), 2) AS ice_share_pct
FROM public.vehicle_registry AS v
WHERE
    v.drive_technology_en IS NOT NULL
    AND v.first_registration_date < (SELECT DATE_TRUNC('quarter', MAX(mivchan_acharon_dt) + INTERVAL '1 day') FROM public.vehicle_registry)
GROUP BY
    1
ORDER BY 1;
