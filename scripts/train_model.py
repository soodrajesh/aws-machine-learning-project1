"""
ML Model Training Script for SageMaker
Trains a machine learning model using sample data and saves artifacts to S3
"""

import os
import sys
import json
import joblib
import pandas as pd
import numpy as np
from datetime import datetime
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.linear_model import LogisticRegression, LinearRegression
from sklearn.metrics import accuracy_score, classification_report, mean_squared_error, r2_score
from sklearn.preprocessing import StandardScaler, LabelEncoder
import boto3
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize S3 client
s3_client = boto3.client('s3')

# Environment variables (set by SageMaker or Lambda)
DATA_BUCKET = os.environ.get('DATA_BUCKET', 'ml-project-data-bucket')
ARTIFACTS_BUCKET = os.environ.get('ARTIFACTS_BUCKET', 'ml-project-artifacts-bucket')
MODEL_TYPE = os.environ.get('MODEL_TYPE', 'classification')  # classification or regression


def main():
    """Main training function"""
    try:
        logger.info("Starting ML model training...")
        
        # Load and prepare data
        X_train, X_test, y_train, y_test, feature_names = load_and_prepare_data()
        
        # Train model
        model, scaler = train_model(X_train, y_train, MODEL_TYPE)
        
        # Evaluate model
        metrics = evaluate_model(model, scaler, X_test, y_test, MODEL_TYPE)
        
        # Save model artifacts
        save_model_artifacts(model, scaler, feature_names, metrics)
        
        logger.info("Training completed successfully!")
        return metrics
        
    except Exception as e:
        logger.error(f"Training failed: {str(e)}")
        raise


def load_and_prepare_data():
    """Load data from S3 and prepare for training"""
    try:
        # For demo purposes, create sample data if no data exists
        # In production, this would load from S3
        logger.info("Loading training data...")
        
        # Generate sample data (Iris-like dataset for classification)
        if MODEL_TYPE == 'classification':
            from sklearn.datasets import make_classification
            X, y = make_classification(
                n_samples=1000,
                n_features=4,
                n_informative=3,
                n_redundant=1,
                n_classes=3,
                random_state=42
            )
            feature_names = ['feature_1', 'feature_2', 'feature_3', 'feature_4']
        else:
            # Regression dataset
            from sklearn.datasets import make_regression
            X, y = make_regression(
                n_samples=1000,
                n_features=4,
                noise=0.1,
                random_state=42
            )
            feature_names = ['feature_1', 'feature_2', 'feature_3', 'feature_4']
        
        # Split the data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y if MODEL_TYPE == 'classification' else None
        )
        
        logger.info(f"Data loaded: {X_train.shape[0]} training samples, {X_test.shape[0]} test samples")
        return X_train, X_test, y_train, y_test, feature_names
        
    except Exception as e:
        logger.error(f"Error loading data: {str(e)}")
        raise


def train_model(X_train, y_train, model_type='classification'):
    """Train the machine learning model"""
    try:
        logger.info(f"Training {model_type} model...")
        
        # Scale features
        scaler = StandardScaler()
        X_train_scaled = scaler.fit_transform(X_train)
        
        # Choose model based on type
        if model_type == 'classification':
            # Use Random Forest for classification
            model = RandomForestClassifier(
                n_estimators=100,
                max_depth=10,
                random_state=42,
                n_jobs=-1
            )
        else:
            # Use Random Forest for regression
            model = RandomForestRegressor(
                n_estimators=100,
                max_depth=10,
                random_state=42,
                n_jobs=-1
            )
        
        # Train the model
        model.fit(X_train_scaled, y_train)
        
        logger.info("Model training completed")
        return model, scaler
        
    except Exception as e:
        logger.error(f"Error training model: {str(e)}")
        raise


def evaluate_model(model, scaler, X_test, y_test, model_type='classification'):
    """Evaluate the trained model"""
    try:
        logger.info("Evaluating model performance...")
        
        # Scale test features
        X_test_scaled = scaler.transform(X_test)
        
        # Make predictions
        y_pred = model.predict(X_test_scaled)
        
        # Calculate metrics based on model type
        if model_type == 'classification':
            accuracy = accuracy_score(y_test, y_pred)
            report = classification_report(y_test, y_pred, output_dict=True)
            
            metrics = {
                'model_type': 'classification',
                'accuracy': float(accuracy),
                'precision': float(report['macro avg']['precision']),
                'recall': float(report['macro avg']['recall']),
                'f1_score': float(report['macro avg']['f1-score']),
                'training_date': datetime.utcnow().isoformat(),
                'n_samples_train': len(X_test),
                'n_features': X_test.shape[1]
            }
            
            logger.info(f"Classification Accuracy: {accuracy:.4f}")
            
        else:
            mse = mean_squared_error(y_test, y_pred)
            r2 = r2_score(y_test, y_pred)
            rmse = np.sqrt(mse)
            
            metrics = {
                'model_type': 'regression',
                'mse': float(mse),
                'rmse': float(rmse),
                'r2_score': float(r2),
                'training_date': datetime.utcnow().isoformat(),
                'n_samples_train': len(X_test),
                'n_features': X_test.shape[1]
            }
            
            logger.info(f"Regression R² Score: {r2:.4f}, RMSE: {rmse:.4f}")
        
        return metrics
        
    except Exception as e:
        logger.error(f"Error evaluating model: {str(e)}")
        raise


