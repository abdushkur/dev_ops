#!/bin/bash
#
# This script automates the creation of service accounts for Google Cloud services.
# It's designed to help with service account creation by generating new accounts
# with predefined roles and a timestamped name.
#
# Prerequisites:
# 1. gcloud CLI: https://cloud.google.com/sdk/docs/install
#    - Authenticate with `gcloud auth login`
# 2. .env file in the same directory as this script containing:
#    PROJECT_ID=your_project_id
#    PROJECT_NUMBER=your_project_number
#    GITHUB_TOKEN=your_github_token (optional, for secret management)
#    - Get GitHub token from: https://github.com/settings/tokens
#
# Usage:
#   ./create-service-accounts.sh <ACCOUNT_TYPE>
#   Examples:
#     ./create-service-accounts.sh fastlane                 # Creates fastlane service account
#     ./create-service-accounts.sh github-actions           # Creates GitHub Actions service account
#
# Note: The script will automatically switch to the 'lebbey' project and restore
#       your original project when finished (regardless of success or failure).
#       For fastlane accounts, it will also automatically create/update the
#       'FASTLANE_SERVICE_ACCOUNT' GitHub Actions secret.

set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # The return value of a pipeline is the status of the last command to exit with a non-zero status.

# Set up trap to restore project on script exit (success or failure)
trap restore_project EXIT

# --- Configuration ---
# Load configuration from .env file if it exists
PROJECT_ID=""
PROJECT_NUMBER=""
GITHUB_TOKEN=""

# GitHub configuration (will be auto-detected from git remote)
GITHUB_OWNER=""
GITHUB_REPO=""

# Fastlane service account roles (for Firebase App Distribution)
FASTLANE_ROLES=(
  "roles/firebaseappdistro.admin"
)

# GitHub Actions service account roles (for Firebase hosting and tools)
GITHUB_ACTIONS_ROLES=(
  "roles/artifactregistry.admin"
  "roles/cloudbuild.workerPoolUser"
  "roles/cloudfunctions.admin"
  "roles/firebase.growthViewer"
  "roles/firebaseapphosting.computeRunner"
  "roles/firebaseapphosting.serviceAgent"
  "roles/firebaseauth.admin"
  "roles/firebaseextensions.developer"
  "roles/firebasehosting.admin"
  "roles/iam.roleViewer"
  "roles/iam.serviceAccountUser"
  "roles/run.admin"
  "roles/run.viewer"
  "roles/serviceusage.apiKeysViewer"
  "roles/serviceusage.serviceUsageConsumer"
  "roles/storage.admin"
)

# --- Helper Functions ---

# Store original project to restore later
ORIGINAL_PROJECT=""

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

    # Validate required variables
    if [ -z "$PROJECT_ID" ]; then
      echo "❌ ERROR: PROJECT_ID not found in .env file"
      exit 1
    fi

    if [ -z "$PROJECT_NUMBER" ]; then
      echo "❌ ERROR: PROJECT_NUMBER not found in .env file"
      exit 1
    fi

    echo "✅ Configuration loaded:"
    echo "   Project ID: $PROJECT_ID"
    echo "   Project Number: $PROJECT_NUMBER"
    if [ -n "$GITHUB_TOKEN" ]; then
      echo "   GitHub Token: [SET]"
    else
      echo "   GitHub Token: [NOT SET]"
    fi
  else
    echo "❌ ERROR: .env file not found in current directory"
    echo "   Please create a .env file with the following variables:"
    echo "   PROJECT_ID=your_project_id"
    echo "   PROJECT_NUMBER=your_project_number"
    echo "   GITHUB_TOKEN=your_github_token (optional)"
    exit 1
  fi
}

# Function to restore original project
restore_project() {
  if [ -n "$ORIGINAL_PROJECT" ] && [ "$ORIGINAL_PROJECT" != "$PROJECT_ID" ]; then
    echo "Restoring original project '$ORIGINAL_PROJECT'..."
    gcloud config set project "$ORIGINAL_PROJECT"
    echo "Project restored successfully."
  fi
}

# Function to detect GitHub repository from git remote
detect_github_repo() {
  local git_remote
  git_remote=$(git remote get-url origin 2>/dev/null || echo "")

  if [ -z "$git_remote" ]; then
    echo "⚠️  Warning: Could not detect GitHub repository. GitHub secret management will be skipped."
    return
  fi

  # Extract owner and repo from git remote URL
  if [[ "$git_remote" =~ github\.com[:/]([^/]+)/([^/]+)\.git$ ]]; then
    GITHUB_OWNER="${BASH_REMATCH[1]}"
    GITHUB_REPO="${BASH_REMATCH[2]}"
    echo "✅ Detected GitHub repository: $GITHUB_OWNER/$GITHUB_REPO"
  else
    echo "⚠️  Warning: Could not parse GitHub repository URL. GitHub secret management will be skipped."
  fi
}

