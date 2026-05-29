/* ============================================================
   MUKHYAMANTRI MAJHI LADKI BAHIN YOJANA — DATA ANALYTICS
   Phase 2 | Data Cleaning & Deep SQL Analysis
   ============================================================
   12 analytical queries across 6 topics:
     Topic 1: Suspension & Rejection Analysis     (Q1–Q2)
     Topic 2: District Coverage & Performance     (Q3–Q4)
     Topic 3: Fraud Detection Patterns            (Q5–Q6)
     Topic 4: DBT & eKYC Pipeline Health          (Q7–Q8)
     Topic 5: Disbursement Timeline Analysis      (Q9–Q10)
     Topic 6: Demographic & Equity Analysis       (Q11–Q12)

   Key Findings Summary:
     Q1  → eKYC failure is #1 suspension reason (16,487 cases)
     Q2  → Amravati Division has worst suspension rate
     Q3  → Akola has lowest district active rate
     Q4  → Konkan ranks #1, Amravati last on performance
     Q5  → Male registrants caused highest fraud loss in Rs
     Q6  → Gram Panchayat Office riskiest channel; Nari Shakti App safest
     Q7  → Punjab National Bank has worst DBT success rate
     Q8  → eKYC gap driven by application mode, not just area type
     Q9  → Feb 2025 had biggest beneficiary drop (gradual eKYC erosion)
     Q10 → October applicants received 1.06 fewer installments than July
     Q11 → ST women have lowest active rate — most underserved group
     Q12 → No critical marital/ration combination — gap is geographic
   ============================================================ */

USE LadkiBahinDB;
GO

-- ============================================================
-- TOPIC 1: SUSPENSION & REJECTION ANALYSIS
-- ============================================================

-- ── Q1: Suspension reason breakdown
-- What is getting people suspended?
-- ────────────────────────────────────────────────────────────
SELECT
    Suspension_Rejection_Reason                             AS Suspension_Reason,
    COUNT(*)                                                AS Affected_Beneficiaries,
    CAST(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER ()
    AS DECIMAL(5,2))                                        AS Pct_of_All_Suspended,
    SUM(CAST(Total_Amount_Received_Rs AS BIGINT))           AS Total_Rs_Already_Paid,
    AVG(CAST(Installments_Received AS FLOAT))               AS Avg_Installments_Before_Caught,
    AVG(CAST(Total_Amount_Received_Rs AS FLOAT))            AS Avg_Rs_Per_Person_Paid
FROM dbo.fact_beneficiaries
WHERE Application_Status IN (
    'Suspended due to Ineligibility',
    'Suspended due to Pending Verification'
)
GROUP BY Suspension_Rejection_Reason
ORDER BY Affected_Beneficiaries DESC;


