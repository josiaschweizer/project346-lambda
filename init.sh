#!/bin/bash

# Variablen definieren
INPUT_BUCKET="csv-input-bucket"
OUTPUT_BUCKET="json-output-bucket"
LAMBDA_NAME="CsvToJsonConverter"
LAMBDA_ROLE_ARN="arn:aws:iam::488917449132:role/LabRole"

# 1. S3-Buckets erstellen
echo "Creating AWS S3-Buckets..."
aws s3 mb s3://$INPUT_BUCKET
aws s3 mb s3://$OUTPUT_BUCKET
echo "S3-Buckets created: $INPUT_BUCKET and $OUTPUT_BUCKET"

# 2. Lambda-Funktion erstellen
echo "Erstelle Lambda-Funktion..."
zip lambda.zip csv_to_json.js
aws lambda create-function --function-name $LAMBDA_NAME \
    --runtime nodejs18.x \
    --role $LAMBDA_ROLE_ARN \
    --handler csv_to_json.handler \
    --zip-file fileb://lambda.zip
echo "Lambda-Function $LAMBDA_NAME created."

# 3. S3-Bucket-Trigger hinzufügen
echo "Adding trigger for $INPUT_BUCKET..."
aws lambda add-permission \
    --function-name $LAMBDA_NAME \
    --statement-id s3invoke \
    --action "lambda:InvokeFunction" \
    --principal s3.amazonaws.com \
    --source-arn arn:aws:s3:::$INPUT_BUCKET

aws s3api put-bucket-notification-configuration \
    --bucket $INPUT_BUCKET \
    --notification-configuration file://notification.json
echo "Trigger added."

# Aufräumen
rm lambda.zip
echo "Setup finished!"
