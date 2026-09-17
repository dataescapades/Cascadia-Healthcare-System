-- ============================================================================
-- SCRIPT:      03_readmission_cohort.sql
-- OBJECTIVE:   Materialize Gold analytic cohort with continuous time-to-event
--              intervals, cumulative running-max transfer stitching, lateral
--              ICD-9 array deduplication, and zero-leakage T-1 longitudinal joins.
-- SCHEMA:      cascadia_analytics.cohort_readmission
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS cascadia_analytics;

DROP TABLE IF EXISTS cascadia_analytics.cohort_readmission CASCADE;

CREATE TABLE cascadia_analytics.cohort_readmission AS
WITH 

-- ----------------------------------------------------------------------------
-- 1. CONSOLIDATE SPLIT CLAIMS SEGMENTS INTO SINGLE CLAIM RECORDS
-- ----------------------------------------------------------------------------
claims_deduped AS (
    SELECT 
        desynpuf_id,
        claim_id,
        MIN(admission_date)                                                     AS admission_date,
        MAX(discharge_date)                                                     AS discharge_date,
        (ARRAY_AGG(admit_diagnosis_code ORDER BY claim_segment))[1]             AS admit_diagnosis_code,
        SUM(COALESCE(claim_payment_amount, 0.00))                               AS medicare_payment_amount,
        SUM(COALESCE(primary_payer_paid_amount, 0.00))                          AS primary_insurance_payment_amount,
        SUM(COALESCE(deductible_amount, 0.00))                                  AS deductible_amount,
        SUM(COALESCE(coinsurance_amount, 0.00))                                 AS coinsurance_amount,
        SUM(COALESCE(blood_deductible_amount, 0.00))                            AS blood_deductible_amount,
        -- Aggregate non-null secondary diagnoses across segments
        ARRAY_REMOVE(
            ARRAY_AGG(admit_diagnosis_code) ||
            ARRAY_AGG(icd9_dx_1) || ARRAY_AGG(icd9_dx_2) ||
            ARRAY_AGG(icd9_dx_3) || ARRAY_AGG(icd9_dx_4) ||
            ARRAY_AGG(icd9_dx_5) || ARRAY_AGG(icd9_dx_6) ||
            ARRAY_AGG(icd9_dx_7) || ARRAY_AGG(icd9_dx_8) ||
            ARRAY_AGG(icd9_dx_9) || ARRAY_AGG(icd9_dx_10),
            NULL)                                                               AS raw_all_dx,
        -- Aggregate non-null procedures across segments
        ARRAY_REMOVE(
            ARRAY_AGG(icd9_proc_1) || ARRAY_AGG(icd9_proc_2) ||
            ARRAY_AGG(icd9_proc_3) || ARRAY_AGG(icd9_proc_4) ||
            ARRAY_AGG(icd9_proc_5) || ARRAY_AGG(icd9_proc_6),
            NULL)                                                               AS raw_procedures
    FROM cascadia_lake.fact_inpatient_claims
    GROUP BY desynpuf_id, claim_id),

-- ----------------------------------------------------------------------------
-- 2. DETECT OVERLAPPING / SAME-DAY CLAIMS VIA RUNNING MAX DISCHARGE
-- ----------------------------------------------------------------------------
claims_running_max AS (
    SELECT 
        *,
        MAX(discharge_date) OVER (
            PARTITION BY desynpuf_id 
            ORDER BY admission_date, discharge_date, claim_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)                   AS max_prior_discharge
    FROM claims_deduped),

claims_windowed AS (
    SELECT 
        *,
        CASE 
            WHEN max_prior_discharge IS NULL THEN 1
            WHEN admission_date > max_prior_discharge THEN 1
            ELSE 0 
        END                                                                     AS is_new_episode
    FROM claims_running_max),

episode_groups AS (
    SELECT 
        *,
        SUM(is_new_episode) OVER (
            PARTITION BY desynpuf_id 
            ORDER BY admission_date, discharge_date, claim_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)                   AS episode_id
    FROM claims_windowed),

