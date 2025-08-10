#!/bin/bash

# GitHub Secrets Manager Script
# Interactive script to manage GitHub repository secrets

set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
GITHUB_OWNER=""
GITHUB_REPO=""
GITHUB_TOKEN=""

# Track source of repository configuration
REPO_FROM_ENV=""
REPO_FROM_PARAM=""

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to load configuration from .env file
load_env_config() {
    # Get the directory where this script is located
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local dev_ops_dir="$(dirname "$script_dir")"
    local env_file="$dev_ops_dir/common/.env"

    if [ -f "$env_file" ]; then
        print_status $BLUE "📁 Loading configuration from .env file..."

        # Source the .env file
        set -a
        source "$env_file"
        set +a

        # Validate required variables
        if [ -z "$GITHUB_TOKEN" ]; then
            print_status $RED "❌ ERROR: GITHUB_TOKEN not found in .env file"
            exit 1
        fi

        print_status $GREEN "✅ Configuration loaded:"
        print_status $BLUE "   GitHub Token: [SET]"
        
        # Check if repository is specified in .env
        if [ -n "$GITHUB_OWNER" ] && [ -n "$GITHUB_REPO" ]; then
            print_status $BLUE "   Repository: $GITHUB_OWNER/$GITHUB_REPO (from .env)"
            REPO_FROM_ENV=1
        fi
    else
        print_status $RED "❌ ERROR: .env file not found at $env_file"
        print_status $YELLOW "   Please create a .env file with GITHUB_TOKEN=your_token"
        exit 1
    fi
}

# Function to detect GitHub repository from git remote
detect_github_repo() {
    # Skip auto-detection if already set (e.g., via --repo parameter or .env file)
    if [ -n "$GITHUB_OWNER" ] && [ -n "$GITHUB_REPO" ]; then
        # Determine source of repository configuration
        if [ -n "$REPO_FROM_PARAM" ]; then
            print_status $GREEN "✅ Using repository from --repo parameter: $GITHUB_OWNER/$GITHUB_REPO"
        elif [ -n "$REPO_FROM_ENV" ]; then
            print_status $GREEN "✅ Using repository from .env file: $GITHUB_OWNER/$GITHUB_REPO"
        else
            print_status $GREEN "✅ Using specified repository: $GITHUB_OWNER/$GITHUB_REPO"
        fi
        return
    fi
    
    local remote_url=$(git remote get-url origin 2>/dev/null || echo "")

    if [ -z "$remote_url" ]; then
        print_status $RED "❌ ERROR: No git remote 'origin' found"
        print_status $YELLOW "   Please do one of the following:"
        print_status $YELLOW "   1. Set GITHUB_OWNER and GITHUB_REPO in your .env file"
        print_status $YELLOW "   2. Use --repo owner/repository parameter"
        print_status $YELLOW "   3. Run this script from a git repository"
        exit 1
    fi

    # Extract owner and repo from git remote URL
    if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/]+)\.git$ ]]; then
        GITHUB_OWNER="${BASH_REMATCH[1]}"
        GITHUB_REPO="${BASH_REMATCH[2]}"
        print_status $GREEN "✅ Auto-detected GitHub repository: $GITHUB_OWNER/$GITHUB_REPO"
    else
        print_status $RED "❌ ERROR: Could not parse GitHub repository from remote URL"
        print_status $YELLOW "   Remote URL: $remote_url"
        print_status $YELLOW "   Please set GITHUB_OWNER and GITHUB_REPO in your .env file"
        print_status $YELLOW "   or use --repo owner/repository parameter"
        exit 1
    fi
}

# Function to parse repository from --repo parameter
parse_repo_param() {
    local repo_param="$1"
    
    if [[ "$repo_param" =~ ^([^/]+)/([^/]+)$ ]]; then
        GITHUB_OWNER="${BASH_REMATCH[1]}"
        GITHUB_REPO="${BASH_REMATCH[2]}"
        REPO_FROM_PARAM=1
        print_status $BLUE "📌 Repository set to: $GITHUB_OWNER/$GITHUB_REPO"
    else
        print_status $RED "❌ ERROR: Invalid repository format: $repo_param"
        print_status $YELLOW "   Expected format: owner/repository"
        print_status $YELLOW "   Example: --repo abdushkur/lebbey_flutter"
        exit 1
    fi
}



# Function to check if a secret exists
check_secret_exists() {
    local secret_name=$1

    local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/secrets/$secret_name" 2>/dev/null)

    # Check for "Not Found" message or empty response
    if [[ "$response" == *"Not Found"* ]] || [[ -z "$response" ]]; then
        return 1  # Secret doesn't exist
    else
        return 0  # Secret exists
    fi
}



