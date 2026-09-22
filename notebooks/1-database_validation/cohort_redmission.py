# %%
from src.utils.database import get_engine
from src.utils.data_prep import binary_var_distribution
import pandas as pd

# %%
engine = get_engine()

# %%
query = "SELECT * FROM cascadia_analytics.cohort_readmission;"

with engine.connect() as conn:
    df = pd.read_sql(query, conn, dtype_backend="pyarrow")

readmit_df = df[df['days_to_next_admit'] <= 30]
not_readmit_df = df[df['days_to_next_admit'].isna() | (df['days_to_next_admit'] > 30)]

# %%
df.info()
# %%
readmit_df.info()

# %%
not_readmit_df.info()

# %%
df.describe()

# %%
readmit_df.describe()

# %%
not_readmit_df.describe()

# %%
binary_variables = [col for col in df.columns if col.startswith('has_')]

binary_var_df = binary_var_distribution(binary_variables, df)
readmit_binary_df = binary_var_distribution(binary_variables, readmit_df)
not_readmit_binary_df = binary_var_distribution(binary_variables, not_readmit_df)

print(binary_var_df)
print(readmit_binary_df)
print(not_readmit_binary_df)

# %%
