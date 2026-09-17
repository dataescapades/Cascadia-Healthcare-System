-- =========================================================================
-- SCRIPT:      02_data_ingestion.sql
-- OBJECTIVE:   Ingests raw CSV data into staging tables, performs ELT transformations,
--              and populates production tables.
-- DATABASE:    cascadia_db
-- SCHEMA:      cascadia_lake
-- TABLES:      stg_bene_2008, stg_bene_2009, stg_bene_2010, stg_inpatient_claims,
--              dim_beneficiary_annual, fact_inpatient_claims
-- =========================================================================

SET search_path TO cascadia_lake, public;

-- ----------------------------------------------------------------------------
-- 1. POPULATE SSA STATE CODE LOOKUP TABLE
-- ----------------------------------------------------------------------------

INSERT INTO ref_ssa_state_codes (ssa_state_code, state_abbr, state_name)
VALUES
    ('01', 'AL', 'Alabama'),
    ('02', 'AK', 'Alaska'),
    ('03', 'AZ', 'Arizona'),
    ('04', 'AR', 'Arkansas'),
    ('05', 'CA', 'California'),
    ('06', 'CO', 'Colorado'),
    ('07', 'CT', 'Connecticut'),
    ('08', 'DE', 'Delaware'),
    ('09', 'DC', 'District of Columbia'),
    ('10', 'FL', 'Florida'),
    ('11', 'GA', 'Georgia'),
    ('12', 'HI', 'Hawaii'),
    ('13', 'ID', 'Idaho'),
    ('14', 'IL', 'Illinois'),
    ('15', 'IN', 'Indiana'),
    ('16', 'IA', 'Iowa'),
    ('17', 'KS', 'Kansas'),
    ('18', 'KY', 'Kentucky'),
    ('19', 'LA', 'Louisiana'),
    ('20', 'ME', 'Maine'),
    ('21', 'MD', 'Maryland'),
    ('22', 'MA', 'Massachusetts'),
    ('23', 'MI', 'Michigan'),
    ('24', 'MN', 'Minnesota'),
    ('25', 'MS', 'Mississippi'),
    ('26', 'MO', 'Missouri'),
    ('27', 'MT', 'Montana'),
    ('28', 'NE', 'Nebraska'),
    ('29', 'NV', 'Nevada'),
    ('30', 'NH', 'New Hampshire'),
    ('31', 'NJ', 'New Jersey'),
    ('32', 'NM', 'New Mexico'),
    ('33', 'NY', 'New York'),
    ('34', 'NC', 'North Carolina'),
    ('35', 'ND', 'North Dakota'),
    ('36', 'OH', 'Ohio'),
    ('37', 'OK', 'Oklahoma'),
    ('38', 'OR', 'Oregon'),
    ('39', 'PA', 'Pennsylvania'),
    ('41', 'RI', 'Rhode Island'),
    ('42', 'SC', 'South Carolina'),
    ('43', 'SD', 'South Dakota'),
    ('44', 'TN', 'Tennessee'),
    ('45', 'TX', 'Texas'),
    ('46', 'UT', 'Utah'),
    ('47', 'VT', 'Vermont'),
    ('49', 'VA', 'Virginia'),
    ('50', 'WA', 'Washington'),
    ('51', 'WV', 'West Virginia'),
    ('52', 'WI', 'Wisconsin'),
    ('53', 'WY', 'Wyoming'),
    ('54', 'XX', 'Other/Unknown');

-- ----------------------------------------------------------------------------
-- 2. STAGING DEFINITIONS (All TEXT to ensure fault-tolerant CSV ingestion)
-- ----------------------------------------------------------------------------

DROP TABLE IF EXISTS stg_bene_2008;
DROP TABLE IF EXISTS stg_bene_2009;
DROP TABLE IF EXISTS stg_bene_2010;
DROP TABLE IF EXISTS stg_inpatient_claims;

