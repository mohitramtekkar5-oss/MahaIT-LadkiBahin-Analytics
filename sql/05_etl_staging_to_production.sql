/* ============================================================
   MUKHYAMANTRI MAJHI LADKI BAHIN YOJANA — DATA ANALYTICS
   Phase 1 | Script 05: ETL — Staging → Production Tables
   ============================================================
   Reads from raw.* staging tables, casts all data types,
   applies business-rule transformations, and inserts into
   the clean dbo.* production tables.

   Load order (respects FK constraints):
     1. dbo.dim_budget           (no dependencies)
     2. dbo.dim_district         (no dependencies)
     3. dbo.dim_installment      (→ dim_budget)
     4. dbo.fact_beneficiaries   (→ dim_district)
   ============================================================ */

USE LadkiBahinDB;
GO

-- ═══════════════════════════════════════════════════════════
-- STEP 1: Load dbo.dim_budget
-- ═══════════════════════════════════════════════════════════
PRINT '>> [1/4] Loading dbo.dim_budget...';

INSERT INTO dbo.dim_budget (
    Fiscal_Year, Budget_Allocated_Cr_Rs, Actual_Spent_Cr_Rs,
    Utilisation_Pct, Avg_Active_Beneficiaries_Cr,
    Months_Operational, Installments_Released, Key_Events
)
SELECT
    CAST(Fiscal_Year              AS CHAR(7)),
    CAST(Budget_Allocated_Cr_Rs   AS INT),
    CASE WHEN Actual_Spent_Cr_Rs  = '' OR Actual_Spent_Cr_Rs IS NULL
         THEN NULL
         ELSE CAST(Actual_Spent_Cr_Rs AS INT) END,
    CASE WHEN Utilisation_Pct     = '' OR Utilisation_Pct IS NULL
         THEN NULL
         ELSE CAST(Utilisation_Pct AS DECIMAL(5,1)) END,
    CAST(Avg_Active_Beneficiaries_Cr AS DECIMAL(4,2)),
    CAST(Months_Operational          AS TINYINT),
    Installments_Released,
    Key_Events
FROM raw.budget_allocation;

PRINT '   Rows inserted: ' + CAST(@@ROWCOUNT AS VARCHAR);

-- ═══════════════════════════════════════════════════════════
-- STEP 2: Load dbo.dim_district
-- ═══════════════════════════════════════════════════════════
PRINT '>> [2/4] Loading dbo.dim_district...';

INSERT INTO dbo.dim_district (
    District, Division, Approx_Urban_Pct, Fraud_Risk_Score,
    Synthetic_Total_Applications, Synthetic_Active,
    Synthetic_Suspended_Ineligible, Synthetic_Suspended_Pending,
    Synthetic_Pending_Approval, Synthetic_Male_Fraud_Cases,
    Synthetic_Govt_Emp_Cases, Synthetic_Dual_Scheme,
    Synthetic_Total_Disbursed_Rs, Estimated_Real_Beneficiaries
)
SELECT
    District,
    Division,
    -- Remove '%' suffix and cast to TINYINT
    CAST(REPLACE(Approx_Urban_Pct, '%', '') AS TINYINT),
    CAST(Fraud_Risk_Score                  AS DECIMAL(3,1)),
    CAST(Synthetic_Total_Applications      AS INT),
    CAST(Synthetic_Active                  AS INT),
    CAST(Synthetic_Suspended_Ineligible    AS INT),
    CAST(Synthetic_Suspended_Pending       AS INT),
    CAST(Synthetic_Pending_Approval        AS INT),
    CAST(Synthetic_Male_Fraud_Cases        AS SMALLINT),
    CAST(Synthetic_Govt_Emp_Cases          AS SMALLINT),
    CAST(Synthetic_Dual_Scheme             AS INT),
    CAST(Synthetic_Total_Disbursed_Rs      AS BIGINT),
    Estimated_Real_Beneficiaries
FROM raw.district_summary;

PRINT '   Rows inserted: ' + CAST(@@ROWCOUNT AS VARCHAR);

-- ═══════════════════════════════════════════════════════════
-- STEP 3: Load dbo.dim_installment
-- Fiscal_Year derived from Credit_Date
-- ═══════════════════════════════════════════════════════════
PRINT '>> [3/4] Loading dbo.dim_installment...';