# Function to check if GitHub secret exists
check_github_secret() {
  local secret_name="$1"

  if [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_REPO" ] || [ -z "$GITHUB_TOKEN" ]; then
    return 1
  fi

  # Use GitHub REST API to check if secret exists
  local response
  response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/secrets" 2>/dev/null)

  if echo "$response" | grep -q "\"name\":\"$secret_name\""; then
    return 0  # Secret exists
  else
    return 1  # Secret doesn't exist
  fi
}

# Function to create or update GitHub secret using our manage-github-secrets.sh script
create_or_update_github_secret() {
  local secret_name="$1"
  local secret_value="$2"

  if [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_REPO" ]; then
    echo "⚠️  Skipping GitHub secret management: Repository not detected"
    return
  fi

  if [ -z "$GITHUB_TOKEN" ]; then
    echo "⚠️  Skipping GitHub secret management: GITHUB_TOKEN not set"
    return
  fi

  echo "Managing GitHub secret: $secret_name"

  # Debug: show what we received
  echo "🔍 DEBUG: Received secret_name: '$secret_name'"
  echo "🔍 DEBUG: Received secret_value length: ${#secret_value} characters"
  echo "🔍 DEBUG: Secret value preview (first 100 chars): ${secret_value:0:100}..."
  echo "🔍 DEBUG: Secret value preview (last 100 chars): ...${secret_value: -100}"

  # Use our manage-github-secrets.sh script for proper secret management
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local dev_ops_dir="$(dirname "$script_dir")"
  local secrets_script="$dev_ops_dir/github/manage-github-secrets.sh"

  if [ ! -f "$secrets_script" ]; then
    echo "❌ ERROR: manage-github-secrets.sh script not found at $secrets_script"
    return 1
  fi

  # Make sure the script is executable
  chmod +x "$secrets_script"

                # Debug: show what we're passing to the script
              echo "🔍 DEBUG: Calling manage-github-secrets.sh with:"
              echo "   - Script: $secrets_script"
              echo "   - Args: --add '$secret_name' '${secret_value:0:50}...'"

              # Call the script in non-interactive mode
              if "$secrets_script" --add "$secret_name" "$secret_value"; then
                echo "  ✅ Secret '$secret_name' successfully managed!"
              else
                echo "  ❌ Failed to manage secret '$secret_name'"
                return 1
              fi
}

# Check for required tools
check_deps() {
  if ! command -v gcloud &> /dev/null; then
    echo "ERROR: 'gcloud' command not found. Please install the Google Cloud SDK and authenticate."
    exit 1
  fi

  if ! command -v curl &> /dev/null; then
    echo "ERROR: 'curl' command not found. Please install curl."
    exit 1
  fi

  # Check for GitHub token (required for API calls)
  if [ -z "$GITHUB_TOKEN" ]; then
    echo "⚠️  Warning: GITHUB_TOKEN environment variable not set."
    echo "   GitHub secret management will be skipped."
    echo "   To enable it, set: export GITHUB_TOKEN=your_github_token"
    echo "   Get token from: https://github.com/settings/tokens"
  fi

  # Check if a project is configured
  if ! gcloud config get-value project &> /dev/null; then
    echo "ERROR: No Google Cloud project is configured."
    echo "Please run 'gcloud config set project YOUR_PROJECT_ID'"
    exit 1
  fi

  # Load configuration from .env file
  load_env_config

  # Store current project and switch if needed
  ORIGINAL_PROJECT=$(gcloud config get-value project)
  if [ "$ORIGINAL_PROJECT" != "$PROJECT_ID" ]; then
    echo "Switching from project '$ORIGINAL_PROJECT' to '$PROJECT_ID'..."
    gcloud config set project "$PROJECT_ID"
    echo "Project switched successfully."
  fi

  # Detect GitHub repository
  detect_github_repo
}

# Function to create a new service account
create_service_account() {
  local account_type="$1"
  local display_name_prefix="$2"
  local roles_array_name="$3"

  local timestamp
  timestamp=$(date +"%Y%m%d-%H%M%S")
  local new_display_name="${display_name_prefix} (${timestamp})"
  local new_account_id="${account_type}-${timestamp}"
  local new_email="${new_account_id}@${PROJECT_ID}.iam.gserviceaccount.com"

  echo "--------------------------------------------------"
  echo "Creating new service account: '${new_display_name}'"
  echo "  - Account ID: ${new_account_id}"
  echo "  - Email: ${new_email}"
  echo "  - Roles: ${#roles_array_name[@]} roles"
  echo "--------------------------------------------------"

  # Create the service account
  echo "Creating service account..."
  gcloud iam service-accounts create "${new_account_id}" \
    --display-name="${new_display_name}" \
    --description="Service account for ${display_name_prefix} created on ${timestamp}"

  # Wait a moment for the service account to be fully available
  echo "Waiting for service account to be ready..."
  sleep 5

  # Verify the service account exists with retries
  local max_retries=3
  local retry_count=0
  local account_ready=false

  while [ $retry_count -lt $max_retries ] && [ "$account_ready" = false ]; do
    if gcloud iam service-accounts describe "${new_email}" &> /dev/null; then
      account_ready=true
      echo "Service account verified successfully."
    else
      retry_count=$((retry_count + 1))
      echo "Attempt ${retry_count}/${max_retries}: Service account not ready yet, waiting..."
      sleep 5
    fi
  done

  if [ "$account_ready" = false ]; then
    echo "ERROR: Service account creation failed or account not found after ${max_retries} attempts: ${new_email}"
    exit 1
  fi

  # Get the roles array dynamically
  local roles_array
  if [ "$account_type" = "fastlane" ]; then
    roles_array=("${FASTLANE_ROLES[@]}")
  else
    roles_array=("${GITHUB_ACTIONS_ROLES[@]}")
  fi

  # Assign roles to the service account
  echo "Assigning roles..."
  for role in "${roles_array[@]}"; do
    echo "  - Assigning role: ${role}"
    if gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
      --member="serviceAccount:${new_email}" \
      --role="${role}" \
      --no-user-output-enabled \
      --condition=None; then
      echo "    ✅ Role assigned successfully: ${role}"
    else
      echo "    ❌ Failed to assign role: ${role}"
      exit 1
    fi
  done

  # Verify roles were assigned
  echo "Verifying role assignments..."
  local assigned_roles
  assigned_roles=$(gcloud projects get-iam-policy "${PROJECT_ID}" \
    --flatten="bindings[].members" \
    --filter="bindings.members:${new_email}" \
    --format="value(bindings.role)" | wc -l)

  echo "  - Total roles assigned: ${assigned_roles}"
  if [ "$assigned_roles" -eq "${#roles_array[@]}" ]; then
    echo "  ✅ All roles assigned successfully!"
  else
    echo "  ⚠️  Expected ${#roles_array[@]} roles, but found ${assigned_roles} roles"
  fi

  # Create and download the JSON key
  echo "Creating JSON key file..."
  local key_file="${new_account_id}-key.json"
  gcloud iam service-accounts keys create "${key_file}" \
    --iam-account="${new_email}"

  # Handle GitHub secret management for fastlane accounts
  if [ "$account_type" = "fastlane" ]; then
    echo ""
    echo "🔐 Managing GitHub Actions Secret: FASTLANE_SERVICE_ACCOUNT"

    # Read the JSON key content
    local json_key_content
    json_key_content=$(cat "$key_file")

    # Debug: show what we're about to pass
    echo "🔍 DEBUG: JSON key file: $key_file"
    echo "🔍 DEBUG: JSON content length: ${#json_key_content} characters"
    echo "🔍 DEBUG: JSON content: ${json_key_content}"
    echo "🔍 DEBUG: About to call create_or_update_github_secret with:"
    echo "   - Secret name: FASTLANE_SERVICE_ACCOUNT"
    echo "   - Content length: ${#json_key_content}"

    # Create or update the GitHub secret
    create_or_update_github_secret "FASTLANE_SERVICE_ACCOUNT" "$json_key_content"

    echo "✅ GitHub secret management completed!"
  fi

  echo ""
  echo "✅ New Service Account created successfully!"
  echo "   Account ID: ${new_account_id}"
  echo "   Email: ${new_email}"
  echo "   Display Name: ${new_display_name}"
  echo "   Key File: ${key_file}"
  echo ""
  echo "➡️  Next steps:"
  echo "   1. The JSON key file '${key_file}' has been downloaded to your current directory."
  if [ "$account_type" = "fastlane" ]; then
    echo "   2. ✅ GitHub secret 'FASTLANE_SERVICE_ACCOUNT' has been created/updated automatically."
    echo "   3. Use this key file in your application or CI/CD pipeline."
    echo "   4. Store the key file securely and add it to your .gitignore if applicable."
    echo "   5. After confirming the new service account works, consider deleting old service accounts."
  else
    echo "   2. Use this key file in your application or CI/CD pipeline."
    echo "   3. Store the key file securely and add it to your .gitignore if applicable."
    echo "   4. After confirming the new service account works, consider deleting old service accounts."
  fi
  echo "--------------------------------------------------"
}

# --- Main Logic ---

main() {
  check_deps

  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <account_type>"
    echo "Available account types: fastlane, github-actions"
    echo ""
    echo "Account Types:"
    echo "  fastlane      - Creates service account for Firebase App Distribution (1 role)"
    echo "  github-actions - Creates service account for GitHub Actions/Firebase hosting (16 roles)"
    exit 1
  fi

  local account_type="$1"

  case "$account_type" in
    fastlane)
      create_service_account \
        "fastlane" \
        "Fastlane Service Account" \
        "FASTLANE_ROLES"
      ;;
    github-actions)
      create_service_account \
        "github-actions" \
        "GitHub Actions Service Account" \
        "GITHUB_ACTIONS_ROLES"
      ;;
    *)
      echo "ERROR: Invalid account type '${account_type}'."
      echo "Available account types: fastlane, github-actions"
      exit 1
      ;;
  esac
}

# Run the main function with all script arguments
main "$@"
