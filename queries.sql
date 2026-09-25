-- ============================================================================
-- Analytical SQL queries against vaccination.db
-- Each query is labeled with the brief question it answers.
-- ============================================================================

-- Q: How do vaccination rates correlate with a decrease in disease incidence?
-- (Country-year matched DTP3 coverage vs Pertussis incidence)
SELECT c.year, ROUND(AVG(fc.coverage_pct),1) AS avg_dtp3_coverage,
       ROUND(AVG(fi.incidence_rate),2) AS avg_pertussis_incidence
FROM fact_coverage fc
JOIN dim_antigen a ON a.antigen_id = fc.antigen_id AND a.antigen_code = 'DTPCV3'
JOIN dim_year c ON c.year_id = fc.year_id
JOIN fact_incidence fi ON fi.country_id = fc.country_id AND fi.year_id = fc.year_id
JOIN dim_disease d ON d.disease_id = fi.disease_id AND d.disease_code = 'PERTUSSIS'
GROUP BY c.year
ORDER BY c.year;

-- Q: What is the drop-off rate between 1st dose and subsequent doses? (DTP1 -> DTP3, global)
SELECT y.year,
       ROUND(AVG(CASE WHEN a.antigen_code='DTPCV1' THEN fc.coverage_pct END),1) AS dtp1,
       ROUND(AVG(CASE WHEN a.antigen_code='DTPCV3' THEN fc.coverage_pct END),1) AS dtp3
FROM fact_coverage_global fc
JOIN dim_year y ON y.year_id = fc.year_id
JOIN dim_antigen a ON a.antigen_id = fc.antigen_id AND a.antigen_code IN ('DTPCV1','DTPCV3')
GROUP BY y.year
ORDER BY y.year;

-- Q: Has the rate of booster dose uptake increased over time? (MCV1 vs MCV2, global)
SELECT y.year,
       ROUND(AVG(CASE WHEN a.antigen_code='MCV1' THEN fc.coverage_pct END),1) AS mcv1,
       ROUND(AVG(CASE WHEN a.antigen_code='MCV2' THEN fc.coverage_pct END),1) AS mcv2_booster
FROM fact_coverage_global fc
JOIN dim_year y ON y.year_id = fc.year_id
JOIN dim_antigen a ON a.antigen_id = fc.antigen_id AND a.antigen_code IN ('MCV1','MCV2')
GROUP BY y.year
ORDER BY y.year;

-- Q: Which regions have low coverage (or high disease incidence despite high vaccination rates)?
-- DTP3 coverage by WHO region, latest year
SELECT fcr.who_region, y.year, ROUND(fcr.coverage_pct,1) AS dtp3_coverage
FROM fact_coverage_region fcr
JOIN dim_year y ON y.year_id = fcr.year_id
JOIN dim_antigen a ON a.antigen_id = fcr.antigen_id AND a.antigen_code = 'DTPCV3'
WHERE y.year = (SELECT MAX(year) FROM dim_year)
ORDER BY dtp3_coverage ASC;

-- Q: Are there significant disparities in vaccine introduction timelines across WHO regions? (Rotavirus)
SELECT dc.who_region,
       ROUND(100.0 * SUM(CASE WHEN fvi.introduced='Yes' THEN 1 ELSE 0 END) / COUNT(DISTINCT dc.country_id), 1) AS pct_introduced
FROM fact_vaccine_intro fvi
JOIN dim_country dc ON dc.country_id = fvi.country_id
JOIN dim_vaccine v ON v.vaccine_id = fvi.vaccine_id AND v.vaccine_description LIKE '%Rotavirus%'
WHERE dc.who_region IS NOT NULL
GROUP BY dc.who_region
ORDER BY pct_introduced DESC;

-- Q: What percentage of the target population has been covered by each vaccine? (latest global year)
SELECT a.antigen_description, ROUND(fcg.coverage_pct,1) AS coverage_pct
FROM fact_coverage_global fcg
JOIN dim_antigen a ON a.antigen_id = fcg.antigen_id
JOIN dim_year y ON y.year_id = fcg.year_id
WHERE y.year = (SELECT MAX(year) FROM dim_year)
ORDER BY coverage_pct DESC;

-- Q: What are the gaps in coverage for vaccines targeting high-priority diseases (e.g., TB, Hepatitis B)?
SELECT a.antigen_description, ROUND(fcg.coverage_pct,1) AS coverage_pct
FROM fact_coverage_global fcg
JOIN dim_antigen a ON a.antigen_id = fcg.antigen_id
JOIN dim_year y ON y.year_id = fcg.year_id
WHERE y.year = (SELECT MAX(year) FROM dim_year)
  AND a.antigen_code IN ('BCG','HEPB3','HEPB_BD')
ORDER BY coverage_pct ASC;

-- Q: Countries with high reported coverage but high measles incidence (outbreak-risk flag)
SELECT dc.country_name, y.year, ROUND(fc.coverage_pct,1) AS mcv1_coverage, ROUND(fi.incidence_rate,1) AS measles_incidence
FROM fact_coverage fc
JOIN dim_antigen a ON a.antigen_id = fc.antigen_id AND a.antigen_code = 'MCV1'
JOIN dim_year y ON y.year_id = fc.year_id AND y.year >= 2018
JOIN dim_country dc ON dc.country_id = fc.country_id
JOIN fact_incidence fi ON fi.country_id = fc.country_id AND fi.year_id = fc.year_id
JOIN dim_disease d ON d.disease_id = fi.disease_id AND d.disease_code = 'MEASLES'
WHERE fc.coverage_pct >= 90 AND fi.incidence_rate > 1
ORDER BY fi.incidence_rate DESC
LIMIT 10;

-- Q: Which diseases have shown the most significant reduction in cases due to vaccination?
-- (global reported cases, first vs last available year, % change)
SELECT d.disease_description,
       SUM(CASE WHEN y.year = (SELECT MIN(year) FROM dim_year) THEN fca.cases ELSE 0 END) AS cases_first_year,
       SUM(CASE WHEN y.year = (SELECT MAX(year) FROM dim_year) THEN fca.cases ELSE 0 END) AS cases_last_year
FROM fact_cases fca
JOIN dim_disease d ON d.disease_id = fca.disease_id
JOIN dim_year y ON y.year_id = fca.year_id
GROUP BY d.disease_description
ORDER BY cases_first_year DESC;

-- Q: Are certain diseases more prevalent in specific geographic areas? (by WHO region, latest year, joined via country)
SELECT dc.who_region, d.disease_description, ROUND(AVG(fi.incidence_rate),2) AS avg_incidence
FROM fact_incidence fi
JOIN dim_country dc ON dc.country_id = fi.country_id
JOIN dim_disease d ON d.disease_id = fi.disease_id
JOIN dim_year y ON y.year_id = fi.year_id
WHERE dc.who_region IS NOT NULL AND y.year = (SELECT MAX(year) FROM dim_year)
GROUP BY dc.who_region, d.disease_description
ORDER BY d.disease_description, avg_incidence DESC;
