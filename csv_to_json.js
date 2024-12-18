const AWS = require('aws-sdk');
const s3 = new AWS.S3();
const csv = require('csvtojson');

exports.handler = async (event) => {
    const bucket = event.Records[0].s3.bucket.name;
    const key = decodeURIComponent(event.Records[0].s3.object.key);

    try {
        const csvData = await s3.getObject({ Bucket: bucket, Key: key }).promise();
        const jsonData = await csv().fromString(csvData.Body.toString());
        const jsonKey = key.replace('.csv', '.json');

        await s3.putObject({
            Bucket: 'josiaschweizer-output-bucket',
            Key: jsonKey,
            Body: JSON.stringify(jsonData),
            ContentType: 'application/json',
        }).promise();

        console.log(`Konvertiert und gespeichert: ${jsonKey}`);
    } catch (error) {
        console.error(`Fehler: ${error.message}`);
    }
};
