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
```

### github-secret-encrypt.js
Node.js helper script that handles proper encryption of secrets using libsodium.

**Dependencies:**
- libsodium-wrappers (auto-installed)

## Configuration

Requires `../common/.env` file with:
```
GITHUB_TOKEN=your_github_personal_access_token
```

Get a token from: https://github.com/settings/tokens with `repo` scope.