-- ----------------------------------------------------------------------------
-- 3. UNNEST & DEDUPLICATE CODES ACROSS STITCHED EPISODES
-- ----------------------------------------------------------------------------
episode_diagnoses_unnested AS (
    SELECT 
        eg.desynpuf_id,
        eg.episode_id,
        TRIM(d.dx)                                                              AS dx_code
    FROM episode_groups eg
    CROSS JOIN LATERAL UNNEST(eg.raw_all_dx) AS d(dx)
    WHERE d.dx IS NOT NULL AND TRIM(d.dx) <> ''),

episode_diagnoses_deduped AS (
    SELECT 
        desynpuf_id,
        episode_id,
        ARRAY_AGG(DISTINCT dx_code ORDER BY dx_code)                            AS all_icd9_diagnosis_codes
    FROM episode_diagnoses_unnested
    GROUP BY desynpuf_id, episode_id),

episode_procedures_unnested AS (
    SELECT 
        eg.desynpuf_id,
        eg.episode_id,
        TRIM(p.prcdr)                                                           AS prcdr_code
    FROM episode_groups eg
    CROSS JOIN LATERAL UNNEST(eg.raw_procedures) AS p(prcdr)
    WHERE p.prcdr IS NOT NULL AND TRIM(p.prcdr) <> ''),

episode_procedures_deduped AS (
    SELECT 
        desynpuf_id,
        episode_id,
        ARRAY_AGG(DISTINCT prcdr_code ORDER BY prcdr_code)                      AS procedure_icd9_codes
    FROM episode_procedures_unnested
    GROUP BY desynpuf_id, episode_id),

consolidated_episodes AS (
    SELECT 
        eg.desynpuf_id,
        eg.episode_id,
        MIN(eg.admission_date)                                                  AS admission_date,
        MAX(eg.discharge_date)                                                  AS discharge_date,
        (MAX(eg.discharge_date) - MIN(eg.admission_date))::INTEGER              AS length_of_stay_days,
        (ARRAY_AGG(
            eg.admit_diagnosis_code
            ORDER BY eg.admission_date, eg.claim_id))[1]                        AS admitting_icd9_code,
        SUM(COALESCE(eg.medicare_payment_amount, 0.00))                         AS medicare_payment_amount,
        SUM(
            COALESCE(eg.deductible_amount, 0.00) + 
            COALESCE(eg.coinsurance_amount, 0.00) + 
            COALESCE(eg.blood_deductible_amount, 0.00))                         AS beneficiary_payment_amount,
        SUM(COALESCE(eg.primary_insurance_payment_amount, 0.00))                AS primary_insurance_payment_amount,
        COALESCE(ed.all_icd9_diagnosis_codes, ARRAY[]::VARCHAR[])               AS all_icd9_diagnosis_codes,
        COALESCE(ep.procedure_icd9_codes, ARRAY[]::VARCHAR[])                   AS procedure_icd9_codes
    FROM episode_groups eg
    LEFT JOIN episode_diagnoses_deduped ed
        ON eg.desynpuf_id = ed.desynpuf_id 
        AND eg.episode_id = ed.episode_id
    LEFT JOIN episode_procedures_deduped ep
        ON eg.desynpuf_id = ep.desynpuf_id 
        AND eg.episode_id = ep.episode_id
    GROUP BY 
        eg.desynpuf_id, 
        eg.episode_id, 
        ed.all_icd9_diagnosis_codes, 
        ep.procedure_icd9_codes),

-- ----------------------------------------------------------------------------
-- 4. DIRECTIONAL TIME-TO-EVENT INTERVALS & SUBSEQUENT REIMBURSEMENT
-- ----------------------------------------------------------------------------
episodes_with_outcomes AS (
    SELECT 
        ce.*,
        MD5(ce.desynpuf_id || ce.admission_date::TEXT || ce.episode_id::TEXT)   AS encounter_id,
        EXTRACT(YEAR FROM ce.admission_date)::SMALLINT                          AS admit_year,
        (ce.admission_date - LAG(ce.discharge_date) OVER (
            PARTITION BY ce.desynpuf_id 
            ORDER BY ce.admission_date))::INTEGER                               AS days_since_prior_discharge,
        (LEAD(ce.admission_date) OVER (
            PARTITION BY ce.desynpuf_id 
            ORDER BY ce.admission_date) - ce.discharge_date)::INTEGER           AS days_to_next_admit
    FROM consolidated_episodes ce),

