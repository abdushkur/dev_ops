# GitHub Scripts

Tools for managing GitHub repository settings and secrets.

## Scripts

### manage-github-secrets.sh

Interactive and non-interactive tool for managing GitHub Actions secrets with proper encryption.

**Features:**

- Automatic repository detection from git remote
- Proper libsodium encryption for secrets
- Support for large secrets (e.g., service account JSON files)
- Interactive menu for easy secret management

**Usage:**

```bash
# Interactive mode
./manage-github-secrets.sh

# Add/update a secret
./manage-github-secrets.sh --add SECRET_NAME "secret value"

# Check if a secret exists
./manage-github-secrets.sh --check SECRET_NAME

# Specify a custom repository (useful when running from submodule)
./manage-github-secrets.sh --repo owner/repository --add SECRET_NAME "value"
./manage-github-secrets.sh --repo abdushkur/lebbey_flutter --check SECRET_NAME
```

**Note:** When the script is in a git submodule, it will detect the submodule's repository by default. Use the `--repo` parameter to specify the parent repository instead.

### github-secret-encrypt.js

Node.js helper script that handles proper encryption of secrets using libsodium.

**Dependencies:**

- libsodium-wrappers (auto-installed)

## GitHub Actions Workflow Samples

The `actions_sample` directory contains ready-to-use GitHub Actions workflow templates:

### flutter_ios.yaml

Complete iOS build and deployment workflow using Fastlane.

**Features:**

- Automated iOS app building
- Ruby/Fastlane setup with caching
- Flutter setup with version pinning
- Service account integration
- Firebase App Distribution deployment

**Required Secrets:**

- `ENV_FILE` - Environment configuration
- `FASTLANE_SERVICE_ACCOUNT` - Service account JSON (created by our script)

### firebase-app-hosting-merge.yml

Firebase App Hosting deployment workflow for web applications.

**Features:**

- Automatic deployment on merge to master
- Environment file management
- Firebase tools setup
- Service account authentication
- Skip release option via commit message

**Required Secrets:**

- `ENV_FILE` - Environment configuration
- `APP_HOSTING_YAML_FILE` - App hosting configuration
- `APP_HOSTING_GITHUB_ACTION_SERVICE_ACCOUNT` - Service account JSON (created by our script)

## Configuration

Requires `../common/.env` file with:

```env
# Required
GITHUB_TOKEN=your_github_personal_access_token

# Optional - for submodule or detached directory usage
GITHUB_OWNER=owner
GITHUB_REPO=repository
```

Get a token from: https://github.com/settings/tokens with `repo` scope.

### Repository Detection Priority

The script determines the target repository in this order:

1. **Command-line parameter** (`--repo owner/repository`)
2. **Environment file** (GITHUB_OWNER and GITHUB_REPO in `.env`)
3. **Git auto-detection** (from current directory's git remote)
