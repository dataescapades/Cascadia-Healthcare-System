# %% [markdown]
## Demographics Feature Engineering

# %%
# import libraries
from src.utils.database import get_engine
from src.utils.eda import numeric_variable_histograms, numeric_variable_boxplots
import pandas as pd
import gc
import numpy as np

# %% [markdown]
### Load and filter cohort datasets

# %%
engine = get_engine()

# %%
# Load the cohort readmission data from the database
query = "SELECT * FROM cascadia_analytics.cohort_readmission;"

with engine.connect() as conn:
    df = pd.read_sql(query, conn)

# Convert date features to datetime objects
date_features = [col for col in df.columns if col.endswith('_date')]

for col in date_features:
    df[col] = pd.to_datetime(df[col])

# %% [markdown]
### Create SSA and FIPS codes

# %%
# Concatenate SSA state and county codes to create SSA code
df['ssa_code'] = df['ssa_state_code'] + df['ssa_county_code']

# Map SSA codes to FIPS codes
fips_codes = pd.read_csv('../../data/raw/ssa_fips_state_county2011.csv', dtype=str)
fips_codes = fips_codes.drop(0)     # drop first row - empty
df['fips_code'] = df['ssa_code'].map(fips_codes.set_index('ssacounty')['fipscounty'])
# %%
# delete fips_codes dataframe to free up memory
del fips_codes
gc.collect()

# %% [markdown]
### Map SAIPE data to FIPS codes

# %%
# import SAIPE data
saipe_data = pd.read_excel('../../data/raw/est10all.xls', dtype=str, header=2)

# zero-fill State and County FIPS codes and create combined FIPS code
saipe_data['State FIPS'] = saipe_data['State FIPS'].str.zfill(2)
saipe_data['County FIPS'] = saipe_data['County FIPS'].str.zfill(3)
saipe_data['fips_code'] = saipe_data['State FIPS'] + saipe_data['County FIPS']

# drop final 3 rows of the SAIPE data - summary information
saipe_data = saipe_data.iloc[:-3]

# convert '.' to NaN
saipe_data.replace('.', pd.NA, inplace=True)

# %% [markdown]
#### Analyze and rank poverty percentages

# %%
# summary statistics on poverty pct - column indices 7-9
poverty_pct = saipe_data.iloc[:, 7:10].astype(float)
poverty_pct.describe()

# %%
# visualize the distribution of poverty percentages
numeric_variable_histograms(variables=poverty_pct.columns, df=poverty_pct, bins=20)
numeric_variable_boxplots(variables=poverty_pct.columns, df=poverty_pct)

# assign poverty rank by 'Poverty Percent All Ages' distribution
Q1 = poverty_pct['Poverty Percent All Ages'].quantile(0.25)
Q2 = poverty_pct['Poverty Percent All Ages'].quantile(0.5)
Q3 = poverty_pct['Poverty Percent All Ages'].quantile(0.75)
IQR = Q3 - Q1
lower_threshold = Q1 - 1.5 * IQR
upper_threshold = Q3 + 1.5 * IQR

rank_cutoffs = [lower_threshold, Q1, Q2, Q3, upper_threshold]

saipe_data['poverty_rank'] = pd.cut(
    x=poverty_pct['Poverty Percent All Ages'],
    bins=sorted(set([-np.inf] + rank_cutoffs + [np.inf])),
    labels=range(len(rank_cutoffs) + 1))

# drop the poverty_pct dataframe to free up memory
del poverty_pct
gc.collect()

# %% [markdown]
#### Analyze and rank Median Household Income

# %%
# summary statistics on median household income - column indices 22-24
median_income = saipe_data.iloc[:, 22:25].astype(float)
median_income.describe()

# %%
# visualize the distribution of median household income
numeric_variable_histograms(variables=median_income.columns, df=median_income, bins=20)
numeric_variable_boxplots(variables=median_income.columns, df=median_income)

# %%
Q1 = median_income['Median Household Income'].quantile(0.25)
Q2 = median_income['Median Household Income'].quantile(0.5)
Q3 = median_income['Median Household Income'].quantile(0.75)
IQR = Q3 - Q1
lower_threshold = Q1 - 1.5 * IQR
upper_threshold = Q3 + 1.5 * IQR

rank_cutoffs = [lower_threshold, Q1, Q2, Q3, upper_threshold]

saipe_data['median_income_rank'] = pd.cut(
    x=median_income['Median Household Income'],
    bins=sorted(set([-np.inf] + rank_cutoffs + [np.inf])),
    labels=range(len(rank_cutoffs) + 1))

# drop the median_income dataframe to free up memory
del median_income
gc.collect()

# %% [markdown]
#### Join poverty and median income ranks to the main dataframe on FIPS code

# %%
df = df.merge(
    saipe_data[['fips_code', 'poverty_rank', 'median_income_rank']],
    on='fips_code',
    how='left')

# drop SAIPE data to free up memory
del saipe_data
gc.collect()

# %%
df['poverty_rank'].value_counts(dropna=False)

# %%
