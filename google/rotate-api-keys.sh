#!/bin/bash
#
# This script automates the creation of new API keys for Google Cloud services.
# It's designed to help with API key rotation by generating a new key with
# predefined restrictions and a timestamped name.
#
# Features:
# - Automatic project switching based on PROJECT_ID in .env
# - Restores original project on exit (success or failure)
# - Configurable domains and API restrictions via .env file
#
# Prerequisites:
# 1. gcloud CLI: https://cloud.google.com/sdk/docs/install
#    - Authenticate with `gcloud auth login`
# 2. .env file in ../common/.env with:
#    - PROJECT_ID (required) - Target GCP project
#    - API key configuration (domains, APIs, etc.)

set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # The return value of a pipeline is the status of the last command to exit with a non-zero status.

# --- Configuration ---
# Default values (will be overridden by .env if present)
PROD_DOMAIN="example.com"
ANDROID_APP_PACKAGE_NAME="com.example.app"
IOS_APP_BUNDLE_ID="com.example.app"

# Common APIs for a Firebase web app:
FIREBASE_APIS="storage-component.googleapis.com,storage.googleapis.com,firebasestorage.googleapis.com,firebaseappcheck.googleapis.com,firebaseapphosting.googleapis.com,firebaseappdistribution.googleapis.com,firebaseapptesters.googleapis.com,fcm.googleapis.com,firebasedynamiclinks.googleapis.com,firebaseextensions.googleapis.com,firebasehosting.googleapis.com,firebaseremoteconfig.googleapis.com,storage-api.googleapis.com,identitytoolkit.googleapis.com,recaptchaenterprise.googleapis.com,firebasedatabase.googleapis.com,firebase.googleapis.com,firebaseremoteconfigrealtime.googleapis.com,firebaserules.googleapis.com,geocoding-backend.googleapis.com,geolocation.googleapis.com,cloudapis.googleapis.com,iam.googleapis.com,iamcredentials.googleapis.com,cloudfunctions.googleapis.com,firebaseinstallations.googleapis.com,firestorekeyvisualizer.googleapis.com,appenginereporting.googleapis.com,artifactregistry.googleapis.com,firestore.googleapis.com,runtimeconfig.googleapis.com,developerconnect.googleapis.com,fcmregistrations.googleapis.com,privilegedaccessmanager.googleapis.com,maps-backend.googleapis.com,maps-embed-backend.googleapis.com,secretmanager.googleapis.com,securetoken.googleapis.com"

# Common APIs for Google Maps JavaScript:
MAPS_APIS="maps-backend.googleapis.com,static-maps-backend.googleapis.com,places.googleapis.com,places-backend.googleapis.com,maps-embed-backend.googleapis.com,elevation-backend.googleapis.com,geocoding-backend.googleapis.com"

# Common APIs for server-side Firebase authentication:
SERVER_FIREBASE_APIS="identitytoolkit.googleapis.com,securetoken.googleapis.com"

# localhost domains
LOCALHOST_DOMAINS="http://localhost/*,http://localhost:3000,http://localhost:3001"

# Store original project to restore later
ORIGINAL_PROJECT=""

# --- Helper Functions ---

# Set up trap to restore project on script exit (success or failure)
trap restore_project EXIT

# Function to load configuration from .env file
load_env_config() {
  # Get the directory where this script is located
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local dev_ops_dir="$(dirname "$script_dir")"
  local env_file="$dev_ops_dir/common/.env"

  if [ -f "$env_file" ]; then
    echo "📁 Loading configuration from .env file..."
    
    # Source the .env file
    set -a  # automatically export all variables
    source "$env_file"
    set +a  # turn off automatic export
    
    # Validate required PROJECT_ID
    if [ -z "$PROJECT_ID" ]; then
      echo "❌ ERROR: PROJECT_ID not found in .env file"
      echo "   Please add PROJECT_ID=your_project_id to your .env file"
      exit 1
    fi
    
    echo "✅ Configuration loaded:"
    echo "   Project ID: ${PROJECT_ID}"
    echo "   Production Domain: ${PROD_DOMAIN}"
    echo "   Android Package: ${ANDROID_APP_PACKAGE_NAME}"
    echo "   iOS Bundle ID: ${IOS_APP_BUNDLE_ID}"
    
    # Add production domain to localhost domains if not already included
    if [[ "$LOCALHOST_DOMAINS" != *"https://m.${PROD_DOMAIN}"* ]]; then
      LOCALHOST_DOMAINS="${LOCALHOST_DOMAINS},https://m.${PROD_DOMAIN},https://${PROD_DOMAIN}"
    fi
  else
    echo "⚠️  Warning: .env file not found at $env_file"
    echo "   Using default configuration values"
    echo "   Create a .env file from .env.example for custom configuration"
  fi
  echo ""
}

# Function to restore original project
restore_project() {
  if [ -n "$ORIGINAL_PROJECT" ] && [ "$ORIGINAL_PROJECT" != "$PROJECT_ID" ]; then
    echo "Restoring original project '$ORIGINAL_PROJECT'..."
    gcloud config set project "$ORIGINAL_PROJECT"
    echo "Project restored successfully."
  fi
}

