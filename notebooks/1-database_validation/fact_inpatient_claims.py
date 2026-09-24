# %% [markdown]
## Fact Inpatient Claims Validation and EDA

# %%
from src.utils.database import get_engine
import pandas as pd
from src.utils.eda import numeric_variable_histograms, numeric_variable_boxplots

# %% [markdown]
### Load dataset

# %%
engine = get_engine()

# Query data into Pandas
query = "SELECT * FROM cascadia_lake.fact_inpatient_claims;"

with engine.connect() as conn:
    df = pd.read_sql(query, conn, dtype_backend="pyarrow")

date_columns = ['admission_date', 'discharge_date', 'claim_from_date', 'claim_thru_date']

for col in date_columns:
    df[col] = pd.to_datetime(df[col], errors='coerce')

# %% [markdown]
### Basic EDA

# %%
df.info()
# %%
df.describe()

# %% [markdown]
### Visualize Distributions of financial variables

# %%
# Plot with histograms of financial fields
financial_fields = [
    'claim_payment_amount', 'primary_payer_paid_amount', 'per_diem_pass_thru_amount',
    'deductible_amount', 'coinsurance_amount', 'blood_deductible_amount']

numeric_variable_histograms(financial_fields, df)
numeric_variable_boxplots(financial_fields, df)

# %%
