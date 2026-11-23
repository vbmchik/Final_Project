-- QUESTION 1 METRICS: 
-- 1) Quarterly EV Share (shows the pace of the market's transition to electric power)

SELECT 
    registration_quarter,
    COUNT(CASE WHEN fuel_en = 'Electric' THEN mispar_rechev END) AS num_of_ev,
    COUNT(mispar_rechev) AS total_vehicles,
    ROUND(
        COUNT(CASE WHEN fuel_en = 'Electric' THEN mispar_rechev END) * 100.0 / COUNT(mispar_rechev), 
        2
    ) AS electric_share_pct
FROM vehicle_registry
WHERE registration_quarter IS NOT NULL
GROUP BY registration_quarter
ORDER BY registration_quarter;

-- 2) QoQ EV Registration Growth Rate (to distints the real growth of EV usage 
-- from the scenario when EV share increased because ICE sales dropped)

SELECT 
    registration_quarter,
    COUNT(CASE WHEN fuel_en = 'Electric' THEN mispar_rechev END) AS num_of_ev,
    ROUND(
        100.0 * (COUNT(CASE WHEN fuel_en = 'Electric' THEN mispar_rechev END) - 
		LAG(COUNT(CASE WHEN fuel_en = 'Electric' THEN mispar_rechev END)) OVER (ORDER BY registration_quarter)) 
        / LAG(COUNT(CASE WHEN fuel_en = 'Electric' THEN mispar_rechev END)) OVER (ORDER BY registration_quarter), 
    2) AS qoq_ev_growth_pct
FROM vehicle_registry
WHERE registration_quarter IS NOT NULL
GROUP BY registration_quarter
ORDER BY registration_quarter;

-- 3) Share of charging stations of different technology types (shows whether buyers prefer 
-- pure EVs or hybrids)

SELECT 
    registration_quarter,
	wm.drive_technology_en AS drive_technology,
    COUNT(vr.tozeret_cd) AS num_of_vehicles,
    ROUND(100.0 * COUNT(vr.tozeret_cd) / SUM(COUNT(vr.tozeret_cd)) OVER (PARTITION BY registration_quarter), 2) AS tech_share_pct
FROM vehicle_registry vr
LEFT JOIN wltp_models_2024_2026 wm ON wm.tozeret_cd = vr.tozeret_cd 
								   AND wm.degem_cd = vr.degem_cd
WHERE registration_quarter IS NOT NULL
GROUP BY registration_quarter, 
		 wm.drive_technology_en
ORDER BY registration_quarter, tech_share_pct DESC;


-- QUESTION 2 METRICS: 
-- 1) EV Market Share by maker and country (to determine market leaders)

SELECT 
    maker_en AS maker,
    production_country_en AS production_country,
    COUNT(CASE WHEN fuel_en = 'Electric' THEN mispar_rechev END) AS num_of_ev,
    ROUND(100.0 * COUNT(CASE WHEN fuel_en = 'Electric' THEN mispar_rechev END) / 
  	      SUM(COUNT(CASE WHEN fuel_en = 'Electric' THEN mispar_rechev END)) OVER (), 2) 
	      AS ev_market_share_pct
FROM vehicle_registry
GROUP BY maker, production_country
HAVING COUNT(CASE WHEN fuel_en = 'Electric' THEN mispar_rechev END) > 0
ORDER BY num_of_ev DESC;

-- 2) Brand Electrification Rate (shows brand strategy regarding EV models)

SELECT 
    maker_en AS maker,
    production_country_en AS production_country,
	COUNT(mispar_rechev) AS total_sales,
    ROUND(100.0 * COUNT(CASE WHEN fuel_en = 'Electric' THEN mispar_rechev END) / 
	      COUNT(mispar_rechev), 2) 
     AS brand_electrification_rate_pct
FROM vehicle_registry
GROUP BY maker, production_country
HAVING COUNT(CASE WHEN fuel_en = 'Electric' THEN mispar_rechev END) > 0
ORDER BY brand_electrification_rate_pct DESC, total_sales DESC;

-- 3) EV Ownership (shows who buys EVs (private, leasing, company))

SELECT 
    ownership_en AS ownership_type,
    COUNT(mispar_rechev) AS num_of_ev,
    ROUND(100.0 * COUNT(mispar_rechev) / SUM(COUNT(mispar_rechev)) OVER (), 2) AS ownership_share_pct
FROM vehicle_registry
WHERE fuel_en = 'Electric'
GROUP BY ownership_type
ORDER BY num_of_ev DESC;

-- QUESTION 3 METRICS:
-- 1) Regional EV Share (to identify regions with the highest demand for charging infrastructure)

SELECT 
    district_en AS district,
    SUM(car_num) AS total_evs,
    ROUND(100.0 * SUM(car_num) / SUM(SUM(car_num)) OVER (), 2) AS district_ev_share_pct
FROM ev_by_district
WHERE district_en IS NOT NULL
GROUP BY district_en
ORDER BY total_evs DESC;

-- 2) Different Ownership Types by District and Share of Stations 
-- according to business demand of 50 stations
-- The separation to Private and Corporate shows if there is a high demand for the slow-charging 
-- stations for homes (for private vehicles) or fast-charging stations for
-- business districts or industrial zones (for corporate vehicles)

WITH district_summary AS (
    SELECT 
        district_en AS district,
		(CASE WHEN subdistrict_en IS NOT NULL THEN subdistrict_en ELSE district_en END) AS subdistrict,
		SUM(car_num) AS total_evs,
        SUM(CASE WHEN ownership_en = 'Private' THEN car_num ELSE 0 END) AS private_evs,
        SUM(CASE WHEN ownership_en IN ('Leasing', 'Company') THEN car_num ELSE 0 END) AS corporate_evs	
    FROM ev_by_district
	WHERE district_en IS NOT NULL
    GROUP BY district, subdistrict
),

market_shares AS (
    SELECT 
        district,
		subdistrict,
        total_evs,
        private_evs,
        corporate_evs,
        ROUND(100.0 * total_evs / SUM(total_evs) OVER (), 2) AS market_share_pct,
        ROUND(private_evs / corporate_evs, 2) AS private_to_corporate,
		ROUND(100.0 * private_evs / total_evs, 2) AS private_share_pct,
        ROUND(100.0 * corporate_evs / total_evs, 2) AS corporate_share_pct
    FROM district_summary
)
SELECT 
    district,
	subdistrict,
    market_share_pct,
	private_share_pct,
    corporate_share_pct,
    private_to_corporate,
    ROUND(50.0 * total_evs / SUM(total_evs) OVER (), 0) AS recommended_share_of_stations_out_of_50
FROM market_shares
ORDER BY total_evs DESC;