def save_model_artifacts(model, scaler, feature_names, metrics):
    """Save model artifacts to S3"""
    try:
        logger.info("Saving model artifacts...")
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        
        # Save the trained model
        model_filename = f'model_{timestamp}.joblib'
        joblib.dump(model, f'/tmp/{model_filename}')
        
        # Save the scaler
        scaler_filename = f'scaler_{timestamp}.joblib'
        joblib.dump(scaler, f'/tmp/{scaler_filename}')
        
        # Save feature names
        feature_names_filename = f'feature_names_{timestamp}.json'
        with open(f'/tmp/{feature_names_filename}', 'w') as f:
            json.dump(feature_names, f)
        
        # Save metrics
        metrics_filename = f'metrics_{timestamp}.json'
        with open(f'/tmp/{metrics_filename}', 'w') as f:
            json.dump(metrics, f, indent=2)
        
        # Upload to S3
        s3_client.upload_file(f'/tmp/{model_filename}', ARTIFACTS_BUCKET, f'models/{model_filename}')
        s3_client.upload_file(f'/tmp/{scaler_filename}', ARTIFACTS_BUCKET, f'models/{scaler_filename}')
        s3_client.upload_file(f'/tmp/{feature_names_filename}', ARTIFACTS_BUCKET, f'models/{feature_names_filename}')
        s3_client.upload_file(f'/tmp/{metrics_filename}', ARTIFACTS_BUCKET, f'metrics/{metrics_filename}')
        
        # Also save as "latest" for easy access
        s3_client.upload_file(f'/tmp/{model_filename}', ARTIFACTS_BUCKET, 'models/latest_model.joblib')
        s3_client.upload_file(f'/tmp/{scaler_filename}', ARTIFACTS_BUCKET, 'models/latest_scaler.joblib')
        s3_client.upload_file(f'/tmp/{feature_names_filename}', ARTIFACTS_BUCKET, 'models/latest_feature_names.json')
        s3_client.upload_file(f'/tmp/{metrics_filename}', ARTIFACTS_BUCKET, 'metrics/latest_metrics.json')
        
        # Clean up temporary files
        for filename in [model_filename, scaler_filename, feature_names_filename, metrics_filename]:
            if os.path.exists(f'/tmp/{filename}'):
                os.remove(f'/tmp/{filename}')
        
        logger.info(f"Model artifacts saved to S3: {ARTIFACTS_BUCKET}/models/")
        
    except Exception as e:
        logger.error(f"Error saving model artifacts: {str(e)}")
        raise


def load_data_from_s3(bucket, key):
    """Load data from S3 (utility function for production use)"""
    try:
        response = s3_client.get_object(Bucket=bucket, Key=key)
        data = pd.read_csv(response['Body'])
        return data
    except Exception as e:
        logger.error(f"Error loading data from S3: {str(e)}")
        return None


def create_sample_data():
    """Create sample data for demonstration"""
    try:
        # Create a sample dataset
        np.random.seed(42)
        n_samples = 1000
        
        # Features
        feature_1 = np.random.normal(0, 1, n_samples)
        feature_2 = np.random.normal(0, 1, n_samples)
        feature_3 = np.random.normal(0, 1, n_samples)
        feature_4 = np.random.normal(0, 1, n_samples)
        
        # Target (classification example)
        target = (feature_1 + feature_2 + np.random.normal(0, 0.1, n_samples) > 0).astype(int)
        
        # Create DataFrame
        data = pd.DataFrame({
            'feature_1': feature_1,
            'feature_2': feature_2,
            'feature_3': feature_3,
            'feature_4': feature_4,
            'target': target
        })
        
        return data
        
    except Exception as e:
        logger.error(f"Error creating sample data: {str(e)}")
        raise


if __name__ == "__main__":
    # This allows the script to be run both as a SageMaker training job
    # and as a standalone script for testing
    try:
        metrics = main()
        print(f"Training completed with metrics: {json.dumps(metrics, indent=2)}")
    except Exception as e:
        print(f"Training failed: {str(e)}")
        sys.exit(1)
