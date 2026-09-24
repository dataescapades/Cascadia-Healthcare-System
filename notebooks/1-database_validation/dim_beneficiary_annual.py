# %% [markdown]
## Dim Beneficiary Annual Validation and EDA

# %%
from src.utils.database import get_engine
import pandas as pd
from src.utils.eda import binary_var_distribution, numeric_variable_histograms, numeric_variable_boxplots

# %% [markdown]
### Load dataset

# %%
engine = get_engine()

# %%
# Query data into Pandas
query = "SELECT * FROM cascadia_lake.dim_beneficiary_annual;"

with engine.connect() as conn:
    df = pd.read_sql(query, conn, dtype_backend="pyarrow")

# Set date columns to datetime format
df['birth_date'] = pd.to_datetime(df['birth_date'], errors='coerce')
df['death_date'] = pd.to_datetime(df['death_date'], errors='coerce')

# %% [markdown]
### Basic EDA
# %%
df.info()

# %%
df.describe()

# %% [markdown]
### Visualize Distributions of binary and annual variables

# %%
# Visualize the distribution of binary variables
binary_variables = [col for col in df.columns if col.startswith('has_')]
binary_var_distribution(binary_variables, df)

# Visualize the distribution of annual variables
annual_variables = [col for col in df.columns if col.startswith('annual_')]
numeric_variable_histograms(annual_variables, df)
numeric_variable_boxplots(annual_variables, df)

# %%
