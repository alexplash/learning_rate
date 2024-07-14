import pandas as pd
from sklearn.datasets import make_classification

x, y = make_classification(n_samples = 1000, n_features = 20, n_informative = 8, n_redundant = 0, n_clusters_per_class = 1, n_classes = 4)

df = pd.DataFrame(x, columns = [f'feature_{i+1}' for i in range(20)])
df['label'] = y

label_map = {
    0: 'A',
    1: 'B',
    2: 'C',
    3: 'D'
}
df['label'] = df['label'].replace(label_map)

df.to_csv('randomForestData.csv', index = False)