CREATE TABLE stg_bene_2008 (
    DESYNPUF_ID                 TEXT,
    BENE_BIRTH_DT               TEXT,
    BENE_DEATH_DT               TEXT,
    BENE_SEX_IDENT_CD           TEXT,
    BENE_RACE_CD                TEXT,
    BENE_ESRD_IND               TEXT,
    SP_STATE_CODE               TEXT,
    BENE_COUNTY_CD              TEXT,
    BENE_HI_CVRAGE_TOT_MONS     TEXT,
    BENE_SMI_CVRAGE_TOT_MONS    TEXT,
    BENE_HMO_CVRAGE_TOT_MONS    TEXT,
    PLAN_CVRG_MOS_NUM           TEXT,
    SP_ALZHDMTA                 TEXT,
    SP_CHF                      TEXT,
    SP_CHRNKIDN                 TEXT,
    SP_CNCR                     TEXT,
    SP_COPD                     TEXT,
    SP_DEPRESSN                 TEXT,
    SP_DIABETES                 TEXT,
    SP_ISCHMCHT                 TEXT,
    SP_OSTEOPRS                 TEXT,
    SP_RA_OA                    TEXT,
    SP_STRKETIA                 TEXT,
    MEDREIMB_IP                 TEXT,
    BENRES_IP                   TEXT,
    PPPYMT_IP                   TEXT,
    MEDREIMB_OP                 TEXT,
    BENRES_OP                   TEXT,
    PPPYMT_OP                   TEXT,
    MEDREIMB_CAR                TEXT,
    BENRES_CAR                  TEXT,
    PPPYMT_CAR                  TEXT);

CREATE TABLE stg_bene_2009 (LIKE stg_bene_2008);
CREATE TABLE stg_bene_2010 (LIKE stg_bene_2008);

CREATE TABLE stg_inpatient_claims (
    DESYNPUF_ID                     TEXT,
    CLM_ID                          TEXT,
    SEGMENT                         TEXT,
    CLM_FROM_DT                     TEXT,
    CLM_THRU_DT                     TEXT,
    PRVDR_NUM                       TEXT,
    CLM_PMT_AMT                     TEXT,
    NCH_PRMRY_PYR_CLM_PD_AMT        TEXT,
    AT_PHYSN_NPI                    TEXT,
    OP_PHYSN_NPI                    TEXT,
    OT_PHYSN_NPI                    TEXT,
    CLM_ADMSN_DT                    TEXT,
    ADMTNG_ICD9_DGNS_CD             TEXT,
    CLM_PASS_THRU_PER_DIEM_AMT      TEXT,
    NCH_BENE_IP_DDCTBL_AMT          TEXT,
    NCH_BENE_PTA_COINSRNC_LBLTY_AM  TEXT,
    NCH_BENE_BLOOD_DDCTBL_LBLTY_AM  TEXT,
    CLM_UTLZTN_DAY_CNT              TEXT,
    NCH_BENE_DSCHRG_DT              TEXT,
    CLM_DRG_CD                      TEXT,
    ICD9_DGNS_CD_1                  TEXT,
    ICD9_DGNS_CD_2                  TEXT,
    ICD9_DGNS_CD_3                  TEXT,
    ICD9_DGNS_CD_4                  TEXT,
    ICD9_DGNS_CD_5                  TEXT,
    ICD9_DGNS_CD_6                  TEXT,
    ICD9_DGNS_CD_7                  TEXT,
    ICD9_DGNS_CD_8                  TEXT,
    ICD9_DGNS_CD_9                  TEXT,
    ICD9_DGNS_CD_10                 TEXT,
    ICD9_PRCDR_CD_1                 TEXT,
    ICD9_PRCDR_CD_2                 TEXT,
    ICD9_PRCDR_CD_3                 TEXT,
    ICD9_PRCDR_CD_4                 TEXT,
    ICD9_PRCDR_CD_5                 TEXT,
    ICD9_PRCDR_CD_6                 TEXT,
    HCPCS_CD_1                      TEXT,
    HCPCS_CD_2                      TEXT,
    HCPCS_CD_3                      TEXT,
    HCPCS_CD_4                      TEXT,
    HCPCS_CD_5                      TEXT,
    HCPCS_CD_6                      TEXT,
    HCPCS_CD_7                      TEXT,
    HCPCS_CD_8                      TEXT,
    HCPCS_CD_9                      TEXT,
    HCPCS_CD_10                     TEXT,
    HCPCS_CD_11                     TEXT,
    HCPCS_CD_12                     TEXT,
    HCPCS_CD_13                     TEXT,
    HCPCS_CD_14                     TEXT,
    HCPCS_CD_15                     TEXT,
    HCPCS_CD_16                     TEXT,
    HCPCS_CD_17                     TEXT,
    HCPCS_CD_18                     TEXT,
    HCPCS_CD_19                     TEXT,  
    HCPCS_CD_20                     TEXT,
    HCPCS_CD_21                     TEXT,
    HCPCS_CD_22                     TEXT,
    HCPCS_CD_23                     TEXT,
    HCPCS_CD_24                     TEXT,
    HCPCS_CD_25                     TEXT,
    HCPCS_CD_26                     TEXT,
    HCPCS_CD_27                     TEXT,
    HCPCS_CD_28                     TEXT,
    HCPCS_CD_29                     TEXT,
    HCPCS_CD_30                     TEXT,
    HCPCS_CD_31                     TEXT,
    HCPCS_CD_32                     TEXT,
    HCPCS_CD_33                     TEXT,
    HCPCS_CD_34                     TEXT,
    HCPCS_CD_35                     TEXT,
    HCPCS_CD_36                     TEXT,
    HCPCS_CD_37                     TEXT,
    HCPCS_CD_38                     TEXT,
    HCPCS_CD_39                     TEXT,
    HCPCS_CD_40                     TEXT,
    HCPCS_CD_41                     TEXT,
    HCPCS_CD_42                     TEXT,
    HCPCS_CD_43                     TEXT,
    HCPCS_CD_44                     TEXT,
    HCPCS_CD_45                     TEXT);

