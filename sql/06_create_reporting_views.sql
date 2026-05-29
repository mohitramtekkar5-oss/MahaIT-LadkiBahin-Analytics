/* ============================================================
   MUKHYAMANTRI MAJHI LADKI BAHIN YOJANA — DATA ANALYTICS
   Phase 1 | Script 06: Reporting Views (rpt schema)
   ============================================================
   Creates 8 pre-built views in the rpt schema.
   Power BI will connect to these views directly.
   SSMS queries can also SELECT from these for quick analysis.

   Views created:
     rpt.v_beneficiary_summary      — full enriched fact (main)
     rpt.v_district_kpis            — per-district KPI table
     rpt.v_status_breakdown         — status counts + pcts
     rpt.v_fraud_analysis           — fraud cases detail
     rpt.v_installment_tracker      — 17-month disbursement
     rpt.v_ekyc_dbt_health          — eKYC & DBT pipeline health
     rpt.v_caste_income_profile     — beneficiary demographics
     rpt.v_budget_utilisation       — FY-wise budget vs spend
   ============================================================ */

USE LadkiBahinDB;
GO

-- ────────────────────────────────────────────────────────────
-- VIEW 1: rpt.v_beneficiary_summary
-- The main analytical view — enriched fact with all dimensions
-- ────────────────────────────────────────────────────────────
CREATE OR ALTER VIEW rpt.v_beneficiary_summary AS
SELECT
    -- Identification
    f.Record_ID,
    f.Beneficiary_ID,
    f.Application_ID,
    f.Application_Date,
    YEAR(f.Application_Date)                           AS Application_Year,
    MONTH(f.Application_Date)                          AS Application_Month,
    DATENAME(MONTH, f.Application_Date)                AS Application_Month_Name,
    f.Application_Mode,

    -- Location
    f.District,
    f.Division,
    f.Area_Type,
    d.Approx_Urban_Pct,
    d.Fraud_Risk_Score,

    -- Personal
    f.Declared_Gender,
    f.Age_at_Application,
    CASE
        WHEN f.Age_at_Application BETWEEN 21 AND 30 THEN '21–30'
        WHEN f.Age_at_Application BETWEEN 31 AND 40 THEN '31–40'
        WHEN f.Age_at_Application BETWEEN 41 AND 50 THEN '41–50'
        WHEN f.Age_at_Application BETWEEN 51 AND 60 THEN '51–60'
        ELSE '61–65'
    END                                                AS Age_Group,
    f.Marital_Status,
    f.Caste_Category,

    -- Economic
    f.Annual_Family_Income_Rs,
    CASE
        WHEN f.Annual_Family_Income_Rs < 50000  THEN 'Below ₹50K'
        WHEN f.Annual_Family_Income_Rs < 100000 THEN '₹50K–1L'
        WHEN f.Annual_Family_Income_Rs < 150000 THEN '₹1L–1.5L'
        WHEN f.Annual_Family_Income_Rs < 200000 THEN '₹1.5L–2L'
        ELSE '₹2L–2.5L'
    END                                                AS Income_Band,
    f.Ration_Card_Type,
    f.Family_Member_Govt_Employee,
    f.Income_Tax_Payer_in_Family,
    f.Also_on_Namo_Shetkari_Scheme,

    -- Documents
    f.Domicile_Proof_Type,
    f.Hamipatra_Declaration_Submitted,

    -- Bank & Aadhaar
    f.Bank_Name,
    f.Aadhaar_Bank_Linked_NPCI,
    f.eKYC_Status,

    -- Scheme Status
    f.Application_Status,
    CASE
        WHEN f.Application_Status = 'Active'                           THEN 1
        ELSE 0
    END                                                AS Is_Active,
    CASE
        WHEN f.Application_Status LIKE 'Suspended%'                    THEN 1
        ELSE 0
    END                                                AS Is_Suspended,
    f.Suspension_Rejection_Reason,
    f.Fraud_Type_Detected,
    CASE
        WHEN f.Fraud_Type_Detected != 'None'                           THEN 1
        ELSE 0
    END                                                AS Is_Fraud,

    -- Payment
    f.Monthly_Benefit_Rs,
    f.Installments_Received,
    f.Total_Amount_Received_Rs,
    f.DBT_Transfer_Status,
    f.First_Payment_Date,

    -- Grievance
    f.Grievance_Filed,
    f.Grievance_Type,

    -- District dimension extras
    d.Estimated_Real_Beneficiaries

