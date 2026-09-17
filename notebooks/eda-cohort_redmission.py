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

# %%
df.info()
df.describe()

# %%
binary_variables = [col for col in df.columns if col.startswith('has_')]
binary_var_df = binary_var_distribution(binary_variables, df)
# %%
