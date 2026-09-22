# Methodology
## Database

## Overview
This file documents steps and decisions made in the .sql scripts, from database creation through final analytics tables used for Python imports.

The database follows a medallion structure:
- **Bronze** - staging tables - dropped after ingestion into the silver layer to save local disk space. The original dataset is preserved in the downloaded files for auditability.
- **Silver** - cascadia_lake - minimal processing and cleaning
- **Gold** - cascadia_analytics - cleaned and engineered for Python importation

This separation was designed to preserve the original data as much as possible in the Silver layer. This allows for the most flexibility in analytics tables and ensures transparency of the impact of any cleaning steps (ie null handling) on the analytics.

## 00_init_db.sql
Basic script to initialize the database if it's not already created.

## 01_schema_ddl.sql (Silver Layer)
Creates the schema for the silver layer, cascadia_lake. Three tables are defined, one for beneficiary summaries, one for inpatient claims, and a lookup table for state codes. The only fields requiring NOT NULL are primary keys, ensuring values are not imputed at this stage. Additionally, no default values are set because it does not require handling of new data, and it follows the previous NULL handling guideline.

Allowing for nulls at this stage ensures analysis can clearly evaluate tradeoffs on imputation on a case-by-case basis. At this stage, filling nulls could alter the data without clear understanding of the implications and no clear trail of the changes without reviewing the original dataset.

Column names were altered for clarity in analysis and datatypes were chosen consistent with the dataset and reducing storage requirements. All columns are retained from the original dataset except those that are null for all records (HCPCS_CD_*). This ensures all data is available for analysis should new questions arise.

The beneficiary summary table uses the state abbreviation instead of the code for readability. It also contains a new field for coverage year to allow for all three years in the same table.

### Potential Future Improvement

During later steps in the project, it was recognized that the Silver Layer would benefit from a beneficiary_master table to capture features that do not change, pending validation of the dataset (ie birth date, death date, race, and sex). It was decided that altering the schema was not worth the time investment at this time. However, if the database were to be used in future projects or go to production, this should be reevaluated for refactoring.

## 02_data_ingestion.sql (Silver Layer)
### State Lookup Table
The state lookup table was populated with the data provided in the CMS DE-SynPUF documentation.

### Staging Tables
Staging tables were creating using all text fields to ensure ingestion. Field names and order match those in the CMS DE-SynPUF documentation for clarity and validation. Capitalization was retained in defining the tables, though Postgres automatically converts them to lower. Again, this was chosen to simplify validation. Note that three staging tables were created for the beneficiary summaries, one for each year's dataset.

### Ingestion
The datasets were ingested into the staging tables with no alterations.

### ELT - Beneficiary Summary
#### Coverage Year
A CTE was used to union the three beneficiary summary tables, imputing the year to coverage_year.

#### Cleaning Choices
- **TRIM** - All fields used TRIM to remove extra whitespace.
- **Nulls** - All fields except primary keys (desynpuf_id and coverage_year) have a NULL case or NULLIF.
- **LPAD** - LPAD is used for the state code and county code fields have a consistent number of digits to meet CHAR requirements in the schema.

#### State Abbreviation
The state lookup table is left joined on the state code to pull the corresponding state abbreviation into the final table.

### ELT - Inpatient Claims
- **TRIM** - All fields used TRIM to remove extra whitespace.
- **Nulls** - All fields except primary keys (desynpuf_id, claim_id, and claim_segment) use NULLIF.
- **UPPER** - CHAR and VARCHAR fields applied UPPER to ensure consistency for querying. While many should not contain letters, the schema does not enforce numeric values.

### Drop Staging Tables
Staging tables were dropped as the original data is retained in the csv files. The state lookup table was retained for future use and reference if needed.

## 03_readmission_cohort.sql (Gold Layer)
### Feature Engineering and Extraction
This script creates the Gold Layer for analysis. The goal was to consolidate multiple records for the same inpatient stay into a single record. It also pulls data from the previous year's beneficiary summary, avoiding temporal leakage, and ensures 2008 records were filled with NULL values for beneficiary summary fields. This ensured clarity that this data was not available, as there were no 2007 beneficiary summaries in the dataset. In choosing what features to engineer, this step was limited to data that provides wide use and applicability to analysis projects. Anything that requires model input or parameters to define was left for either Parquet files or separate tables designed for specific model input.

#### Consolidate Claims into a Single Inpatient Stay
One of the key factors being analyzed is readmissions. To determine if a patient is readmitted within 30 days, we need to ensure a patient was discharged, not transferred. We also need to consolidate claims segments and possible overlapping claims. This was achieved through a series of steps:

- **Segments** - consolidated into a single record, summing dollar amounts, MIN/MAX for admission/discharge dates, and aggregating dx and procedure codes into arrays with nulls removed.
- **Episodes** - New episodes were defined as non-overlapping claims with admission at least one day after discharge. An episode ID was assigned to each record by partitioning by patient and ordering by admission, discharge, and claim_id. A running max was created on the discharge date and a binary new episode flag was created by comparing the admission date and max prior discharge date. A running sum of the binary new episode flag assigned an episode ID to each record, only increasing when the next admission was at least 1 day after the previous max prior discharge. The episodes were then consolidated. MIN/MAX was used for admission/discharge dates. Dx and procedure codes were aggregated into arrays, removing nulls and duplicates. Financial data was summed, consolidating the claim payment amount, the beneficiary payment amount, and the total cost of the stay.

#### Temporal Feature Engineering
With the claims consolidated by stay, a unique encounter ID was created. Admission year and month were extracted into separate columns and days since previous admission and days to next admission were engineered for lookahead and lookback analyses.

#### Beneficiary CTE
To facilitate creation of a field calculating days to death, a CTE with beneficiary features that should generally be static was created.