FROM dbo.fact_beneficiaries f
INNER JOIN dbo.dim_district  d ON f.District = d.District;
GO

PRINT '>> rpt.v_beneficiary_summary created.';

-- ────────────────────────────────────────────────────────────
-- VIEW 2: rpt.v_district_kpis
-- Aggregated KPIs per district — primary Power BI map source
-- ────────────────────────────────────────────────────────────
CREATE OR ALTER VIEW rpt.v_district_kpis AS
SELECT
    f.District,
    f.Division,
    d.Approx_Urban_Pct,
    d.Fraud_Risk_Score,
    d.Estimated_Real_Beneficiaries,

    COUNT(*)                                                AS Total_Applications,
    SUM(CASE WHEN f.Application_Status = 'Active'
             THEN 1 ELSE 0 END)                             AS Active_Beneficiaries,
    SUM(CASE WHEN f.Application_Status = 'Suspended – Ineligible'
             THEN 1 ELSE 0 END)                             AS Suspended_Ineligible,
    SUM(CASE WHEN f.Application_Status = 'Suspended – Pending Verification'
             THEN 1 ELSE 0 END)                             AS Suspended_Pending,
    SUM(CASE WHEN f.Application_Status = 'Pending Approval'
             THEN 1 ELSE 0 END)                             AS Pending_Approval,

    -- Rates
    CAST(
        SUM(CASE WHEN f.Application_Status = 'Active' THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100
    AS DECIMAL(5,1))                                        AS Active_Rate_Pct,

    CAST(
        SUM(CASE WHEN f.Application_Status LIKE 'Suspended%' THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100
    AS DECIMAL(5,1))                                        AS Suspension_Rate_Pct,

    -- Fraud
    SUM(CASE WHEN f.Fraud_Type_Detected != 'None'
             THEN 1 ELSE 0 END)                             AS Total_Fraud_Cases,
    SUM(CASE WHEN f.Fraud_Type_Detected = 'Male Registrant'
             THEN 1 ELSE 0 END)                             AS Male_Fraud_Cases,
    SUM(CASE WHEN f.Fraud_Type_Detected = 'Govt Employee in Family'
             THEN 1 ELSE 0 END)                             AS Govt_Emp_Fraud_Cases,

    -- Payments
    SUM(f.Total_Amount_Received_Rs)                         AS Total_Disbursed_Rs,
    AVG(CAST(f.Total_Amount_Received_Rs AS BIGINT))         AS Avg_Disbursed_Per_Beneficiary_Rs,
    AVG(CAST(f.Installments_Received AS FLOAT))             AS Avg_Installments_Received,

    -- eKYC health
    SUM(CASE WHEN f.eKYC_Status = 'Completed'
             THEN 1 ELSE 0 END)                             AS eKYC_Completed,
    CAST(
        SUM(CASE WHEN f.eKYC_Status = 'Completed' THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100
    AS DECIMAL(5,1))                                        AS eKYC_Completion_Rate_Pct,

    -- DBT health
    SUM(CASE WHEN f.DBT_Transfer_Status = 'Credited Successfully'
             THEN 1 ELSE 0 END)                             AS DBT_Success_Count,
    CAST(
        SUM(CASE WHEN f.DBT_Transfer_Status = 'Credited Successfully' THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100
    AS DECIMAL(5,1))                                        AS DBT_Success_Rate_Pct,

    -- Grievances
    SUM(CASE WHEN f.Grievance_Filed = 'Yes'
             THEN 1 ELSE 0 END)                             AS Grievances_Filed,
    CAST(
        SUM(CASE WHEN f.Grievance_Filed = 'Yes' THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100
    AS DECIMAL(5,1))                                        AS Grievance_Rate_Pct,

    -- Dual scheme
    SUM(CASE WHEN f.Also_on_Namo_Shetkari_Scheme = 'Yes'
             THEN 1 ELSE 0 END)                             AS Dual_Scheme_Count

FROM dbo.fact_beneficiaries f
INNER JOIN dbo.dim_district  d ON f.District = d.District
GROUP BY
    f.District, f.Division, d.Approx_Urban_Pct,
    d.Fraud_Risk_Score, d.Estimated_Real_Beneficiaries;
GO

PRINT '>> rpt.v_district_kpis created.';

-- ────────────────────────────────────────────────────────────
-- VIEW 3: rpt.v_status_breakdown
-- Overall status counts with percentages — KPI cards
-- ────────────────────────────────────────────────────────────
CREATE OR ALTER VIEW rpt.v_status_breakdown AS
SELECT
    Application_Status,
    COUNT(*)                                                AS Beneficiary_Count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()
         AS DECIMAL(5,2))                                   AS Pct_of_Total,
    SUM(Total_Amount_Received_Rs)                           AS Total_Disbursed_Rs,
    AVG(CAST(Installments_Received AS FLOAT))               AS Avg_Installments
FROM dbo.fact_beneficiaries
GROUP BY Application_Status;
GO

PRINT '>> rpt.v_status_breakdown created.';

-- ────────────────────────────────────────────────────────────
-- VIEW 4: rpt.v_fraud_analysis
-- All fraud and suspension cases with full context
-- ────────────────────────────────────────────────────────────
CREATE OR ALTER VIEW rpt.v_fraud_analysis AS
SELECT
    f.Beneficiary_ID,
    f.District,
    f.Division,
    f.Area_Type,
    f.Declared_Gender,
    f.Age_at_Application,
    f.Caste_Category,
    f.Application_Status,
    f.Fraud_Type_Detected,
    f.Suspension_Rejection_Reason,
    f.Application_Mode,
    f.Bank_Name,
    f.eKYC_Status,
    f.Aadhaar_Bank_Linked_NPCI,
    f.Installments_Received,
    f.Total_Amount_Received_Rs,
    f.Grievance_Filed,
    -- Flag: loss to govt exchequer
    CASE
        WHEN f.Fraud_Type_Detected != 'None' THEN f.Total_Amount_Received_Rs
        ELSE 0
    END                                                     AS Fraudulent_Amount_Rs,
    -- Category label for reporting
    CASE
        WHEN f.Fraud_Type_Detected  = 'Male Registrant'         THEN 'Gender Fraud'
        WHEN f.Fraud_Type_Detected  = 'Govt Employee in Family' THEN 'Income Ineligibility'
        WHEN f.Suspension_Rejection_Reason LIKE '%Duplicate%'   THEN 'Duplicate Registration'
        WHEN f.Suspension_Rejection_Reason LIKE '%eKYC%'        THEN 'eKYC Non-Compliance'
        WHEN f.Suspension_Rejection_Reason LIKE '%income%'      THEN 'Income Ineligibility'
        WHEN f.Suspension_Rejection_Reason LIKE '%domicile%'    THEN 'Domicile Issue'
        WHEN f.Suspension_Rejection_Reason LIKE '%pension%'     THEN 'Dual Benefit'
        ELSE 'Other / Pending'
    END                                                     AS Suspension_Category
FROM dbo.fact_beneficiaries f
WHERE f.Application_Status != 'Active'
   OR f.Fraud_Type_Detected != 'None';
GO

PRINT '>> rpt.v_fraud_analysis created.';

-- ────────────────────────────────────────────────────────────
-- VIEW 5: rpt.v_installment_tracker
-- 17-installment disbursement timeline for trend analysis
-- ────────────────────────────────────────────────────────────
CREATE OR ALTER VIEW rpt.v_installment_tracker AS
SELECT
    i.Installment_No,
    i.Credit_Date,
    DATENAME(MONTH, i.Credit_Date) + ' ' + CAST(YEAR(i.Credit_Date) AS VARCHAR) AS Month_Label,
    i.Period_Covered,
    i.Amount_Per_Beneficiary_Rs,
    i.Beneficiaries_Paid,
    i.Total_Disbursed_Cr_Rs,
    i.Cumulative_Disbursed_Cr_Rs,
    i.Notes,
    i.Fiscal_Year,
    b.Budget_Allocated_Cr_Rs,
    -- Running % of annual budget consumed
    CAST(i.Cumulative_Disbursed_Cr_Rs / b.Budget_Allocated_Cr_Rs * 100
         AS DECIMAL(5,1))                                   AS Cumulative_Budget_Used_Pct,
    -- Month-on-month change in beneficiaries
    i.Beneficiaries_Paid - LAG(i.Beneficiaries_Paid, 1)
        OVER (ORDER BY i.Installment_No)                    AS Beneficiary_Change_MoM,
    -- Month-on-month change in disbursement (Cr)
    i.Total_Disbursed_Cr_Rs - LAG(i.Total_Disbursed_Cr_Rs, 1)
        OVER (ORDER BY i.Installment_No)                    AS Disbursement_Change_Cr_MoM
FROM dbo.dim_installment i
INNER JOIN dbo.dim_budget b ON i.Fiscal_Year = b.Fiscal_Year;
GO

PRINT '>> rpt.v_installment_tracker created.';

-- ────────────────────────────────────────────────────────────
-- VIEW 6: rpt.v_ekyc_dbt_health
-- eKYC and DBT pipeline health by district and bank
-- ────────────────────────────────────────────────────────────
CREATE OR ALTER VIEW rpt.v_ekyc_dbt_health AS
SELECT
    f.District,
    f.Division,
    f.Area_Type,
    f.Bank_Name,
    f.eKYC_Status,
    f.Aadhaar_Bank_Linked_NPCI,
    f.DBT_Transfer_Status,
    COUNT(*)                                                AS Beneficiary_Count,
    SUM(CASE WHEN f.eKYC_Status = 'Completed'  THEN 1 ELSE 0 END) AS eKYC_OK,
    SUM(CASE WHEN f.eKYC_Status != 'Completed' THEN 1 ELSE 0 END) AS eKYC_Fail_Or_Pending,
    SUM(CASE WHEN f.Aadhaar_Bank_Linked_NPCI = 'Yes' THEN 1 ELSE 0 END) AS NPCI_Linked,
    SUM(CASE WHEN f.DBT_Transfer_Status = 'Credited Successfully' THEN 1 ELSE 0 END) AS DBT_Success,
    SUM(CASE WHEN f.DBT_Transfer_Status LIKE 'Failed%' THEN 1 ELSE 0 END) AS DBT_Failed,
    CAST(
        SUM(CASE WHEN f.DBT_Transfer_Status = 'Credited Successfully' THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100
    AS DECIMAL(5,1))                                        AS DBT_Success_Rate_Pct
FROM dbo.fact_beneficiaries f
GROUP BY
    f.District, f.Division, f.Area_Type,
    f.Bank_Name, f.eKYC_Status,
    f.Aadhaar_Bank_Linked_NPCI, f.DBT_Transfer_Status;
GO

PRINT '>> rpt.v_ekyc_dbt_health created.';

-- ────────────────────────────────────────────────────────────
-- VIEW 7: rpt.v_caste_income_profile
-- Beneficiary demographic profile for equity analysis
-- ────────────────────────────────────────────────────────────
CREATE OR ALTER VIEW rpt.v_caste_income_profile AS
SELECT
    f.Caste_Category,
    f.Marital_Status,
    f.Ration_Card_Type,
    f.Area_Type,
    f.Division,
    CASE
        WHEN f.Age_at_Application BETWEEN 21 AND 30 THEN '21–30'
        WHEN f.Age_at_Application BETWEEN 31 AND 40 THEN '31–40'
        WHEN f.Age_at_Application BETWEEN 41 AND 50 THEN '41–50'
        WHEN f.Age_at_Application BETWEEN 51 AND 60 THEN '51–60'
        ELSE '61–65'
    END                                                     AS Age_Group,
    CASE
        WHEN f.Annual_Family_Income_Rs < 50000  THEN 'Below ₹50K'
        WHEN f.Annual_Family_Income_Rs < 100000 THEN '₹50K–1L'
        WHEN f.Annual_Family_Income_Rs < 150000 THEN '₹1L–1.5L'
        WHEN f.Annual_Family_Income_Rs < 200000 THEN '₹1.5L–2L'
        ELSE '₹2L–2.5L'
    END                                                     AS Income_Band,
    COUNT(*)                                                AS Beneficiary_Count,
    SUM(CASE WHEN f.Application_Status = 'Active' THEN 1 ELSE 0 END) AS Active_Count,
    AVG(f.Annual_Family_Income_Rs)                          AS Avg_Annual_Income_Rs,
    SUM(f.Total_Amount_Received_Rs)                         AS Total_Disbursed_Rs,
    AVG(CAST(f.Installments_Received AS FLOAT))             AS Avg_Installments,
    SUM(CASE WHEN f.Grievance_Filed = 'Yes' THEN 1 ELSE 0 END) AS Grievances_Filed
FROM dbo.fact_beneficiaries f
GROUP BY
    f.Caste_Category, f.Marital_Status, f.Ration_Card_Type,
    f.Area_Type, f.Division,
    CASE
        WHEN f.Age_at_Application BETWEEN 21 AND 30 THEN '21–30'
        WHEN f.Age_at_Application BETWEEN 31 AND 40 THEN '31–40'
        WHEN f.Age_at_Application BETWEEN 41 AND 50 THEN '41–50'
        WHEN f.Age_at_Application BETWEEN 51 AND 60 THEN '51–60'
        ELSE '61–65'
    END,
    CASE
        WHEN f.Annual_Family_Income_Rs < 50000  THEN 'Below ₹50K'
        WHEN f.Annual_Family_Income_Rs < 100000 THEN '₹50K–1L'
        WHEN f.Annual_Family_Income_Rs < 150000 THEN '₹1L–1.5L'
        WHEN f.Annual_Family_Income_Rs < 200000 THEN '₹1.5L–2L'
        ELSE '₹2L–2.5L'
    END;
GO

PRINT '>> rpt.v_caste_income_profile created.';

-- ────────────────────────────────────────────────────────────
-- VIEW 8: rpt.v_budget_utilisation
-- FY-wise budget allocation vs. spend — executive summary
-- ────────────────────────────────────────────────────────────
CREATE OR ALTER VIEW rpt.v_budget_utilisation AS
SELECT
    b.Fiscal_Year,
    b.Budget_Allocated_Cr_Rs,
    b.Actual_Spent_Cr_Rs,
    b.Utilisation_Pct,
    b.Avg_Active_Beneficiaries_Cr,
    b.Months_Operational,
    b.Installments_Released,
    b.Key_Events,
    -- Cost per active beneficiary per year (crore Rs / crore beneficiaries → Rs)
    CASE
        WHEN b.Actual_Spent_Cr_Rs IS NOT NULL AND b.Avg_Active_Beneficiaries_Cr > 0
        THEN CAST(b.Actual_Spent_Cr_Rs * 10000000.0
                  / (b.Avg_Active_Beneficiaries_Cr * 10000000)
                  AS DECIMAL(10,2))
        ELSE NULL
    END                                                     AS Cost_Per_Beneficiary_Per_Year_Rs,
    -- Budget change YoY
    b.Budget_Allocated_Cr_Rs
    - LAG(b.Budget_Allocated_Cr_Rs, 1) OVER (ORDER BY b.Fiscal_Year) AS Budget_Change_Cr_YoY,
    -- Beneficiary count from installment data
    (SELECT SUM(i.Beneficiaries_Paid)
     FROM dbo.dim_installment i
     WHERE i.Fiscal_Year = b.Fiscal_Year)                   AS Total_Beneficiary_Payments_In_FY
FROM dbo.dim_budget b;
GO

PRINT '>> rpt.v_budget_utilisation created.';
PRINT '';
PRINT '========================================================';
PRINT '  All 8 reporting views created in [rpt] schema.';
PRINT '  Next: Run 07_audit_and_quality.sql for DQ checks.';
PRINT '========================================================';
GO
