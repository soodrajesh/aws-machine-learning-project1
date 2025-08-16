"""
AWS Lambda Handler for ML Pipeline Automation
Triggers SageMaker training jobs and handles batch processing
"""

import json
import boto3
import os
import logging
from datetime import datetime
from typing import Dict, Any

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
sagemaker_client = boto3.client('sagemaker')
cloudwatch_client = boto3.client('cloudwatch')

# Environment variables
DATA_BUCKET = os.environ.get('DATA_BUCKET')
ARTIFACTS_BUCKET = os.environ.get('ARTIFACTS_BUCKET')
CODE_BUCKET = os.environ.get('CODE_BUCKET')
SAGEMAKER_ROLE = os.environ.get('SAGEMAKER_ROLE')
TRAINING_INSTANCE_TYPE = os.environ.get('TRAINING_INSTANCE_TYPE', 'ml.m5.large')
MAX_TRAINING_TIME = int(os.environ.get('MAX_TRAINING_TIME', '3600'))
AWS_REGION = os.environ.get('AWS_REGION', 'eu-west-1')


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler function
    
    Args:
        event: Lambda event data
        context: Lambda context object
        
    Returns:
        Response dictionary with status and message
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Determine the trigger source
        if 'Records' in event:
            # S3 trigger
            return handle_s3_trigger(event)
        elif 'action' in event:
            # Direct invocation with action
            return handle_direct_invocation(event)
        elif 'trigger_type' in event:
            # CloudWatch Events trigger
            return handle_scheduled_trigger(event)
        else:
            logger.warning("Unknown event type")
            return create_response(400, "Unknown event type")
            
    except Exception as e:
        logger.error(f"Error processing event: {str(e)}")
        return create_response(500, f"Error: {str(e)}")


def handle_s3_trigger(event: Dict[str, Any]) -> Dict[str, Any]:
    """Handle S3 object creation events"""
    try:
        processed_files = []
        
        for record in event['Records']:
            bucket_name = record['s3']['bucket']['name']
            object_key = record['s3']['object']['key']
            
            logger.info(f"Processing S3 object: s3://{bucket_name}/{object_key}")
            
            # Check if it's a CSV file in the raw data folder
            if object_key.startswith('raw/') and object_key.endswith('.csv'):
                # Process the data file
                result = process_data_file(bucket_name, object_key)
                processed_files.append(result)
                
                # Optionally trigger training if enough data is available
                if should_trigger_training(bucket_name):
                    training_result = start_training_job()
                    processed_files.append(training_result)
        
        return create_response(200, f"Processed {len(processed_files)} files", processed_files)
        
    except Exception as e:
        logger.error(f"Error handling S3 trigger: {str(e)}")
        return create_response(500, f"S3 trigger error: {str(e)}")


def handle_direct_invocation(event: Dict[str, Any]) -> Dict[str, Any]:
    """Handle direct Lambda invocation with specific actions"""
    try:
        action = event.get('action')
        
        if action == 'train_model':
            return start_training_job()
        elif action == 'process_data':
            return process_all_data()
        elif action == 'cleanup_old_models':
            return cleanup_old_models()
        else:
            return create_response(400, f"Unknown action: {action}")
            
    except Exception as e:
        logger.error(f"Error handling direct invocation: {str(e)}")
        return create_response(500, f"Direct invocation error: {str(e)}")


def handle_scheduled_trigger(event: Dict[str, Any]) -> Dict[str, Any]:
    """Handle CloudWatch Events scheduled triggers"""
    try:
        trigger_type = event.get('trigger_type')
        action = event.get('action', 'train_model')
        
        logger.info(f"Handling scheduled trigger: {trigger_type}, action: {action}")
        
        if action == 'train_model':
            return start_training_job()
        else:
            return create_response(400, f"Unknown scheduled action: {action}")
            
    except Exception as e:
        logger.error(f"Error handling scheduled trigger: {str(e)}")
        return create_response(500, f"Scheduled trigger error: {str(e)}")


def process_data_file(bucket_name: str, object_key: str) -> Dict[str, Any]:
    """Process a single data file"""
    try:
        # Get the file from S3
        response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
        file_content = response['Body'].read()
        
        # Basic file validation
        if len(file_content) == 0:
            raise ValueError("Empty file")
        
        # Move processed file to processed folder
        processed_key = object_key.replace('raw/', 'processed/')
        s3_client.copy_object(
            Bucket=bucket_name,
            CopySource={'Bucket': bucket_name, 'Key': object_key},
            Key=processed_key
        )
        
        # Send custom metric to CloudWatch
        send_custom_metric('DataFileProcessed', 1, 'Count')
        
        logger.info(f"Successfully processed file: {object_key}")
        return {
            'file': object_key,
            'status': 'processed',
            'processed_location': processed_key
        }
        
    except Exception as e:
        logger.error(f"Error processing file {object_key}: {str(e)}")
        return {
            'file': object_key,
            'status': 'error',
            'error': str(e)
        }