# Check for required tools
check_deps() {
  if ! command -v gcloud &> /dev/null; then
    echo "ERROR: 'gcloud' command not found. Please install the Google Cloud SDK and authenticate."
    exit 1
  fi
  
  # Check if a project is configured
  if ! gcloud config get-value project &> /dev/null; then
    echo "ERROR: No Google Cloud project is configured."
    echo "Please run 'gcloud config set project YOUR_PROJECT_ID'"
    exit 1
  fi
  
  # Store current project for restoration later
  ORIGINAL_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
  
  # Switch to target project if different
  if [ -n "$PROJECT_ID" ] && [ "$ORIGINAL_PROJECT" != "$PROJECT_ID" ]; then
    echo "Switching from project '$ORIGINAL_PROJECT' to '$PROJECT_ID'..."
    gcloud config set project "$PROJECT_ID"
    echo "Project switched successfully."
  elif [ -n "$PROJECT_ID" ]; then
    echo "Already using project '$PROJECT_ID'."
  fi
}

# Function to create a new API key
create_api_key() {
  local display_name_prefix="$1"
  local allowed_referrers="$2"
  local api_list="$3" # Comma-separated list of APIs

  local timestamp
  timestamp=$(date +"%Y%m%d-%H%M%S")
  local new_display_name="${display_name_prefix} (${timestamp})"

  echo "--------------------------------------------------"
  echo "Creating new API key: '${new_display_name}'"
  echo "  - Allowed Referrers: ${allowed_referrers}"
  echo "  - Enabled APIs: ${api_list}"
  echo "--------------------------------------------------"

  # Build the gcloud command arguments dynamically
  local gcloud_args=()
  gcloud_args+=(--display-name="${new_display_name}")
  gcloud_args+=(--allowed-referrers="${allowed_referrers}")

  # Build --api-target flag from the comma-separated list
  # The --api-target flag expects service=SERVICE format
  IFS=',' read -ra apis_to_add <<< "$api_list"
  for api in "${apis_to_add[@]}"; do
    # Skip empty entries that might result from a trailing comma
    if [ -n "$api" ]; then
      gcloud_args+=(--api-target="service=${api}")
    fi
  done

    # The `gcloud services api-keys create` command creates API keys with the specified restrictions.
  local response
  response=$(gcloud services api-keys create "${gcloud_args[@]}" 2>&1)
  
  # Extract the key string from the JSON response
  local new_key_string
  new_key_string=$(echo "$response" | grep -o '"keyString":"[^"]*"' | sed 's/.*"keyString":"\([^"]*\)".*/\1/')
  

  
  if [ -z "$new_key_string" ]; then
    echo "ERROR: Failed to create API key. Please check your permissions and ensure the following APIs are enabled:"
    echo " - serviceusage.googleapis.com"
    echo " - cloudresourcemanager.googleapis.com"
    exit 1
  fi

  echo ""
  echo "✅ New API Key created successfully!"
  echo "   Key: ${new_key_string}"
  echo ""
  echo "➡️  Next steps:"
  echo "   1. Copy the key above."
  echo "   2. Replace the old key in your .env file or GitHub secrets."
  echo "   3. After confirming the new key works, remember to DELETE the old key from the Google Cloud Console to complete the rotation."
  echo "--------------------------------------------------"
}

# --- Main Logic ---

main() {
  # Load configuration from .env file
  load_env_config
  
  check_deps

  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <key_type>"
    echo "Available key types: prod-firebase, prod-maps, local-firebase, local-maps, server-maps, server-firebase"
    exit 1
  fi

  local key_type="$1"

  case "$key_type" in
    prod-firebase)
      create_api_key \
        "Prod Firebase Web" \
        "https://*.${PROD_DOMAIN},https://${PROD_DOMAIN}" \
        "${FIREBASE_APIS}"
      ;;
    prod-maps)
      create_api_key \
        "Prod Google Maps Web" \
        "https://*.${PROD_DOMAIN},https://${PROD_DOMAIN}" \
        "${MAPS_APIS}"
      ;;
    local-firebase)
      create_api_key \
        "Local Firebase Web" \
        "${LOCALHOST_DOMAINS}" \
        "${FIREBASE_APIS}"
      ;;
    local-maps)
      create_api_key \
        "Local Google Maps Web" \
        "${LOCALHOST_DOMAINS}" \
        "${MAPS_APIS}"
      ;;
    server-maps)
      create_api_key \
        "Server-Side Google Maps" \
        "" \
        "${MAPS_APIS}"
      ;;
    server-firebase)
      create_api_key \
        "Server-Side Firebase" \
        "" \
        "${SERVER_FIREBASE_APIS}"
      ;;
      *)
        echo "ERROR: Invalid key type '${key_type}'."
        echo "Available key types: prod-firebase, prod-maps, local-firebase, local-maps, server-maps, server-firebase"
        exit 1
        ;;
  esac
}

# Run the main function with all script arguments
main "$@"