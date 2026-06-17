USE LadkiBahinDB;
GO

-- ═══════════════════════════════════════════════════════════
-- DIMENSION 1: dim_district
-- ═══════════════════════════════════════════════════════════
IF OBJECT_ID('dbo.dim_district', 'U') IS NOT NULL DROP TABLE dbo.dim_district;
GO

CREATE TABLE dbo.dim_district (
    District_ID                     SMALLINT        NOT NULL IDENTITY(1,1),
    District                        NVARCHAR(60)    NOT NULL,
    Division                        NVARCHAR(40)    NOT NULL,
    Approx_Urban_Pct                TINYINT         NOT NULL,   -- stored as integer e.g. 68 = 68%
    Fraud_Risk_Score                DECIMAL(3,1)    NOT NULL,
    Synthetic_Total_Applications    INT             NOT NULL,
    Synthetic_Active                INT             NOT NULL,
    Synthetic_Suspended_Ineligible  INT             NOT NULL,
    Synthetic_Suspended_Pending     INT             NOT NULL,
    Synthetic_Pending_Approval      INT             NOT NULL,
    Synthetic_Male_Fraud_Cases      SMALLINT        NOT NULL,
    Synthetic_Govt_Emp_Cases        SMALLINT        NOT NULL,
    Synthetic_Dual_Scheme           INT             NOT NULL,
    Synthetic_Total_Disbursed_Rs    BIGINT          NOT NULL,
    Estimated_Real_Beneficiaries    NVARCHAR(20)    NOT NULL,   -- kept as label e.g. "~472,500"

    CONSTRAINT PK_dim_district PRIMARY KEY (District_ID),
    CONSTRAINT UQ_dim_district_name UNIQUE (District)
);
GO

-- ═══════════════════════════════════════════════════════════
-- DIMENSION 2: dim_budget
-- ═══════════════════════════════════════════════════════════
IF OBJECT_ID('dbo.dim_budget', 'U') IS NOT NULL DROP TABLE dbo.dim_budget;
GO

CREATE TABLE dbo.dim_budget (
    Budget_ID                       TINYINT         NOT NULL IDENTITY(1,1),
    Fiscal_Year                     CHAR(7)         NOT NULL,   -- e.g. "2024-25"
    Budget_Allocated_Cr_Rs          INT             NOT NULL,
    Actual_Spent_Cr_Rs              INT             NULL,       -- NULL for future FYs
    Utilisation_Pct                 DECIMAL(5,1)    NULL,
    Avg_Active_Beneficiaries_Cr     DECIMAL(4,2)    NOT NULL,
    Months_Operational              TINYINT         NOT NULL,
    Installments_Released           NVARCHAR(50)    NOT NULL,
    Key_Events                      NVARCHAR(400)   NOT NULL,

    CONSTRAINT PK_dim_budget PRIMARY KEY (Budget_ID),
    CONSTRAINT UQ_dim_budget_fy UNIQUE (Fiscal_Year)
);
GO

-- ═══════════════════════════════════════════════════════════
-- DIMENSION 3: dim_installment
-- ═══════════════════════════════════════════════════════════
IF OBJECT_ID('dbo.dim_installment', 'U') IS NOT NULL DROP TABLE dbo.dim_installment;
GO

CREATE TABLE dbo.dim_installment (
    Installment_No                  TINYINT         NOT NULL,
    Credit_Date                     DATE            NOT NULL,
    Period_Covered                  NVARCHAR(40)    NOT NULL,
    Amount_Per_Beneficiary_Rs       SMALLINT        NOT NULL,
    Beneficiaries_Paid              INT             NOT NULL,
    Total_Disbursed_Cr_Rs           DECIMAL(8,2)    NOT NULL,
    Cumulative_Disbursed_Cr_Rs      DECIMAL(10,2)   NOT NULL,
    Notes                           NVARCHAR(200)   NOT NULL,
    Fiscal_Year                     CHAR(7)         NOT NULL,   -- computed from Credit_Date

    CONSTRAINT PK_dim_installment PRIMARY KEY (Installment_No),
    CONSTRAINT FK_installment_budget FOREIGN KEY (Fiscal_Year)
        REFERENCES dbo.dim_budget (Fiscal_Year)
);
GO

