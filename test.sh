#!/bin/bash

# 1. Init-Script ausführen und Bucket-Namen extrahieren
echo "Running init.sh to set up infrastructure..."
INIT_OUTPUT=$(./init.sh) || { echo "init.sh failed to set up infrastructure"; exit 1; }
echo "$INIT_OUTPUT"

# Bucket-Namen aus der Ausgabe extrahieren
INPUT_BUCKET=$(echo "$INIT_OUTPUT" | grep "Input-Bucket" | awk '{print $2}')
OUTPUT_BUCKET=$(echo "$INIT_OUTPUT" | grep "Output-Bucket" | awk '{print $2}')

if [ -z "$INPUT_BUCKET" ] || [ -z "$OUTPUT_BUCKET" ]; then
    echo "Error: Could not determine bucket names from init.sh"
    exit 1
fi
echo "Input bucket: $INPUT_BUCKET"
echo "Output bucket: $OUTPUT_BUCKET"

# 2. Test-CSV-Dateien erstellen
echo "Creating test CSV files..."
echo -e "name,age,city\nJohn,25,New York\nAlice,30,Los Angeles\nBob,22,Chicago" > test1.csv
echo -e "name,age,city\nEve,35,San Francisco\nCharlie,28,Boston\nDavid,40,Seattle" > test2.csv
echo -e "name,age,city\nSophia,22,Madrid\nOlivia,29,Paris\nLiam,34,London" > test3.csv

# Sehr große CSV-Datei erstellen
echo "Creating a very large CSV file: test4.csv"
echo "name,age,city" > test4.csv
seq 1 10000 | awk -F, '{print "User" $1 "," int(rand()*100) "," "City" $1}' >> test4.csv
echo "Test4.csv created with 10,000 rows."

# 3. CSV-Dateien hochladen
echo "Uploading CSV files to input bucket: $INPUT_BUCKET"
aws s3 cp test1.csv s3://$INPUT_BUCKET/test1.csv --region us-east-1 || { echo "Failed to upload test1.csv"; exit 1; }
aws s3 cp test2.csv s3://$INPUT_BUCKET/test2.csv --region us-east-1 || { echo "Failed to upload test2.csv"; exit 1; }
aws s3 cp test3.csv s3://$INPUT_BUCKET/test3.csv --region us-east-1 || { echo "Failed to upload test3.csv"; exit 1; }
aws s3 cp test4.csv s3://$INPUT_BUCKET/test4.csv --region us-east-1 || { echo "Failed to upload test4.csv"; exit 1; }

# 4. Warten auf Verarbeitung
echo "Waiting for files to be processed..."
sleep 15  # Wartezeit für die Lambda-Verarbeitung

# 5. Überprüfen der JSON-Dateien im Output-Bucket
echo "Checking output bucket for JSON files..."
JSON_FILES=$(aws s3 ls s3://$OUTPUT_BUCKET/ --region us-east-1 | grep ".json")
JSON_FILES_COUNT=$(echo "$JSON_FILES" | wc -l)

if [ "$JSON_FILES_COUNT" -eq 4 ]; then
    echo "Test passed: Found 4 JSON files in the output bucket."
else
    echo "Test failed: Expected 4 JSON files, but found $JSON_FILES_COUNT."
    exit 1
fi

# 6. Herunterladen der JSON-Dateien
echo "Downloading JSON files from output bucket: $OUTPUT_BUCKET"
aws s3 cp s3://$OUTPUT_BUCKET/ ./ --recursive --exclude "*" --include "*.json" --region us-east-1 || { echo "Failed to download JSON files"; exit 1; }
echo "JSON files downloaded successfully to the current directory."

# 7. Aufräumen
rm test1.csv test2.csv test3.csv test4.csv
echo "Test completed successfully!"