# Function to get repository public key
get_repo_public_key() {
    local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/secrets/public-key" 2>/dev/null)

    # Debug: show response structure (redirect to stderr to avoid interfering with data)
    print_status $BLUE "🔍 Debug: GitHub API response length: ${#response} chars" >&2

    # Extract key_id and key from response
    local key_id=""
    local key=""

    if command -v jq &> /dev/null; then
        key_id=$(echo "$response" | jq -r '.key_id')
        key=$(echo "$response" | jq -r '.key')
    else
        # Fallback to awk method - more robust parsing
        key_id=$(echo "$response" | awk -F'"' '/"key_id"/ {print $4}')
        # Extract the key value more carefully
        key=$(echo "$response" | awk -F': ' '/"key"/ {gsub(/[",]/, "", $2); print $2}')
    fi

    # Debug: show extracted values and raw response (redirect to stderr)
    print_status $BLUE "🔍 Debug: Extracted key_id: '$key_id', key length: ${#key} chars" >&2
    print_status $BLUE "🔍 Debug: Raw response preview: ${response:0:100}..." >&2
    print_status $BLUE "🔍 Debug: Key value: '$key'" >&2

    # Return only the data, not the debug messages
    printf "%s|%s" "$key_id" "$key"
}

# Function to add or update a secret
add_or_update_secret() {
    local secret_name=$1
    local secret_value=$2

    # Debug: show what we received
    print_status $BLUE "🔍 DEBUG: add_or_update_secret received:" >&2
    print_status $BLUE "   - secret_name: '$secret_name'" >&2
    print_status $BLUE "   - secret_value length: ${#secret_value} characters" >&2
    print_status $BLUE "   - secret_value preview (first 100 chars): ${secret_value:0:100}..." >&2
    print_status $BLUE "   - secret_value preview (last 100 chars): ...${secret_value: -100}" >&2

    # Check if secret exists
    if check_secret_exists "$secret_name"; then
        print_status $YELLOW "⚠️  Secret '$secret_name' already exists. Updating..."
    else
        print_status $BLUE "➕ Adding new secret '$secret_name'..."
    fi

    # Get repository public key
    local key_info=$(get_repo_public_key)
    local key_id=$(echo "$key_info" | cut -d'|' -f1)
    local public_key=$(echo "$key_info" | cut -d'|' -f2)

    if [ -z "$key_id" ] || [ -z "$public_key" ]; then
        print_status $RED "❌ Failed to get repository public key"
        return 1
    fi

    # Get the directory where this script is located
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local encrypt_script="$script_dir/github-secret-encrypt.js"
    
    # Check if our encryption script exists and Node.js is available
    if [ -f "$encrypt_script" ] && command -v node &> /dev/null; then
        # Use proper libsodium encryption via Node.js
        print_status $BLUE "🔐 Using libsodium encryption..." >&2
        
        # Write secret to temp file to avoid shell escaping issues
        local temp_file=$(mktemp)
        printf '%s' "$secret_value" > "$temp_file"
        
        # Encrypt using our Node.js script
        local encrypted_value=$(node "$encrypt_script" "$public_key" "@$temp_file" 2>/dev/null)
        
        # Clean up temp file
        rm -f "$temp_file"
        
        if [ -z "$encrypted_value" ]; then
            print_status $YELLOW "⚠️  Encryption failed, falling back to base64..." >&2
            encrypted_value=$(printf '%s' "$secret_value" | base64)
        fi
    else
        # Fallback to base64 encoding (may work for small secrets)
        print_status $YELLOW "⚠️  Using base64 encoding (encryption script not found)..." >&2
        encrypted_value=$(printf '%s' "$secret_value" | base64)
    fi
    
    # Create the JSON payload using printf to avoid issues with special characters
    local json_payload=$(printf '{"encrypted_value":"%s","key_id":"%s"}' "$encrypted_value" "$key_id")
    
    # Create or update the secret
    local response=$(curl -s -w "%{http_code}" -X PUT \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        -d "$json_payload" \
        "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/secrets/$secret_name" 2>/dev/null)

    local http_code="${response: -3}"
    local response_body="${response%???}"

    if [ "$http_code" -eq 201 ] || [ "$http_code" -eq 204 ]; then
        print_status $GREEN "✅ Secret '$secret_name' successfully managed!"
    else
        print_status $RED "❌ Failed to manage secret '$secret_name'"
        print_status $YELLOW "   HTTP Code: $http_code"
        print_status $YELLOW "   Response: $response_body"
        return 1
    fi
}

