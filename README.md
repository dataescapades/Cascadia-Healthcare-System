# Cascadia Health System
## Inpatient 30-Day Readmission Analytics & Pipeline

A reproducible clinical data engineering pipeline and analytics mart evaluating acute 30-day all-cause readmissions across Medicare beneficiaries. Built on the CMS De-identified Synthetic Public Use Files (DE-SynPUF), this repository models institutional readmission exposure under a two-sided Medicare Shared Savings Program (MSSP) Accountable Care Organization (ACO) framework.

---

### Project Status: Phase 1 Shipped
* **Phase 1: Database Architecture & Analytic Cohort Engineering** — **Complete**
* **Phase 2: Feature Store & Clinical Code Grouping** — *In Progress*
* **Phase 3: Risk Stratification, Time-Series Forecasting & Governance** — *Planned*

---

## Operational Context

In a two-sided MSSP ACO arrangement, acute 30-day all-cause readmissions function as direct expenditures against the health system's annual Medicare Part A benchmark (averaging ~$12,000 to $15,000 per index readmission). Unplanned returns deplete shared savings distributions and expose the organization to shared loss penalties.

This project models the analytical infrastructure required to support two distinct operational decision points:
1. **Executive / Budgetary Planning:** Macro-level longitudinal forecasting of readmission volume and Part A expenditure exposure to allocate clinical care management budgets.
2. **Follow-Up Care Management Triage:** Micro-level risk stratification at discharge to prioritize transitional care interventions for high-risk patients after they leave the acute setting.

---

## Gold Mart Summary & Cohort Validation

Phase 1 establishes the relational schema, ingests raw CMS files through a PostgreSQL Medallion architecture, and derives a consolidated encounter-level analytic mart (`cascadia_analytics.cohort_readmissions`). 

The summary metrics below reflect the completed Phase 1 cohort derivation from CMS DE-SynPUF Sample 1 (2008–2010 claims):

| Metric | Cohort Value | Operational Definition |
| :--- | :--- | :--- |
| **Total Inpatient Claim Lines** | `66,773` | Raw institutional Part A claims in Silver layer |
| **Full Cohort: Consolidated Acute Episodes** | `64,552` | Distinct acute stays after running-max transfer collapse |
| **Full Cohort: Unique Beneficiaries** | `37,779` | Distinct Medicare beneficiaries with an index admission |
| **Full Cohort: Median Days to Readmission** | `88` | Time-to-event interval among all readmitted beneficiaries |
| **Readmitted Cohort: Consolidated Acute Episodes** | `6,386 (~9.89%)` | Distinct acute stays of beneficiaries readmitted within 30 days of discharge |
| **Readmitted Cohort: Unique Beneficiaries** | `5,054` | Distinct Medicare beneficiaries readmitted within 30 days of discharge |
| **Readmitted Cohort: Median Days to Readmission** | `13` | Time-to-event interval among beneficiaries readmitted within 30 days of discharge |

> Detailed data distribution checks, null-rate profiling, and table integrity audits are available in the validation notebooks:
> `notebooks/1-database_validation/` (covering Inpatient Claims, Beneficiary Summaries, and the Gold Analytic Mart).

---

## Clinical Data Engineering & Analytical Hygiene

Administrative claims data present structural challenges that compromise predictive modeling if treated like standard tabular data. Phase 1 implements strict safeguards to enforce clinical validity and prevent target leakage:

* **Transfer & Episode Consolidation:** CMS claims frequently split continuous acute episodes across multiple billing lines or hospital-to-hospital transfers. The Gold cohort consolidates overlapping or adjacent stays using running-max discharge windows, preventing artificial inflation of readmission rates.
* **Temporal Leakage Elimination ($Y-1$ Baseline Joins):** Chronic condition flags and annual reimbursement features are joined strictly from the *prior calendar year's* summary ($Y-1$). Contemporaneous joins introduce target leakage by encoding survival and late-diagnosed conditions into early index admissions. Baseline admissions in 2008 deliberately retain `NULL` histories rather than imputing artificial baselines.
* **Continuous Interval Tracking:** Rather than imposing fixed 30-day binary targets early, intervals (`days_to_next_admission`, `days_since_previous_admission`) are calculated as continuous integer metrics. This preserves analytical flexibility for downstream multi-window modeling (e.g., 30, 60, 90 days).
* **Declarative Configuration & Type Safety:** Analytical pipelines use Pydantic schemas to validate data contracts and configuration parameters prior to execution, avoiding runtime failures in downstream modeling runs.