-- ── Q2: Suspension rate by Division
-- Which division has the worst compliance?
-- ────────────────────────────────────────────────────────────
SELECT
    Division,
    COUNT(*)                                                AS Total_Applications,
    SUM(CASE WHEN Application_Status = 'Active'
             THEN 1 ELSE 0 END)                             AS Active,
    SUM(CASE WHEN Application_Status IN (
                  'Suspended due to Ineligibility',
                  'Suspended due to Pending Verification')
             THEN 1 ELSE 0 END)                             AS Total_Suspended,
    CAST(
        SUM(CASE WHEN Application_Status IN (
                      'Suspended due to Ineligibility',
                      'Suspended due to Pending Verification')
                 THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100
    AS DECIMAL(5,2))                                        AS Suspension_Rate_Pct,
    RANK() OVER (
        ORDER BY
            SUM(CASE WHEN Application_Status IN (
                          'Suspended due to Ineligibility',
                          'Suspended due to Pending Verification')
                     THEN 1.0 ELSE 0 END)
            / COUNT(*) DESC
    )                                                       AS Suspension_Rank
FROM dbo.fact_beneficiaries
GROUP BY Division
ORDER BY Suspension_Rate_Pct DESC;


-- ============================================================
-- TOPIC 2: DISTRICT COVERAGE & PERFORMANCE
-- ============================================================

-- ── Q3: Bottom 10 districts by Active Rate
-- Which districts are most underserving eligible women?
-- ────────────────────────────────────────────────────────────
SELECT
    District,
    Division,
    Approx_Urban_Pct                                        AS Urban_Pct,
    Total_Applications,
    Active_Beneficiaries,
    Active_Rate_Pct,
    Suspension_Rate_Pct,
    eKYC_Completion_Rate_Pct,
    DBT_Success_Rate_Pct,
    Total_Fraud_Cases,
    Estimated_Real_Beneficiaries,
    CAST(
        (Total_Applications - Active_Beneficiaries) * 100.0
        / Total_Applications
    AS DECIMAL(5,2))                                        AS Non_Active_Rate_Pct
FROM rpt.v_district_kpis
ORDER BY Active_Rate_Pct ASC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;


-- ── Q4: Division-level performance scorecard
-- Aggregated KPIs at division level for executive reporting
-- ────────────────────────────────────────────────────────────
SELECT
    Division,
    SUM(Total_Applications)                                 AS Total_Applications,
    SUM(Active_Beneficiaries)                               AS Active_Beneficiaries,
    CAST(
        SUM(Active_Beneficiaries) * 100.0
        / SUM(Total_Applications)
    AS DECIMAL(5,2))                                        AS Division_Active_Rate_Pct,
    CAST(
        SUM(Total_Fraud_Cases) * 100.0
        / SUM(Total_Applications)
    AS DECIMAL(5,2))                                        AS Division_Fraud_Rate_Pct,
    CAST(
        SUM(eKYC_Completed) * 100.0
        / SUM(Total_Applications)
    AS DECIMAL(5,2))                                        AS Division_eKYC_Rate_Pct,
    CAST(
        SUM(DBT_Success_Count) * 100.0
        / SUM(Total_Applications)
    AS DECIMAL(5,2))                                        AS Division_DBT_Rate_Pct,
    CAST(
        SUM(CAST(Total_Disbursed_Rs AS BIGINT)) / 10000000.0
    AS DECIMAL(10,2))                                       AS Total_Disbursed_Cr_Rs,
    CAST(
        SUM(Grievances_Filed) * 100.0
        / SUM(Total_Applications)
    AS DECIMAL(5,2))                                        AS Division_Grievance_Rate_Pct,
    RANK() OVER (
        ORDER BY
            SUM(Active_Beneficiaries) * 100.0
            / SUM(Total_Applications) DESC
    )                                                       AS Performance_Rank
FROM rpt.v_district_kpis
GROUP BY Division
ORDER BY Performance_Rank;


-- ============================================================
-- TOPIC 3: FRAUD DETECTION PATTERNS
-- ============================================================

-- ── Q5: Fraud profile analysis
-- Who are the fraudsters and what did it cost the exchequer?
-- ────────────────────────────────────────────────────────────
SELECT
    Fraud_Type_Detected,
    District,
    Division,
    Area_Type,
    Application_Mode,
    COUNT(*)                                                AS Fraud_Cases,
    SUM(CAST(Total_Amount_Received_Rs AS BIGINT))           AS Total_Loss_Rs,
    AVG(CAST(Total_Amount_Received_Rs AS FLOAT))            AS Avg_Loss_Per_Case_Rs,
    AVG(CAST(Installments_Received AS FLOAT))               AS Avg_Installments_Before_Detection,
    CAST(
        SUM(CAST(Total_Amount_Received_Rs AS BIGINT)) * 100.0
        / SUM(SUM(CAST(Total_Amount_Received_Rs AS BIGINT))) OVER ()
    AS DECIMAL(5,2))                                        AS Pct_of_Total_Fraud_Loss
FROM dbo.fact_beneficiaries
WHERE Fraud_Type_Detected != 'None'
GROUP BY
    Fraud_Type_Detected, District, Division,
    Area_Type, Application_Mode
ORDER BY Total_Loss_Rs DESC;


-- ── Q6: Fraud risk by application mode
-- Do certain registration channels have higher fraud rates?
-- ────────────────────────────────────────────────────────────
SELECT
    Application_Mode,
    COUNT(*)                                                AS Total_Applications,
    SUM(CASE WHEN Fraud_Type_Detected != 'None'
             THEN 1 ELSE 0 END)                             AS Fraud_Cases,
    SUM(CASE WHEN Application_Status IN (
                  'Suspended due to Ineligibility',
                  'Suspended due to Pending Verification')
             THEN 1 ELSE 0 END)                             AS Suspended_Cases,
    CAST(
        SUM(CASE WHEN Fraud_Type_Detected != 'None'
                 THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100
    AS DECIMAL(5,3))                                        AS Fraud_Rate_Pct,
    CAST(
        SUM(CASE WHEN Application_Status IN (
                      'Suspended due to Ineligibility',
                      'Suspended due to Pending Verification')
                 THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100
    AS DECIMAL(5,2))                                        AS Suspension_Rate_Pct,
    RANK() OVER (
        ORDER BY
            SUM(CASE WHEN Fraud_Type_Detected != 'None'
                     THEN 1.0 ELSE 0 END)
            / COUNT(*) DESC
    )                                                       AS Fraud_Risk_Rank,
    SUM(CAST(Total_Amount_Received_Rs AS BIGINT))           AS Total_Disbursed_Rs,
    CAST(
        SUM(CASE WHEN Fraud_Type_Detected != 'None'
                 THEN CAST(Total_Amount_Received_Rs AS BIGINT)
                 ELSE 0 END) * 100.0
        / NULLIF(SUM(CAST(Total_Amount_Received_Rs AS BIGINT)), 0)
    AS DECIMAL(5,3))                                        AS Fraud_Loss_As_Pct_Of_Disbursed
FROM dbo.fact_beneficiaries
GROUP BY Application_Mode
ORDER BY Fraud_Rate_Pct DESC;


-- ============================================================
-- TOPIC 4: DBT & eKYC PIPELINE HEALTH
-- ============================================================

-- ── Q7: Bank-wise DBT failure analysis
-- Which banks are failing to credit beneficiaries?
-- ────────────────────────────────────────────────────────────
SELECT
    Bank_Name,
    COUNT(*)                                                AS Total_Beneficiaries,
    SUM(CASE WHEN DBT_Transfer_Status = 'Credited Successfully'
             THEN 1 ELSE 0 END)                             AS DBT_Success,
    SUM(CASE WHEN DBT_Transfer_Status LIKE 'Failed%'
             THEN 1 ELSE 0 END)                             AS DBT_Failed,
    SUM(CASE WHEN Aadhaar_Bank_Linked_NPCI = 'No'
             THEN 1 ELSE 0 END)                             AS NPCI_Not_Seeded,
    CAST(
        SUM(CASE WHEN DBT_Transfer_Status = 'Credited Successfully'
                 THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100
    AS DECIMAL(5,2))                                        AS DBT_Success_Rate_Pct,
    CAST(
        SUM(CASE WHEN Aadhaar_Bank_Linked_NPCI = 'No'
                 THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100
    AS DECIMAL(5,2))                                        AS NPCI_Gap_Pct,
    SUM(CASE WHEN DBT_Transfer_Status LIKE 'Failed%'
             THEN Monthly_Benefit_Rs ELSE 0 END)            AS Monthly_Benefit_At_Risk_Rs,
    RANK() OVER (
        ORDER BY
            SUM(CASE WHEN DBT_Transfer_Status = 'Credited Successfully'
                     THEN 1.0 ELSE 0 END)
            / COUNT(*) ASC
    )                                                       AS Failure_Rank
FROM dbo.fact_beneficiaries
WHERE Application_Status = 'Active'
GROUP BY Bank_Name
ORDER BY DBT_Success_Rate_Pct ASC;


-- ── Q8: eKYC compliance — rural vs urban by division
-- Does area type determine eKYC success?
-- ────────────────────────────────────────────────────────────
SELECT
    Division,
    Area_Type,
    COUNT(*)                                                AS Total_Beneficiaries,
    SUM(CASE WHEN eKYC_Status = 'Completed'
             THEN 1 ELSE 0 END)                             AS eKYC_Completed,
    SUM(CASE WHEN eKYC_Status = 'Failed / Expired'
             THEN 1 ELSE 0 END)                             AS eKYC_Failed,
    SUM(CASE WHEN eKYC_Status = 'Pending'
             THEN 1 ELSE 0 END)                             AS eKYC_Pending,
    SUM(CASE WHEN eKYC_Status = 'Not Started'
             THEN 1 ELSE 0 END)                             AS eKYC_Not_Started,
    CAST(
        SUM(CASE WHEN eKYC_Status = 'Completed'
                 THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100
    AS DECIMAL(5,2))                                        AS eKYC_Completion_Rate_Pct,
    CAST(
        SUM(CASE WHEN eKYC_Status IN ('Failed / Expired', 'Pending', 'Not Started')
                 THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100
    AS DECIMAL(5,2))                                        AS eKYC_Gap_Pct,
    SUM(CASE WHEN eKYC_Status != 'Completed'
             AND Application_Status IN (
                 'Suspended due to Ineligibility',
                 'Suspended due to Pending Verification')
             THEN 1 ELSE 0 END)                             AS Suspended_Due_To_eKYC
FROM dbo.fact_beneficiaries
GROUP BY GROUPING SETS (
    (Division, Area_Type),
    (Division),
    ()
)
ORDER BY Division, Area_Type;


-- ============================================================
-- TOPIC 5: DISBURSEMENT TIMELINE ANALYSIS
-- ============================================================

-- ── Q9: Month-on-month beneficiary and disbursement trend
-- How did the scheme evolve across 17 installments?
-- ────────────────────────────────────────────────────────────
SELECT
    Installment_No,
    Month_Label,
    Fiscal_Year,
    Period_Covered,
    Amount_Per_Beneficiary_Rs,
    Beneficiaries_Paid,
    Total_Disbursed_Cr_Rs,
    Cumulative_Disbursed_Cr_Rs,
    Beneficiary_Change_MoM,
    CAST(
        Beneficiary_Change_MoM * 100.0
        / NULLIF(
            LAG(Beneficiaries_Paid, 1) OVER (ORDER BY Installment_No),
            0)
    AS DECIMAL(6,2))                                        AS Beneficiary_Change_MoM_Pct,
    Cumulative_Budget_Used_Pct,
    CASE
        WHEN Amount_Per_Beneficiary_Rs = 3000
             THEN 'Double Payment Month'
        WHEN Beneficiary_Change_MoM < -1000000
             THEN 'Major Drop — Audit/Suspension Event'
        WHEN Beneficiary_Change_MoM > 500000
             THEN 'Major Surge — New Registrations'
        ELSE 'Normal'
    END                                                     AS Month_Classification
FROM rpt.v_installment_tracker
ORDER BY Installment_No;


-- ── Q10: Cohort analysis — early vs late applicants
-- Do July applicants receive significantly more than October?
-- ────────────────────────────────────────────────────────────
SELECT
    DATENAME(MONTH, Application_Date)
        + ' ' + CAST(YEAR(Application_Date) AS VARCHAR) AS Application_Month,
    DATEPART(MONTH, Application_Date)                       AS Month_Num,
    COUNT(*)                                                AS Total_Applicants,
    SUM(CASE WHEN Application_Status = 'Active'
             THEN 1 ELSE 0 END)                             AS Active_Count,
    CAST(
        SUM(CASE WHEN Application_Status = 'Active'
                 THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100
    AS DECIMAL(5,2))                                        AS Active_Rate_Pct,
    AVG(CAST(Installments_Received AS FLOAT))               AS Avg_Installments_Received,
    AVG(CAST(Total_Amount_Received_Rs AS FLOAT))            AS Avg_Total_Received_Rs,
    SUM(CAST(Total_Amount_Received_Rs AS BIGINT))           AS Total_Disbursed_Rs,
    AVG(CAST(Installments_Received AS FLOAT))
        - FIRST_VALUE(AVG(CAST(Installments_Received AS FLOAT)))
          OVER (ORDER BY DATEPART(MONTH, Application_Date))
                                                            AS Installments_Behind_July_Cohort
FROM dbo.fact_beneficiaries
GROUP BY
    DATENAME(MONTH, Application_Date),
    DATEPART(MONTH, Application_Date),
    YEAR(Application_Date)
ORDER BY Month_Num;


-- ============================================================
-- TOPIC 6: DEMOGRAPHIC & EQUITY ANALYSIS
-- ============================================================

-- ── Q11: Caste-wise equity analysis
-- Are all caste categories being served equally?
-- ────────────────────────────────────────────────────────────
SELECT
    Caste_Category,
    COUNT(*)                                                AS Total_Beneficiaries,
    SUM(CASE WHEN Application_Status = 'Active'
             THEN 1 ELSE 0 END)                             AS Active_Count,
    CAST(
        SUM(CASE WHEN Application_Status = 'Active'
                 THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100
    AS DECIMAL(5,2))                                        AS Active_Rate_Pct,
    SUM(CASE WHEN Application_Status IN (
                  'Suspended due to Ineligibility',
                  'Suspended due to Pending Verification')
             THEN 1 ELSE 0 END)                             AS Suspended_Count,
    CAST(
        SUM(CASE WHEN Application_Status IN (
                      'Suspended due to Ineligibility',
                      'Suspended due to Pending Verification')
                 THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100
    AS DECIMAL(5,2))                                        AS Suspension_Rate_Pct,
    AVG(CAST(Annual_Family_Income_Rs AS FLOAT))             AS Avg_Annual_Income_Rs,
    AVG(CAST(Installments_Received AS FLOAT))               AS Avg_Installments,
    AVG(CAST(Total_Amount_Received_Rs AS FLOAT))            AS Avg_Total_Received_Rs,
    SUM(CASE WHEN Grievance_Filed = 'Yes'
             THEN 1 ELSE 0 END)                             AS Grievances_Filed,
    CAST(
        SUM(CASE WHEN Grievance_Filed = 'Yes'
                 THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100
    AS DECIMAL(5,2))                                        AS Grievance_Rate_Pct,
    RANK() OVER (
        ORDER BY
            SUM(CASE WHEN Application_Status = 'Active'
                     THEN 1.0 ELSE 0 END)
            / COUNT(*) DESC
    )                                                       AS Equity_Rank
FROM dbo.fact_beneficiaries
GROUP BY Caste_Category
ORDER BY Active_Rate_Pct DESC;


-- ── Q12: Marital status vs ration card — vulnerability matrix
-- Which combination of marital status + economic category
-- is most underserved? Subquery pattern to allow CASE on aggregates.
-- ────────────────────────────────────────────────────────────
SELECT
    Marital_Status,
    Ration_Card_Type,
    Total_Beneficiaries,
    Active_Count,
    Active_Rate_Pct,
    Avg_Income_Rs,
    Avg_Installments,
    Grievances_Filed,
    Grievance_Rate_Pct,
    CASE
        WHEN Active_Rate_Pct < 70
         AND Ration_Card_Type = 'Yellow – BPL/Antyodaya'
             THEN 'CRITICAL — Poorest Women Underserved'
        WHEN Active_Rate_Pct < 72
             THEN 'AT RISK — Below Average Active Rate'
        ELSE 'Adequately Served'
    END                                                     AS Service_Status_Flag
FROM (
    SELECT
        Marital_Status,
        Ration_Card_Type,
        COUNT(*)                                            AS Total_Beneficiaries,
        SUM(CASE WHEN Application_Status = 'Active'
                 THEN 1 ELSE 0 END)                         AS Active_Count,
        CAST(
            SUM(CASE WHEN Application_Status = 'Active'
                     THEN 1.0 ELSE 0 END)
            / COUNT(*) * 100
        AS DECIMAL(5,2))                                    AS Active_Rate_Pct,
        AVG(CAST(Annual_Family_Income_Rs AS FLOAT))         AS Avg_Income_Rs,
        AVG(CAST(Installments_Received AS FLOAT))           AS Avg_Installments,
        SUM(CASE WHEN Grievance_Filed = 'Yes'
                 THEN 1 ELSE 0 END)                         AS Grievances_Filed,
        CAST(
            SUM(CASE WHEN Grievance_Filed = 'Yes'
                     THEN 1.0 ELSE 0 END)
            / COUNT(*) * 100
        AS DECIMAL(5,2))                                    AS Grievance_Rate_Pct
    FROM dbo.fact_beneficiaries
    GROUP BY Marital_Status, Ration_Card_Type
) AS grouped
ORDER BY Active_Rate_Pct ASC;
