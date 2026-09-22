# Cascadia Health System
***Inpatient Readmissions: Preliminary Opportunity Assessment***

An enterprise clinical data science pipeline evaluating acute 30-day readmissions across Medicare beneficiaries. Built on the CMS De-identified Synthetic Public Use Files (DE-SynPUF), this repository models financial risk under a Medicare Shared Savings Program (MSSP) Accountable Care Organization (ACO) framework.

---

## Scenario Overview

*Note: This repository models an enterprise operational scenario using the CMS 2008–2010 Medicare De-Identified Synthetic Public Use Files (DE-SynPUF). All organizational structures, operational targets, and clinical workflows are simulated.*

Cascadia Health System operates as a Medicare Shared Savings Program (MSSP) Accountable Care Organization (ACO) under a two-sided financial risk model. In this arrangement, acute 30-day all-cause readmissions function as direct expenditures against Cascadia’s assigned annual Medicare Part A benchmark (~$12,000 to $15,000 direct cost per index readmission). Unplanned readmissions directly deplete shared savings distributions and expose the health system to shared loss penalties.

To mitigate financial exposure and improve patient transitions, Cascadia is evaluating investments in enhanced post-discharge care programs. This project delivers an analytical foundation to inform both executive budgetary planning and clinical care management triage:
* **Macro Budgetary Allocation (Executive / Finance):** Longitudinal forecasting of readmission volume and Part A expenditure exposure to size investments and staffing for transitional care initiatives.
* **Micro Clinical Triage (Bedside / Care Management):** Supervised risk stratification and comorbidity phenotyping to direct care coordinators toward high-probability patients and tailor follow-up interventions prior to discharge.

---

## Project Architecture

Production analytical workflows require strict separation between exploratory prototyping and reproducible code execution. This codebase is decoupled into modular Python packages, ordered SQL scripts, and declarative configuration schemas orchestrated via CLI entry points.

### Engineering Standards & Experimental Rigor

Coming from wet-lab biological research and intelligence analysis, my baseline expectation is reproducible science and clean data provenance. In clinical analytics, a model is only as dependable as the pipeline behind it.

I built this repository to avoid the "hidden state" and configuration drift common in loose data science workflows:

- **Modular Architecture (`src/`, `sql/`, `scripts/` vs. `notebooks/`):**  
  Notebooks are used strictly as scratchpads for initial exploratory analysis. All production steps—database schema design, cohort creation, feature engineering, modeling, and evaluation—are decoupled into modular Python packages and ordered SQL scripts orchestrated via CLI entry points.

- **Proactive Config Controls (`model_configs/`):**  
  Instead of digging through post-run logs to figure out why an experiment shifted, parameters are controlled upfront. Runs use a "Base-and-Delta" pattern via YAML anchors: a shared baseline defines global controls, and individual experiments specify only what changes. Pydantic schemas validate types and feature sets before execution so pipelines fail fast instead of breaking mid-run.

- **End-to-End Methodological Lineage (`docs/`):**  
  Treated like an operational laboratory notebook. It documents the analytical chain of custody across every phase: ELT design and clinical code grouping rationales, model specifications (time-series forecasting, predictive readmission triage, and unsupervised patient phenotyping), and bias audit protocols—ensuring clinical SMEs and technical auditors can trace every insight directly back to source claims.

- **Locked Environments (`pyproject.toml`, `environment.yaml`):**  
  Strict dependency locking guarantees runs execute identically across environments without silent package breaks.

### Mirrored Pipeline Stages

To ensure seamless navigation and maintain an auditable analytical chain of custody, the repository enforces a mirrored stage numbering convention across execution entry points, modular logic, and methodology dossiers. As downstream modeling and governance stages are introduced, they follow this exact structure:

| Stage | Execution CLI (`scripts/`) | Production Logic (`src/`) | Methodology Dossier (`docs/`) | Exploratory Notebooks |
| :--- | :--- | :--- | :--- | :--- |
| **1. Database & Cohort** | `scripts/1-build_db.py` | `src/1-database/` | `docs/methodology/1-database.md` | `notebooks/1-database_validation/` |
| **2. Feature Engineering** | `scripts/2-build_features.py` | `src/2-feature_engineering/` | `docs/methodology/2-feature_engineering.md` | `notebooks/2-feature_engineering/` |

