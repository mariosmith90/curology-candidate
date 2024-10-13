import boto3
from botocore.exceptions import ClientError

s3_client = boto3.client('s3', region_name='us-west-2')

bucket_name = 'curology-state-bucket' 

try:
    s3_client.create_bucket(
        Bucket=bucket_name,
        CreateBucketConfiguration={
            'LocationConstraint': 'us-west-2'  
        }
    )
    print(f"S3 bucket '{bucket_name}' created successfully.")
except ClientError as e:
    print(f"Error creating S3 bucket: {e}")

dynamodb_client = boto3.client('dynamodb', region_name='us-west-2')
table_name = 'curology-dynamo-table'

try:
    dynamodb_client.create_table(
        TableName=table_name,
        KeySchema=[
            {
                'AttributeName': 'LockID',
                'KeyType': 'HASH'  
            }
        ],
        AttributeDefinitions=[
            {
                'AttributeName': 'LockID',
                'AttributeType': 'S'
            }
        ],
        ProvisionedThroughput={
            'ReadCapacityUnits': 5,
            'WriteCapacityUnits': 5
        }
    )
    print(f"DynamoDB table '{table_name}' created successfully.")
except ClientError as e:
    print(f"Error creating DynamoDB table: {e}")