-- ----------------------------------------------------------------------------
-- 5. AGGREGATE STATIC BENEFICIARY PROFILE ACROSS ANNUAL SUMMARIES
-- ----------------------------------------------------------------------------
beneficiary_demographics AS (
    SELECT 
        desynpuf_id,
        MAX(birth_date)                                                         AS birth_date,
        MAX(death_date)                                                         AS death_date,
        MAX(sex)                                                                AS sex,
        MAX(race)                                                               AS race
    FROM cascadia_lake.dim_beneficiary_annual
    GROUP BY desynpuf_id),

-- ----------------------------------------------------------------------------
-- 6. ATTACH LONGITUDINAL BASELINE, DEMOGRAPHICS & COMPETING RISK
-- ----------------------------------------------------------------------------
cohort_with_baseline AS (
    SELECT 
        e.encounter_id,
        e.desynpuf_id,
        e.admission_date,
        e.discharge_date,
        e.length_of_stay_days,
        e.admit_year,
        e.admitting_icd9_code,
        e.all_icd9_diagnosis_codes,
        e.procedure_icd9_codes,
        e.medicare_payment_amount,
        e.beneficiary_payment_amount,
        e.primary_insurance_payment_amount,
        
        -- Invariant Demographics from Master Profile
        EXTRACT(YEAR FROM AGE(e.admission_date, bene.birth_date))::INTEGER      AS age,
        bene.sex::VARCHAR(6)                                                    AS sex,
        bene.race::VARCHAR(16)                                                  AS race,
        bene.birth_date                                                         AS birth_date,
        bene.death_date                                                         AS death_date,
        
        -- Dynamic Geographic & Coverage Attributes from Current Coverage Year
        demo_yr.state_abbr                                                      AS state_abbr,
        demo_yr.county_code                                                     AS county_code,
        
        -- CCW Chronic Condition Flags Strictly from T-1 Lookback
        hist.has_alzheimers                                                     AS has_alzheimers,
        hist.has_chf                                                            AS has_chf,
        hist.has_ckd                                                            AS has_ckd,
        hist.has_cancer                                                         AS has_cancer,
        hist.has_copd                                                           AS has_copd,
        hist.has_depression                                                     AS has_depression,
        hist.has_diabetes                                                       AS has_diabetes,
        hist.has_ischemic_heart                                                 AS has_ischemic_heart,
        hist.has_osteoporosis                                                   AS has_osteoporosis,
        hist.has_arthritis                                                      AS has_arthritis,
        hist.has_stroke                                                         AS has_stroke,
        
        -- Prior-Year Financial Baselines Strictly from T-1 Lookback
        hist.annual_ip_reimbursement                                            AS prior_year_ip_reimbursement,
        hist.annual_op_reimbursement                                            AS prior_year_op_reimbursement,
        
        -- Continuous Outcomes & Competing Risk Intervals
        e.days_since_prior_discharge,
        e.days_to_next_admit,
        (bene.death_date - e.discharge_date)::INTEGER                           AS days_to_death
    FROM episodes_with_outcomes e
    LEFT JOIN beneficiary_demographics bene
        ON e.desynpuf_id = bene.desynpuf_id
    LEFT JOIN cascadia_lake.dim_beneficiary_annual demo_yr
        ON e.desynpuf_id = demo_yr.desynpuf_id 
        AND demo_yr.coverage_year = e.admit_year
    LEFT JOIN cascadia_lake.dim_beneficiary_annual hist
        ON e.desynpuf_id = hist.desynpuf_id 
        AND hist.coverage_year = (e.admit_year - 1)
    WHERE bene.death_date IS NULL OR bene.death_date > e.discharge_date)
SELECT * FROM cohort_with_baseline;

-- ----------------------------------------------------------------------------
-- Performance Indexes for Downstream Extraction
-- ----------------------------------------------------------------------------
CREATE INDEX idx_cohort_desynpuf_id 
    ON cascadia_analytics.cohort_readmission (desynpuf_id);

CREATE INDEX idx_cohort_admission_date 
    ON cascadia_analytics.cohort_readmission (admission_date);

CREATE INDEX idx_cohort_days_to_next 
    ON cascadia_analytics.cohort_readmission (days_to_next_admit);