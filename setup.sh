#!/usr/bin/env bash
# Setup script for local LLM chatbot on Raspberry Pi 500
# Run: chmod +x setup.sh && ./setup.sh

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# Check architecture
if [ "$(uname -m)" != "aarch64" ]; then
    error "This script is designed for ARM64 (aarch64). Detected: $(uname -m)"
fi

# Check RAM
RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
if [ "$RAM_GB" -lt 4 ]; then
    error "At least 4 GB RAM required. Detected: ${RAM_GB} GB"
fi
info "RAM: ${RAM_GB} GB"

# Check Docker
if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Install it first: https://docs.docker.com/engine/install/debian/"
fi
info "Docker found: $(docker --version 2>/dev/null || echo 'installed')"

# Install Ollama
if command -v ollama &> /dev/null; then
    info "Ollama already installed: $(ollama --version)"
else
    info "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    info "Ollama installed"
fi

# Configure Ollama to listen on all interfaces
if [ -f /etc/systemd/system/ollama.service.d/override.conf ]; then
    info "Ollama systemd override already exists"
else
    info "Configuring Ollama to listen on all interfaces..."
    sudo mkdir -p /etc/systemd/system/ollama.service.d
    sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null <<'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
EOF
    sudo systemctl daemon-reload
    sudo systemctl restart ollama
    info "Ollama configured and restarted"
fi

# Wait for Ollama to be ready
info "Waiting for Ollama to start..."
for i in $(seq 1 30); do
    if curl -s http://localhost:11434 > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

if ! curl -s http://localhost:11434 > /dev/null 2>&1; then
    error "Ollama failed to start. Check: sudo systemctl status ollama"
fi
info "Ollama is running"

# Pull models
info "Pulling Qwen 2.5 3B (~1.9 GB)..."
ollama pull qwen2.5:3b

info "Pulling Qwen 2.5 7B (~4.7 GB)..."
ollama pull qwen2.5:7b

info "Pulling Qwen 2.5 Coder 3B (~1.9 GB)..."
ollama pull qwen2.5-coder:3b

# Start Open WebUI
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info "Starting Open WebUI..."
cd "$SCRIPT_DIR"
docker compose up -d

# Wait for Open WebUI
info "Waiting for Open WebUI to initialize (this takes ~60s on ARM)..."
for i in $(seq 1 90); do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null | grep -q "200"; then
        break
    fi
    sleep 2
done

if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null | grep -q "200"; then
    info "Open WebUI is ready"
else
    warn "Open WebUI is still starting. Check: docker logs open-webui"
fi

# Summary
echo ""
echo "============================================"
info "Setup complete!"
echo "============================================"
echo ""
echo "Models installed:"
ollama list
echo ""
echo "Access:"
echo "  Web UI:  http://localhost:3000"
echo "  CLI:     ollama run qwen2.5:3b"
echo ""
if command -v vcgencmd &> /dev/null; then
    echo "Temperature: $(vcgencmd measure_temp)"
fi
