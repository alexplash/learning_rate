import pandas as pd
from sklearn.datasets import make_regression

x, y = make_regression(n_samples = 1000, n_features = 15, n_informative = 10, noise = 0.2)

df = pd.DataFrame(x, columns = [f"feature_{i+1}" for i in range(15)])
df['target'] = y

df.to_csv('gradBoostRegData.csv', index = False)