from flask import Flask, jsonify, request
from flask_cors import CORS
from google.cloud import storage
from joblib import dump, load
import zipfile
import json
from dotenv import load_dotenv
import os
import pandas as pd
import numpy as np
from sklearn.linear_model import LinearRegression, LogisticRegression
from sklearn.ensemble import RandomForestClassifier, GradientBoostingRegressor
from sklearn.cluster import KMeans
from sklearn.tree import export_graphviz
from PIL import Image
import io
import pydotplus
import base64

load_dotenv()

app = Flask(__name__)
CORS(app)

gcp_service_account = os.getenv('GOOGLE_APPLICATION_CREDENTIALS')
if gcp_service_account:
    os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = gcp_service_account
else:
    raise RuntimeError('Failed to load the GCP credentials path from the .env file')

gcp_files_bucket = 'learning_rate_files'
gcp_models_bucket = 'learning_rate_models'

trained_models = {}

@app.route('/store_data', methods = ['POST'])
def store_data():
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
    
    try:
        storage_client = storage.Client()
        bucket = storage_client.bucket(gcp_files_bucket)

        blob = bucket.blob(file.filename)
        blob.upload_from_string(file.read(), content_type=file.content_type)

        return jsonify({'message': 'File uploaded successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route('/delete_data', methods = ['POST'])
def delete_data():
    data = request.json
    dataset_name = data['data_name']

    if not dataset_name:
        return jsonify({'error': 'No dataset name provided'}), 400
    
    try:
        storage_client = storage.Client()
        bucket = storage_client.bucket(gcp_files_bucket)

        blob = bucket.blob(dataset_name)
        if blob.exists():
            blob.delete()
            return jsonify({'success': 'File deleted successfully'}), 200
        else:
            return jsonify({'error': 'File not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/fetch_data_names', methods = ['GET'])
def fetch_data_names():
    try:
        storage_client = storage.Client()
        bucket = storage_client.bucket(gcp_files_bucket)
        blobs = bucket.list_blobs()

        file_names = [blob.name for blob in blobs]
        return jsonify(file_names)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route('/fetch_dataset', methods = ['GET'])
def fetch_dataset():
    file_name = request.args.get('file_name')
    if not file_name:
        return jsonify({'error': 'no file name provided'}), 400
    
    temp_dir_path = '/tmp'
    temp_file_path = os.path.join(temp_dir_path, file_name)
    
    try:
        if not os.path.exists(temp_dir_path):
            os.makedirs(temp_dir_path)

        storage_client = storage.Client()
        bucket = storage_client.bucket(gcp_files_bucket)
        blob = bucket.blob(file_name)

        blob.download_to_filename(temp_file_path)

        if os.path.exists(temp_file_path):
            if file_name.endswith('.csv'):
                df = pd.read_csv(temp_file_path)
                data = df.to_dict(orient = 'records')
            else:
                return jsonify({'error': 'file type not supported'}), 400
            return jsonify(data)
        else:
            return jsonify({'error': 'file not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if os.path.exists(temp_file_path):
            os.remove(temp_file_path)

@app.route('/save_model', methods = ['POST'])
def save_model():
    data = request.json
    if not data:
        return jsonify({'error': 'Must provide information to save model'}), 400
    
    algo_name = data.get('algo_name')
    model_name = data.get('model_name')
    features = data.get('features')
    target = data.get('target')
    dataset = data.get('dataset')
    if not algo_name or not model_name or not features or not target or not dataset:
        return jsonify({'error': 'Must provide all required information'}), 400
    
    current_model = trained_models[algo_name]
    model_buffer = io.BytesIO()
    dump(current_model, model_buffer)
    model_buffer.seek(0)

    df_dataset= pd.DataFrame(dataset)
    dataset_buffer = io.StringIO()
    df_dataset.to_csv(dataset_buffer, index = False)
    dataset_buffer.seek(0)

    metadata = {
        "features": features,
        "target": target,
        "algo_name": algo_name
    }
    metadata_buffer = io.StringIO()
    json.dump(metadata, metadata_buffer)
    metadata_buffer.seek(0)

    zip_buffer = io.BytesIO()
    with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zf:
        zf.writestr(f"{model_name}.joblib", model_buffer.getvalue())
        zf.writestr(f"{model_name}_data.csv", dataset_buffer.getvalue())
        zf.writestr(f"{model_name}_metadata.json", metadata_buffer.getvalue())
    zip_buffer.seek(0)

    storage_client = storage.Client()
    bucket = storage_client.bucket(gcp_models_bucket)
    blob = bucket.blob(f"{model_name}.zip")
    blob.upload_from_file(zip_buffer)

    return jsonify({'success': 'model, data, and metadata successfully saved and uploaded'}), 200

@app.route('/save_unsupervised', methods = ['POST'])
def save_unsupervised():
    data = request.json
    if not data:
        return jsonify({'error': 'Must provide information to save model'}), 400
    
    algo_name = data.get('algo_name')
    model_name = data.get('model_name')
    features = data.get('features')
    dataset = data.get('dataset')
    if not algo_name or not model_name or not features or not dataset:
        return jsonify({'error': 'Must provide all required information'}), 400
    
    current_model = trained_models[algo_name]['model']
    model_buffer = io.BytesIO()
    dump(current_model, model_buffer)
    model_buffer.seek(0)
    
    new_dataset = trained_models[algo_name]['new_dataset']
    df_new_dataset = pd.DataFrame(new_dataset)
    new_dataset_buffer = io.StringIO()
    df_new_dataset.to_csv(new_dataset_buffer, index = False)
    new_dataset_buffer.seek(0)

    df_dataset= pd.DataFrame(dataset)
    dataset_buffer = io.StringIO()
    df_dataset.to_csv(dataset_buffer, index = False)
    dataset_buffer.seek(0)

    metadata = {
        "features": features,
        "algo_name": algo_name
    }
    metadata_buffer = io.StringIO()
    json.dump(metadata, metadata_buffer)
    metadata_buffer.seek(0)

    zip_buffer = io.BytesIO()
    with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zf:
        zf.writestr(f"{model_name}.joblib", model_buffer.getvalue())
        zf.writestr(f"{model_name}_data.csv", dataset_buffer.getvalue())
        zf.writestr(f"{model_name}_new_data.csv", new_dataset_buffer.getvalue())
        zf.writestr(f"{model_name}_metadata.json", metadata_buffer.getvalue())
    zip_buffer.seek(0)

    storage_client = storage.Client()
    bucket = storage_client.bucket(gcp_models_bucket)
    blob = bucket.blob(f"{model_name}.zip")
    blob.upload_from_file(zip_buffer)

    return jsonify({'success': 'model, data, and metadata successfully saved and uploaded'}), 200

@app.route('/delete_model', methods = ['POST'])
def delete_model():
    data = request.json
    model_name = data['model_name']

    if not model_name:
        return jsonify({'error': 'No model name provided'}), 400
    
    try:
        storage_client = storage.Client()
        bucket = storage_client.bucket(gcp_models_bucket)

        blob = bucket.blob(model_name)
        if blob.exists():
            blob.delete()
            return jsonify({'error': 'Model deleted successfully'}), 200
        else:
            return jsonify({'error': 'Model not found'}), 404
    except Exception as e:
        return jsonify({'error', str(e)}), 500

@app.route('/fetch_model_names', methods = ['GET'])
def fetch_model_names():
    try:
        storage_client = storage.Client()
        bucket = storage_client.bucket(gcp_models_bucket)
        blobs = bucket.list_blobs()

        model_names = [blob.name for blob in blobs]
        return jsonify(model_names), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/load_model', methods = ['POST'])
def load_model():
    data = request.json
    if not data:
        return jsonify({'error': 'Must provide file info'}), 400
    
    model_name = data['model_name']
    if not data:
        return jsonify({'error': 'Must provide model name'}), 400
    
    storage_client = storage.Client()
    bucket = storage_client.bucket(gcp_models_bucket)
    blob = bucket.blob(model_name)

    zip_buffer = io.BytesIO()
    blob.download_to_file(zip_buffer)
    zip_buffer.seek(0)

    parsed_model_name = model_name.split('.zip')[0]
    with zipfile.ZipFile(zip_buffer, 'r') as zf:

        with zf.open(f"{parsed_model_name}.joblib") as model_file:
            model_buffer = io.BytesIO(model_file.read())
            current_model = load(model_buffer)

        with zf.open(f"{parsed_model_name}_data.csv") as dataset_file:
            dataset_buffer = io.StringIO(dataset_file.read().decode())
            df_dataset = pd.read_csv(dataset_buffer)

        with zf.open(f"{parsed_model_name}_metadata.json") as metadata_file:
            metadata_buffer = io.StringIO(metadata_file.read().decode())
            metadata = json.load(metadata_buffer)
        
        if metadata['algo_name'] == 'k_means':
            with zf.open(f"{parsed_model_name}_new_data.csv") as new_dataset_file:
                new_dataset_buffer = io.StringIO(new_dataset_file.read().decode())
                df_new_dataset = pd.read_csv(new_dataset_buffer)
        
    algo_name = metadata['algo_name']
    if algo_name == 'k_means':
        if algo_name in trained_models:
            trained_models[algo_name]['model'] = current_model
            trained_models[algo_name]['new_dataset'] = df_new_dataset.to_dict(orient = 'records')
        else:
            trained_models[algo_name] = {
                'model': current_model,
                'new_dataset': df_new_dataset.to_dict(orient='records')
            }
    else:
        if algo_name not in trained_models:
            trained_models[algo_name] = {}
        trained_models[algo_name] = current_model

    result = {
        'metadata': metadata,
        'dataset': df_dataset.to_dict(orient = 'records')
    }

    return jsonify(result), 200


@app.route('/train_lin_reg', methods = ['POST'])
def train_lin_reg():
    data = request.json
    if not data:
        return jsonify({'error': 'no data provided'})
    
    features = data.get('features')
    target = data.get('target')
    dataset = data.get('dataset')
    if not features or not target or not dataset:
        return jsonify({'error': 'features, target, and dataset must be provided'})
    
    try:
        df = pd.DataFrame(dataset)
        x = df[features]
        y = df[target]

        model = LinearRegression()
        model.fit(x, y)
        trained_models['lin_reg'] = model

        coefficients = model.coef_.tolist()

        result = {
            'coefficients': {features[i]: coefficients[i] for i in range(len(features))}
        }
        
        return jsonify(result), 200
    except Exception as e:
        return jsonify({'error': str(e)})
    
@app.route('/load_lin_reg', methods = ['POST'])
def load_lin_reg():
    data = request.json
    if not data:
        return jsonify({'error': 'no data provided'})
    
    features = data.get('features')
    if not features:
        return jsonify({'error': 'features must be provided'})
    try:
        model = trained_models['lin_reg']
        coefficients = model.coef_.tolist()
        result = {
            'coefficients': {features[i]: coefficients[i] for i in range(len(features))}
        }
        return jsonify(result), 200
    except Exception as e:
        return jsonify({'error': str(e)})
    
@app.route('/infer_lin_reg', methods = ['POST'])
def infer_lin_reg():
    if 'lin_reg' not in trained_models:
        return jsonify({'error': 'Model not trained'}), 400
    
    data = request.json
    features = data.get('features')
    if not data or not features:
        return jsonify({'error': 'Features not provided'}), 400
    
    try:
        model = trained_models['lin_reg']
        df = pd.DataFrame([features], index = [0])
        prediction = model.predict(df)
        return jsonify({'prediction': prediction.tolist()}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route('/train_log_reg', methods = ['POST'])
def train_log_reg():
    data = request.json
    if not data:
        return jsonify({'error': 'no data provided'})

    features = data.get('features')
    target = data.get('target')
    dataset = data.get('dataset')
    if not features or not target or not dataset:
        return jsonify({'error': 'features, target, and dataset must be provided'})

    try:
        df = pd.DataFrame(dataset)
        x = df[features]
        y = df[target]

        unique_classes = y.nunique()
        if unique_classes == 2:
            model = LogisticRegression(multi_class = 'auto', solver = 'liblinear')
        elif unique_classes > 2:
            model = LogisticRegression(multi_class = 'multinomial', solver = 'lbfgs')
        model.fit(x, y)
        trained_models['log_reg'] = model

        coefficients = model.coef_
        if coefficients.ndim == 1:
            coefficients = coefficients.reshape(1, -1)
        
        intercepts = model.intercept_
        if intercepts.ndim == 0:
            intercepts = np.array([intercepts])

        coefficients_map = {class_label: dict(zip(features, coeff)) for class_label, coeff in zip(model.classes_, coefficients)}
        intercepts_map = {class_label: intercept for class_label, intercept in zip(model.classes_, intercepts)}

        result = {
            'intercepts': intercepts_map,
            'coefficients': coefficients_map,
            'classes': model.classes_.tolist()
        }

        return jsonify(result), 200
    except Exception as e:
        return jsonify({'error': str(e)})
    
@app.route('/load_log_reg', methods = ['POST'])
def load_log_reg():
    data = request.json
    if not data:
        return jsonify({'error': 'no data provided'}), 400
    
    features = data.get('features')
    if not features:
        return jsonify({'error': 'features must be provided'}), 400

    try:
        model = trained_models['log_reg']

        coefficients = model.coef_
        if coefficients.ndim == 1:
            coefficients = coefficients.reshape(1, -1)

        intercepts = model.intercept_
        if intercepts.ndim == 0:
            intercepts = np.array([intercepts])

        coefficients_map = {class_label: dict(zip(features, coeff)) for class_label, coeff in zip(model.classes_, coefficients)}
        intercepts_map = {class_label: intercept for class_label, intercept in zip(model.classes_, intercepts)}

        result = {
            'intercepts': intercepts_map,
            'coefficients': coefficients_map,
            'classes': model.classes_.tolist()
        }

        return jsonify(result), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/infer_log_reg', methods = ['POST'])
def infer_log_reg():
    if 'log_reg' not in trained_models:
        return jsonify({'error': 'Model not trained'}), 400
    
    data = request.json
    features = data.get('features')
    if not data or not features:
        return jsonify({'error': 'Features not provided'}), 400
    
    try:
        model = trained_models['log_reg']
        df = pd.DataFrame([features])
        prediction = model.predict(df)
        return jsonify({'prediction': prediction.tolist()}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route('/train_random_forest', methods = ['POST'])
def train_random_forest():
    data = request.json
    if not data:
        return jsonify({'error': 'No data provided'})
    
    features = data.get('features')
    target = data.get('target')
    dataset = data.get('dataset')
    n_trees = int(data.get('n_trees', 100))
    if not features or not target or not dataset:
        return jsonify({'error': 'features, target, and dataset must be provided'})

    try:
        df = pd.DataFrame(dataset)
        x = df[features]
        y = df[target]
        model = RandomForestClassifier(n_estimators = n_trees, oob_score = True)
        model.fit(x, y)
        trained_models['random_forest'] = model

        feature_importance = dict(zip(features, model.feature_importances_.tolist()))
        estimators = len(model.estimators_)
        classes = list(model.classes_)
        result = {
            'feature_importance': feature_importance,
            "estimators": estimators,
            'classes': classes
        }

        return jsonify(result), 200
    except Exception as e:
        return jsonify({'error': str(e)})

@app.route('/load_random_forest', methods = ['POST'])
def load_random_forest():
    data = request.json
    if not data:
        return jsonify({'error': 'No data provided'}), 400
    
    features = data.get('features')
    if not features:
        return jsonify({'error': 'features must be provided'}), 400

    try:
        model = trained_models['random_forest']

        feature_importance = dict(zip(features, model.feature_importances_.tolist()))
        estimators = len(model.estimators_)
        classes = list(model.classes_)
        result = {
            'feature_importance': feature_importance,
            'estimators': estimators,
            'classes': classes
        }

        return jsonify(result), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route('/graph_random_forest', methods = ['POST'])
def graph_random_forest():
    data = request.json
    tree_index = data.get('tree_index')

    if 'random_forest' not in trained_models:
        return jsonify({'error': 'Random Forest model not trained'}), 400
    
    if tree_index is None or not isinstance(tree_index, int):
        return jsonify({'error': 'Tree index must be provided'}), 400
    
    try:
        forest = trained_models['random_forest']
        tree = forest.estimators_[tree_index - 1]
        dot_data = export_graphviz(tree, out_file = None, filled = True, rounded = True)
        graph = pydotplus.graph_from_dot_data(dot_data)
        png_image = graph.create_png()

        # Convert byte data to an image
        image = Image.open(io.BytesIO(png_image))
        # Resize the image to a more manageable size
        image = image.resize((1024, 768), Image.Resampling.LANCZOS)

        # Save the resized image back to a byte buffer
        buffer = io.BytesIO()
        image.save(buffer, format = 'PNG')
        resized_png_image = buffer.getvalue()

        # Encode to base64
        image_base64 = base64.b64encode(resized_png_image).decode('utf-8')
        return jsonify({'image_base64': image_base64}), 200
    except Exception as e:
        print("Error generating image: ", str(e)) 
        return jsonify({'error': str(e)}), 500
    
@app.route('/infer_random_forest', methods = ['POST'])
def infer_random_forest():
    if 'random_forest' not in trained_models:
        return jsonify({'error': 'Random Forest model not trained'}), 400
    
    data = request.json
    features = data.get('features')
    if not data or not features:
        return jsonify({'error': 'Features not provided'}), 400
    
    try:
        model = trained_models['random_forest']
        df = pd.DataFrame([features])
        prediction = model.predict(df)
        return jsonify({'prediction': prediction.tolist()}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route('/train_grad_boost_reg', methods = ['POST'])
def train_grad_boost_reg():
    data = request.json
    if not data:
        return jsonify({'error': 'No data provided'}), 400
    
    features = data.get('features')
    target = data.get('target')
    dataset = data.get('dataset')
    n_trees = data.get('n_trees')
    learning_rate = data.get('learning_rate')
    max_depth = data.get('max_depth')
    if not features or not target or not dataset or not n_trees or not learning_rate or not max_depth:
        return jsonify({'error': 'please provide all required fields'})
    
    try:
        df = pd.DataFrame(dataset)
        x = df[features]
        y = df[target]
        model = GradientBoostingRegressor(n_estimators = n_trees, learning_rate = learning_rate, max_depth = max_depth)
        model.fit(x, y)
        trained_models['grad_boost_reg'] = model

        feature_importance = dict(zip(features, model.feature_importances_.tolist()))
        estimators = len(model.estimators_)
        train_scores = model.train_score_.tolist()
        final_learning_rate = model.learning_rate
        final_max_depth = model.max_depth
        result = {
            'feature_importance': feature_importance,
            'estimators': estimators,
            'train_scores': train_scores,
            'learning_rate': final_learning_rate,
            'max_depth': final_max_depth
        }

        return jsonify(result), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route('/load_grad_boost_reg', methods = ['POST'])
def load_grad_boost_reg():
    data = request.json
    if not data:
        return jsonify({'error': 'No data provided'}), 400
    
    features = data.get('features')
    if not features:
        return jsonify({'error': 'features must be provided'}), 400
    
    try:
        model = trained_models['grad_boost_reg']

        feature_importance = dict(zip(features, model.feature_importances_.tolist()))
        estimators = len(model.estimators_)
        train_scores = model.train_score_.tolist()
        final_learning_rate = model.learning_rate
        final_max_depth = model.max_depth
        result = {
            'feature_importance': feature_importance,
            'estimators': estimators,
            'train_scores': train_scores,
            'learning_rate': final_learning_rate,
            'max_depth': final_max_depth
        }
        return jsonify(result), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/graph_grad_boost_reg', methods = ['POST'])
def graph_grad_boost_reg():
    data = request.json
    tree_index = data.get('tree_index')

    if 'grad_boost_reg' not in trained_models:
        return jsonify({'error': 'grad boost regressor model must be trained'}), 400
    
    if tree_index is None or not isinstance(tree_index, int):
        return jsonify({'error': 'Tree index must be provided'}), 400
    
    try:
        model = trained_models['grad_boost_reg']
        tree = model.estimators_[tree_index - 1, 0]
        dot_data = export_graphviz(tree, out_file = None, filled = True, rounded = True)
        graph = pydotplus.graph_from_dot_data(dot_data)
        png_image = graph.create_png()

        image = Image.open(io.BytesIO(png_image))
        image = image.resize((1023, 768), Image.Resampling.LANCZOS)

        buffer = io.BytesIO()
        image.save(buffer, format = 'PNG')
        resized_png_image = buffer.getvalue()

        image_base64 = base64.b64encode(resized_png_image).decode('utf-8')
        return jsonify({'image_base64': image_base64}), 200
    except Exception as e:
        print("Error generating image: ", str(e)) 
        return jsonify({'error': str(e)}), 500

@app.route('/infer_grad_boost_reg', methods = ['POST'])
def infer_grad_boost_reg():
    if 'grad_boost_reg' not in trained_models:
        return jsonify({'error': 'grad boost reg model not trained'}), 400
    
    data = request.json
    features = data.get('features')
    if not data or not features:
        return jsonify({'error': 'Features not provided'}), 400
    
    try:
        model = trained_models['grad_boost_reg']
        df = pd.DataFrame([features])
        prediction = model.predict(df)
        return jsonify({'prediction': prediction.tolist()}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route('/train_k_means', methods = ['POST'])
def train_k_means():
    data = request.json
    if not data:
        return jsonify({'error': 'Data must be provided'}), 400
    
    features = data.get('features')
    dataset = data.get('dataset')
    n_clusters = data.get('n_clusters')
    if not features or not dataset or not n_clusters or n_clusters > 8:
        return jsonify({'error': 'Please provide all information, and ensure n_clusters is at most 8'}), 400
    
    try:
        df = pd.DataFrame(dataset)
        x = df[features]
        model = KMeans(n_clusters = n_clusters)
        df['cluster'] = model.fit_predict(x)
        new_df = df[features + ['cluster']]
        new_dataset = new_df.to_dict(orient = 'records')
        trained_models['k_means'] = {
            'model': model,
            'new_dataset': new_dataset
        }

        centers = {str(i): {str(feature): float(center[j]) for j, feature in enumerate(features)} for i, center in enumerate(model.cluster_centers_)}

        class_labels = [class_label for class_label in range(model.n_clusters)]

        cluster_inertias = {}
        for cluster_index in range(model.n_clusters):
            points_in_cluster = new_df[new_df['cluster'] == cluster_index][features]
            center = model.cluster_centers_[cluster_index]
            intertia = np.sum((points_in_cluster - center) ** 2).sum()
            cluster_inertias[str(cluster_index)] = intertia

        cluster_sizes = {str(key): int(value) for key, value in zip(*np.unique(model.labels_, return_counts = True))}

        result = {
            'centers': centers,
            'new_dataset': new_dataset,
            'class_labels': class_labels,
            "cluster_inertias": cluster_inertias,
            'cluster_sizes': cluster_sizes
        }
        
        return jsonify(result), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/load_k_means', methods = ['POST'])
def load_k_means():
    data = request.json
    if not data:
        return jsonify({'error': 'Data must be provided'}), 400
    
    features = data.get('features')
    if not features:
        return jsonify({'error': 'Provide all information'}), 400
    
    try:
        model = trained_models['k_means']['model']
        new_dataset = trained_models['k_means']['new_dataset']
        new_df = pd.DataFrame(new_dataset)

        centers = {str(i): {str(feature): float(center[j]) for j, feature in enumerate(features)} for i, center in enumerate(model.cluster_centers_)}

        class_labels = [class_label for class_label in range(model.n_clusters)]

        cluster_inertias = {}
        for cluster_index in range(model.n_clusters):
            points_in_cluster = new_df[new_df['cluster'] == cluster_index][features]
            center = model.cluster_centers_[cluster_index]
            intertia = np.sum((points_in_cluster - center) ** 2).sum()
            cluster_inertias[str(cluster_index)] = intertia

        cluster_sizes = {str(key): int(value) for key, value in zip(*np.unique(model.labels_, return_counts = True))}

        result = {
            'centers': centers,
            'new_dataset': new_dataset,
            'class_labels': class_labels,
            'cluster_inertias': cluster_inertias,
            'cluster_sizes': cluster_sizes
        }

        return jsonify(result), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route('/infer_k_means', methods = ['POST'])
def infer_k_means():
    if 'k_means' not in trained_models:
        return jsonify({'error': 'Model not trained'}), 200
    
    data = request.json
    features = data.get('features')
    if not features:
        return jsonify({'error': 'Features not provided'}), 200
    
    try:
        model = trained_models['k_means']['model']
        df = pd.DataFrame([features])
        prediction = model.predict(df)
        return jsonify({'prediction': prediction.tolist()}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    app.run(debug = True)