-- ----------------------------------------------------------------------------
-- 3. BULK INGESTION (psql syntax - paths relative to project root)
-- ----------------------------------------------------------------------------

\copy stg_bene_2008 FROM 'data/raw/DE1_0_2008_Beneficiary_Summary_File_Sample_1.csv' WITH (FORMAT csv, HEADER true);
\copy stg_bene_2009 FROM 'data/raw/DE1_0_2009_Beneficiary_Summary_File_Sample_1.csv' WITH (FORMAT csv, HEADER true);
\copy stg_bene_2010 FROM 'data/raw/DE1_0_2010_Beneficiary_Summary_File_Sample_1.csv' WITH (FORMAT csv, HEADER true);
\copy stg_inpatient_claims FROM 'data/raw/DE1_0_2008_to_2010_Inpatient_Claims_Sample_1.csv' WITH (FORMAT csv, HEADER true);

-- ----------------------------------------------------------------------------
-- 4. ELT PROJECTION: dim_beneficiary_annual
-- ----------------------------------------------------------------------------

WITH raw_unioned AS (
    SELECT 2008 AS coverage_year, * FROM stg_bene_2008
    UNION ALL
    SELECT 2009 AS coverage_year, * FROM stg_bene_2009
    UNION ALL
    SELECT 2010 AS coverage_year, * FROM stg_bene_2010)
INSERT INTO dim_beneficiary_annual (
    desynpuf_id,
    coverage_year,
    birth_date,
    death_date,
    sex,
    race,
    state_abbr,
    county_code,
    has_esrd,
    part_a_coverage_months,
    part_b_coverage_months,
    hmo_coverage_months,
    part_d_coverage_months,
    has_alzheimers,
    has_chf,
    has_ckd,
    has_cancer,
    has_copd,
    has_depression,
    has_diabetes,
    has_ischemic_heart,
    has_osteoporosis,
    has_arthritis,
    has_stroke,
    annual_ip_reimbursement,
    annual_ip_beneficiary_resp,
    annual_ip_primary_payer_amt,
    annual_op_reimbursement,
    annual_op_beneficiary_resp,
    annual_op_primary_payer_amt,
    annual_carrier_reimbursement,
    annual_carrier_beneficiary_resp,
    annual_carrier_primary_payer_amt)
