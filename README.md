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
│   └── github-secret-encrypt.js    # Encryption helper for GitHub secrets
└── google/          # Google Cloud Platform scripts
    └── create-service-accounts.sh  # Create GCP service accounts
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
```

### Google Service Account Creation

```bash
cd google
# Create service account for Fastlane (Firebase App Distribution deployment)
./create-service-accounts.sh fastlane

# Create service account for GitHub Actions (Firebase App Hosting deployment)
./create-service-accounts.sh github-actions
```

## Prerequisites

- **GitHub scripts**: Node.js, npm
- **Google scripts**: gcloud CLI, authenticated Google account
- **Common**: Valid `.env` file with required tokens and IDs

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes and improvements.