INSERT INTO dbo.dim_installment (
    Installment_No, Credit_Date, Period_Covered,
    Amount_Per_Beneficiary_Rs, Beneficiaries_Paid,
    Total_Disbursed_Cr_Rs, Cumulative_Disbursed_Cr_Rs,
    Notes, Fiscal_Year
)
SELECT
    CAST(Installment_No             AS TINYINT),
    CAST(Credit_Date                AS DATE),
    Period_Covered,
    CAST(Amount_Per_Beneficiary_Rs  AS SMALLINT),
    CAST(Beneficiaries_Paid         AS INT),
    CAST(Total_Disbursed_Cr_Rs      AS DECIMAL(8,2)),
    CAST(Cumulative_Disbursed_Cr_Rs AS DECIMAL(10,2)),
    Notes,
    -- Fiscal year: Apr–Mar cycle
    -- Credit dates Apr 2024–Mar 2025 → '2024-25'
    -- Credit dates Apr 2025–Mar 2026 → '2025-26'
    CASE
        WHEN MONTH(CAST(Credit_Date AS DATE)) >= 4
             THEN CAST(YEAR(CAST(Credit_Date AS DATE)) AS CHAR(4))
                  + '-'
                  + RIGHT(CAST(YEAR(CAST(Credit_Date AS DATE)) + 1 AS CHAR(4)), 2)
        ELSE CAST(YEAR(CAST(Credit_Date AS DATE)) - 1 AS CHAR(4))
             + '-'
             + RIGHT(CAST(YEAR(CAST(Credit_Date AS DATE)) AS CHAR(4)), 2)
    END AS Fiscal_Year
FROM raw.installment_schedule;

PRINT '   Rows inserted: ' + CAST(@@ROWCOUNT AS VARCHAR);

-- ═══════════════════════════════════════════════════════════
-- STEP 4: Load dbo.fact_beneficiaries (main ETL — 500K rows)
-- This is the most complex step. It:
--   - Casts all columns to correct data types
--   - Handles NULL vs empty string for optional fields
--   - Maps First_Payment_Date (may be empty string)
--   - Validates FK to dim_district
-- ═══════════════════════════════════════════════════════════
PRINT '>> [4/4] Loading dbo.fact_beneficiaries (500,000 rows — may take 30-60 sec)...';

