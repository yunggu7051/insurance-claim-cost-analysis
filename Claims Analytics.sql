-- DATABASE CREATION
CREATE DATABASE claims_DB;
USE claims_DB;

DROP TABLE IF EXISTS insurance_claims;

CREATE TABLE insurance_claims (
    ClaimID VARCHAR(50) PRIMARY KEY,
    PatientID VARCHAR(50),
    ProviderID VARCHAR(50),
    ClaimAmount DECIMAL(12,2),
    ClaimDate DATE,
    DiagnosisCode VARCHAR(20),
    ProcedureCode VARCHAR(20),
    PatientAge INT,
    PatientGender VARCHAR(10),
    ProviderSpecialty VARCHAR(100),
    ClaimStatus VARCHAR(20),
    PatientIncome DECIMAL(12,2),
    PatientMaritalStatus VARCHAR(20),
    PatientEmploymentStatus VARCHAR(30),
    ProviderLocation VARCHAR(100),
    ClaimType VARCHAR(30),
    ClaimSubmissionMethod VARCHAR(30)
);

-- Double Check

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN ClaimID IS NULL THEN 1 ELSE 0 END) AS missing_claimid,
    SUM(CASE WHEN ClaimAmount IS NULL THEN 1 ELSE 0 END) AS missing_claimamount,
    SUM(CASE WHEN ClaimDate IS NULL THEN 1 ELSE 0 END) AS missing_claimdate,
    SUM(CASE WHEN ClaimStatus IS NULL THEN 1 ELSE 0 END) AS missing_claimstatus,
    SUM(CASE WHEN ProviderSpecialty IS NULL THEN 1 ELSE 0 END) AS missing_specialty,
    SUM(CASE WHEN ClaimType IS NULL THEN 1 ELSE 0 END) AS missing_claimtype,
    SUM(CASE WHEN ClaimSubmissionMethod IS NULL THEN 1 ELSE 0 END) AS missing_submissionmethod
FROM insurance_claims;

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN ClaimAmount <= 0 THEN 1 ELSE 0 END) AS bad_amount,
    SUM(CASE WHEN PatientAge < 0 OR PatientAge > 120 THEN 1 ELSE 0 END) AS bad_age,
    SUM(CASE WHEN ClaimStatus NOT IN ('Approved', 'Denied', 'Pending') THEN 1 ELSE 0 END) AS bad_status,
    SUM(CASE WHEN ClaimDate > CURDATE() THEN 1 ELSE 0 END) AS future_dates
FROM insurance_claims;

SELECT * FROM insurance_claims;




-- 1. Overview

-- Looking at Approved, Denied, and Pending claims in 2022, 2023, and 2024. Measured how many claims were in each status and how much cost each status made up,
-- to build a starting view of the claims data before moving into deeper analysis.

-- Total number of claims and total claim amount for each claim status within each year

SELECT
    YEAR(claimDate) AS claim_year,
    claimStatus,
    COUNT(*) AS total_cases,
    SUM(claimAmount) AS total_cost
FROM insurance_claims
WHERE YEAR(claimDate) IN (2022, 2023, 2024)
GROUP BY YEAR(claimDate), claimStatus
ORDER BY claim_year, claimStatus;

-- Full total cost of each year

SELECT
    YEAR(claimDate) AS claim_year,
    COUNT(*) AS year_total_cases,
    SUM(claimAmount) AS year_total_cost
FROM insurance_claims
WHERE YEAR(claimDate) IN (2022, 2023, 2024)
GROUP BY YEAR(claimDate)
ORDER BY claim_year;

-- Then rate group over claimstaus per year 

WITH yearly_sum AS
( 
	SELECT
    YEAR(claimDate) AS claim_year,
    COUNT(*) AS year_total_cases,
    SUM(claimAmount) AS year_total_cost
FROM insurance_claims
WHERE YEAR(claimDate) IN (2022, 2023, 2024)
GROUP BY YEAR(claimDate)),

idv AS 
(SELECT
    YEAR(claimDate) AS claim_year,
    claimStatus,
    COUNT(*) AS total_cases,
    SUM(claimAmount) AS total_cost
FROM insurance_claims
WHERE YEAR(claimDate) IN (2022, 2023, 2024)
GROUP BY YEAR(claimDate), claimStatus)

SELECT
	i.claim_year,
    i.claimStatus,
    i.total_cases,
	y.year_total_cases,
    ROUND(i.total_cases * 100.0 / y.year_total_cases, 2) AS case_rate,
    i.total_cost,
    y.year_total_cost,
    ROUND(i.total_cost * 100.0 / y.year_total_cost, 2) AS cost_rate
FROM idv i
JOIN yearly_sum y
	ON i.claim_year = y.claim_year
ORDER BY
    i.claim_year,
    FIELD(i.claimStatus, 'Approved', 'Denied', 'Pending');

-- Findings:

-- Across 2022–2024, Approved, Denied, and Pending claims each made up a similar share of total cases and total cost. 
-- 2023 showed the highest claim activity and spending overall.



-- 2. Claim Cost Drivers - Provider 
-- Analyzed which provider contributed most to overall spending.
-- And how is that cost split across Approved, Denied, and Pending claims
-- Basic Logic: group cost / overall cost

-- Provider 's overall spending