SELECT
    UPPER(TRIM(u.desynpuf_id))                              AS desynpuf_id,
    u.coverage_year::SMALLINT                               AS coverage_year,
    TO_DATE(NULLIF(TRIM(u.bene_birth_dt), ''), 'YYYYMMDD')  AS birth_date,
    TO_DATE(NULLIF(TRIM(u.bene_death_dt), ''), 'YYYYMMDD')  AS death_date,
    CASE TRIM(u.bene_sex_ident_cd) 
        WHEN '1' THEN 'Male' 
        WHEN '2' THEN 'Female' 
        ELSE NULL 
    END                                                     AS sex,
    CASE TRIM(u.bene_race_cd)
        WHEN '1' THEN 'White'
        WHEN '2' THEN 'Black'
        WHEN '3' THEN 'Other'
        WHEN '5' THEN 'Hispanic'
        ELSE NULL
    END                                                     AS race,
    s.state_abbr                                            AS state_abbr,
    LPAD(TRIM(u.bene_county_cd), 3, '0')                    AS county_code,
    CASE UPPER(TRIM(u.bene_esrd_ind))
        WHEN 'Y' THEN 1
        WHEN '0' THEN 0
        ELSE NULL
    END                                                     AS has_esrd,
    NULLIF(TRIM(u.bene_hi_cvrage_tot_mons), '')::SMALLINT   AS part_a_coverage_months,
    NULLIF(TRIM(u.bene_smi_cvrage_tot_mons), '')::SMALLINT  AS part_b_coverage_months,
    NULLIF(TRIM(u.bene_hmo_cvrage_tot_mons), '')::SMALLINT  AS hmo_coverage_months,
    NULLIF(TRIM(u.plan_cvrg_mos_num), '')::SMALLINT         AS part_d_coverage_months,
    CASE TRIM(u.sp_alzhdmta)
        WHEN '1' THEN 1
        WHEN '2' THEN 0
        ELSE NULL
    END                                                     AS has_alzheimers,
    CASE TRIM(u.sp_chf)
        WHEN '1' THEN 1
        WHEN '2' THEN 0
        ELSE NULL
    END                                                     AS has_chf,
    CASE TRIM(u.sp_chrnkidn)
        WHEN '1' THEN 1
        WHEN '2' THEN 0
        ELSE NULL
    END                                                     AS has_ckd,
    CASE TRIM(u.sp_cncr)
        WHEN '1' THEN 1
        WHEN '2' THEN 0
        ELSE NULL
    END                                                     AS has_cancer,
    CASE TRIM(u.sp_copd)
        WHEN '1' THEN 1
        WHEN '2' THEN 0
        ELSE NULL
    END                                                     AS has_copd,
    CASE TRIM(u.sp_depressn)
        WHEN '1' THEN 1
        WHEN '2' THEN 0
        ELSE NULL
    END                                                     AS has_depression,
    CASE TRIM(u.sp_diabetes)
        WHEN '1' THEN 1
        WHEN '2' THEN 0
        ELSE NULL
    END                                                     AS has_diabetes,
    CASE TRIM(u.sp_ischmcht)
        WHEN '1' THEN 1
        WHEN '2' THEN 0
        ELSE NULL
    END                                                     AS has_ischemic_heart,
    CASE TRIM(u.sp_osteoprs)
        WHEN '1' THEN 1
        WHEN '2' THEN 0
        ELSE NULL
    END                                                     AS has_osteoporosis,
    CASE TRIM(u.sp_ra_oa)
        WHEN '1' THEN 1
        WHEN '2' THEN 0
        ELSE NULL
        END                                                 AS has_arthritis,
    CASE TRIM(u.sp_strketia)
        WHEN '1' THEN 1
        WHEN '2' THEN 0
        ELSE NULL
    END                                                     AS has_stroke,
    NULLIF(TRIM(u.medreimb_ip), '')::NUMERIC                AS annual_ip_reimbursement,
    NULLIF(TRIM(u.benres_ip), '')::NUMERIC                  AS annual_ip_beneficiary_resp,
    NULLIF(TRIM(u.pppymt_ip), '')::NUMERIC                  AS annual_ip_primary_payer_amt,
    NULLIF(TRIM(u.medreimb_op), '')::NUMERIC                AS annual_op_reimbursement,
    NULLIF(TRIM(u.benres_op), '')::NUMERIC                  AS annual_op_beneficiary_resp,
    NULLIF(TRIM(u.pppymt_op), '')::NUMERIC                  AS annual_op_primary_payer_amt,
    NULLIF(TRIM(u.medreimb_car), '')::NUMERIC               AS annual_carrier_reimbursement,
    NULLIF(TRIM(u.benres_car), '')::NUMERIC                 AS annual_carrier_beneficiary_resp,
    NULLIF(TRIM(u.pppymt_car), '')::NUMERIC                 AS annual_carrier_primary_payer_amt
FROM raw_unioned u
LEFT JOIN ref_ssa_state_codes s 
    ON LPAD(TRIM(u.sp_state_code), 2, '0') = s.ssa_state_code;

-- ----------------------------------------------------------------------------
-- 5. ELT PROJECTION: fact_inpatient_claims
-- ----------------------------------------------------------------------------
INSERT INTO fact_inpatient_claims (
    claim_id,
    claim_segment,
    desynpuf_id,
    admission_date,
    discharge_date,
    claim_from_date,
    claim_thru_date,
    provider_number,
    claim_payment_amount,
    primary_payer_paid_amount,
    attending_physician_npi,
    operating_physician_npi,
    other_physician_npi,
    admit_diagnosis_code,
    per_diem_pass_thru_amount,
    deductible_amount,
    coinsurance_amount,
    blood_deductible_amount,
    utilization_day_count,
    drg_code,
    icd9_dx_1,
    icd9_dx_2,
    icd9_dx_3,
    icd9_dx_4,
    icd9_dx_5,
    icd9_dx_6,
    icd9_dx_7,
    icd9_dx_8,
    icd9_dx_9,
    icd9_dx_10,
    icd9_proc_1,
    icd9_proc_2,
    icd9_proc_3,
    icd9_proc_4,
    icd9_proc_5,
    icd9_proc_6)
