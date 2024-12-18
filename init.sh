#!/bin/bash

# Variablen definieren
DATE=$(date +"%Y%m%d%H%M%S")  # Format: YYYYMMDDHHMM
INPUT_BUCKET="josiaschweizer-input-bucket-$DATE"
OUTPUT_BUCKET="josiaschweizer-output-bucket"  # Fester Output-Bucket-Name
LAMBDA_NAME="CsvToJsonConverterV2-josia123-$DATE"
LAMBDA_ROLE_ARN=$(aws iam get-role --role-name 'LabRole' --query 'Role.Arn' --output text)
REGION="us-east-1"

# Überprüfen, ob csv_to_json.js existiert
if [ ! -f csv_to_json.js ]; then
    echo "Error: csv_to_json.js not found!"
    exit 1
fi

# Funktion zum Löschen eines Buckets (falls vorhanden)
delete_bucket_if_exists() {
    BUCKET_NAME=$1
    if aws s3 ls "s3://$BUCKET_NAME" --region $REGION >/dev/null 2>&1; then
        echo "Bucket $BUCKET_NAME exists. Deleting it..."
        aws s3 rb "s3://$BUCKET_NAME" --force --region $REGION || { echo "Failed to delete $BUCKET_NAME"; exit 1; }
        echo "Bucket $BUCKET_NAME deleted."
    else
        echo "Bucket $BUCKET_NAME does not exist. No need to delete."
    fi
}

# 1. Überprüfen und Löschen der vorhandenen Buckets (falls nötig)
delete_bucket_if_exists $OUTPUT_BUCKET

# 2. S3-Buckets erstellen
echo "Creating AWS S3-Buckets..."
aws s3 mb s3://$INPUT_BUCKET --region $REGION || { echo "Failed to create input bucket"; exit 1; }
aws s3 mb s3://$OUTPUT_BUCKET --region $REGION || { echo "Failed to create output bucket"; exit 1; }
echo "S3-Buckets created: $INPUT_BUCKET and $OUTPUT_BUCKET"

# 3. Lambda-Funktion erstellen oder aktualisieren
echo "Creating or updating Lambda function..."
# Cleanup existing zip if exists
rm -f lambda.zip

# Create new zip file
zip lambda.zip csv_to_json.js || { echo "Failed to create zip file"; exit 1; }

# Erstelle oder update die Lambda-Funktion und setze die Umgebungsvariablen
if aws lambda get-function --function-name $LAMBDA_NAME --region $REGION 2>/dev/null; then
    echo "Updating existing Lambda function..."
    asdf=$(aws lambda update-function-configuration \
        --function-name $LAMBDA_NAME \
        --environment "Variables={OUTPUT_BUCKET=$OUTPUT_BUCKET}" \
        --region $REGION || { echo "Failed to update Lambda function configuration"; exit 1; }
    aws lambda update-function-code \
        --function-name $LAMBDA_NAME \
        --zip-file fileb://lambda.zip \
        --region $REGION) || { echo "Failed to update Lambda function"; exit 1; }
else
    echo "Creating new Lambda function..."
    asdf=$(aws lambda create-function \
        --function-name $LAMBDA_NAME \
        --runtime nodejs18.x \
        --role $LAMBDA_ROLE_ARN \
        --handler csv_to_json.handler \
        --zip-file fileb://lambda.zip \
        --environment "Variables={OUTPUT_BUCKET=$OUTPUT_BUCKET}" \
        --region $REGION) || { echo "Failed to create Lambda function"; exit 1; }
fi
echo "Lambda-Function $LAMBDA_NAME deployed successfully."

# 4. S3-Bucket-Trigger hinzufügen
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

# Setze S3-Trigger für den Input-Bucket
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

# Ausgabe der erstellten Buckets
echo "Input-Bucket: $INPUT_BUCKET"
echo "Output-Bucket: $OUTPUT_BUCKET"

# Aufräumen
rm -f lambda.zip
echo "Setup finished!"

