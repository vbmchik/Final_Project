-- Query 1: Vehicle counts by fuel type.
SELECT v.sug_delek_nm AS fuel_he, f.fuel_en, COUNT(*) AS vehicle_count
FROM public.vehicle_registry AS v
    LEFT JOIN public.lookup_fuel AS f ON v.sug_delek_nm = f.sug_delek_nm
GROUP BY
    v.sug_delek_nm,
    f.fuel_en
ORDER BY vehicle_count DESC;

-- Query 2: Electric vehicle registrations by quarter.
SELECT
    EXTRACT(
        YEAR
        FROM TO_DATE(
                v.moed_aliya_lakvish, 'YYYY-MM'
            )
    )::int AS registration_year,
    EXTRACT(
        QUARTER
        FROM TO_DATE(
                v.moed_aliya_lakvish, 'YYYY-MM'
            )
    )::int AS registration_quarter,
    COUNT(*) AS ev_count
FROM public.vehicle_registry AS v
    JOIN public.lookup_fuel AS f ON v.sug_delek_nm = f.sug_delek_nm
WHERE
    f.fuel_en = 'Electric'
GROUP BY
    1,
    2
ORDER BY 1, 2;

-- Query 3: Total vehicles, total EVs and EV share up to each year.
WITH
    yearly AS (
        SELECT
            EXTRACT(
                YEAR
                FROM TO_DATE(
                        v.moed_aliya_lakvish, 'YYYY-MM'
                    )
            )::int AS registration_year,
            COUNT(*) AS total_vehicles,
            COUNT(*) FILTER (
                WHERE
                    f.fuel_en = 'Electric'
            ) AS electric_vehicles
        FROM public.vehicle_registry AS v
            LEFT JOIN public.lookup_fuel AS f ON v.sug_delek_nm = f.sug_delek_nm
        WHERE
            v.moed_aliya_lakvish IS NOT NULL
        GROUP BY
            1
    )
SELECT
    registration_year,
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

-- Query 4: Top 10 EV brands and their market shares.
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

-- Query 5: Top 5 EV brands in each quarter.
WITH
    quarterly AS (
        SELECT
            EXTRACT(
                YEAR
                FROM TO_DATE(
                        v.moed_aliya_lakvish, 'YYYY-MM'
                    )
            )::int AS registration_year,
            EXTRACT(
                QUARTER
                FROM TO_DATE(
                        v.moed_aliya_lakvish, 'YYYY-MM'
                    )
            )::int AS registration_quarter,
            m.maker_en,
            COUNT(*) AS electric_vehicles
        FROM public.vehicle_registry AS v
            JOIN public.lookup_fuel AS f ON v.sug_delek_nm = f.sug_delek_nm
            LEFT JOIN public.lookup_makers AS m ON v.tozeret_cd = m.tozeret_cd
        WHERE
            f.fuel_en = 'Electric'
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


-- Query 6: EV share among registrations in each quarter.

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
    v.moed_aliya_lakvish IS NOT NULL
GROUP BY
    1
ORDER BY 1;

-- Query 7: Top 10 countries that produce EVs.
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

-- Query 8: EV counts and shares by owner type.
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

-- Query 9: EV counts and shares by district.
SELECT
    district_en,
    SUM(car_num) AS EV,
    ROUND(
        100.0 * SUM(car_num) / SUM(SUM(car_num)) OVER (),
        2
    ) AS EV_share_pct
FROM public.ev_by_district
GROUP BY
    district_en
ORDER BY EV DESC;


-- Query 10: Private EVs per charging point in each district.
SELECT
    district_en,
    private_ev_reported,
    charging_points,
    ROUND(
        1.0 * private_ev_reported / NULLIF(charging_points, 0),
        2
    ) AS ev_per_charging_point
FROM public.charging_districts
ORDER BY ev_per_charging_point DESC;