SELECT
    UPPER(TRIM(clm_id))                                         AS claim_id,
    TRIM(segment)::SMALLINT                                     AS claim_segment,
    UPPER(TRIM(desynpuf_id))                                    AS desynpuf_id,
    TO_DATE(NULLIF(TRIM(clm_admsn_dt), ''), 'YYYYMMDD')         AS admission_date,
    TO_DATE(NULLIF(TRIM(nch_bene_dschrg_dt), ''), 'YYYYMMDD')   AS discharge_date,
    TO_DATE(NULLIF(TRIM(clm_from_dt), ''), 'YYYYMMDD')          AS claim_from_date,
    TO_DATE(NULLIF(TRIM(clm_thru_dt), ''), 'YYYYMMDD')          AS claim_thru_date,
    NULLIF(UPPER(TRIM(prvdr_num)), '')                          AS provider_number,
    NULLIF(TRIM(clm_pmt_amt), '')::NUMERIC                      AS claim_payment_amount,
    NULLIF(TRIM(nch_prmry_pyr_clm_pd_amt), '')::NUMERIC         AS primary_payer_paid_amount,
    NULLIF(UPPER(TRIM(at_physn_npi)), '')                       AS attending_physician_npi,
    NULLIF(UPPER(TRIM(op_physn_npi)), '')                       AS operating_physician_npi,
    NULLIF(UPPER(TRIM(ot_physn_npi)), '')                       AS other_physician_npi,
    NULLIF(UPPER(TRIM(admtng_icd9_dgns_cd)), '')                AS admit_diagnosis_code,
    NULLIF(TRIM(clm_pass_thru_per_diem_amt), '')::NUMERIC       AS per_diem_pass_thru_amount,
    NULLIF(TRIM(nch_bene_ip_ddctbl_amt), '')::NUMERIC           AS deductible_amount,
    NULLIF(TRIM(nch_bene_pta_coinsrnc_lblty_am), '')::NUMERIC   AS coinsurance_amount,
    NULLIF(TRIM(nch_bene_blood_ddctbl_lblty_am), '')::NUMERIC   AS blood_deductible_amount,
    NULLIF(TRIM(clm_utlztn_day_cnt), '')::INTEGER               AS utilization_day_count,
    NULLIF(UPPER(TRIM(clm_drg_cd)), '')                         AS drg_code,
    NULLIF(UPPER(TRIM(icd9_dgns_cd_1)), '')                     AS icd9_dx_1,
    NULLIF(UPPER(TRIM(icd9_dgns_cd_2)), '')                     AS icd9_dx_2,
    NULLIF(UPPER(TRIM(icd9_dgns_cd_3)), '')                     AS icd9_dx_3,
    NULLIF(UPPER(TRIM(icd9_dgns_cd_4)), '')                     AS icd9_dx_4,
    NULLIF(UPPER(TRIM(icd9_dgns_cd_5)), '')                     AS icd9_dx_5,
    NULLIF(UPPER(TRIM(icd9_dgns_cd_6)), '')                     AS icd9_dx_6,
    NULLIF(UPPER(TRIM(icd9_dgns_cd_7)), '')                     AS icd9_dx_7,
    NULLIF(UPPER(TRIM(icd9_dgns_cd_8)), '')                     AS icd9_dx_8,
    NULLIF(UPPER(TRIM(icd9_dgns_cd_9)), '')                     AS icd9_dx_9,
    NULLIF(UPPER(TRIM(icd9_dgns_cd_10)), '')                    AS icd9_dx_10,
    NULLIF(UPPER(TRIM(icd9_prcdr_cd_1)), '')                    AS icd9_proc_1,
    NULLIF(UPPER(TRIM(icd9_prcdr_cd_2)), '')                    AS icd9_proc_2,
    NULLIF(UPPER(TRIM(icd9_prcdr_cd_3)), '')                    AS icd9_proc_3,
    NULLIF(UPPER(TRIM(icd9_prcdr_cd_4)), '')                    AS icd9_proc_4,
    NULLIF(UPPER(TRIM(icd9_prcdr_cd_5)), '')                    AS icd9_proc_5,
    NULLIF(UPPER(TRIM(icd9_prcdr_cd_6)), '')                    AS icd9_proc_6
FROM stg_inpatient_claims;

-- ----------------------------------------------------------------------------
-- 6. TEARDOWN STAGING TABLES
-- ----------------------------------------------------------------------------

DROP TABLE stg_bene_2008;
DROP TABLE stg_bene_2009;
DROP TABLE stg_bene_2010;
DROP TABLE stg_inpatient_claims;