*For the complete schema definitions, SQL migration scripts, and clinical grouping rationales, see the [Stage 1 Methodology Dossier](docs/methodology/1-database.md).*

---

## Data Realities & Analytical Boundaries

Administrative claims data differ fundamentally from electronic health records (EHR). While this pipeline models post-discharge triage and enterprise spend, several structural constraints shape the analytical design:

* **Claims vs. Bedside Clinical EHR:** True inpatient bedside triage relies on rich, real-time EHR data (e.g., vital sign trajectories, lab panels, nursing acuity flowsheets) that do not exist in claims files. In their absence, this project uses secondary ICD-9 diagnostic codes and chronic condition flags as proxy risk indicators.
* **Temporal Lag & Chronic Baselines:** Administrative claims are subject to adjudication runout and billing lag. To model a patient's pre-admission baseline without contemporaneous leakage, the pipeline joins Chronic Condition Warehouse (CCW) flags strictly from the prior calendar year ($Y-1$). This trades immediate visibility for strict temporal hygiene.
* **Synthetic Artifacts (DE-SynPUF):** To protect beneficiary privacy, CMS introduces intentional perturbation and synthetic noise into DE-SynPUF. While encounter structures and financial totals mirror realistic distributions, clinical associations are synthetic and intended solely for pipeline prototyping and software evaluation.

---
## Technical Architecture & Pipeline Organization

The pipeline enforces modularity, isolating ad-hoc exploration from production SQL transformations and Python orchestration.

### Directory Layout

    ├── environment.yaml            # Conda environment specification
    ├── pyproject.toml              # Package dependencies and project metadata
    ├── .env.example                # Template for local database credentials
    ├── docs/
    │   ├── assets/                 # Architecture and distribution diagrams
    │   └── methodology/            # In-depth analytical dossiers and clinical rationales
    ├── model_configs/              # Pydantic-validated YAML execution parameters
    ├── notebooks/                  # EDA scratchpads and distribution profiling
    ├── scripts/                    # CLI orchestrators for pipeline stages
    ├── sql/                        # Schema DDL, indexing, and migration scripts
    └── src/                        # Modular pipeline packages
        ├── 1-database/             # Medallion DDL and cohort derivation logic
        ├── 2-features/             # ICD-9 groupings, CCW flags, and utilization metrics
        └── utils/                  # Shared database engines and logging utilities

### Mirrored Pipeline Stages

To maintain an auditable analytical chain of custody, execution CLI scripts, modular source logic, and documentation follow a consistent stage structure:

| Stage | CLI Orchestrator | Production Logic | Methodology Dossier | Focus Area | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1. Database & Cohort** | [`scripts/1-build_db.py`](scripts/1-build_db.py) | [`src/1-database/`](src/1-database/) | [`docs/methodology/1-database.md`](docs/methodology/1-database.md) | Medallion ingestion, cohort logic | **Complete** |
| **2. Feature Store** | [`scripts/2-build_features.py`](scripts/2-build_features.py) | [`src/2-features/`](src/2-features/) | [`docs/methodology/2-features.md`](docs/methodology/2-features.md) | ICD-9 maps, CCW flags, utilization | *In Progress* |
| **3a. Longitudinal Spend** | `scripts/3a-run_forecasting.py` | `src/models/3a-forecasting/` | `docs/methodology/3a-forecasting.md` | SARIMA expenditure trajectories | *Planned* |
| **3b1. Bedside Risk Triage** | `scripts/3b1-run_risk_triage.py` | `src/models/3b1-risk_triage/` | `docs/methodology/3b1-risk_triage.md` | XGBoost 30-day classification & SHAP | *Planned* |
| **3b2. Algorithmic Governance** | `scripts/3b2-audit_fairness.py` | `src/models/3b2-fairness/` | `docs/methodology/3b2-fairness.md` | Fairlearn disparity & subgroup parity | *Planned* |
| **3c. Comorbidity Clustering** | `scripts/3c-run_phenotyping.py` | `src/models/3c-phenotyping/` | `docs/methodology/3c-phenotyping.md` | Hierarchical multimorbidity phenotyping | *Planned* |

