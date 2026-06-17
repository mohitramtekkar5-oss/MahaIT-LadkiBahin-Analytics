USE LadkiBahinDB;
GO

DECLARE @DataPath NVARCHAR(200) = 'C:\LadkiBahin\Data\';
PRINT '>> Loading from: ' + @DataPath;

PRINT '';
PRINT '>> Loading raw.beneficiaries...';

BULK INSERT raw.beneficiaries
FROM 'C:\LadkiBahin\Data\1_beneficiaries.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,                
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = '65001',          
    TABLOCK,                            
    MAXERRORS       = 100               
);

PRINT '   Rows loaded: ' + CAST(@@ROWCOUNT AS VARCHAR);

PRINT '';
PRINT '>> Loading raw.installment_schedule...';

BULK INSERT raw.installment_schedule
FROM 'C:\LadkiBahin\Data\2_installment_schedule.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = '65001'
);

PRINT '   Rows loaded: ' + CAST(@@ROWCOUNT AS VARCHAR);

PRINT '';
PRINT '>> Loading raw.district_summary...';

BULK INSERT raw.district_summary
FROM 'C:\LadkiBahin\Data\3_district_summary.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = '65001'
);

PRINT '   Rows loaded: ' + CAST(@@ROWCOUNT AS VARCHAR);

PRINT '';
PRINT '>> Loading raw.budget_allocation...';

BULK INSERT raw.budget_allocation
FROM 'C:\LadkiBahin\Data\4_budget_allocation.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = '65001'
);

PRINT '   Rows loaded: ' + CAST(@@ROWCOUNT AS VARCHAR);

PRINT '';
PRINT '========== ROW COUNT VALIDATION ==========';
SELECT 'raw.beneficiaries' AS [Table], COUNT(*) AS [Rows_Loaded], 500000 AS [Expected] FROM raw.beneficiaries
UNION ALL
SELECT 'raw.installment_schedule', COUNT(*),                  17               FROM raw.installment_schedule
UNION ALL
SELECT 'raw.district_summary',                COUNT(*),                  36               FROM raw.district_summary
UNION ALL
SELECT 'raw.budget_allocation',               COUNT(*),                  3                FROM raw.budget_allocation;

PRINT '>> If Rows_Loaded = Expected for all tables, proceed to Script 04.';
GO
