#!/bin/bash

# Variablen definieren
DATE=$(date +"%Y%m%d%H%M")  # Format: YYYYMMDDHHMM
INPUT_BUCKET="csv-input-bucket-josia123-$DATE"
OUTPUT_BUCKET="json-output-bucket-josia123-$DATE"
LAMBDA_NAME="CsvToJsonConverterV2-josia123-$DATE"
REGION="us-east-1"
ROLE_NAME="LabRole"

# ARN der LabRole dynamisch ermitteln
LAMBDA_ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)
if [ -z "$LAMBDA_ROLE_ARN" ]; then
    echo "Error: Could not retrieve ARN for role $ROLE_NAME"
    exit 1
fi

# Überprüfen, ob csv_to_json.js existiert
if [ ! -f csv_to_json.js ]; then
    echo "Error: csv_to_json.js not found!"
    exit 1
fi

# 1. S3-Buckets erstellen
echo "Creating AWS S3-Buckets..."
aws s3 mb s3://$INPUT_BUCKET --region $REGION || { echo "Failed to create input bucket"; exit 1; }
aws s3 mb s3://$OUTPUT_BUCKET --region $REGION || { echo "Failed to create output bucket"; exit 1; }
echo "S3-Buckets created: $INPUT_BUCKET and $OUTPUT_BUCKET"

# 2. Lambda-Funktion erstellen
echo "Creating Lambda-Function..."
# Cleanup existing zip if exists
rm -f lambda.zip

# Create new zip file
zip lambda.zip csv_to_json.js || { echo "Failed to create zip file"; exit 1; }

# Check if function exists
if aws lambda get-function --function-name $LAMBDA_NAME --region $REGION 2>/dev/null; then
    echo "Updating existing Lambda function..."
    aws lambda update-function-code \
        --function-name $LAMBDA_NAME \
        --zip-file fileb://lambda.zip \
        --region $REGION || { echo "Failed to update Lambda function"; exit 1; }
else
    echo "Creating new Lambda function..."
    aws lambda create-function \
        --function-name $LAMBDA_NAME \
        --runtime nodejs18.x \
        --role $LAMBDA_ROLE_ARN \
        --handler csv_to_json.handler \
        --zip-file fileb://lambda.zip \
        --region $REGION || { echo "Failed to create Lambda function"; exit 1; }
fi
echo "Lambda-Function $LAMBDA_NAME deployed successfully."

# 3. S3-Bucket-Trigger hinzufügen
echo "Adding trigger for $INPUT_BUCKET..."
aws lambda add-permission \
    --function-name $LAMBDA_NAME \
    --statement-id "s3invoke-$DATE" \
    --action "lambda:InvokeFunction" \
    --principal s3.amazonaws.com \
    --source-arn arn:aws:s3:::$INPUT_BUCKET \
    --region $REGION || { echo "Warning: Failed to add Lambda permission"; }

# Get Lambda ARN
LAMBDA_ARN=$(aws lambda get-function --function-name $LAMBDA_NAME --region $REGION --query "Configuration.FunctionArn" --output text)
if [ -z "$LAMBDA_ARN" ]; then
    echo "Error: Could not get Lambda ARN"
    exit 1
fi

aws s3api put-bucket-notification-configuration \
    --bucket $INPUT_BUCKET \
    --notification-configuration '{
        "LambdaFunctionConfigurations": [
            {
                "LambdaFunctionArn": "'"$LAMBDA_ARN"'",
                "Events": ["s3:ObjectCreated:*"]
            }
        ]
    }' --region $REGION || { echo "Failed to configure S3 trigger"; exit 1; }
echo "Trigger added."

# Aufräumen
rm -f lambda.zip
echo "Setup finished!"