---

## Analytical Roadmap

Downstream modeling addresses the dual operational challenges outlined above:

| Method | Target | Clinical / Operational Objective | Primary Consideration |
| :--- | :--- | :--- | :--- |
| **3a - SARIMA** | Monthly Part A Readmission Spend | Budget allocation and care coordinator staffing sizing | Structural shifts and claims runout lag |
| **3b1 - XGBoost + SHAP** | Patient-level 30-day readmission risk | Discharge triage and follow-up queue prioritization | Severe class imbalance; probability calibration |
| **3b2 - Fairlearn** | Model performance parity across demographics | Preventing systematic under-triage of vulnerable demographics | False Negative Rate (FNR) parity vs. predictive precision |
| **3c - Agglomerative Clustering** | Multimorbidity diagnostic profiles | Tailored transitional care pathways for clinical sub-cohorts | Jaccard/Gower distances over sparse binary flags |
| **Tableau** | Executive KPIs & Clinical Worklists | Operationalizing triage lists for care management teams | Workflow-integrated UI design for clinical staff |

---

## Reproducibility & Quickstart

### Environment Setup
Clone Repository:
```text
git clone https://github.com/dataescapades/Cascadia-Healthcare-System
cd Cascadia-Healthcare-System
```

Build conda environment:
```text
conda env create -f environment.yaml
conda activate health_analytics_env
```

### Database Configuration
Create a .env file in the project root:
```text
cp .env.example .env
```

Configure local PostgreSQL connection parameters:
```text
PGHOST=localhost
PGPORT=5432
PGDATABASE=cascadia_db
PGUSER=your_username
PGPASSWORD=your_password
```

### Download Datasets
Download CMS De-SynPUF Sample 1 inpatient claims and beneficiary summary files from the [CMS website](https://www.cms.gov/data-research/statistics-trends-and-reports/medicare-claims-synthetic-public-use-files/cms-2008-2010-data-entrepreneurs-synthetic-public-use-file-de-synpuf/de10-sample-1). Unzip and save the CSV files to data/raw/ and ensure the file names match those provided below.

* **Inpatient Claims**: `DE1_0_2008_to_2010_Inpatient_Claims_Sample_1.csv`
* **Beneficiary Summary 2008**: `DE1_0_2008_Beneficiary_Summary_File_Sample_1.csv`
* **Beneficiary Summary 2009:** `DE1_0_2009_Beneficiary_Summary_File_Sample_1.csv`
* **Beneficiary Summary 2010:** `DE1_0_2010_Beneficiary_Summary_File_Sample_1.csv`


### Initialize Database & Generate Gold Cohort
Run the stage 1 orchestrator to build schemas, run migrations, and assemble the analytic mart:
```text
python scripts/1-build_db.py
```

---

## Data Attribution & Governance
This project utilizes the CMS 2008–2010 Data Entrepreneurs’ Synthetic Public Use Files (DE-SynPUF), accessed under the [CMS Public Use File Disclaimer and User Agreement](https://www.cms.gov/files/document/pufdisclaimerpdf). In accordance with CMS terms:
* **No Re-Identification or Linkage:** Users agree not to attempt to identify any individual, provider, or establishment, nor link these data to external person-level records.
* **Disclaimer:** Findings and methodologies presented here are solely those of the author and do not reflect the endorsement or official views of CMS or HHS.
* **Code & Pipeline:** Open-source software released under the [MIT License](LICENSE).