USE LadkiBahinDB;
GO

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


SELECT * FROM rpt.v_status_breakdown
ORDER BY Beneficiary_Count DESC;
GO


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


SELECT
    Check_ID,
    Check_Name,
    Expected_Value,
    Actual_Value,
    Status
FROM audit.dq_results
ORDER BY Check_ID;
GO


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
