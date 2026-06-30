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
-- cleaned column names match the Power BI model so the two line up.
-- =====================================================================

-- Step 1: Checked the raw State column, name and coordinates are in one cell
SELECT State
FROM workplace_safety
LIMIT 10;

-- Step 2: Baseline row count before cleaning. File has extra non-state rows
SELECT COUNT(*) AS "Rows Before Cleaning"
FROM workplace_safety;

-- Step 3: Counted blanks in the key columns so averages reflect known gaps
SELECT COUNT(*)                                                                          AS "Total Rows",
       SUM(CASE WHEN TRIM("Rate of Fatalities, 2012") = '' THEN 1 ELSE 0 END)            AS "Blank Fatality Rate",
       SUM(CASE WHEN TRIM("Number of Injuries/Illnesses 2012") = '' THEN 1 ELSE 0 END)   AS "Blank Injuries",
       SUM(CASE WHEN TRIM("Inspectors") = '' THEN 1 ELSE 0 END)                          AS "Blank Inspectors",
       SUM(CASE WHEN TRIM("Years to Inspect Each Workplace Once") = '' THEN 1 ELSE 0 END) AS "Blank Inspection Cycle"
FROM workplace_safety;

-- Step 4: Created clean copy, splitting state name from coordinates, converting blanks to NULL, casting numbers, and keeping only the 50 State/Federal rows. Column names match the Power BI fields.
DROP TABLE IF EXISTS safety_clean;

CREATE TABLE safety_clean AS
SELECT
    TRIM(SUBSTR(State, 1, INSTR(State, CHAR(10)) - 1))                                                   AS "State",
    "State or Federal Program"                                                                           AS "Program Type",
    CAST(NULLIF(TRIM("Rate of Fatalities, 2012"), '') AS REAL)                                           AS "Fatality Rate",
    CAST(NULLIF(TRIM("Number of Fatalities, 2012"), '') AS REAL)                                         AS "Fatalities",
    CAST(NULLIF(TRIM("Number of Injuries/Illnesses 2012"), '') AS REAL)                                  AS "Injuries and Illnesses",
    CAST(NULLIF(TRIM("State Rank, Fatalities 2012"), '') AS REAL)                                         AS "Fatality Rank",
    CAST(NULLIF(TRIM("Penalties FY 2013 (Average $)"), '') AS REAL)                                       AS "Average Penalty",
    CAST(NULLIF(TRIM("Penalties FY 2013 (Rank)"), '') AS REAL)                                            AS "Penalty Rank",
    CAST(NULLIF(TRIM("Inspectors"), '') AS REAL)                                                          AS "Inspectors",
    CAST(NULLIF(TRIM("Years to Inspect Each Workplace Once"), '') AS REAL)                                AS "Inspection Cycle Years"
FROM workplace_safety
WHERE "State or Federal Program" IN ('State', 'Federal');

-- Step 5: Confirmed clean copy holds only the 50 states
SELECT COUNT(*) AS "Rows After Cleaning"
FROM safety_clean;

-- Step 6: Spot-checked the clean copy
SELECT "State", "Program Type", "Fatality Rate", "Injuries and Illnesses", "Inspectors"
FROM safety_clean
LIMIT 10;

-- =====================================================================
-- ENGINEERED COLUMNS (the same calculated fields built in Excel and Power BI)
-- =====================================================================

-- Step 7: Engineered columns matching the Excel and Power BI fields: injuries per inspector, coverage score, fatalities per 100k, fatality rate and inspection cycle differences from average, the risk index, and the high-risk flag
DROP TABLE IF EXISTS safety_enriched;

CREATE TABLE safety_enriched AS
SELECT
    "State",
    "Program Type",
    "Fatality Rate",
    "Fatalities",
    "Injuries and Illnesses",
    "Inspectors",
    "Inspection Cycle Years",
    "Average Penalty",
    ROUND("Injuries and Illnesses" / NULLIF("Inspectors", 0), 2)                                  AS "Injuries per Inspector",
    ROUND(1.0 / NULLIF("Inspection Cycle Years", 0), 4)                                           AS "Inspection Coverage Score",
    ROUND("Fatalities" / NULLIF("Injuries and Illnesses", 0) * 100000, 2)                         AS "Fatalities per 100,000 Injuries/Illnesses",
    ROUND("Fatality Rate" - (SELECT AVG("Fatality Rate") FROM safety_clean), 2)                   AS "Fatality Rate Difference from Average",
    ROUND("Inspection Cycle Years" - (SELECT AVG("Inspection Cycle Years") FROM safety_clean), 2) AS "Inspection Cycle Difference from Average",
    ROUND("Inspection Cycle Years" * "Fatality Rate", 2)                                          AS "Inspection-Fatality Risk Index",
    CASE
        WHEN "Fatality Rate"          > (SELECT AVG("Fatality Rate")          FROM safety_clean)
         AND "Inspection Cycle Years" > (SELECT AVG("Inspection Cycle Years") FROM safety_clean)
        THEN 'High Risk / Long Cycle'
        ELSE 'Other'
    END                                                                                          AS "High Risk / Long Cycle Flag"
