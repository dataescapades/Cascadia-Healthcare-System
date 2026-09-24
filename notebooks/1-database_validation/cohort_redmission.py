# %% [markdown]
## Cohort Readmission Validation and EDA

# %%
from src.utils.database import get_engine
from src.utils.eda import binary_var_distribution
import pandas as pd

# %% [markdown]
### Load and filter cohort datasets

# %%
engine = get_engine()

# %%
# Load the cohort readmission data from the database
query = "SELECT * FROM cascadia_analytics.cohort_readmission;"

with engine.connect() as conn:
    df = pd.read_sql(query, conn)

# %%
# Convert date features to datetime objects
date_features = [col for col in df.columns if col.endswith('_date')]

for col in date_features:
    df[col] = pd.to_datetime(df[col])

# %%
# Split the data into readmitted and not readmitted cohorts based on days_to_next_admit
readmit_df = df[df['days_to_next_admit'] <= 30]
not_readmit_df = df[df['days_to_next_admit'].isna() | (df['days_to_next_admit'] > 30)]

# %% [markdown]
### .info() on full, readmitted, and not readmitted cohorts

# %%
print("Full Cohort Info:")
print(df.info())
print()
print("Readmitted Cohort Info:")
print(readmit_df.info())
print()
print("Not Readmitted Cohort Info:")
print(not_readmit_df.info())

# %% [markdown]
### Unique Beneficiaries

# %%
print("Unique Beneficiaries in Full Cohort:", df['desynpuf_id'].nunique())
print("Unique Beneficiaries in Readmitted Cohort:", readmit_df['desynpuf_id'].nunique())

# %% [markdown]
### Distribution of binary variables across full, readmitted, and not readmitted cohorts

# %%
binary_variables = [col for col in df.columns if col.startswith('has_')]

binary_var_df = binary_var_distribution(binary_variables, df)
readmit_binary_df = binary_var_distribution(binary_variables, readmit_df)
not_readmit_binary_df = binary_var_distribution(binary_variables, not_readmit_df)

condition_percentages = pd.DataFrame({
    'variable': binary_variables,
    'full': binary_var_df['percent_with_condition'],
    'readmitted': readmit_binary_df['percent_with_condition'],
    'not_readmitted': not_readmit_binary_df['percent_with_condition']})

print(condition_percentages)

# %% [markdown]
### Distribution of categorical variables across full, readmitted, and not readmitted cohorts

# %%
sex_df = pd.DataFrame({
    'full': df['sex'].value_counts(normalize=True),
    'readmitted': readmit_df['sex'].value_counts(normalize=True),
    'not_readmitted': not_readmit_df['sex'].value_counts(normalize=True)})

race_df = pd.DataFrame({
    'full': df['race'].value_counts(normalize=True),
    'readmitted': readmit_df['race'].value_counts(normalize=True),
    'not_readmitted': not_readmit_df['race'].value_counts(normalize=True)})

state_df = pd.DataFrame({
    'full': df['state_abbr'].value_counts(normalize=True),
    'readmitted': readmit_df['state_abbr'].value_counts(normalize=True),
    'not_readmitted': not_readmit_df['state_abbr'].value_counts(normalize=True)})

print("Sex Distribution:")
print(sex_df)
print()
print("Race Distribution:")
print(race_df)
print()
print("State Distribution:")
print(state_df)

# %% [markdown]
### Summary statistics for numeric variables across full, readmitted, and not readmitted cohorts

# %%
numeric_features = [
    'length_of_stay_days',
    'medicare_payment_amount',
    'beneficiary_payment_amount',
    'primary_insurance_payment_amount',
    'age',
    'prior_year_ip_reimbursement',
    'prior_year_op_reimbursement',
    'days_since_prior_discharge',
    'days_to_next_admit',
    'days_to_death']

for col in numeric_features:
    col_df = pd.DataFrame({
        'full': df[col].describe(),
        'readmitted': readmit_df[col].describe(),
        'not_readmitted': not_readmit_df[col].describe()
    })
    print(f"Summary for {col}:")
    print(col_df)
    print()

# %%