With provider AS(
SELECT
	ProviderSpecialty,
	COUNT(*) AS total_cases,
	SUM(claimAmount) AS total_cost
FROM insurance_claims
GROUP BY ProviderSpecialty
),

overall AS(
SELECT
	SUM(claimAmount) AS overall_total_cost
    FROM insurance_claims
)

SELECT
    p.ProviderSpecialty,
    p.total_cases,
    p.total_cost,
    ROUND(p.total_cost * 100.0 / o.overall_total_cost, 2) AS cost_share
FROM provider p
CROSS JOIN overall o
ORDER BY p.total_cost DESC;

-- Finding:
-- Among provider specialties, Pediatrics had the highest total claim cost, accounting for 21.80% of overall spending
-- followed by Cardiology, Orthopedics, General Practice, and Neurology.


-- Then Within each provider specialty, break cost into Approved, Denied, and Pending

WITH provider_status AS (
SELECT
        ProviderSpecialty,
        claimStatus,
        COUNT(*) AS total_cases,
        SUM(claimAmount) AS total_cost
FROM insurance_claims
GROUP BY ProviderSpecialty, claimStatus
),

provider_total AS (
SELECT
        ProviderSpecialty,
        COUNT(*) AS specialty_total_cases,
        SUM(claimAmount) AS specialty_total_cost
FROM insurance_claims
GROUP BY ProviderSpecialty
)

SELECT
    ps.ProviderSpecialty,
    ps.claimStatus,
    ps.total_cases,
    pt.specialty_total_cases,
    ROUND(ps.total_cases * 100.0 / pt.specialty_total_cases, 2) AS case_rate,
    ps.total_cost,
    pt.specialty_total_cost,
    ROUND(ps.total_cost * 100.0 / pt.specialty_total_cost, 2) AS cost_rate
FROM provider_status ps
JOIN provider_total pt
    ON ps.ProviderSpecialty = pt.ProviderSpecialty
ORDER BY
    ps.ProviderSpecialty,
    FIELD(ps.claimStatus, 'Approved', 'Denied', 'Pending');
    
-- Finding:
-- The status mix was fairly balanced within each provider specialty, but some differences stood out. Orthopedics and Neurology had more approved cost,
-- while Pediatrics had the largest pending share.

-- Pediatrics generated the highest total claim cost overall, but Orthopedics had the highest approved claim cost. Pediatrics also had the largest pending cost share
-- meaning more of its claim dollars were still unresolved.


-- 3. Claim Cost Drivers - Patient Claimtype

WITH claim_type_summary AS (
    SELECT
        ClaimType,
        COUNT(*) AS total_cases,
        SUM(claimAmount) AS total_cost
    FROM insurance_claims
    GROUP BY ClaimType
),

overall_summary AS (
    SELECT
        SUM(claimAmount) AS overall_total_cost
    FROM insurance_claims
)

SELECT
    c.ClaimType,
    c.total_cases,
    ROUND(c.total_cost, 2) AS total_cost,
    ROUND(c.total_cost * 100.0 / o.overall_total_cost, 2) AS cost_share
FROM claim_type_summary c
CROSS JOIN overall_summary o
ORDER BY c.total_cost DESC;

-- Finding:
-- Claim costs were fairly evenly distributed across Outpatient, Routine, Inpatient, and Emergency claims, 
-- with Outpatient contributing the highest total cost share.
	
-- Then break cost into Approved, Denied, and Pending

WITH claim_type_status AS (
SELECT
        ClaimType,
        claimStatus,
        COUNT(*) AS total_cases,
        SUM(claimAmount) AS total_cost
FROM insurance_claims
GROUP BY ClaimType, claimStatus
),

claim_type_total AS (
SELECT
        ClaimType,
        COUNT(*) AS type_total_cases,
        SUM(claimAmount) AS type_total_cost
FROM insurance_claims
GROUP BY ClaimType
)

SELECT
    cts.ClaimType,
    cts.claimStatus,
    cts.total_cases,
    ctt.type_total_cases,
    ROUND(cts.total_cases * 100.0 / ctt.type_total_cases, 2) AS case_rate,
    ROUND(cts.total_cost, 2) AS total_cost,
    ROUND(ctt.type_total_cost, 2) AS type_total_cost,
    ROUND(cts.total_cost * 100.0 / ctt.type_total_cost, 2) AS cost_rate
FROM claim_type_status cts
JOIN claim_type_total ctt
    ON cts.ClaimType = ctt.ClaimType
ORDER BY
    cts.ClaimType,
    FIELD(cts.claimStatus, 'Approved', 'Denied', 'Pending');

-- Finding: 
-- Within claim types, costs were still fairly evenly distributed across Approved, Denied, and Pending claims, but Outpatient and Inpatient showed higher approved cost shares, 
-- while Routine showed a slightly higher denied share.


-- Summary:

-- Claim status distribution: 
-- From 2022–2024, Approved, Denied, and Pending claims were fairly evenly distributed in both total cases and total cost, 
-- with 2023 showing the highest overall claim activity and spending.

-- Provider specialty cost drivers: 
-- Pediatrics had the highest total claim cost among provider specialties, though overall spending remained relatively balanced.

-- Claim type cost drivers: 
-- Outpatient claims contributed the largest share of total claim cost, followed closely by Routine, Inpatient, and Emergency