# Function to get secret value from user
get_secret_value() {
    local secret_name=$1
    local prompt="Enter value for secret '$secret_name': "
    local secret_value=""
    local confirm=""

    # Use regular read (no hiding) so user can see what they're typing
    read -p "$prompt" secret_value
    echo

    # Show what was entered
    echo "You entered: '$secret_value'"
    echo

    # Ask for confirmation
    read -p "Confirm value for '$secret_name'? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "$secret_value"
    else
        echo ""
    fi
}

# Function to get secrets and return them as arrays
get_secrets() {
    local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/secrets?per_page=100" 2>/dev/null)

    # Parse secret names from response using jq if available, otherwise use awk
    if command -v jq &> /dev/null; then
        echo "$response" | jq -r '.secrets[].name'
    else
        # Fallback to awk method - more reliable
        echo "$response" | awk -F'"' '/"name"/ {print $4}'
    fi
}

# Function to show main menu
show_menu() {
    echo
    print_status $BLUE "🔐 GitHub Secrets Manager"
    print_status $BLUE "Repository: $GITHUB_OWNER/$GITHUB_REPO"
    echo

    # Get current secrets
    local -a secret_names=()  # Reset array
    local line_num=1

    while IFS= read -r secret_name_from_api; do
        if [ -n "$secret_name_from_api" ]; then
            secret_names+=("$secret_name_from_api")
            echo "   $line_num. $secret_name_from_api"
            ((line_num++))
        fi
    done < <(get_secrets)

    if [ ${#secret_names[@]} -eq 0 ]; then
        print_status $YELLOW "No existing secrets found. Choose an option:"
        echo "1. Add new secret"
        echo "2. Exit"
    else
        print_status $GREEN "Existing secrets:"
        echo "   $line_num. Add new secret"
        echo "   $((line_num+1)). Exit"
    fi
    echo
}

# Function to handle secret selection
handle_secret_selection() {
    local secret_name=$1

    if [ -z "$secret_name" ]; then
        read -p "Enter secret name: " secret_name
    fi

    if [ -z "$secret_name" ]; then
        print_status $RED "❌ Secret name cannot be empty"
        return 1
    fi

    # Check if secret exists
    if check_secret_exists "$secret_name"; then
        print_status $YELLOW "⚠️  Secret '$secret_name' already exists"
        read -p "Do you want to overwrite it? (y/N): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            print_status $BLUE "Operation cancelled"
            return 0
        fi
    fi

    # Get secret value
    local secret_value=$(get_secret_value "$secret_name")
    if [ -z "$secret_value" ]; then
        print_status $BLUE "Operation cancelled"
        return 0
    fi

    # Add or update the secret
    add_or_update_secret "$secret_name" "$secret_value"
}



# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Interactive mode (no arguments):"
    echo "  $0                    # Start interactive GitHub secrets manager"
    echo
    echo "Non-interactive mode:"
    echo "  $0 --add SECRET_NAME SECRET_VALUE  # Add/update a secret"
    echo "  $0 --check SECRET_NAME             # Check if secret exists"
    echo "  $0 --repo OWNER/REPO ...           # Specify repository manually"
    echo
    echo "Examples:"
    echo "  $0 --add ENV_FILE 'content=value'"
    echo "  $0 --check FASTLANE_SERVICE_ACCOUNT"
    echo "  $0 --repo abdushkur/lebbey_flutter --add SECRET_NAME 'value'"
    echo "  $0 --repo owner/repo --check SECRET_NAME"
    echo
    echo "Options:"
    echo "  --repo OWNER/REPO                  Specify GitHub repository (overrides auto-detection)"
    echo "  --add SECRET_NAME SECRET_VALUE     Add or update a secret"
    echo "  --check SECRET_NAME                Check if secret exists (returns 0 if exists, 1 if not)"
    echo "  -h, --help                         Show this help message"
    echo
    echo "Note: When running from a git submodule, use --repo to specify the parent repository."
}

# Function to handle non-interactive secret addition
handle_noninteractive_add() {
    local secret_name=$1
    local secret_value=$2

    # Debug: show what we received
    print_status $BLUE "🔍 DEBUG: handle_noninteractive_add received:" >&2
    print_status $BLUE "   - secret_name: '$secret_name'" >&2
    print_status $BLUE "   - secret_value length: ${#secret_value} characters" >&2
    print_status $BLUE "   - secret_value preview (first 100 chars): ${secret_value:0:100}..." >&2
    print_status $BLUE "   - secret_value preview (last 100 chars): ...${secret_value: -100}" >&2

    if [ -z "$secret_name" ] || [ -z "$secret_value" ]; then
        print_status $RED "❌ ERROR: Both secret name and value are required for --add"
        show_usage
        exit 1
    fi

    # Load configuration and detect repo
    load_env_config
    detect_github_repo

    # Check if secret exists
    if check_secret_exists "$secret_name"; then
        print_status $YELLOW "⚠️  Secret '$secret_name' already exists. Updating..."
    else
        print_status $BLUE "➕ Adding new secret '$secret_name'..."
    fi

    # Add or update the secret
    if add_or_update_secret "$secret_name" "$secret_value"; then
        print_status $GREEN "✅ Secret '$secret_name' successfully managed!"
        exit 0
    else
        print_status $RED "❌ Failed to manage secret '$secret_name'"
        exit 1
    fi
}

# Function to handle non-interactive secret check
handle_noninteractive_check() {
    local secret_name=$1

    if [ -z "$secret_name" ]; then
        print_status $RED "❌ ERROR: Secret name is required for --check"
        show_usage
        exit 1
    fi

    # Load configuration and detect repo
    load_env_config
    detect_github_repo

    # Check if secret exists
    if check_secret_exists "$secret_name"; then
        print_status $GREEN "✅ Secret '$secret_name' exists"
        exit 0
    else
        print_status $YELLOW "⚠️  Secret '$secret_name' does not exist"
        exit 1
    fi
}

# Main function
main() {
    # Check dependencies
    if ! command -v curl &> /dev/null; then
        print_status $RED "❌ ERROR: 'curl' command not found"
        print_status $YELLOW "   Please install curl and try again"
        exit 1
    fi

    # Git is optional if --repo is provided
    local git_required=true
    
    # Parse arguments to handle --repo parameter
    local args=("$@")
    local new_args=()
    local i=0
    
    while [ $i -lt $# ]; do
        case "${args[$i]}" in
            --repo)
                if [ $((i+1)) -lt $# ]; then
                    parse_repo_param "${args[$((i+1))]}"
                    git_required=false
                    ((i+=2))
                else
                    print_status $RED "❌ ERROR: --repo requires a repository argument"
                    show_usage
                    exit 1
                fi
                ;;
            *)
                new_args+=("${args[$i]}")
                ((i++))
                ;;
        esac
    done
    
    # Check git if required
    if [ "$git_required" = true ] && ! command -v git &> /dev/null; then
        print_status $RED "❌ ERROR: 'git' command not found"
        print_status $YELLOW "   Please run this script from a git repository or use --repo option"
        exit 1
    fi

    # Handle remaining command-line arguments
    case "${new_args[0]:-}" in
        --add)
            handle_noninteractive_add "${new_args[1]}" "${new_args[2]}"
            ;;
        --check)
            handle_noninteractive_check "${new_args[1]}"
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        "")
            # No arguments - run interactive mode
            ;;
        *)
            print_status $RED "❌ ERROR: Unknown option '${new_args[0]}'"
            show_usage
            exit 1
            ;;
    esac

    # Load configuration
    load_env_config

    # Detect GitHub repository
    detect_github_repo

                # Main menu loop
    while true; do
        show_menu

        # Get current secrets for dynamic menu handling
        local -a secret_names=()  # Reset array
        local line_num=1

        while IFS= read -r secret_name_from_api; do
            if [ -n "$secret_name_from_api" ]; then
                secret_names+=("$secret_name_from_api")
                ((line_num++))
            fi
        done < <(get_secrets)



        local max_choice=$((line_num + 1))  # +1 for Exit option

        if [ ${#secret_names[@]} -eq 0 ]; then
            read -p "Enter your choice (1-2): " choice

            case $choice in
                1)
                    handle_secret_selection
                    ;;
                2)
                    print_status $GREEN "👋 Goodbye!"
                    exit 0
                    ;;
                *)
                    print_status $RED "❌ Invalid choice. Please enter 1-2."
                    ;;
            esac
        else
            read -p "Enter your choice (1-$max_choice): " choice

            if [ "$choice" -ge 1 ] && [ "$choice" -le ${#secret_names[@]} ]; then
                # User selected an existing secret
                local selected_secret="${secret_names[$((choice-1))]}"
                print_status $BLUE "Selected secret: $selected_secret"
                handle_secret_selection "$selected_secret"
            elif [ "$choice" -eq $line_num ]; then
                # User selected "Add new secret"
                handle_secret_selection
            elif [ "$choice" -eq $max_choice ]; then
                # User selected "Exit"
                print_status $GREEN "👋 Goodbye!"
                exit 0
            else
                print_status $RED "❌ Invalid choice. Please enter 1-$max_choice."
            fi
        fi

        echo
        read -p "Press Enter to continue..."
    done
}

# Run main function
main "$@"
