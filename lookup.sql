
SELECT v.sug_delek_nm AS fuel_he, f.fuel_en, COUNT(*) AS vehicle_count
FROM public.vehicle_registry AS v
    LEFT JOIN public.lookup_fuel AS f ON v.sug_delek_nm = f.sug_delek_nm
GROUP BY
    v.sug_delek_nm,
    f.fuel_en
ORDER BY vehicle_count DESC;

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

## Registration by quarter for electric vehicles

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

## Electric cars registration percentage by year

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

## Electric cars cumulative registration percentage by year

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

## Summary of top 10 electric vehicle brands by market share

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