-- ═══════════════════════════════════════════════════════════
-- FACT TABLE: fact_beneficiaries (500,000 rows)
-- ═══════════════════════════════════════════════════════════
IF OBJECT_ID('dbo.fact_beneficiaries', 'U') IS NOT NULL DROP TABLE dbo.fact_beneficiaries;
GO

CREATE TABLE dbo.fact_beneficiaries (

    -- ── Surrogate key ────────────────────────────────────────
    Record_ID                       INT             NOT NULL IDENTITY(1,1),

    -- ── Section A: Identification ─────────────────────────
    Beneficiary_ID                  NVARCHAR(30)    NOT NULL,
    Application_ID                  NVARCHAR(20)    NOT NULL,
    Application_Date                DATE            NOT NULL,
    Application_Mode                NVARCHAR(60)    NOT NULL,

    -- ── Section B: Location ───────────────────────────────
    District                        NVARCHAR(60)    NOT NULL,
    Division                        NVARCHAR(40)    NOT NULL,
    Area_Type                       NVARCHAR(10)    NOT NULL
        CONSTRAINT CK_area_type CHECK (Area_Type IN ('Urban', 'Rural')),
    Taluka_Ward_Anganwadi           NVARCHAR(100)   NOT NULL,

    -- ── Section C: Personal Details ───────────────────────
    Declared_Gender                 NVARCHAR(10)    NOT NULL
        CONSTRAINT CK_gender CHECK (Declared_Gender IN ('Female', 'Male')),
    Age_at_Application              TINYINT         NOT NULL
        CONSTRAINT CK_age CHECK (Age_at_Application BETWEEN 21 AND 65),
    Birth_Year_Approx               SMALLINT        NOT NULL,
    Marital_Status                  NVARCHAR(60)    NOT NULL,
    Caste_Category                  NVARCHAR(30)    NOT NULL,

    -- ── Section D: Family & Economic ──────────────────────
    Annual_Family_Income_Rs         INT             NOT NULL
        CONSTRAINT CK_income CHECK (Annual_Family_Income_Rs BETWEEN 0 AND 500000),
    Ration_Card_Type                NVARCHAR(40)    NOT NULL,
    Family_Member_Govt_Employee     CHAR(3)         NOT NULL
        CONSTRAINT CK_fam_govt CHECK (Family_Member_Govt_Employee IN ('Yes', 'No')),
    Income_Tax_Payer_in_Family      CHAR(3)         NOT NULL
        CONSTRAINT CK_itr CHECK (Income_Tax_Payer_in_Family IN ('Yes', 'No')),
    Also_on_Namo_Shetkari_Scheme    CHAR(3)         NOT NULL
        CONSTRAINT CK_dual_scheme CHECK (Also_on_Namo_Shetkari_Scheme IN ('Yes', 'No')),

    -- ── Section E: Documents ──────────────────────────────
    Domicile_Proof_Type             NVARCHAR(60)    NOT NULL,
    Income_Proof_Submitted          NVARCHAR(60)    NOT NULL,
    Hamipatra_Declaration_Submitted CHAR(3)         NOT NULL
        CONSTRAINT CK_hamipatra CHECK (Hamipatra_Declaration_Submitted IN ('Yes', 'No')),

    -- ── Section F: Aadhaar & Bank ─────────────────────────
    Aadhaar_Number_Masked           NVARCHAR(20)    NOT NULL,
    Bank_Name                       NVARCHAR(60)    NOT NULL,
    Bank_Account_Masked             NVARCHAR(20)    NOT NULL,
    IFSC_Code                       NVARCHAR(15)    NOT NULL,
    Aadhaar_Bank_Linked_NPCI        CHAR(3)         NOT NULL
        CONSTRAINT CK_npci CHECK (Aadhaar_Bank_Linked_NPCI IN ('Yes', 'No')),
    eKYC_Status                     NVARCHAR(30)    NOT NULL,

    -- ── Section G: Scheme Status ──────────────────────────
    Application_Status              NVARCHAR(50)    NOT NULL,
    Suspension_Rejection_Reason     NVARCHAR(100)   NULL,
    Fraud_Type_Detected             NVARCHAR(40)    NOT NULL DEFAULT 'None',

    -- ── Section H: Payment ────────────────────────────────
    Monthly_Benefit_Rs              SMALLINT        NOT NULL
        CONSTRAINT CK_benefit CHECK (Monthly_Benefit_Rs IN (500, 1500)),
    Installments_Received           TINYINT         NOT NULL DEFAULT 0,
    Total_Amount_Received_Rs        INT             NOT NULL DEFAULT 0,
    DBT_Transfer_Status             NVARCHAR(40)    NOT NULL,
    First_Payment_Date              DATE            NULL,

    -- ── Section I: Grievance ──────────────────────────────
    Grievance_Filed                 CHAR(3)         NOT NULL DEFAULT 'No'
        CONSTRAINT CK_grievance CHECK (Grievance_Filed IN ('Yes', 'No')),
    Grievance_Type                  NVARCHAR(60)    NULL,

    -- ── Constraints ───────────────────────────────────────
    CONSTRAINT PK_fact_beneficiaries PRIMARY KEY (Record_ID),
    CONSTRAINT UQ_beneficiary_id UNIQUE (Beneficiary_ID),
    CONSTRAINT UQ_application_id UNIQUE (Application_ID),

    -- Business rule: if flagged as Male Registrant, Declared_Gender must be Male
    CONSTRAINT CK_male_fraud_consistency
        CHECK (
            NOT (Fraud_Type_Detected = 'Male Registrant' AND Declared_Gender = 'Female')
        ),

    -- Business rule: Active beneficiaries must have eKYC Completed
    CONSTRAINT CK_active_ekyc
        CHECK (
            NOT (Application_Status = 'Active' AND eKYC_Status != 'Completed')
        ),

    -- Business rule: Pending Approval rows must have 0 installments
    CONSTRAINT CK_pending_no_payment
        CHECK (
            NOT (Application_Status = 'Pending Approval' AND Installments_Received > 0)
        ),

    -- FK to dimension
    CONSTRAINT FK_fact_district FOREIGN KEY (District)
        REFERENCES dbo.dim_district (District)
);
GO
-- ═══════════════════════════════════════════════════════════
-- INDEXES for analytical query performance
-- ═══════════════════════════════════════════════════════════

