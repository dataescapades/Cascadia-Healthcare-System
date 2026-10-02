# Methodology: Features

## Demographics
One aspect that should be considered for the fairlearn audit is income and geographic information. The dataset contains the SSA state and county codes, which can be mapped to FIPS codes and then income and urban/rural classifications.

### Datasets
| Dataset | Description | File Name | Website Link |
| :--- | :--- | :--- | :--- |
| NBER FIPS Crosswalk | 2011 CSV | ssa_fips_state_county2011.csv | [FIPS](https://www.nber.org/research/data/ssa-federal-information-processing-series-fips-state-and-county-crosswalk) |
| SAIPE | 2010 US and All States and Counties | est10all.xls | [SAIPE](https://www.census.gov/data/datasets/2010/demo/saipe/2010-state-and-county.html) |
| RUCC | 2013 Urban/Rural | ruralurbancodes2013.xls | [RUCC](https://www.ers.usda.gov/data-products/rural-urban-continuum-codes) |

### FIPS Codes
Mapping the SSA codes to FIPS codes presented a few complications. The CMS dataset is 2008-2010, during which time no crosswalk tables were published. However, 2010 was a census year. The 2011 CMS crosswalk table, 2010 SAIPE dataset, and 2013 RUCC urban/rural dataset all reflect updates at the 2010 census. While it does present some inconsistencies, with a few SSA county codes not mapping to FIPS codes, it provides a consistent baseline overlapping with the end of the dataset's timeframe.

### Area-Level Socioeconomic Feature Engineering

### Area-Level Socioeconomic Features

To audit readmission disparities across community economic tiers, two candidate features were engineered from the 2010 Census SAIPE county dataset:
* `median_income_rank`: Discretized from county *Median Household Income*.
* `poverty_rank`: Discretized from county *Poverty Percent All Ages* (the only broad, non-child poverty metric available in annual county SAIPE files).

#### Discretization Logic
County metrics were mapped to an ordinal 0–5 scale using standard Tukey boxplot fences:
* **0:** Extreme low outlier ($< Q1 - 1.5 \times \text{IQR}$)
* **1:** Inner lower quartile ($[Q1 - 1.5 \times \text{IQR},\; Q1)$)
* **2:** Below median ($[Q1,\; Q2)$)
* **3:** Above median ($[Q2,\; Q3)$)
* **4:** Inner upper quartile ($[Q3,\; Q3 + 1.5 \times \text{IQR})$)
* **5:** Extreme high outlier ($> Q3 + 1.5 \times \text{IQR}$)

This preserves standard quartiles while isolating distribution extremes. Tail bin counts and sparsity will be checked in EDA before finalizing these bins for modeling.

#### Rationale & Limitations
* **Area-Level SDOH, Not Patient Income:** These metrics represent local infrastructure and environment (e.g., primary care access, pharmacy availability, outpatient resources), not individual beneficiary wealth. High-income patients living in under-resourced counties still face systemic care-coordination barriers post-discharge.
* **Candidate Staging:** Both features are candidates for now. Because county poverty and median income are strongly correlated, collinearity checks and bivariate readmission trends in EDA will determine whether one or both are kept for the final model and fairness audits.

### RUCC