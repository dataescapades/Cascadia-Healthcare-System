-- =========================================================================
-- SCRIPT:      01_schema_ddl.sql
-- OBJECTIVE:   Creates the schema and tables for the Cascadia Lake data warehouse.
-- SCHEMA:      cascadia_db.cascadia_lake
-- TABLES:      ref_ssa_state_codes, dim_beneficiary_annual, fact_inpatient_claims
-- =========================================================================

CREATE SCHEMA IF NOT EXISTS cascadia_lake;
SET search_path TO cascadia_lake, public;

-- Clean rebuild of production tables
DROP TABLE IF EXISTS fact_inpatient_claims CASCADE;
DROP TABLE IF EXISTS dim_beneficiary_annual CASCADE;
DROP TABLE IF EXISTS ref_ssa_state_codes CASCADE;

-- ----------------------------------------------------------------------------
-- 1. Reference Table: SSA State Code Lookup
-- ----------------------------------------------------------------------------

CREATE TABLE ref_ssa_state_codes (
    ssa_state_code CHAR(2) PRIMARY KEY,
    state_abbr     CHAR(2),
    state_name     VARCHAR(32));

-- ----------------------------------------------------------------------------
-- 2. Dimension Table: Longitudinal Beneficiary Annual Summary
-- ----------------------------------------------------------------------------

CREATE TABLE dim_beneficiary_annual (
    desynpuf_id                         VARCHAR(32) NOT NULL,
    coverage_year                       SMALLINT NOT NULL,
    birth_date                          DATE,
    death_date                          DATE,
    sex                                 VARCHAR(6),
    race                                VARCHAR(16),
    state_abbr                          CHAR(2),
    county_code                         CHAR(3),
    has_esrd                            SMALLINT,
    part_a_coverage_months              SMALLINT,
    part_b_coverage_months              SMALLINT,
    hmo_coverage_months                 SMALLINT,
    part_d_coverage_months              SMALLINT,
    has_alzheimers                      SMALLINT,
    has_chf                             SMALLINT,
    has_ckd                             SMALLINT,
    has_cancer                          SMALLINT,
    has_copd                            SMALLINT,
    has_depression                      SMALLINT,
    has_diabetes                        SMALLINT,
    has_ischemic_heart                  SMALLINT,
    has_osteoporosis                    SMALLINT,
    has_arthritis                       SMALLINT,
    has_stroke                          SMALLINT,
    annual_ip_reimbursement             NUMERIC(12, 2),
    annual_ip_beneficiary_resp          NUMERIC(12, 2),
    annual_ip_primary_payer_amt         NUMERIC(12, 2),
    annual_op_reimbursement             NUMERIC(12, 2),
    annual_op_beneficiary_resp          NUMERIC(12, 2),
    annual_op_primary_payer_amt         NUMERIC(12, 2),
    annual_carrier_reimbursement        NUMERIC(12, 2),
    annual_carrier_beneficiary_resp     NUMERIC(12, 2),
    annual_carrier_primary_payer_amt    NUMERIC(12, 2),
    CONSTRAINT pk_dim_beneficiary PRIMARY KEY (desynpuf_id, coverage_year));

-- ----------------------------------------------------------------------------
-- 3. Fact Table: Inpatient Claims (Encounter Level)
-- ----------------------------------------------------------------------------

CREATE TABLE fact_inpatient_claims (
    claim_id                     VARCHAR(32) NOT NULL,
    claim_segment                SMALLINT NOT NULL,
    desynpuf_id                  VARCHAR(32) NOT NULL,
    admission_date               DATE,
    discharge_date               DATE,
    claim_from_date              DATE,
    claim_thru_date              DATE,
    provider_number              VARCHAR(10),
    claim_payment_amount         NUMERIC(12, 2),
    primary_payer_paid_amount    NUMERIC(12, 2),
    attending_physician_npi      VARCHAR(10),
    operating_physician_npi      VARCHAR(10),
    other_physician_npi          VARCHAR(10),
    admit_diagnosis_code         VARCHAR(10),
    per_diem_pass_thru_amount    NUMERIC(12, 2),
    deductible_amount            NUMERIC(12, 2),
    coinsurance_amount           NUMERIC(12, 2),
    blood_deductible_amount      NUMERIC(12, 2),
    utilization_day_count        INTEGER,
    drg_code                     VARCHAR(5),
    icd9_dx_1                    VARCHAR(10),
    icd9_dx_2                    VARCHAR(10),
    icd9_dx_3                    VARCHAR(10),
    icd9_dx_4                    VARCHAR(10),
    icd9_dx_5                    VARCHAR(10),
    icd9_dx_6                    VARCHAR(10),
    icd9_dx_7                    VARCHAR(10),
    icd9_dx_8                    VARCHAR(10),
    icd9_dx_9                    VARCHAR(10),
    icd9_dx_10                   VARCHAR(10),
    icd9_proc_1                  VARCHAR(10),
    icd9_proc_2                  VARCHAR(10),
    icd9_proc_3                  VARCHAR(10),
    icd9_proc_4                  VARCHAR(10),
    icd9_proc_5                  VARCHAR(10),
    icd9_proc_6                  VARCHAR(10),
    CONSTRAINT pk_fact_inpatient PRIMARY KEY (claim_id, claim_segment));

-- Primary Performance Indexes for Windowing & Joining
CREATE INDEX idx_dim_bene_temporal ON dim_beneficiary_annual (desynpuf_id, coverage_year);
CREATE INDEX idx_fact_claims_bene  ON fact_inpatient_claims (desynpuf_id, admission_date, claim_id);
CREATE INDEX idx_fact_claims_dschrg ON fact_inpatient_claims (discharge_date);