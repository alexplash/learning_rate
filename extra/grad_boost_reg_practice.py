from sklearn.datasets import fetch_california_housing as load_data
from sklearn.ensemble import GradientBoostingRegressor
import numpy as np
from sklearn.tree import export_graphviz
from IPython.display import Image
import pydotplus

data = load_data()
x = data.data
y = data.target
feature_names = data.feature_names

gbr = GradientBoostingRegressor() #default values: n_estimators = 100, learning_rate = 0.1, max_depth = 3
gbr.fit(x, y)

feature_importance = gbr.feature_importances_
train_score = gbr.train_score_
estimators = gbr.estimators_

def visualize_tree(tree, feature_names):
    dot_data = export_graphviz(
        tree,
        out_file = None,
        feature_names = feature_names,
        filled = True,
        rounded = True,
        special_characters = True
    )

    graph = pydotplus.graph_from_dot_data(dot_data)
    graph.write_png('tree.png')
    return Image(graph.create_png())

tree = estimators[10, 0]
visualize_tree(tree, feature_names)