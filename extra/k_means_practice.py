import numpy as np
import pandas as pd
from sklearn.datasets import make_blobs
from sklearn.cluster import KMeans

x, _ = make_blobs(n_samples = 300, centers = 3, cluster_std = 0.6, n_features = 10)

df = pd.DataFrame(x, columns = [f"feature_{i+1}" for i in range(10)])

kmeans = KMeans(n_clusters = 3)

df['cluster'] = kmeans.fit_predict(df)