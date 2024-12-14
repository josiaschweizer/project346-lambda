#!/bin/bash

# Variablen definieren
DATE=$(date +"%Y%m%d%H%M")  # Format: YYYYMMDDHHMM
INPUT_BUCKET="csv-input-bucket-josia123-$DATE"
OUTPUT_BUCKET="json-output-bucket-josia123-$DATE"
LAMBDA_NAME="CsvToJsonConverterV2-josia123-$DATE"
LAMBDA_ROLE_ARN="arn:aws:iam::488917449132:role/LabRole"
REGION="us-east-1"

# Erstellen der S3-Buckets
echo "Creating AWS S3-Buckets..."
aws s3 mb s3://$INPUT_BUCKET --region $REGION
aws s3 mb s3://$OUTPUT_BUCKET --region $REGION
echo "S3-Buckets created: $INPUT_BUCKET and $OUTPUT_BUCKET"

# Erstellen von CSV-Testdateien
echo "Creating CSV test files..."
echo -e "name,age,city\nJohn,25,New York\nAlice,30,Los Angeles\nBob,22,Chicago" > test1.csv
echo -e "name,age,city\nEve,35,San Francisco\nCharlie,28,Boston\nDavid,40,Seattle" > test2.csv
echo -e "name,age,city\nSophia,22,Madrid\nOlivia,29,Paris\nLiam,34,London" > test3.csv
echo "CSV test files created."

# Hochladen der CSV-Dateien in den Input-Bucket
echo "Uploading test files to S3..."
aws s3 cp test1.csv s3://$INPUT_BUCKET/test1.csv --region $REGION
aws s3 cp test2.csv s3://$INPUT_BUCKET/test2.csv --region $REGION
aws s3 cp test3.csv s3://$INPUT_BUCKET/test3.csv --region $REGION
echo "Test files uploaded to $INPUT_BUCKET."

# Lambda-Funktion erstellen oder aktualisieren
echo "Creating or updating Lambda function..."
zip lambda.zip csv_to_json.js
aws lambda create-function --function-name $LAMBDA_NAME \
    --runtime nodejs18.x \
    --role $LAMBDA_ROLE_ARN \
    --handler csv_to_json.handler \
    --zip-file fileb://lambda.zip --region $REGION || \
aws lambda update-function-code --function-name $LAMBDA_NAME \
    --zip-file fileb://lambda.zip --region $REGION
echo "Lambda-Function $LAMBDA_NAME created."

# S3-Bucket-Trigger hinzufügen
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

# Überprüfen der konvertierten JSON-Dateien im Output-Bucket
echo "Checking for converted JSON files in the output bucket..."
aws s3 ls s3://$OUTPUT_BUCKET/ --region $REGION

# Aufräumen
rm lambda.zip
echo "Setup finished!"
