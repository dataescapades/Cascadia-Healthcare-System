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
query = "SELECT * FROM cascadia_lake.fact_inpatient_claims;"

with engine.connect() as conn:
    df = pd.read_sql(text(query), conn, dtype_backend="pyarrow")

# %%
date_columns = ['admission_date', 'discharge_date', 'claim_from_date', 'claim_thru_date']

for col in date_columns:
    df[col] = pd.to_datetime(df[col], errors='coerce')

# %%
# Basic EDA
df.info()
df.describe()

# %%
# Plot with histograms of financial fields
financial_fields = [
    'claim_payment_amount', 'primary_payer_paid_amount', 'per_diem_pass_thru_amount',
    'deductible_amount', 'coinsurance_amount', 'blood_deductible_amount']

plt.figure(figsize=(15, 10))

for i, field in enumerate(financial_fields, 1):
    plt.subplot(2, 3, i)
    plt.hist(df[field], bins=50)
    plt.title(f'Distribution of {field}')
    plt.xlabel(field)
    plt.ylabel('Frequency')

plt.tight_layout()
plt.show()

# %%
# Plot with boxplots of financial fields
plt.figure(figsize=(15, 10))

for i, field in enumerate(financial_fields, 1):
    plt.subplot(2, 3, i)
    sns.boxplot(x=df[field])
    plt.title(f'Boxplot of {field}')
    plt.xlabel(field)
    plt.ylabel('Value')

plt.tight_layout()
plt.show()

# %%
