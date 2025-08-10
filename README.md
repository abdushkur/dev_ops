# DevOps Scripts

This directory contains scripts and tools for managing infrastructure, CI/CD, and cloud services.

## Directory Structure

```md
dev_ops/
├── common/          # Shared configuration and environment files
│   ├── .env         # Environment variables (not in git)
│   └── .env.example # Example environment configuration
├── github/          # GitHub-related tools and scripts
│   ├── manage-github-secrets.sh    # Manage GitHub Actions secrets
│   ├── github-secret-encrypt.js    # Encryption helper for GitHub secrets
│   └── actions_sample/              # Sample GitHub Actions workflows
│       ├── flutter_ios.yaml        # iOS build with Fastlane
│       └── firebase-app-hosting-merge.yml  # Firebase App Hosting deployment
└── google/          # Google Cloud Platform scripts
    ├── create-service-accounts.sh  # Create GCP service accounts
    └── rotate-api-keys.sh          # Create and rotate API keys
```

## Setup

1. Copy `common/.env.example` to `common/.env`
2. Fill in your environment-specific values
3. Make scripts executable: `chmod +x */**.sh`

## Usage

### GitHub Secrets Management

```bash
cd github
./manage-github-secrets.sh  # Interactive mode
./manage-github-secrets.sh --add SECRET_NAME "secret_value"  # Direct mode

# For submodules: Set GITHUB_OWNER and GITHUB_REPO in common/.env
# Or use: ./manage-github-secrets.sh --repo owner/repo --add SECRET_NAME "value"
```

### GitHub Actions Workflows

Sample workflows are provided in `github/actions_sample/`:

- **flutter_ios.yaml** - iOS build and Firebase App Distribution deployment
- **firebase-app-hosting-merge.yml** - Firebase App Hosting deployment

Copy these to your project's `.github/workflows/` directory and customize as needed.

### Google Cloud Scripts

```bash
cd google

# Service Account Creation
./create-service-accounts.sh fastlane        # For Firebase App Distribution
./create-service-accounts.sh github-actions  # For Firebase Hosting deployment

# API Key Rotation
./rotate-api-keys.sh prod-firebase    # Production Firebase key
./rotate-api-keys.sh local-maps       # Local development Maps key
./rotate-api-keys.sh server-firebase  # Server-side Firebase key
```

## Prerequisites

- **GitHub scripts**: Node.js, npm
- **Google scripts**: gcloud CLI, authenticated Google account
- **Common**: Valid `.env` file with required tokens and IDs

## Using as a Git Submodule

This repository is designed to be used as a git submodule in your projects. See [SUBMODULE_USAGE.md](SUBMODULE_USAGE.md) for detailed instructions on:

- Adding this repository as a submodule
- Configuring for parent project usage
- Cloning projects with submodules
- Updating and maintaining submodules

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes and improvements.