FROM safety_clean;

-- Step 8: Checked the engineered columns
SELECT "State", "Injuries per Inspector", "Inspection-Fatality Risk Index", "High Risk / Long Cycle Flag"
FROM safety_enriched
ORDER BY "Inspection-Fatality Risk Index" DESC
LIMIT 10;

-- =====================================================================
-- REQUIRED QUESTIONS
-- =====================================================================

-- Step 9: Q1 average fatality rate by program type, averaged because it is a rate
SELECT "Program Type",
       ROUND(AVG("Fatality Rate"), 2) AS "Avg Fatality Rate",
       COUNT("Fatality Rate")         AS "States With Data"
FROM safety_enriched
GROUP BY "Program Type"
ORDER BY "Avg Fatality Rate" DESC;

-- Step 10: Q2 State-program state with the most injuries/illnesses
SELECT "State",
       SUM("Injuries and Illnesses") AS "Total Injuries and Illnesses"
FROM safety_enriched
WHERE "Program Type" = 'State'
  AND "Injuries and Illnesses" IS NOT NULL
GROUP BY "State"
ORDER BY "Total Injuries and Illnesses" DESC;

-- Step 11: Q3 inspection cycle length vs fatality rate, paired per state for the scatter plot
SELECT "State",
       "Inspection Cycle Years",
       "Fatality Rate"
FROM safety_enriched
WHERE "Inspection Cycle Years" IS NOT NULL
  AND "Fatality Rate" IS NOT NULL
ORDER BY "Inspection Cycle Years" DESC;

-- =====================================================================
-- EXTRA QUESTIONS
-- =====================================================================

-- Step 12: Q4 states with the highest average penalties
SELECT "State",
       "Program Type",
       ROUND(AVG("Average Penalty"), 2) AS "Average Penalty"
FROM safety_enriched
WHERE "Average Penalty" IS NOT NULL
GROUP BY "State", "Program Type"
ORDER BY "Average Penalty" DESC;

-- Step 13: Q5 inspectors by program type
SELECT "Program Type",
       ROUND(AVG("Inspectors"), 1) AS "Avg Inspectors",
       SUM("Inspectors")           AS "Total Inspectors",
       COUNT("Inspectors")         AS "States With Data"
FROM safety_enriched
GROUP BY "Program Type"
ORDER BY "Avg Inspectors" DESC;

-- =====================================================================
-- SUPPORTING ANALYSIS
-- =====================================================================

-- Step 14: Inspector workload, highest injuries per inspector first
SELECT "State",
       "Program Type",
       "Injuries and Illnesses",
       "Inspectors",
       "Injuries per Inspector"
FROM safety_enriched
WHERE "Injuries per Inspector" IS NOT NULL
ORDER BY "Injuries per Inspector" DESC;

-- Step 15: States flagged both high risk and long inspection cycle
SELECT "State",
       "Program Type",
       "Fatality Rate",
       "Inspection Cycle Years",
       "Inspection-Fatality Risk Index"
FROM safety_enriched
WHERE "High Risk / Long Cycle Flag" = 'High Risk / Long Cycle'
ORDER BY "Inspection-Fatality Risk Index" DESC;

-- Step 16: Fatality rate distribution by band, the histogram view
SELECT CASE
           WHEN "Fatality Rate" < 2  THEN '0.0 - 1.9'
           WHEN "Fatality Rate" < 4  THEN '2.0 - 3.9'
           WHEN "Fatality Rate" < 6  THEN '4.0 - 5.9'
           WHEN "Fatality Rate" < 8  THEN '6.0 - 7.9'
           ELSE '8.0+'
       END          AS "Fatality Rate Band",
       COUNT(*)     AS "State Count"
FROM safety_enriched
WHERE "Fatality Rate" IS NOT NULL
GROUP BY "Fatality Rate Band"
ORDER BY "Fatality Rate Band";