> **Navigation Rule:** For any pipeline stage **`N`**, the CLI orchestrator in `scripts/N_*` executes the modular logic defined in `src/N-*/`, while the corresponding dossier in `docs/methodology/N-*.md` serves as the operational lab notebook detailing clinical rationale, trade-offs, and validation diagnostics.


### Repository Layout

```text
├── environment.yaml            # Conda environment specification
├── pyproject.toml              # Build dependencies and package metadata
├── .env                        # key/values for Postgres database connection
├── data/                       # Datasets used throughout project
├── docs/
│   ├── assets/                 # Visuals used in documentation
│   └── methodology/            # In-depth methodology discussions
├── model_configs/              # Pydantic-validated YAML execution configs
├── notebooks/                  # EDA scratchpads and distribution profiling
├── outputs/                    # Pipeline run artifacts (logs, metrics, models)
├── scripts/                    # CLI orchestrators of src subfolder files
└── src/                        # Modular production code
    └── utils/                  # Shared database engines and data prep utilities
```

---

## Dataset & Data Handling

### Data Provenance (CMS DE-SynPUF)
This project uses the *CMS 2008–2010 Medicare De-Identified Synthetic Public Use Files (DE-SynPUF) Sample 1, linking multi-year beneficiary summaries (demographics, chronic conditions) with longitudinal inpatient claims (diagnoses, procedures, reimbursements).

### Database Architecture (Medallion Structure)
The PostgreSQL database follows an ELT Medallion design prioritizing data fidelity—preserving raw structures to minimize early bias and avoid unverified assumptions:

* **Bronze (Staging):** Ingests raw CSVs into untyped text tables matching CMS specs. Tables are dropped post-ingestion to conserve local storage while retaining source files for auditability.

* **Silver (`cascadia_lake`):** Normalized, typed tables across claims and annual summaries. Missing values are strictly retained as `NULL`s (no synthetic defaults or premature imputation) to allow downstream feature pipelines to evaluate imputation trade-offs transparently.

* **Gold (`cascadia_analytics`):** A consolidated, patient-encounter analytics mart. Deferring model-specific parameters to later stages, this layer transforms transactional billing lines into continuous clinical episodes.

### Analytic Cohort Engineering
Rather than hardcoding rigid targets early, the Gold layer (`src/1-database/03_readmission_cohort.sql`) constructs clean encounter units while eliminating temporal leakage:

* **Episode & Transfer Consolidation:** Multiple claim segments and overlapping hospital transfers are merged into distinct acute stays using running-max discharge windows.

* **Leakage-Free Baselines:** Chronic conditions and beneficiary features are joined strictly from the **prior year's** summary (2008 admissions intentionally retain `NULL`s to reflect true historical absence).

* **Flexible Interval Metrics:** Features such as `days_to_next_admission` and `days_since_previous_admission` are engineered as continuous intervals rather than fixed binary cutoffs, preserving flexibility for multi-window analyses (30/60/90 days) downstream.

> *For the complete schema DDL, episode windowing logic, and trade-off rationales, see [docs/methodology/01-database.md](docs/methodology/1-database.md).*

---

## Modeling & Analysis Strategy
The downstream analytical phase applies complementary quantitative methods to address budgetary, operational, and clinical questions. Detailed specifications, hypotheses, and diagnostic findings are documented in the respective methodology dossiers.

### SARIMA (Readmission Expenditure Forecasting)

**Status:** Planned — Dossier in development.

**Objective:** Forecast monthly readmission volume and associated Part A financial debits to inform transitional care staffing and executive budget allocation.

**Exploratory Focus:** Evaluating monthly versus quarterly aggregation windows; testing seasonal decomposition against baseline naive and exponential smoothing models.

**Key Considerations:** Accounting for synthetic temporal artifacts, claim lag, and structural breaks in time-series claims data.

### XGBoost & SHAP (Clinical Risk Stratification & Explainability)

