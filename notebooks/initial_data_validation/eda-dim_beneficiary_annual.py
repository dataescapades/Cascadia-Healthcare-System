# %%
# Import necessary libraries
import os
from dotenv import load_dotenv, find_dotenv
import pandas as pd
from sqlalchemy import create_engine, URL, text
import matplotlib.pyplot as plt
import seaborn as sns

# %%
# Locate and load the .env file from the project root
load_dotenv(find_dotenv())

# Construct the connection object without hardcoded strings
connection_url = URL.create(
    drivername="postgresql+psycopg2",
    username=os.getenv("PGUSER"),
    password=os.getenv("PGPASSWORD"),
    host=os.getenv("PGHOST"),
    port=int(os.getenv("PGPORT", 5432)),
    database=os.getenv("PGDATABASE"))

# Initialize the SQLAlchemy engine
engine = create_engine(connection_url)

# %%
# Query data into Pandas
query = "SELECT * FROM cascadia_lake.dim_beneficiary_annual;"

with engine.connect() as conn:
    df = pd.read_sql(text(query), conn, dtype_backend="pyarrow")

# Set date columns to datetime format
df['birth_date'] = pd.to_datetime(df['birth_date'], errors='coerce')
df['death_date'] = pd.to_datetime(df['death_date'], errors='coerce')

# %%
# Basic EDA
df.info()
df.describe()

# %%
# Visualize the distribution of binary variables
binary_variables = [col for col in df.columns if col.startswith('has_')]

value_counts_dict = {}
for var in binary_variables:
    # value counts
    value_counts_dict[var] = df[var].value_counts()

value_counts_df = pd.DataFrame(value_counts_dict).T.fillna(0)
plt.figure(figsize=(12, 8))
value_counts_df.plot(kind='bar', stacked=True, ax=plt.gca())
plt.title("Distribution of Binary Variables")
plt.xlabel("Variables")
plt.ylabel("Count")
plt.legend(title="Values")
plt.show()


# %%
# Visualize the distribution of annual variables
annual_variables = [col for col in df.columns if col.startswith('annual_')]

fig, axes = plt.subplots(3, 3, figsize=(15, 10))
axes = axes.flatten()

for i, var in enumerate(annual_variables):
    sns.boxplot(data=df, y=var, ax=axes[i])
    axes[i].set_title(f"Distribution of {var}")
    axes[i].set_ylabel("Values")

plt.tight_layout()
plt.show()

# %%
