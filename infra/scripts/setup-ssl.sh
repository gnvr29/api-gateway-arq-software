#!/usr/bin/env bash
# ─── SSL Certificate Setup Script ───────────────────────────────────────────
# Generates TLS certificates for local development.
# Supports mkcert (trusted) or falls back to openssl (self-signed).
#
# Usage:
#   ./infra/scripts/setup-ssl.sh
#   ./infra/scripts/setup-ssl.sh --force   # Overwrite existing certs
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_DIR="$SCRIPT_DIR/../nginx/ssl"
CERT_FILE="$SSL_DIR/server.crt"
KEY_FILE="$SSL_DIR/server.key"

FORCE=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE=true
fi

# Check if certs already exist
if [[ -f "$CERT_FILE" && -f "$KEY_FILE" && "$FORCE" == false ]]; then
    echo "✓ SSL certificates already exist at $SSL_DIR"
    echo "  Use --force to regenerate."
    exit 0
fi

# Create ssl directory if it doesn't exist
mkdir -p "$SSL_DIR"

# Try mkcert first (produces locally-trusted certs)
if command -v mkcert &> /dev/null; then
    echo "→ Found mkcert, generating locally-trusted certificates..."

    # Install local CA if not already done
    mkcert -install 2>/dev/null || true

    mkcert \
        -key-file "$KEY_FILE" \
        -cert-file "$CERT_FILE" \
        localhost 127.0.0.1 ::1

    echo "✓ Certificates generated with mkcert (trusted by your system)"
    echo "  No browser warnings — HTTPS will just work."
else
    echo "→ mkcert not found, falling back to openssl (self-signed)..."

    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$KEY_FILE" \
        -out "$CERT_FILE" \
        -subj "/CN=localhost/O=API Gateway Dev/C=BR" \
        2>/dev/null

    echo "✓ Self-signed certificates generated with openssl"
    echo "  ⚠ Browsers will show a security warning (expected for self-signed)."
    echo ""
    echo "  To get trusted certs without warnings, install mkcert:"
    echo "    brew install mkcert    # macOS"
    echo "    Then re-run this script."
fi

echo ""
echo "  Certificate: $CERT_FILE"
echo "  Key:         $KEY_FILE"
