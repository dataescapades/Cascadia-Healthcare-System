import pandas as pd
import matplotlib.pyplot as plt

def binary_var_distribution(variables, df):
    """
    Calculate the distribution of binary variables in a DataFrame.

    Parameters:
    variables (list): List of binary variable names.
    df (pd.DataFrame): DataFrame containing the data.

    Returns:
    Shows a stacked bar plot of the distribution of binary variables.
    Returns a DataFrame with the counts of each binary variable.
    """
    value_counts_dict = {}
    for var in variables:
        # value counts
        value_counts_dict[var] = df[var].value_counts()

    value_counts_df = pd.DataFrame(value_counts_dict).T.fillna(0)

    # Plotting
    plt.figure(figsize=(12, 8))
    value_counts_df.plot(kind='bar', stacked=True)
    plt.xlabel('Variables')
    plt.ylabel('Count')
    plt.title('Distribution of Binary Variables')
    plt.legend(title='Values')
    plt.show()

    value_counts_df['percent_with_condition'] = (
        value_counts_df[1] / (value_counts_df[0] + value_counts_df[1])) * 100

    return value_counts_df