# Google Cloud Scripts

Tools for managing Google Cloud Platform resources and service accounts.

## Scripts

### create-service-accounts.sh
Automated service account creation with predefined roles for different services.

**Features:**
- Automatic project switching and restoration
- Timestamped service account naming
- JSON key file generation
- Automatic GitHub secret creation for Fastlane accounts
- Support for multiple account types

**Supported Account Types:**

1. **`fastlane`** - For deploying apps to Firebase App Distribution
   - Used by Fastlane to upload builds to Firebase App Distribution
   - Automatically creates/updates `FASTLANE_SERVICE_ACCOUNT` GitHub secret
   - Roles attached:
     - `roles/firebaseappdistro.admin` - Full access to Firebase App Distribution

2. **`github-actions`** - For Firebase Hosting deployment and other CI/CD operations
   - Used by GitHub Actions workflows for deploying to Firebase Hosting
   - Includes all necessary roles for Firebase services and artifact management
   - Roles attached:
     - `roles/artifactregistry.admin` - Manage artifact repositories
     - `roles/firebase.admin` - Full Firebase administration
     - `roles/firebasehosting.admin` - Deploy to Firebase Hosting
     - `roles/firebaseappcheck.admin` - Manage Firebase App Check
     - `roles/firebaseauth.admin` - Manage Firebase Authentication
     - `roles/cloudfunctions.admin` - Deploy Cloud Functions
     - `roles/run.admin` - Manage Cloud Run services
     - `roles/storage.admin` - Manage Cloud Storage buckets
     - `roles/iam.serviceAccountUser` - Act as service account

**Usage:**
```bash
# Create Fastlane service account
./create-service-accounts.sh fastlane

# Create GitHub Actions service account
./create-service-accounts.sh github-actions
```

## Configuration

Requires `../common/.env` file with:
```
PROJECT_ID=your_gcp_project_id
PROJECT_NUMBER=your_gcp_project_number
GITHUB_TOKEN=your_github_token  # Optional, for automatic secret creation
```

## Prerequisites

1. Install gcloud CLI: https://cloud.google.com/sdk/docs/install
2. Authenticate: `gcloud auth login`
3. Set up Application Default Credentials: `gcloud auth application-default login`

## Generated Files

Service account keys are saved as:
- `fastlane-YYYYMMDD-HHMMSS-key.json`
- `github-actions-YYYYMMDD-HHMMSS-key.json`

**Important:** Keep these key files secure and never commit them to version control.