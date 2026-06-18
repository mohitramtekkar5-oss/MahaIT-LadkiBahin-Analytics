USE master;
GO

-- ── Drop and recreate database (dev only) ───────────────────
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'LadkiBahinDB')
BEGIN
    ALTER DATABASE LadkiBahinDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE LadkiBahinDB;
    PRINT '>> Existing LadkiBahinDB dropped.';
END
GO

CREATE DATABASE LadkiBahinDB
    COLLATE SQL_Latin1_General_CP1_CI_AS;
GO

PRINT '>> LadkiBahinDB created.';

USE LadkiBahinDB;
GO

-- ── Schemas ─────────────────────────────────────────────────
-- raw    : staging tables (direct CSV imports, no constraints)
-- dbo    : cleaned, production tables with full constraints
-- rpt    : reporting views (used by Power BI / Excel)
-- audit  : data quality and fraud tracking tables

CREATE SCHEMA raw;
GO
CREATE SCHEMA rpt;
GO
CREATE SCHEMA audit;
GO

PRINT '>> Schemas created: raw, dbo (default), rpt, audit.';
GO