**Status:** Planned — Dossier in development.

**Objective:** Predict patient-level 30-day readmission probability at discharge to triage care coordinator follow-up queues; extract local SHAP values to identify primary risk drivers.

**Exploratory Focus:** Managing severe class imbalance; feature engineering across chronic condition burdens and prior healthcare utilization; threshold tuning aligned with care coordinator capacity.

**Key Considerations:** Guarding against lookahead leakage across multi-year claims; probability calibration (Brier score) for clinical credibility.

### Agglomerative Clustering (Comorbidity Phenotyping):

**Status:** Planned — Dossier in development.

**Objective:** Identify recurring multimorbidity profiles among readmitted patients to inform specialized transitional care pathways and targeted patient education materials.

**Exploratory Focus:** Evaluating distance metrics suitable for binary chronic condition flags (e.g., Jaccard vs. Gower); establishing clinically interpretable cluster boundaries.

**Key Considerations:** High-dimensional sparsity; avoiding clusters driven purely by age rather than distinct clinical syndromic patterns.

### Fairlearn (Algorithmic Governance & Disparity Audit):

**Status:** Planned — Dossier in development.

**Objective:** Audit the XGBoost risk model across demographic groups (e.g., age strata, sex proxies) to ensure predictive accuracy is equitable and post-discharge interventions are distributed fairly.

**Exploratory Focus:** Quantifying False Negative Rate (FNR) disparities to prevent the systemic under-triage of vulnerable populations; evaluating post-processing threshold optimization.

**Key Considerations:** Intersectional sample sizes within synthetic files; clinical trade-offs between demographic parity and predictive precision.

### Tableau (Executive & Clinical Dashboards):

**Status:** Planned.

**Objective:** Translate pipeline outputs into an operational BI tool featuring an executive KPI view (spend trends, budget variance) and a clinical worklist view (daily triage queues with SHAP driver tags).

**Exploratory Focus:** Designing intuitive visual hierarchies for non-technical clinical managers.

---

## Reproducibility & Quickstart
### Prerequisites

* Python 3.12+
* PostgreSQL 16+
* Conda

### 1. Environment Setup
```text
# Clone the repository
git clone https://github.com/your-username/cascadia-readmissions-pipeline.git
cd cascadia-readmissions-pipeline

# Create and activate environment
conda env create -f environment.yaml
conda activate health_analytics
```

### 2. Configure Environment Variables
Copy the example environment configuration and supply local PostgreSQL credentials:
```text
cp .env.example .env
```

Update .env with your local database connection parameters:
```text
PGHOST=localhost
PGPORT=5432
PGDATABASE=cascadia_db
PGUSER=your_username
PGPASSWORD=your_password
```

### 3. Build Database & Cohort Marts
Execute the database orchestrator CLI to initialize schemas, run migrations, and build the Gold analytical cohort:

```text
python scripts/1-build_db.py
```

---

## Implementation Roadmap
- [x] Phase 1: Database Architecture & ELT Lineage (COMPLETE)

    - [x] Relational schema DDL and Silver Layer ingestion

    - [x] Gold 30-day readmission cohort derivation mart

    - [x] Exploratory data analysis and cohort validation reports

- [ ] Phase 2: Feature Engineering (IN PROGRESS)

    - [ ] Map ICD9 codes to chronic condition codes for comorbidity cluster analysis

    - [ ] Finalize and engineer service line feature

- [ ] Phase 3: Modeling (PLANNED)

    - [ ] SARIMA - Financial Time-Series Forecasting

    - [ ] XGBoost/SHAP - Patient Readmission Risk Forecasting

    - [ ] Agglomerative Clustering - Comorbidity Analysis

- [ ] Phase 4: Fairlearn - XGBoost Fairness Audit (PLANNED)

    - [ ] Fairlearn demographic parity and False Negative Rate disparity audit

- [ ] Phase 5: Operational Delivery & Visualization (PLANNED)

    - [ ] Tableau executive KPI and clinical care coordinator dashboards

    - [ ] End-to-end pipeline execution CLI (scripts/run_pipeline.py)