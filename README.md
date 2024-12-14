# project346-lambda

## Projektübersicht
**Ziel:**  
Dieses Projekt stellt einen CSV-zu-JSON-Konvertierungsdienst in AWS Lambda zur Verfügung, der automatisch ausgelöst wird, wenn CSV-Dateien in einen S3-Bucket hochgeladen werden. Die Lambda-Funktion konvertiert die CSV-Datei und speichert das Ergebnis als JSON-Datei in einem anderen S3-Bucket.

**Technologien:**
- AWS S3
- AWS Lambda
- AWS CLI
- Node.js

**Funktionsweise:**  
Die Lambda-Funktion wird ausgelöst, wenn eine CSV-Datei in den Input-S3-Bucket hochgeladen wird. Die Funktion konvertiert die CSV-Daten in JSON und speichert die resultierende JSON-Datei im Output-S3-Bucket.

---

## Setup und Konfiguration

### 1. **Voraussetzungen:**
- **AWS CLI** muss auf deinem lokalen Computer installiert sein.
- Du musst ein AWS-Konto haben und über die entsprechenden Anmeldeinformationen verfügen.

### 2. **AWS CLI Installation:**
Installiere die AWS CLI auf deinem Computer. Für Ubuntu (und andere Debian-basierte Distributionen) kannst du den folgenden Befehl verwenden:
```bash
sudo apt install awscli
