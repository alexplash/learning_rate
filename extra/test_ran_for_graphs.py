from sklearn.ensemble import RandomForestClassifier
from sklearn.datasets import load_breast_cancer
from sklearn.tree import export_graphviz
from IPython.display import Image
import pydotplus

def visualize_tree(tree, feature_names, class_names):
    dot_data = export_graphviz(
        tree,
        out_file = None,
        feature_names = feature_names,
        class_names = class_names,
        filled = True,
        rounded = True,
        special_characters = True
    )
    graph = pydotplus.graph_from_dot_data(dot_data)
    graph.write_png('tree.png')
    return Image(graph.create_png())

data = load_breast_cancer()
x = data.data
y = data.target
feature_names = data.feature_names
class_names = [str(cls) for cls in data.target_names]

model = RandomForestClassifier()
model.fit(x, y)

visualize_tree(model.estimators_[0], feature_names, class_names)





