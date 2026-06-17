USE LadkiBahinDB;
GO

IF OBJECT_ID('audit.dq_results', 'U') IS NOT NULL DROP TABLE audit.dq_results;
GO

CREATE TABLE audit.dq_results (
    Check_ID            TINYINT         NOT NULL IDENTITY(1,1),
    Check_Name          NVARCHAR(100)   NOT NULL,
    Check_Description   NVARCHAR(300)   NOT NULL,
    Expected_Value      NVARCHAR(50)    NULL,
    Actual_Value        NVARCHAR(50)    NOT NULL,
    Status              NVARCHAR(10)    NOT NULL,   -- PASS / WARN / FAIL
    Rows_Affected       INT             NULL,
    Run_Timestamp       DATETIME        NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_dq_results PRIMARY KEY (Check_ID)
);
GO

-- Helper procedure to log results
CREATE OR ALTER PROCEDURE audit.sp_log_dq_check
    @Name        NVARCHAR(100),
    @Description NVARCHAR(300),
    @Expected    NVARCHAR(50),
    @Actual      NVARCHAR(50),
    @Status      NVARCHAR(10),
    @Rows        INT = NULL
AS
BEGIN
    INSERT INTO audit.dq_results
        (Check_Name, Check_Description, Expected_Value, Actual_Value, Status, Rows_Affected)
    VALUES (@Name, @Description, @Expected, @Actual, @Status, @Rows);
    PRINT '   [' + @Status + '] ' + @Name + ' → ' + @Actual;
END;
GO

DECLARE @actual_val  NVARCHAR(50);
DECLARE @rows_aff    INT;
DECLARE @status      NVARCHAR(10);


SELECT @actual_val = CAST(COUNT(*) AS NVARCHAR), @rows_aff = COUNT(*)
FROM dbo.fact_beneficiaries;

SET @status = CASE WHEN @rows_aff = 500000 THEN 'PASS' ELSE 'FAIL' END;

EXEC audit.sp_log_dq_check
    'Row Count',
    'Total rows in fact_beneficiaries must equal 500,000',
    '500000', @actual_val, @status, @rows_aff;


SELECT @rows_aff = COUNT(*) FROM (
    SELECT Beneficiary_ID FROM dbo.fact_beneficiaries
    GROUP BY Beneficiary_ID HAVING COUNT(*) > 1
) t;

SET @actual_val = CAST(@rows_aff AS NVARCHAR);
SET @status     = CASE WHEN @rows_aff = 0 THEN 'PASS' ELSE 'FAIL' END;

EXEC audit.sp_log_dq_check
    'Duplicate Beneficiary IDs',
    'No Beneficiary_ID should appear more than once',
    '0', @actual_val, @status, @rows_aff;


SELECT @rows_aff = COUNT(*)
FROM dbo.fact_beneficiaries
WHERE Age_at_Application < 21 OR Age_at_Application > 65;

SET @actual_val = CAST(@rows_aff AS NVARCHAR);
SET @status     = CASE WHEN @rows_aff = 0 THEN 'PASS' ELSE 'FAIL' END;

EXEC audit.sp_log_dq_check
    'Age Range Validity',
    'All beneficiaries must be aged 21–65 at application',
    '0 out-of-range', @actual_val + ' out-of-range', @status, @rows_aff;


SELECT @rows_aff = COUNT(*)
FROM dbo.fact_beneficiaries
WHERE Annual_Family_Income_Rs >= 250000;

SET @actual_val = CAST(@rows_aff AS NVARCHAR);
SET @status     = CASE WHEN @rows_aff = 0 THEN 'PASS'
                        WHEN @rows_aff < 50 THEN 'WARN'
                        ELSE 'FAIL' END;

EXEC audit.sp_log_dq_check
    'Income Eligibility Cap',
    'Annual family income must be below ₹2,50,000 per scheme rules',
    '0', @actual_val, @status, @rows_aff;


SELECT @rows_aff = COUNT(*)
FROM dbo.fact_beneficiaries
WHERE Application_Date < '2024-07-01'
   OR Application_Date > '2024-10-15';

SET @actual_val = CAST(@rows_aff AS NVARCHAR);
SET @status     = CASE WHEN @rows_aff = 0 THEN 'PASS' ELSE 'FAIL' END;

EXEC audit.sp_log_dq_check
    'Application Date Range',
    'All applications must fall within Jul 1 – Oct 15, 2024 (scheme window)',
    '0', @actual_val, @status, @rows_aff;


SELECT @rows_aff = COUNT(*)
FROM dbo.fact_beneficiaries
WHERE Monthly_Benefit_Rs NOT IN (500, 1500);

