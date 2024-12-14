#!/bin/bash

# Variablen definieren
DATE=$(date +"%Y%m%d%H%M")  # Format: YYYYMMDDHHMM
INPUT_BUCKET="csv-input-bucket-josia123-$DATE"
OUTPUT_BUCKET="json-output-bucket-josia123-$DATE"
LAMBDA_NAME="CsvToJsonConverterV2-josia123-$DATE"
LAMBDA_ROLE_ARN="arn:aws:iam::488917449132:role/LabRole"
REGION="us-east-1"

# 1. S3-Buckets erstellen
echo "Creating AWS S3-Buckets..."
aws s3 mb s3://$INPUT_BUCKET --region $REGION
aws s3 mb s3://$OUTPUT_BUCKET --region $REGION
echo "S3-Buckets created: $INPUT_BUCKET and $OUTPUT_BUCKET"

# 2. Lambda-Funktion erstellen
echo "Creating Lambda-Function..."
zip lambda.zip csv_to_json.js
aws lambda create-function --function-name $LAMBDA_NAME \
    --runtime nodejs18.x \
    --role $LAMBDA_ROLE_ARN \
    --handler csv_to_json.handler \
    --zip-file fileb://lambda.zip \
    --region $REGION || \
aws lambda update-function-code --function-name $LAMBDA_NAME \
    --zip-file fileb://lambda.zip \
    --region $REGION
echo "Lambda-Function $LAMBDA_NAME created."

# 3. S3-Bucket-Trigger hinzufügen
echo "Adding trigger for $INPUT_BUCKET..."
aws lambda add-permission \
    --function-name $LAMBDA_NAME \
    --statement-id "s3invoke-$DATE" \
    --action "lambda:InvokeFunction" \
    --principal s3.amazonaws.com \
    --source-arn arn:aws:s3:::$INPUT_BUCKET \
    --region $REGION

aws s3api put-bucket-notification-configuration \
    --bucket $INPUT_BUCKET \
    --notification-configuration '{
        "LambdaFunctionConfigurations": [
            {
                "LambdaFunctionArn": "'"$(aws lambda get-function --function-name $LAMBDA_NAME --region $REGION --query "Configuration.FunctionArn" --output text)"'",
                "Events": ["s3:ObjectCreated:*"]
            }
        ]
    }' --region $REGION
echo "Trigger added."

# Aufräumen
rm lambda.zip
echo "Setup finished!"

