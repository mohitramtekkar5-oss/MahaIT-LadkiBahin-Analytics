/* ============================================================
   MUKHYAMANTRI MAJHI LADKI BAHIN YOJANA — DATA ANALYTICS
   Phase 1 | Script 03: BULK INSERT — Load CSVs into Staging
   ============================================================
   BEFORE RUNNING:
   1. Place all 4 CSV files in: C:\LadkiBahin\Data\
      (or update the file paths below to your actual location)
   2. Ensure SQL Server service account has READ access to
      that folder.
   3. If using SSMS Import Wizard instead of BULK INSERT,
      skip this script and import directly into raw.* tables.

   File list expected:
      1_beneficiaries.csv
      2_installment_schedule.csv
      3_district_summary.csv
      4_budget_allocation.csv
   ============================================================ */

USE LadkiBahinDB;
GO

-- ── Configuration ───────────────────────────────────────────
-- Update this path to where you saved the CSV files
DECLARE @DataPath NVARCHAR(200) = 'C:\LadkiBahin\Data\';
PRINT '>> Loading from: ' + @DataPath;

-- ── 1. Load beneficiaries (largest file ~200 MB, ~30 sec) ──
PRINT '';
PRINT '>> Loading raw.beneficiaries...';

BULK INSERT raw.beneficiaries
FROM 'C:\LadkiBahin\Data\1_beneficiaries.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,                -- skip header row
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = '65001',          -- UTF-8 (for Marathi text in Marital_Status)
    TABLOCK,                            -- table lock for performance
    MAXERRORS       = 100               -- tolerate up to 100 row errors
);

PRINT '   Rows loaded: ' + CAST(@@ROWCOUNT AS VARCHAR);

-- ── 2. Load installment schedule (17 rows) ──────────────────
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

-- ── 3. Load district summary (36 rows) ──────────────────────
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

-- ── 4. Load budget allocation (3 rows) ──────────────────────
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

-- ── Quick row count validation ───────────────────────────────
PRINT '';
PRINT '========== ROW COUNT VALIDATION ==========';
SELECT 'raw.beneficiaries'       AS [Table], COUNT(*) AS [Rows_Loaded], 500000 AS [Expected] FROM raw.beneficiaries
UNION ALL
SELECT 'raw.installment_schedule',            COUNT(*),                  17               FROM raw.installment_schedule
UNION ALL
SELECT 'raw.district_summary',                COUNT(*),                  36               FROM raw.district_summary
UNION ALL
SELECT 'raw.budget_allocation',               COUNT(*),                  3                FROM raw.budget_allocation;

PRINT '>> If Rows_Loaded = Expected for all tables, proceed to Script 04.';
GO

/* ============================================================
   ALTERNATIVE: SSMS Import Wizard (if BULK INSERT fails)
   ============================================================
   If your SQL Server service account lacks file access:

   1. In SSMS: right-click LadkiBahinDB
      → Tasks → Import Flat File
   2. Import each CSV into the corresponding raw.* table
   3. On the "Modify Columns" step, set ALL columns to
      nvarchar(max) — do NOT let it auto-detect types yet.
      Type casting happens in Script 04.
   ============================================================ */
