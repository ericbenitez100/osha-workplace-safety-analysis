-- =====================================================================
-- Project 1: Workplace Safety Analysis
-- Dataset: 2012 U.S. Workplace Safety Data by State (OSHA)
-- Engine:  SQLite, run in DB Browser for SQLite
-- Author:  Eric Benitez
--
-- FRAMING: state-level workplace safety data for 2012, one row per state.
-- Rate of Fatalities is per 100,000 workers, so it is averaged across
-- states, not summed. Injuries/Illnesses is a raw count, so it is summed.
-- The State column holds the state name and its lat/long in one cell, so
-- the clean copy splits them. Blanks are left as missing, not zeroed,
-- because a blank does not mean zero and would drag averages down. The
-- same engineered columns built in the Excel and Power BI versions are
-- rebuilt here so all three line up.
-- =====================================================================

-- Step 1: Checked the raw State column, name and coordinates are in one cell
SELECT State
FROM workplace_safety
LIMIT 10;

-- Step 2: Baseline row count before cleaning. File has extra non-state rows
SELECT COUNT(*) AS total_rows_before_cleaning
FROM workplace_safety;

-- Step 3: Counted blanks in the key columns so averages reflect known gaps
SELECT COUNT(*)                                                                          AS total_rows,
       SUM(CASE WHEN TRIM("Rate of Fatalities, 2012") = '' THEN 1 ELSE 0 END)            AS blank_fatality_rate,
       SUM(CASE WHEN TRIM("Number of Injuries/Illnesses 2012") = '' THEN 1 ELSE 0 END)   AS blank_injuries,
       SUM(CASE WHEN TRIM("Inspectors") = '' THEN 1 ELSE 0 END)                          AS blank_inspectors,
       SUM(CASE WHEN TRIM("Years to Inspect Each Workplace Once") = '' THEN 1 ELSE 0 END) AS blank_inspect_cycle
FROM workplace_safety;

-- Step 4: Created clean copy, splitting state name from coordinates, converting blanks to NULL, casting numbers, and keeping only the 50 State/Federal rows
DROP TABLE IF EXISTS safety_clean;

CREATE TABLE safety_clean AS
SELECT
    TRIM(SUBSTR(State, 1, INSTR(State, CHAR(10)) - 1))                                                   AS State_Name,
    "State or Federal Program"                                                                           AS program_type,
    CAST(NULLIF(TRIM("Rate of Fatalities, 2012"), '') AS REAL)                                           AS fatality_rate,
    CAST(NULLIF(TRIM("Number of Fatalities, 2012"), '') AS REAL)                                         AS fatalities,
    CAST(NULLIF(TRIM("Number of Injuries/Illnesses 2012"), '') AS REAL)                                  AS injuries_illnesses,
    CAST(NULLIF(TRIM("State Rank, Fatalities 2012"), '') AS REAL)                                         AS fatality_rank,
    CAST(NULLIF(TRIM("Penalties FY 2013 (Average $)"), '') AS REAL)                                       AS avg_penalty,
    CAST(NULLIF(TRIM("Penalties FY 2013 (Rank)"), '') AS REAL)                                            AS penalty_rank,
    CAST(NULLIF(TRIM("Inspectors"), '') AS REAL)                                                          AS inspectors,
    CAST(NULLIF(TRIM("Years to Inspect Each Workplace Once"), '') AS REAL)                                AS years_to_inspect
FROM workplace_safety
WHERE "State or Federal Program" IN ('State', 'Federal');

-- Step 5: Confirmed clean copy holds only the 50 states
SELECT COUNT(*) AS rows_after_cleaning
FROM safety_clean;

-- Step 6: Spot-checked the clean copy
SELECT State_Name, program_type, fatality_rate, injuries_illnesses, inspectors
FROM safety_clean
LIMIT 10;

-- =====================================================================
-- ENGINEERED COLUMNS (the same calculated fields built in Excel and Power BI)
-- =====================================================================

-- Step 7: Added the engineered columns to the clean table, matching the Excel formulas
DROP TABLE IF EXISTS safety_enriched;

