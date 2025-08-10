# Using DevOps Scripts as a Git Submodule

This guide explains how to add and use this DevOps repository as a git submodule in your main project.

## Why Use as a Submodule?

Using these scripts as a submodule allows you to:

- Share DevOps tools across multiple projects
- Keep scripts updated from a central repository
- Maintain project-specific configurations via `.env` files
- Version control your DevOps tools separately

## Initial Setup

### 1. Add the Submodule to Your Project

From your main project's root directory:

```bash
# Add the submodule
git submodule add https://github.com/YOUR_USERNAME/devops-scripts.git dev_ops

# Or if using SSH
git submodule add git@github.com:YOUR_USERNAME/devops-scripts.git dev_ops
```

This creates:

- A `dev_ops` directory with the submodule content
- A `.gitmodules` file tracking the submodule

### 2. Initialize .gitmodules File

The `.gitmodules` file is automatically created and looks like:

```ini
[submodule "dev_ops"]
    path = dev_ops
    url = https://github.com/YOUR_USERNAME/devops-scripts.git
```

### 3. Commit the Submodule Addition

```bash
git add .gitmodules dev_ops
git commit -m "Add DevOps scripts as submodule"
```

## Cloning a Project with Submodules

When someone clones your project, they need to initialize the submodules:

### Method 1: Clone with Submodules (Recommended)

```bash
# Clone and initialize submodules in one command
git clone --recurse-submodules https://github.com/YOUR_USERNAME/your-project.git

# Or with specific depth to save bandwidth
git clone --recurse-submodules --shallow-submodules https://github.com/YOUR_USERNAME/your-project.git
```

### Method 2: Initialize After Cloning

```bash
# Clone the main project
git clone https://github.com/YOUR_USERNAME/your-project.git
cd your-project

# Initialize and update submodules
git submodule init
git submodule update

# Or in one command
git submodule update --init --recursive
```

## Configuration for Submodule Usage

### 1. Create Your Environment File

```bash
cd dev_ops/common
cp .env.example .env
```

### 2. Configure for Your Parent Project

Edit `dev_ops/common/.env`:

```bash
# Google Cloud Configuration
PROJECT_ID=your-project-id
PROJECT_NUMBER=your-project-number

# GitHub Configuration
GITHUB_TOKEN=ghp_your_github_token_here

# IMPORTANT: Set these for submodule usage
# This tells the scripts to target your parent repository, not the submodule
GITHUB_OWNER=your-github-username
GITHUB_REPO=your-parent-repo-name
```

### 3. Add .env to Parent Project's .gitignore

Ensure your parent project's `.gitignore` includes:

```gitignore
# DevOps environment configuration
dev_ops/common/.env
dev_ops/**/*.json  # Service account keys
dev_ops/**/node_modules/  # Node dependencies
```

## Working with Submodules

### Update Submodule to Latest Version

```bash
# Navigate to submodule directory
cd dev_ops

# Pull latest changes
git pull origin master

# Go back to parent project
cd ..

# Commit the submodule update
git add dev_ops
git commit -m "Update DevOps submodule to latest version"
```

### Update All Submodules

```bash
# From parent project root
git submodule update --remote --merge
```

### Check Submodule Status

```bash
# Show submodule status
git submodule status

# Detailed information
git submodule foreach 'echo $path `git rev-parse HEAD`'
```

## Common Use Cases

### Running GitHub Secrets Management

Since the submodule has its own git repository, the scripts would normally detect the submodule's repository. With `GITHUB_OWNER` and `GITHUB_REPO` set in `.env`:

```bash
cd dev_ops/github
./manage-github-secrets.sh --add SECRET_NAME "value"
# This will target your parent repository, not the submodule
```

### Creating Service Accounts

```bash
cd dev_ops/google
./create-service-accounts.sh fastlane
# Uses PROJECT_ID from .env
# Automatically adds secret to parent repository via GITHUB_OWNER/GITHUB_REPO
```

## Troubleshooting

### Submodule Not Initialized

If you see an empty `dev_ops` directory:

```bash
git submodule update --init --recursive
```

### Detached HEAD in Submodule

Submodules often end up in detached HEAD state. To fix:

```bash
cd dev_ops
git checkout master  # or main, depending on default branch
git pull origin master
```

### Permission Denied Errors

Make scripts executable:

```bash
chmod +x dev_ops/**/*.sh
```

### Wrong Repository Detected

Ensure your `.env` file has:

```bash
GITHUB_OWNER=your-parent-repo-owner
GITHUB_REPO=your-parent-repo-name
```

## Best Practices

1. **Version Lock**: Submodules track specific commits. Always commit submodule updates to your parent project.

2. **Environment Files**: Never commit `.env` files. Each developer should create their own.

3. **Regular Updates**: Periodically update the submodule to get latest features and fixes:

   ```bash
   git submodule update --remote
   ```

4. **Team Communication**: When you update a submodule reference, notify your team to run:

   ```bash
   git submodule update
   ```

5. **CI/CD Integration**: In your CI/CD pipelines, always initialize submodules:

   ```yaml
   # GitHub Actions example
   - uses: actions/checkout@v3
     with:
       submodules: recursive
   ```

## Example Project Structure

```md
your-flutter-project/
├── .git/
├── .gitignore
├── .gitmodules          # Submodule configuration
├── lib/                 # Flutter app code
├── android/
├── ios/
├── dev_ops/            # Submodule directory
│   ├── common/
│   │   ├── .env        # Your configuration (not in git)
│   │   └── .env.example
│   ├── github/
│   │   └── manage-github-secrets.sh
│   └── google/
│       └── create-service-accounts.sh
└── README.md
```

## Advanced Configuration

### Using Different Branches

To track a specific branch in the submodule:

```bash
# Set the branch to track
git config -f .gitmodules submodule.dev_ops.branch stable

# Update to that branch
git submodule update --remote
```

### Shallow Submodules (Save Space)

For large submodules, use shallow clones:

```bash
git submodule add --depth 1 https://github.com/YOUR_USERNAME/devops-scripts.git dev_ops
```

### Multiple Projects Setup

If you have multiple projects using the same DevOps scripts:

1. Fork or create the devops-scripts repository once
2. Add as submodule to each project
3. Each project has its own `.env` configuration
4. Updates to the central repository benefit all projects

## Additional Resources

- [Git Submodules Documentation](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- [GitHub Actions with Submodules](https://github.com/actions/checkout#checkout-submodules)
- [Atlassian Git Submodules Tutorial](https://www.atlassian.com/git/tutorials/git-submodule)
