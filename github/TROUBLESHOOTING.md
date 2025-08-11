# GitHub Actions Troubleshooting Guide

## iOS Build Issues

### Problem: iOS deployment target warnings

When building iOS apps, you might see errors like:

```
The iOS deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 11.0,
but the range of supported deployment target versions is 12.0 to 17.5.99
```

#### Solution: Update deployment targets to iOS 14.0

The workflow sample includes a step to fix this automatically:

```yaml
- name: Fix iOS deployment target
  run: |
    cd ios

    # Create a script to update deployment targets
    cat > update_deployment_target.rb << 'EOF'
    require 'xcodeproj'

    def update_deployment_target(project_path, target_version)
      project = Xcodeproj::Project.open(project_path)
      project.targets.each do |target|
        target.build_configurations.each do |config|
          config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = target_version
        end
      end
      project.save
      puts "Updated deployment targets in #{project_path}"
    end

    # Update both Runner and Pods projects
    update_deployment_target('Runner.xcodeproj', '14.0') if File.exist?('Runner.xcodeproj')
    update_deployment_target('Pods/Pods.xcodeproj', '14.0') if File.exist?('Pods/Pods.xcodeproj')
    EOF

    # Install pods and update targets
    pod install --repo-update
    ruby update_deployment_target.rb
```

#### Alternative: Update Podfile permanently

Add this to your `ios/Podfile`:

```ruby
platform :ios, '14.0'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
    end
  end
end
```

## JSON Secret Issues

### Problem: Service account JSON losing quotes/formatting

GitHub Actions can corrupt JSON when using double quotes.

#### Solution: Use single quotes

```yaml
# ✅ CORRECT - Single quotes preserve JSON
echo '${{ secrets.FASTLANE_SERVICE_ACCOUNT }}' > service-account.json

# ❌ WRONG - Double quotes allow shell interpretation
echo "${{ secrets.FASTLANE_SERVICE_ACCOUNT }}" > service-account.json
```

#### Alternative: Base64 encoding

1. Encode your JSON:

```bash
base64 service-account.json > service-account.base64
```

1. Store as GitHub secret (e.g., `FASTLANE_SERVICE_ACCOUNT_BASE64`)

2. Decode in workflow:

```yaml
echo "${{ secrets.FASTLANE_SERVICE_ACCOUNT_BASE64 }}" | base64 -d > service-account.json
```

## Fastlane Issues

### Problem: Bundle not found

```sh
bundle: command not found
```

#### Solution: Setup Ruby properly

```yaml
- name: Set up Ruby
  uses: ruby/setup-ruby@v1
  with:
    ruby-version: '3.4.4'
    working-directory: ./ios
    bundler-cache: true  # Runs bundle install automatically
```

### Problem: Fastlane can't find service account

```sh
Could not find service account JSON file
```

#### Solution: Verify file path

```yaml
- name: Debug service account
  run: |
    # Check if file exists
    ls -la ios/fastlane/fastlane-serviceAccount.json

    # Verify it's valid JSON (without exposing content)
    cat ios/fastlane/fastlane-serviceAccount.json | jq empty && echo "✅ Valid JSON"
```

## Pod Installation Issues

### Problem: Pod install fails

```sh
[!] CocoaPods could not find compatible versions
```

#### Solution: Clean and reinstall

```yaml
- name: Clean Pod installation
  run: |
    cd ios
    rm -rf Pods Podfile.lock
    pod cache clean --all
    pod repo update
    pod install
```

## Certificate Issues

### Problem: No signing certificate

```sh
error: No signing certificate "iOS Distribution" found
```

#### Solution: Use Fastlane match

Set up code signing with Fastlane match in your `Fastfile`:

```ruby
lane :beta do
  match(type: "appstore", readonly: true)
  build_app(
    workspace: "Runner.xcworkspace",
    scheme: "Runner",
    export_method: "app-store"
  )
  firebase_app_distribution(
    app: ENV["FIREBASE_APP_ID"],
    service_credentials_file: "fastlane/fastlane-serviceAccount.json"
  )
end
```

## Common Debugging Tips

### Check environment variables

```yaml
- name: Debug environment
  run: |
    echo "Current directory: $(pwd)"
    echo "iOS directory contents:"
    ls -la ios/
    echo "Environment variables set:"
    env | grep -E "(CI|FASTLANE)" | sed 's/=.*/=***/'
```

### Verify secrets are set

```yaml
- name: Verify secrets
  run: |
    if [ -z "${{ secrets.FASTLANE_SERVICE_ACCOUNT }}" ]; then
      echo "❌ FASTLANE_SERVICE_ACCOUNT secret not set"
    else
      echo "✅ FASTLANE_SERVICE_ACCOUNT is set"
    fi
```

### Enable verbose logging

```yaml
- name: Fastlane with verbose logging
  run: |
    cd ios
    bundle exec fastlane beta --verbose
  env:
    FASTLANE_HIDE_TIMESTAMP: false
    FASTLANE_SKIP_UPDATE_CHECK: true
```
