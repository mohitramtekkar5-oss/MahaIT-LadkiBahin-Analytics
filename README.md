# Mukhyamantri Majhi Ladki Bahin Yojana — End-to-End Data Analytics

![SQL Server](https://img.shields.io/badge/SQL%20Server-2019-blue)
![Python](https://img.shields.io/badge/Python-3.10-green)
![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-yellow)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen)

## Overview
An end-to-end data analytics project on Maharashtra's flagship 
women's welfare scheme — Mukhyamantri Majhi Ladki Bahin Yojana. 
The project simulates the analytical work a Data Analyst at MahaIT 
would perform on the scheme's DBT pipeline data.

## Dataset
- 5,00,000 synthetic beneficiary records (1 record = 50.6 real beneficiaries)
- Anchored to real reported statistics: 2.34 crore applications, 
  ₹33,232 crore disbursed, 26.34 lakh suspended, 14,298 male fraud cases
- Application window: July 1 – October 15, 2024
- 17 installment disbursements tracked through December 2025

## Project Structure
| Phase | Tools | Deliverable |
|-------|-------|-------------|
| Phase 1 — Database Design | SQL Server, SSMS | Star schema DB with 4 tables, 8 views, 12 DQ checks |
| Phase 2 — SQL Analysis | SSMS | 12 analytical queries across 6 topics |
| Phase 3 — Python EDA | Python, Google Colab | 15 charts across 6 analytical themes |
| Phase 4 — Dashboard | Power BI | 4-page interactive dashboard |
| Phase 5 — Recommendations | Word | Policy brief with 5 data-backed recommendations |

## Key Findings
- eKYC failure is the #1 suspension reason (~7.8 lakh real beneficiaries affected)
- Amravati Division has the highest suspension rate (19.96%)
- Gram Panchayat Office registrations have the highest fraud rate
- Nari Shakti Doot App has the lowest fraud rate — digital channels outperform manual
- ST women have the lowest active rate of all caste categories
- Punjab National Bank has the worst DBT success rate (NPCI seeding gap)

## How to Run
### SQL Setup
1. Place CSV files in C:\LadkiBahin\Data\
2. Run SQL scripts 01 → 08 in SSMS in order
3. Script 05 loads 500,000 rows (~60 seconds)

### Python EDA
1. Open LadkiBahin_EDA.ipynb in Google Colab
2. Mount Google Drive and update the BASE path
3. Run all cells in order

### Power BI
1. Open LadkiBahin_Dashboard.pbix in Power BI Desktop
2. Update data source to your local SQL Server instance
3. Refresh data

## Tools Used
- SQL Server 2019 / SSMS 18
- Python 3.10 (pandas, matplotlib, seaborn)
- Power BI Desktop
- Microsoft Excel

## Data Disclaimer
This project uses a synthetic dataset generated using real scheme 
parameters. It is not an official government dataset. All aggregate 
statistics are anchored to publicly reported figures from WCD 
Department press releases and Maharashtra Budget Speech FY2024-25.
