/* ============================================================
   MUKHYAMANTRI MAJHI LADKI BAHIN YOJANA — DATA ANALYTICS
   Phase 1 | Script 08: Verification & Orientation Queries
   ============================================================
   Run these after all scripts are complete to verify the
   database is set up correctly and explore the data.
   These are also great demo queries for an interview!
   ============================================================ */

USE LadkiBahinDB;
GO

PRINT '========================================================';
PRINT '  LADKI BAHIN DB — ORIENTATION QUERIES';
PRINT '========================================================';
PRINT '';

-- ── Q1: Database overview ────────────────────────────────────
PRINT '-- Q1: Object inventory --';

SELECT
    s.name                          AS [Schema],
    o.name                          AS [Object_Name],
    o.type_desc                     AS [Object_Type],
    SUM(p.rows)                     AS [Row_Count]
FROM sys.objects o
JOIN sys.schemas s   ON o.schema_id = s.schema_id
LEFT JOIN sys.partitions p ON o.object_id = p.object_id AND p.index_id <= 1
WHERE o.type IN ('U', 'V')          -- Tables and Views only
  AND s.name IN ('raw', 'dbo', 'rpt', 'audit')
GROUP BY s.name, o.name, o.type_desc
ORDER BY s.name, o.type_desc DESC, o.name;
GO

-- ── Q2: First look at the data ───────────────────────────────
PRINT '-- Q2: Sample rows from fact_beneficiaries --';

SELECT TOP 5
    Beneficiary_ID,
    Application_Date,
    District,
    Caste_Category,
    Annual_Family_Income_Rs,
    Application_Status,
    Monthly_Benefit_Rs,
    Installments_Received,
    Total_Amount_Received_Rs,
    eKYC_Status
FROM dbo.fact_beneficiaries
ORDER BY Record_ID;
GO

-- ── Q3: Status distribution with percentages ─────────────────
PRINT '-- Q3: Beneficiary status breakdown --';

SELECT * FROM rpt.v_status_breakdown
ORDER BY Beneficiary_Count DESC;
GO

-- ── Q4: Top 5 districts by total disbursement ────────────────
PRINT '-- Q4: Top 5 districts — total amount disbursed --';

SELECT TOP 5
    District,
    Division,
    Active_Beneficiaries,
    Active_Rate_Pct,
    CAST(Total_Disbursed_Rs / 10000000.0 AS DECIMAL(8,2)) AS Disbursed_Cr_Rs,
    Suspension_Rate_Pct,
    Total_Fraud_Cases
FROM rpt.v_district_kpis
ORDER BY Total_Disbursed_Rs DESC;
GO

-- ── Q5: Installment disbursement timeline ────────────────────
PRINT '-- Q5: 17-installment disbursement tracker --';

SELECT
    Installment_No,
    Month_Label,
    Fiscal_Year,
    Amount_Per_Beneficiary_Rs,
    Beneficiaries_Paid / 100000.0   AS Beneficiaries_Paid_Lakh,
    Total_Disbursed_Cr_Rs,
    Cumulative_Disbursed_Cr_Rs,
    Beneficiary_Change_MoM
FROM rpt.v_installment_tracker
ORDER BY Installment_No;
GO

-- ── Q6: Star schema — confirm FK join works ──────────────────
PRINT '-- Q6: Star schema join: fact → dim_district --';

SELECT
    f.Beneficiary_ID,
    f.District,
    d.Division,
    d.Approx_Urban_Pct,
    d.Fraud_Risk_Score,
    d.Estimated_Real_Beneficiaries,
    f.Application_Status,
    f.Total_Amount_Received_Rs
FROM dbo.fact_beneficiaries f
INNER JOIN dbo.dim_district d ON f.District = d.District
WHERE f.Fraud_Type_Detected != 'None'
ORDER BY f.Total_Amount_Received_Rs DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;
GO

-- ── Q7: Data quality audit results ───────────────────────────
PRINT '-- Q7: Data quality check summary --';

SELECT
    Check_ID,
    Check_Name,
    Expected_Value,
    Actual_Value,
    Status
FROM audit.dq_results
ORDER BY Check_ID;
GO

-- ── Q8: Budget utilisation summary ───────────────────────────
PRINT '-- Q8: Budget allocation vs. actual spend --';

SELECT
    Fiscal_Year,
    Budget_Allocated_Cr_Rs,
    Actual_Spent_Cr_Rs,
    Utilisation_Pct,
    Cost_Per_Beneficiary_Per_Year_Rs,
    Budget_Change_Cr_YoY
FROM rpt.v_budget_utilisation
ORDER BY Fiscal_Year;
GO

PRINT '';
PRINT '========================================================';
PRINT '  Phase 1 Complete! Your database is ready for:';
PRINT '  → Phase 2: Data Cleaning (deep SQL queries)';
PRINT '  → Phase 3: Python EDA (connect via pyodbc)';
PRINT '  → Phase 5: Power BI (connect to rpt.* views)';
PRINT '';
PRINT '  Power BI connection string:';
PRINT '  Server: localhost (or .\SQLEXPRESS)';
PRINT '  Database: LadkiBahinDB';
PRINT '  Import these views: rpt.v_district_kpis,';
PRINT '    rpt.v_beneficiary_summary, rpt.v_installment_tracker,';
PRINT '    rpt.v_fraud_analysis, rpt.v_budget_utilisation';
PRINT '========================================================';
GO
