/* ============================================================
   MUKHYAMANTRI MAJHI LADKI BAHIN YOJANA — DATA ANALYTICS
   Phase 1 | Script 02: Staging (Raw) Tables
   ============================================================
   Purpose : Create raw.* staging tables that exactly mirror
             the CSV column structure — no constraints yet.
             BULK INSERT / Import Wizard loads data here first.
   ============================================================ */

USE LadkiBahinDB;
GO

-- ── 1. raw.beneficiaries (500,000 rows) ────────────────────
IF OBJECT_ID('raw.beneficiaries', 'U') IS NOT NULL
    DROP TABLE raw.beneficiaries;
GO

CREATE TABLE raw.beneficiaries (
    -- Section A: Identification
    Beneficiary_ID                  NVARCHAR(30),
    Application_ID                  NVARCHAR(20),
    Application_Date                NVARCHAR(20),       -- imported as string, cast later
    Application_Mode                NVARCHAR(60),

    -- Section B: Location
    District                        NVARCHAR(60),
    Division                        NVARCHAR(40),
    Area_Type                       NVARCHAR(10),
    Taluka_Ward_Anganwadi           NVARCHAR(100),

    -- Section C: Personal Details
    Declared_Gender                 NVARCHAR(10),
    Age_at_Application              NVARCHAR(5),        -- cast to TINYINT after validation
    Birth_Year_Approx               NVARCHAR(6),
    Marital_Status                  NVARCHAR(60),
    Caste_Category                  NVARCHAR(30),

    -- Section D: Family & Economic
    Annual_Family_Income_Rs         NVARCHAR(10),       -- cast to INT after validation
    Ration_Card_Type                NVARCHAR(40),
    Family_Member_Govt_Employee     NVARCHAR(5),
    Income_Tax_Payer_in_Family      NVARCHAR(5),
    Also_on_Namo_Shetkari_Scheme    NVARCHAR(5),

    -- Section E: Documents
    Domicile_Proof_Type             NVARCHAR(60),
    Income_Proof_Submitted          NVARCHAR(60),
    Hamipatra_Declaration_Submitted NVARCHAR(5),

    -- Section F: Aadhaar & Bank
    Aadhaar_Number_Masked           NVARCHAR(20),
    Bank_Name                       NVARCHAR(60),
    Bank_Account_Masked             NVARCHAR(20),
    IFSC_Code                       NVARCHAR(15),
    Aadhaar_Bank_Linked_NPCI        NVARCHAR(5),
    eKYC_Status                     NVARCHAR(30),

    -- Section G: Scheme Status
    Application_Status              NVARCHAR(50),
    Suspension_Rejection_Reason     NVARCHAR(100),
    Fraud_Type_Detected             NVARCHAR(40),

    -- Section H: Payment
    Monthly_Benefit_Rs              NVARCHAR(6),
    Installments_Received           NVARCHAR(5),
    Total_Amount_Received_Rs        NVARCHAR(12),
    DBT_Transfer_Status             NVARCHAR(40),
    First_Payment_Date              NVARCHAR(20),

    -- Section I: Grievance
    Grievance_Filed                 NVARCHAR(5),
    Grievance_Type                  NVARCHAR(60)
);
GO

PRINT '>> raw.beneficiaries created (37 columns, all NVARCHAR).';

-- ── 2. raw.installment_schedule (17 rows) ──────────────────
IF OBJECT_ID('raw.installment_schedule', 'U') IS NOT NULL
    DROP TABLE raw.installment_schedule;
GO

CREATE TABLE raw.installment_schedule (
    Installment_No                  NVARCHAR(5),
    Credit_Date                     NVARCHAR(20),
    Period_Covered                  NVARCHAR(40),
    Amount_Per_Beneficiary_Rs       NVARCHAR(6),
    Beneficiaries_Paid              NVARCHAR(12),
    Notes                           NVARCHAR(200),
    Total_Disbursed_Cr_Rs           NVARCHAR(12),
    Cumulative_Disbursed_Cr_Rs      NVARCHAR(12)
);
GO

PRINT '>> raw.installment_schedule created.';

-- ── 3. raw.district_summary (36 rows) ──────────────────────
IF OBJECT_ID('raw.district_summary', 'U') IS NOT NULL
    DROP TABLE raw.district_summary;
GO

CREATE TABLE raw.district_summary (
    District                                NVARCHAR(60),
    Division                                NVARCHAR(40),
    Approx_Urban_Pct                        NVARCHAR(10),
    Fraud_Risk_Score                        NVARCHAR(6),
    Synthetic_Total_Applications            NVARCHAR(8),
    Synthetic_Active                        NVARCHAR(8),
    Synthetic_Suspended_Ineligible          NVARCHAR(8),
    Synthetic_Suspended_Pending             NVARCHAR(8),
    Synthetic_Pending_Approval              NVARCHAR(8),
    Synthetic_Male_Fraud_Cases              NVARCHAR(6),
    Synthetic_Govt_Emp_Cases                NVARCHAR(6),
    Synthetic_Dual_Scheme                   NVARCHAR(8),
    Synthetic_Total_Disbursed_Rs            NVARCHAR(16),
    Estimated_Real_Beneficiaries            NVARCHAR(20)
);
GO

PRINT '>> raw.district_summary created.';

-- ── 4. raw.budget_allocation (3 rows) ──────────────────────
IF OBJECT_ID('raw.budget_allocation', 'U') IS NOT NULL
    DROP TABLE raw.budget_allocation;
GO

CREATE TABLE raw.budget_allocation (
    Fiscal_Year                     NVARCHAR(10),
    Budget_Allocated_Cr_Rs          NVARCHAR(10),
    Actual_Spent_Cr_Rs              NVARCHAR(10),
    Utilisation_Pct                 NVARCHAR(8),
    Avg_Active_Beneficiaries_Cr     NVARCHAR(6),
    Months_Operational              NVARCHAR(4),
    Installments_Released           NVARCHAR(40),
    Key_Events                      NVARCHAR(300)
);
GO

PRINT '>> raw.budget_allocation created.';
PRINT '';
PRINT '========================================================';
PRINT '  All 4 staging tables created in [raw] schema.';
PRINT '  Next: Run 03_bulk_insert.sql to load the CSV files.';
PRINT '========================================================';
GO