INSERT INTO dbo.fact_beneficiaries (
    Beneficiary_ID, Application_ID, Application_Date, Application_Mode,
    District, Division, Area_Type, Taluka_Ward_Anganwadi,
    Declared_Gender, Age_at_Application, Birth_Year_Approx,
    Marital_Status, Caste_Category,
    Annual_Family_Income_Rs, Ration_Card_Type,
    Family_Member_Govt_Employee, Income_Tax_Payer_in_Family,
    Also_on_Namo_Shetkari_Scheme,
    Domicile_Proof_Type, Income_Proof_Submitted,
    Hamipatra_Declaration_Submitted,
    Aadhaar_Number_Masked, Bank_Name, Bank_Account_Masked,
    IFSC_Code, Aadhaar_Bank_Linked_NPCI, eKYC_Status,
    Application_Status, Suspension_Rejection_Reason, Fraud_Type_Detected,
    Monthly_Benefit_Rs, Installments_Received, Total_Amount_Received_Rs,
    DBT_Transfer_Status, First_Payment_Date,
    Grievance_Filed, Grievance_Type
)
SELECT
    -- A: Identification
    RTRIM(LTRIM(Beneficiary_ID)),
    RTRIM(LTRIM(Application_ID)),
    CAST(Application_Date    AS DATE),
    RTRIM(LTRIM(Application_Mode)),

    -- B: Location
    RTRIM(LTRIM(District)),
    RTRIM(LTRIM(Division)),
    RTRIM(LTRIM(Area_Type)),
    RTRIM(LTRIM(Taluka_Ward_Anganwadi)),

    -- C: Personal
    RTRIM(LTRIM(Declared_Gender)),
    CAST(Age_at_Application  AS TINYINT),
    CAST(Birth_Year_Approx   AS SMALLINT),
    RTRIM(LTRIM(Marital_Status)),
    RTRIM(LTRIM(Caste_Category)),

    -- D: Economic
    CAST(Annual_Family_Income_Rs         AS INT),
    RTRIM(LTRIM(Ration_Card_Type)),
    RTRIM(LTRIM(Family_Member_Govt_Employee)),
    RTRIM(LTRIM(Income_Tax_Payer_in_Family)),
    RTRIM(LTRIM(Also_on_Namo_Shetkari_Scheme)),

    -- E: Documents
    RTRIM(LTRIM(Domicile_Proof_Type)),
    RTRIM(LTRIM(Income_Proof_Submitted)),
    RTRIM(LTRIM(Hamipatra_Declaration_Submitted)),

    -- F: Aadhaar & Bank
    RTRIM(LTRIM(Aadhaar_Number_Masked)),
    RTRIM(LTRIM(Bank_Name)),
    RTRIM(LTRIM(Bank_Account_Masked)),
    RTRIM(LTRIM(IFSC_Code)),
    RTRIM(LTRIM(Aadhaar_Bank_Linked_NPCI)),
    RTRIM(LTRIM(eKYC_Status)),

    -- G: Status
    RTRIM(LTRIM(Application_Status)),
    NULLIF(RTRIM(LTRIM(Suspension_Rejection_Reason)), ''),
    ISNULL(NULLIF(RTRIM(LTRIM(Fraud_Type_Detected)), ''), 'None'),

    -- H: Payment
    CAST(Monthly_Benefit_Rs          AS SMALLINT),
    CAST(Installments_Received       AS TINYINT),
    CAST(Total_Amount_Received_Rs    AS INT),
    RTRIM(LTRIM(DBT_Transfer_Status)),
    -- First_Payment_Date: cast empty strings → NULL
    NULLIF(CAST(
        CASE WHEN RTRIM(LTRIM(First_Payment_Date)) = '' THEN NULL
             ELSE First_Payment_Date END
        AS DATE), CAST('1900-01-01' AS DATE)),

    -- I: Grievance
    ISNULL(NULLIF(RTRIM(LTRIM(Grievance_Filed)), ''), 'No'),
    NULLIF(RTRIM(LTRIM(Grievance_Type)), '')

FROM raw.beneficiaries rb
-- Only load rows whose District exists in dim_district (FK safety)
WHERE EXISTS (
    SELECT 1 FROM dbo.dim_district dd
    WHERE dd.District = RTRIM(LTRIM(rb.District))
);

PRINT '   Rows inserted: ' + CAST(@@ROWCOUNT AS VARCHAR);

-- ═══════════════════════════════════════════════════════════
-- FINAL VALIDATION
-- ═══════════════════════════════════════════════════════════
PRINT '';
PRINT '========== PRODUCTION TABLE VALIDATION ==========';

SELECT
    'dbo.dim_budget'       AS [Table], COUNT(*) AS [Row_Count] FROM dbo.dim_budget
UNION ALL SELECT
    'dbo.dim_district',                COUNT(*)               FROM dbo.dim_district
UNION ALL SELECT
    'dbo.dim_installment',             COUNT(*)               FROM dbo.dim_installment
UNION ALL SELECT
    'dbo.fact_beneficiaries',          COUNT(*)               FROM dbo.fact_beneficiaries;

-- Status breakdown sanity check
PRINT '';
PRINT '--- fact_beneficiaries: Status Distribution ---';
SELECT
    Application_Status,
    COUNT(*)                                     AS Row_Count,
    CAST(COUNT(*) * 100.0 / 500000 AS DECIMAL(5,1)) AS Pct_of_Total
FROM dbo.fact_beneficiaries
GROUP BY Application_Status
ORDER BY Row_Count DESC;

-- Fraud check
PRINT '';
PRINT '--- fact_beneficiaries: Fraud Type Breakdown ---';
SELECT
    Fraud_Type_Detected,
    COUNT(*) AS Row_Count,
    SUM(Total_Amount_Received_Rs) AS Total_Rs_Disbursed
FROM dbo.fact_beneficiaries
WHERE Fraud_Type_Detected != 'None'
GROUP BY Fraud_Type_Detected;

PRINT '';
PRINT '========================================================';
PRINT '  ETL complete. All 4 production tables populated.';
PRINT '  Next: Run 06_views.sql to create reporting views.';
PRINT '========================================================';
GO