CREATE TABLE safety_enriched AS
SELECT
    State_Name,
    program_type,
    fatality_rate,
    fatalities,
    injuries_illnesses,
    inspectors,
    years_to_inspect,
    avg_penalty,
    -- Injuries per Inspector: injuries / inspectors
    ROUND(injuries_illnesses / NULLIF(inspectors, 0), 2)                          AS injuries_per_inspector,
    -- Inspection Coverage Score: 1 / years to inspect
    ROUND(1.0 / NULLIF(years_to_inspect, 0), 4)                                   AS inspection_coverage_score,
    -- Fatalities per 100,000 Injuries/Illnesses: fatalities / injuries * 100000
    ROUND(fatalities / NULLIF(injuries_illnesses, 0) * 100000, 2)                 AS fatalities_per_100k_injuries,
    -- Fatality Rate Difference from Average: state rate minus the average rate
    ROUND(fatality_rate - (SELECT AVG(fatality_rate) FROM safety_clean), 2)       AS fatality_rate_diff_from_avg,
    -- Years to Inspect Difference from Average: state cycle minus the average cycle
    ROUND(years_to_inspect - (SELECT AVG(years_to_inspect) FROM safety_clean), 2) AS years_diff_from_avg,
    -- Inspection-Fatality Risk Index: years to inspect * fatality rate
    ROUND(years_to_inspect * fatality_rate, 2)                                    AS inspection_fatality_risk_index,
    -- High Risk / Long Cycle Flag: above-average rate AND above-average cycle
    CASE
        WHEN fatality_rate   > (SELECT AVG(fatality_rate)   FROM safety_clean)
         AND years_to_inspect > (SELECT AVG(years_to_inspect) FROM safety_clean)
        THEN 'High Risk / Long Cycle'
        ELSE 'Other'
    END                                                                          AS high_risk_long_cycle_flag
FROM safety_clean;

-- Step 8: Checked the engineered columns
SELECT State_Name, injuries_per_inspector, inspection_fatality_risk_index, high_risk_long_cycle_flag
FROM safety_enriched
ORDER BY inspection_fatality_risk_index DESC
LIMIT 10;

-- =====================================================================
-- REQUIRED QUESTIONS
-- =====================================================================

-- Step 9: Q1 average fatality rate by program type, averaged because it is a rate
SELECT program_type,
       ROUND(AVG(fatality_rate), 2) AS avg_fatality_rate,
       COUNT(fatality_rate)         AS states_with_data
FROM safety_enriched
GROUP BY program_type
ORDER BY avg_fatality_rate DESC;

-- Step 10: Q2 State-program state with the most injuries/illnesses
SELECT State_Name,
       SUM(injuries_illnesses) AS total_injuries_illnesses
FROM safety_enriched
WHERE program_type = 'State'
  AND injuries_illnesses IS NOT NULL
GROUP BY State_Name
ORDER BY total_injuries_illnesses DESC;

-- Step 11: Q3 inspection cycle length vs fatality rate, paired per state for the scatter plot
SELECT State_Name,
       years_to_inspect,
       fatality_rate
FROM safety_enriched
WHERE years_to_inspect IS NOT NULL
  AND fatality_rate IS NOT NULL
ORDER BY years_to_inspect DESC;

-- =====================================================================
-- EXTRA QUESTIONS
-- =====================================================================

-- Step 12: Q4 states with the highest average penalties
SELECT State_Name,
       program_type,
       ROUND(AVG(avg_penalty), 2) AS avg_penalty
FROM safety_enriched
WHERE avg_penalty IS NOT NULL
GROUP BY State_Name, program_type
ORDER BY avg_penalty DESC;

-- Step 13: Q5 inspectors by program type
SELECT program_type,
       ROUND(AVG(inspectors), 1) AS avg_inspectors,
       SUM(inspectors)           AS total_inspectors,
       COUNT(inspectors)         AS states_with_data
FROM safety_enriched
GROUP BY program_type
ORDER BY avg_inspectors DESC;

-- =====================================================================
-- SUPPORTING ANALYSIS
-- =====================================================================

-- Step 14: Inspector workload, highest injuries per inspector first
SELECT State_Name,
       program_type,
       injuries_illnesses,
       inspectors,
       injuries_per_inspector
FROM safety_enriched
WHERE injuries_per_inspector IS NOT NULL
ORDER BY injuries_per_inspector DESC;

-- Step 15: States flagged both high risk and long inspection cycle
SELECT State_Name,
       program_type,
       fatality_rate,
       years_to_inspect,
       inspection_fatality_risk_index
FROM safety_enriched
WHERE high_risk_long_cycle_flag = 'High Risk / Long Cycle'
ORDER BY inspection_fatality_risk_index DESC;

-- Step 16: Fatality rate distribution by band, the histogram view
SELECT CASE
           WHEN fatality_rate < 2  THEN '0.0 - 1.9'
           WHEN fatality_rate < 4  THEN '2.0 - 3.9'
           WHEN fatality_rate < 6  THEN '4.0 - 5.9'
           WHEN fatality_rate < 8  THEN '6.0 - 7.9'
           ELSE '8.0+'
       END        AS fatality_rate_band,
       COUNT(*)   AS state_count
FROM safety_enriched
WHERE fatality_rate IS NOT NULL
GROUP BY fatality_rate_band
ORDER BY fatality_rate_band;