SET @actual_val = CAST(@rows_aff AS NVARCHAR);
SET @status     = CASE WHEN @rows_aff = 0 THEN 'PASS' ELSE 'FAIL' END;

EXEC audit.sp_log_dq_check
    'Monthly Benefit Values',
    'Monthly benefit must be either ₹500 (dual scheme) or ₹1,500 (standard)',
    '0', @actual_val, @status, @rows_aff;


SELECT @rows_aff = COUNT(*)
FROM dbo.fact_beneficiaries
WHERE Application_Status = 'Active'
  AND eKYC_Status != 'Completed';

SET @actual_val = CAST(@rows_aff AS NVARCHAR);
SET @status     = CASE WHEN @rows_aff = 0 THEN 'PASS' ELSE 'WARN' END;

EXEC audit.sp_log_dq_check
    'Active Beneficiary eKYC',
    'Active beneficiaries must all have eKYC status = Completed',
    '0', @actual_val, @status, @rows_aff;


SELECT @rows_aff = COUNT(*)
FROM dbo.fact_beneficiaries
WHERE Application_Status = 'Pending Approval'
  AND Installments_Received > 0;

SET @actual_val = CAST(@rows_aff AS NVARCHAR);
SET @status     = CASE WHEN @rows_aff = 0 THEN 'PASS' ELSE 'FAIL' END;

EXEC audit.sp_log_dq_check
    'Pending With Payments',
    'Pending Approval rows should have 0 installments received',
    '0', @actual_val, @status, @rows_aff;


SELECT @rows_aff = COUNT(*)
FROM dbo.fact_beneficiaries
WHERE Fraud_Type_Detected = 'Male Registrant'
  AND Declared_Gender != 'Male';

SET @actual_val = CAST(@rows_aff AS NVARCHAR);
SET @status     = CASE WHEN @rows_aff = 0 THEN 'PASS' ELSE 'FAIL' END;

EXEC audit.sp_log_dq_check
    'Male Fraud Flag Consistency',
    'If Fraud_Type_Detected = Male Registrant, Declared_Gender must = Male',
    '0', @actual_val, @status, @rows_aff;


SELECT @rows_aff = COUNT(DISTINCT District) FROM dbo.fact_beneficiaries;
SET @actual_val  = CAST(@rows_aff AS NVARCHAR);
SET @status      = CASE WHEN @rows_aff = 36 THEN 'PASS' ELSE 'FAIL' END;

EXEC audit.sp_log_dq_check
    'District Coverage',
    'All 36 Maharashtra districts must have at least 1 beneficiary record',
    '36', @actual_val, @status, @rows_aff;


SELECT @rows_aff = COUNT(*)
FROM dbo.fact_beneficiaries
WHERE Beneficiary_ID IS NULL
   OR Application_Date IS NULL
   OR District IS NULL
   OR Application_Status IS NULL
   OR Monthly_Benefit_Rs IS NULL;

SET @actual_val = CAST(@rows_aff AS NVARCHAR);
SET @status     = CASE WHEN @rows_aff = 0 THEN 'PASS' ELSE 'FAIL' END;

EXEC audit.sp_log_dq_check
    'NULL Check (Critical Fields)',
    'Beneficiary_ID, Application_Date, District, Status, Monthly_Benefit_Rs must not be NULL',
    '0', @actual_val, @status, @rows_aff;


DECLARE @total_disbursed BIGINT;
SELECT @total_disbursed = SUM(CAST(Total_Amount_Received_Rs AS BIGINT))
FROM dbo.fact_beneficiaries;

SET @actual_val = '₹' + CAST(@total_disbursed / 10000000 AS NVARCHAR) + ' Cr (synthetic)';
SET @status     = CASE
    WHEN @total_disbursed BETWEEN 5000000000 AND 20000000000 THEN 'PASS'
    ELSE 'WARN'
END;

EXEC audit.sp_log_dq_check
    'Total Disbursement Sanity Check',
    'Total amount disbursed (synthetic 500K) should be ₹500–2000 Cr range',
    '₹500–2000 Cr', @actual_val, @status;

SELECT
    Check_ID,
    Check_Name,
    Expected_Value,
    Actual_Value,
    Status,
    Rows_Affected,
    Run_Timestamp
FROM audit.dq_results
ORDER BY Check_ID;

-- Summary
PRINT '';
SELECT
    Status,
    COUNT(*) AS Check_Count
FROM audit.dq_results
GROUP BY Status
ORDER BY Status;
GO
