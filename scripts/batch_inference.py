"""
AWS Lambda Handler for Batch ML Inference
Performs batch predictions using trained models stored in S3
"""

import json
import boto3
import os
import logging
import pandas as pd
import joblib
import numpy as np
from datetime import datetime
from typing import Dict, Any, List
from io import BytesIO, StringIO

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
cloudwatch_client = boto3.client('cloudwatch')

# Environment variables
DATA_BUCKET = os.environ.get('DATA_BUCKET')
ARTIFACTS_BUCKET = os.environ.get('ARTIFACTS_BUCKET')
AWS_REGION = os.environ.get('AWS_REGION', 'eu-west-1')


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for batch inference
    
    Args:
        event: Lambda event data
        context: Lambda context object
        
    Returns:
        Response dictionary with predictions and metadata
    """
    try:
        logger.info(f"Starting batch inference with event: {json.dumps(event)}")
        
        # Get input parameters
        input_data_key = event.get('input_data_key', 'processed/batch_input.csv')
        model_key = event.get('model_key', 'models/latest_model.joblib')
        output_key = event.get('output_key', f'predictions/batch_predictions_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv')
        
        # Load the trained model
        model = load_model_from_s3(model_key)
        if model is None:
            return create_response(404, "Model not found")
        
        # Load input data
        input_data = load_data_from_s3(input_data_key)
        if input_data is None:
            return create_response(404, "Input data not found")
        
        # Perform batch predictions
        predictions = perform_batch_predictions(model, input_data)
        
        # Save predictions to S3
        save_predictions_to_s3(predictions, input_data, output_key)
        
        # Send metrics
        send_custom_metric('BatchInferenceCompleted', 1, 'Count')
        send_custom_metric('PredictionCount', len(predictions), 'Count')
        
        return create_response(200, "Batch inference completed successfully", {
            'input_data_key': input_data_key,
            'model_key': model_key,
            'output_key': output_key,
            'prediction_count': len(predictions),
            'output_location': f's3://{ARTIFACTS_BUCKET}/{output_key}'
        })
        
    except Exception as e:
        logger.error(f"Error in batch inference: {str(e)}")
        send_custom_metric('BatchInferenceErrors', 1, 'Count')
        return create_response(500, f"Batch inference error: {str(e)}")


def load_model_from_s3(model_key: str) -> Any:
    """Load a trained model from S3"""
    try:
        logger.info(f"Loading model from s3://{ARTIFACTS_BUCKET}/{model_key}")
        
        # Try to get the model file
        response = s3_client.get_object(Bucket=ARTIFACTS_BUCKET, Key=model_key)
        model_data = response['Body'].read()
        
        # Load the model using joblib
        model = joblib.load(BytesIO(model_data))
        
        logger.info(f"Successfully loaded model: {type(model).__name__}")
        return model
        
    except s3_client.exceptions.NoSuchKey:
        logger.error(f"Model not found: {model_key}")
        return None
    except Exception as e:
        logger.error(f"Error loading model: {str(e)}")
        return None


def load_data_from_s3(data_key: str) -> pd.DataFrame:
    """Load input data from S3"""
    try:
        logger.info(f"Loading data from s3://{DATA_BUCKET}/{data_key}")
        
        # Get the data file
        response = s3_client.get_object(Bucket=DATA_BUCKET, Key=data_key)
        data_content = response['Body'].read().decode('utf-8')
        
        # Load as pandas DataFrame
        data = pd.read_csv(StringIO(data_content))
        
        logger.info(f"Successfully loaded data: {data.shape}")
        return data
        
    except s3_client.exceptions.NoSuchKey:
        logger.error(f"Data file not found: {data_key}")
        return None
    except Exception as e:
        logger.error(f"Error loading data: {str(e)}")
        return None


def perform_batch_predictions(model: Any, input_data: pd.DataFrame) -> np.ndarray:
    """Perform batch predictions using the loaded model"""
    try:
        logger.info(f"Performing predictions on {len(input_data)} samples")
        
        # Prepare features (assuming all columns except 'id' if present)
        feature_columns = [col for col in input_data.columns if col.lower() not in ['id', 'target', 'label']]
        X = input_data[feature_columns]
        
        # Handle missing values
        X = X.fillna(X.mean())
        
        # Make predictions
        if hasattr(model, 'predict_proba'):
            # For classification models, get probabilities
            predictions = model.predict_proba(X)
            # If binary classification, take probability of positive class
            if predictions.shape[1] == 2:
                predictions = predictions[:, 1]
        else:
            # For regression models or predict method only
            predictions = model.predict(X)
        
        logger.info(f"Generated {len(predictions)} predictions")
        return predictions
        
    except Exception as e:
        logger.error(f"Error during prediction: {str(e)}")
        raise


def save_predictions_to_s3(predictions: np.ndarray, input_data: pd.DataFrame, output_key: str) -> None:
    """Save predictions to S3"""
    try:
        # Create output DataFrame
        output_data = input_data.copy()
        
        # Add predictions
        if len(predictions.shape) == 1:
            output_data['prediction'] = predictions
        else:
            # Multi-class predictions
            for i in range(predictions.shape[1]):
                output_data[f'prediction_class_{i}'] = predictions[:, i]
        
        # Add metadata
        output_data['prediction_timestamp'] = datetime.utcnow().isoformat()
        output_data['model_version'] = 'latest'  # Could be enhanced to track actual version
        
        # Convert to CSV
        csv_buffer = StringIO()
        output_data.to_csv(csv_buffer, index=False)
        
        # Upload to S3
        s3_client.put_object(
            Bucket=ARTIFACTS_BUCKET,
            Key=output_key,
            Body=csv_buffer.getvalue(),
            ContentType='text/csv'
        )
        
        logger.info(f"Saved predictions to s3://{ARTIFACTS_BUCKET}/{output_key}")
        
    except Exception as e:
        logger.error(f"Error saving predictions: {str(e)}")
        raise


def send_custom_metric(metric_name: str, value: float, unit: str) -> None:
    """Send custom metric to CloudWatch"""
    try:
        cloudwatch_client.put_metric_data(
            Namespace='ML-Pipeline/BatchInference',
            MetricData=[
                {
                    'MetricName': metric_name,
                    'Value': value,
                    'Unit': unit,
                    'Timestamp': datetime.utcnow()
                }
            ]
        )
    except Exception as e:
        logger.error(f"Error sending metric {metric_name}: {str(e)}")


def create_response(status_code: int, message: str, data: Any = None) -> Dict[str, Any]:
    """Create a standardized response"""
    response = {
        'statusCode': status_code,
        'message': message,
        'timestamp': datetime.utcnow().isoformat()
    }
    
    if data is not None:
        response['data'] = data
    
    return response


# Additional utility functions for different model types
def handle_sklearn_model(model: Any, X: pd.DataFrame) -> np.ndarray:
    """Handle scikit-learn models"""
    if hasattr(model, 'predict_proba'):
        return model.predict_proba(X)
    else:
        return model.predict(X)


def handle_tensorflow_model(model: Any, X: pd.DataFrame) -> np.ndarray:
    """Handle TensorFlow/Keras models"""
    # Convert to numpy array for TensorFlow
    X_array = X.values.astype(np.float32)
    predictions = model.predict(X_array)
    return predictions.flatten() if predictions.shape[1] == 1 else predictions


def preprocess_features(data: pd.DataFrame) -> pd.DataFrame:
    """Basic feature preprocessing"""
    # Handle categorical variables (simple label encoding)
    for col in data.select_dtypes(include=['object']).columns:
        data[col] = pd.Categorical(data[col]).codes
    
    # Handle missing values
    numeric_columns = data.select_dtypes(include=[np.number]).columns
    data[numeric_columns] = data[numeric_columns].fillna(data[numeric_columns].mean())
    
    return data