def start_training_job() -> Dict[str, Any]:
    """Start a SageMaker training job"""
    try:
        timestamp = datetime.now().strftime('%Y-%m-%d-%H-%M-%S')
        job_name = f"ml-training-job-{timestamp}"
        
        # Training job configuration
        training_params = {
            'TrainingJobName': job_name,
            'RoleArn': SAGEMAKER_ROLE,
            'AlgorithmSpecification': {
                'TrainingImage': f'683313688378.dkr.ecr.{AWS_REGION}.amazonaws.com/sagemaker-scikit-learn:0.23-1-cpu-py3',
                'TrainingInputMode': 'File'
            },
            'InputDataConfig': [
                {
                    'ChannelName': 'training',
                    'DataSource': {
                        'S3DataSource': {
                            'S3DataType': 'S3Prefix',
                            'S3Uri': f's3://{DATA_BUCKET}/processed/',
                            'S3DataDistributionType': 'FullyReplicated'
                        }
                    },
                    'ContentType': 'text/csv',
                    'CompressionType': 'None'
                }
            ],
            'OutputDataConfig': {
                'S3OutputPath': f's3://{ARTIFACTS_BUCKET}/models/'
            },
            'ResourceConfig': {
                'InstanceType': TRAINING_INSTANCE_TYPE,
                'InstanceCount': 1,
                'VolumeSizeInGB': 30
            },
            'StoppingCondition': {
                'MaxRuntimeInSeconds': MAX_TRAINING_TIME
            },
            'Tags': [
                {'Key': 'Project', 'Value': 'ML-Pipeline'},
                {'Key': 'Environment', 'Value': 'Development'},
                {'Key': 'ManagedBy', 'Value': 'Lambda'}
            ]
        }
        
        # Start the training job
        response = sagemaker_client.create_training_job(**training_params)
        
        # Send custom metric
        send_custom_metric('TrainingJobStarted', 1, 'Count')
        
        logger.info(f"Started training job: {job_name}")
        return {
            'training_job_name': job_name,
            'training_job_arn': response['TrainingJobArn'],
            'status': 'started'
        }
        
    except Exception as e:
        logger.error(f"Error starting training job: {str(e)}")
        return {
            'status': 'error',
            'error': str(e)
        }


def process_all_data() -> Dict[str, Any]:
    """Process all data files in the raw folder"""
    try:
        # List all objects in the raw folder
        response = s3_client.list_objects_v2(
            Bucket=DATA_BUCKET,
            Prefix='raw/'
        )
        
        processed_count = 0
        if 'Contents' in response:
            for obj in response['Contents']:
                if obj['Key'].endswith('.csv'):
                    process_data_file(DATA_BUCKET, obj['Key'])
                    processed_count += 1
        
        return create_response(200, f"Processed {processed_count} data files")
        
    except Exception as e:
        logger.error(f"Error processing all data: {str(e)}")
        return create_response(500, f"Error processing data: {str(e)}")


def cleanup_old_models() -> Dict[str, Any]:
    """Clean up old model artifacts to save storage costs"""
    try:
        # List objects in the models folder
        response = s3_client.list_objects_v2(
            Bucket=ARTIFACTS_BUCKET,
            Prefix='models/'
        )
        
        deleted_count = 0
        if 'Contents' in response:
            # Sort by last modified date
            objects = sorted(response['Contents'], key=lambda x: x['LastModified'], reverse=True)
            
            # Keep only the 5 most recent models
            for obj in objects[5:]:
                s3_client.delete_object(Bucket=ARTIFACTS_BUCKET, Key=obj['Key'])
                deleted_count += 1
                logger.info(f"Deleted old model: {obj['Key']}")
        
        return create_response(200, f"Cleaned up {deleted_count} old models")
        
    except Exception as e:
        logger.error(f"Error cleaning up models: {str(e)}")
        return create_response(500, f"Cleanup error: {str(e)}")


def should_trigger_training(bucket_name: str) -> bool:
    """Determine if training should be triggered based on data availability"""
    try:
        # Check if there are enough processed files
        response = s3_client.list_objects_v2(
            Bucket=bucket_name,
            Prefix='processed/'
        )
        
        if 'Contents' in response:
            csv_files = [obj for obj in response['Contents'] if obj['Key'].endswith('.csv')]
            return len(csv_files) >= 1  # Trigger if at least 1 processed file
        
        return False
        
    except Exception as e:
        logger.error(f"Error checking training trigger condition: {str(e)}")
        return False


def send_custom_metric(metric_name: str, value: float, unit: str) -> None:
    """Send custom metric to CloudWatch"""
    try:
        cloudwatch_client.put_metric_data(
            Namespace='ML-Pipeline',
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