-- Most queries filter by District
CREATE NONCLUSTERED INDEX IX_fact_district
    ON dbo.fact_beneficiaries (District)
    INCLUDE (Application_Status, Monthly_Benefit_Rs, Total_Amount_Received_Rs);
GO

-- Fraud analysis queries
CREATE NONCLUSTERED INDEX IX_fact_fraud
    ON dbo.fact_beneficiaries (Fraud_Type_Detected)
    INCLUDE (District, Division, Total_Amount_Received_Rs);
GO

-- Status-based filtering (most common analytical filter)
CREATE NONCLUSTERED INDEX IX_fact_status
    ON dbo.fact_beneficiaries (Application_Status)
    INCLUDE (District, Caste_Category, Area_Type, Monthly_Benefit_Rs, Installments_Received);
GO

-- Date-based queries
CREATE NONCLUSTERED INDEX IX_fact_appdate
    ON dbo.fact_beneficiaries (Application_Date)
    INCLUDE (Application_Mode, District, Application_Status);
GO

-- eKYC analysis
CREATE NONCLUSTERED INDEX IX_fact_ekyc
    ON dbo.fact_beneficiaries (eKYC_Status)
    INCLUDE (District, Division, Aadhaar_Bank_Linked_NPCI, Application_Status);
GO
