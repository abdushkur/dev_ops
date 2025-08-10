#!/usr/bin/env node

/**
 * GitHub Secret Encryption Helper
 * Properly encrypts secrets for GitHub Actions using libsodium
 */

const fs = require('fs');
const { execSync } = require('child_process');

// Install libsodium-wrappers if not present
try {
    require.resolve('libsodium-wrappers');
} catch(e) {
    console.error('Installing required dependency libsodium-wrappers...');
    try {
        execSync('npm install libsodium-wrappers', { stdio: 'inherit', cwd: __dirname });
    } catch(installError) {
        console.error('Failed to install libsodium-wrappers. Please run: npm install libsodium-wrappers');
        process.exit(1);
    }
}

const sodium = require('libsodium-wrappers');

async function encryptSecret(publicKeyBase64, secretValue) {
    // Wait for libsodium to be ready
    await sodium.ready;
    
    // Convert base64 public key to Uint8Array
    const publicKey = sodium.from_base64(publicKeyBase64, sodium.base64_variants.ORIGINAL);
    
    // Convert secret string to Uint8Array
    const secretBytes = sodium.from_string(secretValue);
    
    // Encrypt using libsodium's sealed box (anonymous sender)
    const encrypted = sodium.crypto_box_seal(secretBytes, publicKey);
    
    // Return base64 encoded encrypted value
    return sodium.to_base64(encrypted, sodium.base64_variants.ORIGINAL);
}

async function main() {
    const args = process.argv.slice(2);
    
    if (args.length !== 2) {
        console.error('Usage: github-secret-encrypt.js <public_key> <secret_value>');
        console.error('   or: github-secret-encrypt.js <public_key> @<file_path>');
        process.exit(1);
    }
    
    const [publicKey, secretValueOrPath] = args;
    
    try {
        let secretValue;
        
        // Check if the secret value is a file reference
        if (secretValueOrPath.startsWith('@')) {
            const filePath = secretValueOrPath.substring(1);
            secretValue = fs.readFileSync(filePath, 'utf8');
        } else {
            secretValue = secretValueOrPath;
        }
        
        const encryptedValue = await encryptSecret(publicKey, secretValue);
        console.log(encryptedValue);
    } catch (error) {
        console.error('Error:', error.message);
        process.exit(1);
    }
}

if (require.main === module) {
    main().catch(err => {
        console.error('Fatal error:', err);
        process.exit(1);
    });
}