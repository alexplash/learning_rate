import pandas as pd
import numpy as np

total_obs = 1000
data = {
    'ad1_spend_monthly': np.random.uniform(1000, 10000, total_obs),
    'ad1_conv_rate': np.random.uniform(0.01, 0.30, total_obs),
    'ad2_spend_monthly': np.random.uniform(1000, 10000, total_obs),
    'ad2_conv_rate': np.random.uniform(0.01, 0.30, total_obs),
    'ad3_spend_monthly': np.random.uniform(1000, 10000, total_obs),
    'ad3_conv_rate': np.random.uniform(0.01, 0.30, total_obs),
    'monthly_pricing_plan': np.random.uniform(10, 100, total_obs),
    'monthly_active_users': np.random.randint(1000, 100000, total_obs)
}

df = pd.DataFrame(data)

df['annual_revenue'] = (
    df['ad1_spend_monthly'] * 0.6 + 
    df['ad1_conv_rate'] * 5000 +
    df['ad2_spend_monthly'] * 0.5 +
    df['ad2_conv_rate'] * 4500 +
    df['ad3_spend_monthly'] * 0.4 +
    df['ad3_conv_rate'] * 4000 +
    df['monthly_pricing_plan'] * 12 * 0.3 +
    df['monthly_active_users'] * 0.15 +
    np.random.normal(0, 10000, total_obs)
)

df['revenue_category'] = pd.qcut(df['annual_revenue'], 2, labels = ['Low', 'High'])

df.to_csv('appData_log_two_class.csv', index = False)