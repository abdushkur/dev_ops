# Google Cloud Scripts

Tools for managing Google Cloud Platform resources and service accounts.

## Scripts

### rotate-api-keys.sh

Automated API key creation and rotation with predefined restrictions for different environments.

**Features:**

- Creates timestamped API keys for easy tracking
- Automatic project switching and restoration
- Predefined configurations for common use cases
- Domain and API restrictions for security
- Support for production, local, and server environments

**Supported Key Types:**

- `prod-firebase` - Production Firebase web app with domain restrictions
- `prod-maps` - Production Google Maps with domain restrictions
- `local-firebase` - Local development Firebase (localhost access)
- `local-maps` - Local development Google Maps (localhost access)
- `server-maps` - Server-side Google Maps (no referrer restrictions)
- `server-firebase` - Server-side Firebase auth (no referrer restrictions)

**Usage:**

```bash
# Create a new production Firebase API key
./rotate-api-keys.sh prod-firebase

# Create a new local development Maps key
./rotate-api-keys.sh local-maps

# Create a server-side Firebase key
./rotate-api-keys.sh server-firebase
```

**Configuration:**
Customize domains and APIs in `../common/.env`:

- `PROD_DOMAIN` - Your production domain
- `ANDROID_APP_PACKAGE_NAME` - Android app package
- `IOS_APP_BUNDLE_ID` - iOS bundle identifier
- `LOCALHOST_DOMAINS` - Development domains
- `FIREBASE_APIS`, `MAPS_APIS`, `SERVER_FIREBASE_APIS` - API services

### create-service-accounts.sh

Automated service account creation with predefined roles for different services.

**Features:**

- Automatic project switching and restoration
- Timestamped service account naming
- JSON key file generation
- Automatic GitHub secret creation for both account types
- Support for multiple account types

**Supported Account Types:**

1. **`fastlane`** - For deploying apps to Firebase App Distribution
   - Used by Fastlane to upload builds to Firebase App Distribution
   - Automatically creates/updates `FASTLANE_SERVICE_ACCOUNT` GitHub secret
   - Roles attached:
     - `roles/firebaseappdistro.admin` - Full access to Firebase App Distribution

2. **`github-actions`** - For Firebase Hosting deployment and other CI/CD operations
   - Used by GitHub Actions workflows for deploying to Firebase Hosting
   - Automatically creates/updates `APP_HOSTING_GITHUB_ACTION_SERVICE_ACCOUNT` GitHub secret
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

```env
PROJECT_ID=your_gcp_project_id
PROJECT_NUMBER=your_gcp_project_number
GITHUB_TOKEN=your_github_token  # Optional, for automatic secret creation
```

## Prerequisites

1. Install gcloud CLI: <https://cloud.google.com/sdk/docs/install>
2. Authenticate: `gcloud auth login`
3. Set up Application Default Credentials: `gcloud auth application-default login`

## Generated Files

Service account keys are saved as:

- `fastlane-YYYYMMDD-HHMMSS-key.json`
- `github-actions-YYYYMMDD-HHMMSS-key.json`

**Important:** Keep these key files secure and never commit them to version control.
