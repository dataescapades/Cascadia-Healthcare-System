import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

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

def numeric_variable_histograms(variables, df, bins=10):
    """
    Create histograms for numeric variables in a DataFrame.

    Parameters:
    variables (list): List of numeric variable names.
    df (pd.DataFrame): DataFrame containing the data.
    bins (int): Number of bins for the histograms.
    """

    plt.figure(figsize=(15, 10))

    for i, field in enumerate(variables, 1):
        plt.subplot(3, 3, i)
        plt.hist(df[field], bins=bins)
        plt.title(f'Distribution of {field}')
        plt.xlabel(field)
        plt.ylabel('Frequency')

    plt.tight_layout()
    plt.show()


def numeric_variable_boxplots(variables, df):
    """
    Create boxplots for numeric variables in a DataFrame.

    Parameters:
    variables (list): List of numeric variable names.
    df (pd.DataFrame): DataFrame containing the data.
    """

    plt.figure(figsize=(15, 10))

    for i, field in enumerate(variables, 1):
        plt.subplot(3, 3, i)
        sns.boxplot(x=df[field])
        plt.title(f'Boxplot of {field}')
        plt.xlabel(field)
        plt.ylabel('Value')

    plt.tight_layout()
    plt.show()