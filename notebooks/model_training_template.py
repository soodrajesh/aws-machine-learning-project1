"""
AWS ML Pipeline - Model Training Template
This file serves as a template for Jupyter notebook content.
Copy this to a .ipynb file in SageMaker for interactive development.
"""

# Cell 1: Setup and Imports
"""
# AWS ML Pipeline - Model Training Notebook

This notebook demonstrates how to:
1. Load data from S3
2. Perform data exploration and preprocessing
3. Train machine learning models
4. Evaluate model performance
5. Save model artifacts to S3

## Setup
"""

import boto3
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.preprocessing import StandardScaler
import joblib
import os
from datetime import datetime

# Initialize S3 client
s3_client = boto3.client('s3')

# Configuration
DATA_BUCKET = 'your-data-bucket-name'  # Replace with actual bucket name
ARTIFACTS_BUCKET = 'your-artifacts-bucket-name'  # Replace with actual bucket name

# Cell 2: Load Data from S3
"""
## Load Data from S3
"""

def load_data_from_s3(bucket, key):
    """Load CSV data from S3"""
    try:
        response = s3_client.get_object(Bucket=bucket, Key=key)
        data = pd.read_csv(response['Body'])
        return data
    except Exception as e:
        print(f"Error loading data: {e}")
        return None

# Load sample data
data = load_data_from_s3(DATA_BUCKET, 'raw/sample_data.csv')
print(f"Data shape: {data.shape}")
data.head()

# Cell 3: Data Exploration
"""
## Data Exploration
"""

# Basic statistics
print("Data Info:")
data.info()
print("\nData Description:")
data.describe()

# Check for missing values
print("\nMissing Values:")
print(data.isnull().sum())

# Visualize data distribution
plt.figure(figsize=(15, 10))

# Feature distributions
for i, col in enumerate(data.select_dtypes(include=[np.number]).columns[:-1]):
    plt.subplot(2, 3, i+1)
    plt.hist(data[col], bins=30, alpha=0.7)
    plt.title(f'Distribution of {col}')
    plt.xlabel(col)
    plt.ylabel('Frequency')

plt.tight_layout()
plt.show()

# Target distribution
if 'target' in data.columns:
    plt.figure(figsize=(8, 6))
    data['target'].value_counts().plot(kind='bar')
    plt.title('Target Distribution')
    plt.xlabel('Target Class')
    plt.ylabel('Count')
    plt.show()

# Cell 4: Data Preprocessing
"""
## Data Preprocessing
"""

# Separate features and target
feature_columns = [col for col in data.columns if col != 'target']
X = data[feature_columns]
y = data['target'] if 'target' in data.columns else None

# Handle missing values
X = X.fillna(X.mean())

# Split data
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

print(f"Training set size: {X_train.shape}")
print(f"Test set size: {X_test.shape}")

# Scale features
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# Cell 5: Model Training
"""
## Model Training
"""

# Train Random Forest model
model = RandomForestClassifier(
    n_estimators=100,
    max_depth=10,
    random_state=42,
    n_jobs=-1
)

print("Training model...")
model.fit(X_train_scaled, y_train)
print("Model training completed!")

# Cell 6: Model Evaluation
"""
## Model Evaluation
"""

# Make predictions
y_pred = model.predict(X_test_scaled)
y_pred_proba = model.predict_proba(X_test_scaled)

# Calculate metrics
accuracy = accuracy_score(y_test, y_pred)
print(f"Accuracy: {accuracy:.4f}")

# Classification report
print("\nClassification Report:")
print(classification_report(y_test, y_pred))

# Confusion matrix
plt.figure(figsize=(8, 6))
cm = confusion_matrix(y_test, y_pred)
sns.heatmap(cm, annot=True, fmt='d', cmap='Blues')
plt.title('Confusion Matrix')
plt.xlabel('Predicted')
plt.ylabel('Actual')
plt.show()

# Feature importance
feature_importance = pd.DataFrame({
    'feature': feature_columns,
    'importance': model.feature_importances_
}).sort_values('importance', ascending=False)

plt.figure(figsize=(10, 6))
sns.barplot(data=feature_importance, x='importance', y='feature')
plt.title('Feature Importance')
plt.xlabel('Importance')
plt.show()

# Cell 7: Save Model Artifacts
"""
## Save Model Artifacts to S3
"""

def save_model_to_s3(model, scaler, bucket, prefix='models'):
    """Save model and scaler to S3"""
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    
    # Save locally first
    model_filename = f'/tmp/model_{timestamp}.joblib'
    scaler_filename = f'/tmp/scaler_{timestamp}.joblib'
    
    joblib.dump(model, model_filename)
    joblib.dump(scaler, scaler_filename)
    
    # Upload to S3
    s3_client.upload_file(model_filename, bucket, f'{prefix}/model_{timestamp}.joblib')
    s3_client.upload_file(scaler_filename, bucket, f'{prefix}/scaler_{timestamp}.joblib')
    
    # Also save as latest
    s3_client.upload_file(model_filename, bucket, f'{prefix}/latest_model.joblib')
    s3_client.upload_file(scaler_filename, bucket, f'{prefix}/latest_scaler.joblib')
    
    # Clean up local files
    os.remove(model_filename)
    os.remove(scaler_filename)
    
    print(f"Model saved to s3://{bucket}/{prefix}/")
    return f's3://{bucket}/{prefix}/model_{timestamp}.joblib'

# Save the trained model
model_path = save_model_to_s3(model, scaler, ARTIFACTS_BUCKET)
print(f"Model saved at: {model_path}")

# Cell 8: Model Metrics Summary
"""
## Model Performance Summary
"""

metrics_summary = {
    'model_type': 'RandomForestClassifier',
    'accuracy': float(accuracy),
    'training_samples': len(X_train),
    'test_samples': len(X_test),
    'features': len(feature_columns),
    'training_date': datetime.now().isoformat(),
    'model_path': model_path
}

print("Model Performance Summary:")
for key, value in metrics_summary.items():
    print(f"  {key}: {value}")

# Save metrics to S3
metrics_filename = f'/tmp/metrics_{datetime.now().strftime("%Y%m%d_%H%M%S")}.json'
import json
with open(metrics_filename, 'w') as f:
    json.dump(metrics_summary, f, indent=2)

s3_client.upload_file(metrics_filename, ARTIFACTS_BUCKET, 'metrics/latest_metrics.json')
os.remove(metrics_filename)

print("\n✅ Training completed successfully!")
print("🎯 Next steps:")
print("1. Review model performance metrics")
print("2. Test batch inference using the saved model")
print("3. Deploy model for real-time predictions if needed")
print("4. Monitor model performance over time")
