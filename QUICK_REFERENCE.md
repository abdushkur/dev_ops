# Git Submodule Quick Reference

## Essential Commands

### First Time Setup
```bash
# Add submodule to your project
git submodule add https://github.com/USER/devops-scripts.git dev_ops

# Configure environment
cd dev_ops/common
cp .env.example .env
# Edit .env with your settings (especially GITHUB_OWNER and GITHUB_REPO)
```

### Cloning a Project
```bash
# Clone with submodules included
git clone --recurse-submodules <repository-url>

# Or if already cloned
git submodule update --init --recursive
```

### Daily Usage
```bash
# Update submodule to latest
cd dev_ops
git pull origin main
cd ..
git add dev_ops
git commit -m "Update DevOps submodule"

# Or from parent directory
git submodule update --remote --merge
```

### Common Operations

| Task | Command |
|------|---------|
| Check status | `git submodule status` |
| Update all submodules | `git submodule update --remote` |
| Initialize after clone | `git submodule update --init` |
| See submodule commits | `git log --submodule` |
| Remove a submodule | `git rm dev_ops` then remove from `.gitmodules` |

### GitHub Actions Integration
```yaml
- uses: actions/checkout@v3
  with:
    submodules: recursive
```

### Troubleshooting

**Empty submodule directory?**
```bash
git submodule update --init --recursive
```

**Detached HEAD warning?**
```bash
cd dev_ops
git checkout main
```

**Changes in submodule not showing?**
```bash
cd dev_ops
git add .
git commit -m "Your changes"
git push
cd ..
git add dev_ops
git commit -m "Update submodule reference"
```

## Environment Configuration for Submodules

Always set these in `dev_ops/common/.env` when using as a submodule:

```bash
# Target the parent repository, not the submodule
GITHUB_OWNER=your-username
GITHUB_REPO=your-parent-project
```

This ensures scripts operate on your main project, not the DevOps submodule repository.