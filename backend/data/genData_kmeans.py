import numpy as np
import pandas as pd
from sklearn.datasets import make_blobs

x, _ = make_blobs(n_samples = 1000, n_features = 10, )

df = pd.DataFrame(x, columns = [f"feature_{i+1}" for i in range(10)])

df.to_csv('kmeansData.csv', index = False)