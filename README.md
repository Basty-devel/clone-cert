**Clone X.509 certificates for security testing and educational purposes**

</div>

## ✨ Features

- **🎭 Certificate Cloning**: Create identical-looking certificates with different keys
- **🔗 Chain Support**: Clone entire certificate chains
- **🎯 Multiple Key Types**: Support for RSA and EC certificates
- **🌐 SNI Support**: Virtual host specification via Server Name Indication
- **🔍 Verification**: Built-in certificate validation and comparison
- **🎨 User-Friendly**: Colored output, progress indicators, and clear error messages
- **⚡ Performance**: Optional key reuse for faster operations

## 🚀 Quick Start

### Basic Usage
```bash
./clone-cert.sh example.com:443
```
Advanced Examples
# Clone with custom output name
```bash
./clone-cert.sh --output my-clone --verify www.example.com:443
```
# Clone entire certificate chain
```
./clone-cert.sh --chain --compare api.example.com:443
```
# Use custom CA for signing
```
./clone-cert.sh --cert my-ca.crt --key my-ca.key example.com:443
```
# Quiet mode for scripting
```
./clone-cert.sh --quiet example.com:443
```
📋 Requirements
OpenSSL 1.1.1 or newer

Bash 4.0 or newer

🛠️ Installation
Download the script:

```bash
curl -O https://raw.githubusercontent.com/your-repo/clone-cert/main/clone-cert.sh
chmod +x clone-cert.sh
```
Verify dependencies:

```bash
./clone-cert.sh --version
```
📖 Usage
Command Line Options
Option	Description
-d, --directory DIR	Output directory (default: /tmp/cert-clones)
-o, --output NAME	Custom output filename prefix
-r, --reuse-keys	Reuse previously generated keys
