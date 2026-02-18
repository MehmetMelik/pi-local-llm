# Local LLM Chatbot on Raspberry Pi 500

Run a fully local, private AI chatbot on a Raspberry Pi 500 (16 GB RAM, ARM64, CPU-only). This gives you a ChatGPT-like experience entirely on your Pi, accessible via a web UI and the terminal.

## Architecture

```
Raspberry Pi 500 (bare metal)
  └── Ollama (native systemd service, port 11434)
        └── Models stored in ~/.ollama/models (NVMe SSD)

Docker
  └── Open WebUI (container, port 3000)
        └── Connects to Ollama via host.docker.internal:11434
```

- **Ollama** runs natively (not in Docker) for better ARM performance
- **Open WebUI** runs in Docker for easy updates and isolation

## Requirements

- Raspberry Pi 5 / Pi 500 with 8+ GB RAM (16 GB recommended for 7B models)
- Raspberry Pi OS (Bookworm) or Debian 12, 64-bit
- Docker and Docker Compose installed
- ~10 GB free disk space (for models + container)

## Models

| Model | Size | Speed (Pi 500) | Use case |
|---|---|---|---|
| Qwen 2.5 3B | ~1.9 GB | 5-7 tokens/sec | Fast daily driver |
| Qwen 2.5 7B | ~4.7 GB | 1-3 tokens/sec | Best quality at 7B |

The 3B model is recommended for everyday use. The 7B model produces better answers but a 300-word response takes 2-4 minutes on CPU.

## Setup

### 1. Install Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### 2. Configure Ollama for Docker access

Ollama defaults to localhost only. To let the Docker container reach it, configure it to listen on all interfaces:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null <<'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
EOF
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

Verify it's running:

```bash
curl http://localhost:11434
# Should print: Ollama is running
```

### 3. Pull models

```bash
ollama pull qwen2.5:3b    # ~1.9 GB download
ollama pull qwen2.5:7b    # ~4.7 GB download
```

### 4. Test the CLI

```bash
ollama run qwen2.5:3b "Hello, who are you?"
```

### 5. Start Open WebUI

```bash
docker compose up -d
```

Wait about 60 seconds for the container to initialize on ARM, then open:

- **Local**: http://localhost:3000
- **Network**: http://<your-pi-ip>:3000

On first visit, create an account (fully local, just for the UI).

### 6. Verify

```bash
# Check models are downloaded
ollama list

# Check Open WebUI is running
docker ps --filter name=open-webui

# Monitor temperature during inference
vcgencmd measure_temp
```

## Usage

### Web UI

Open http://localhost:3000 in your browser. Select a model from the dropdown and start chatting.

### CLI

```bash
# Fast model
ollama run qwen2.5:3b

# Higher quality model
ollama run qwen2.5:7b

# One-shot query (non-interactive)
ollama run qwen2.5:3b "Explain quicksort in simple terms"
```

### API

Ollama exposes a REST API at `http://localhost:11434`:

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5:3b",
  "prompt": "What is the capital of France?",
  "stream": false
}'
```

## Managing models

```bash
# List installed models
ollama list

# Pull a new model
ollama pull <model-name>

# Remove a model
ollama rm <model-name>

# Show model details
ollama show <model-name>
```

Other models that work well on Pi 500 (16 GB):

| Model | Pull command | Size | Notes |
|---|---|---|---|
| Phi-3 Mini | `ollama pull phi3:mini` | ~2.3 GB | Microsoft, good for code |
| Gemma 2 2B | `ollama pull gemma2:2b` | ~1.6 GB | Google, very fast |
| Llama 3.2 3B | `ollama pull llama3.2:3b` | ~2.0 GB | Meta, general purpose |
| Mistral 7B | `ollama pull mistral:7b` | ~4.1 GB | Strong all-rounder |

## Stopping and starting

```bash
# Stop Open WebUI
docker compose down

# Start Open WebUI
docker compose up -d

# Stop Ollama
sudo systemctl stop ollama

# Start Ollama
sudo systemctl start ollama

# Check Ollama status
sudo systemctl status ollama
```

## Performance tips

- Use the **3B model** for everyday tasks, reserve 7B for when quality matters
- Close other memory-heavy applications during inference
- Monitor temperature: `vcgencmd measure_temp` (throttling starts at 80C)
- Models load into RAM on first use, subsequent queries are faster
- The Pi 500 has passive cooling; consider airflow if running long sessions

## Troubleshooting

**Open WebUI can't connect to Ollama**
- Verify Ollama is listening on 0.0.0.0: `ss -tlnp | grep 11434`
- Check the systemd override is applied: `systemctl cat ollama.service`
- Restart both: `sudo systemctl restart ollama && docker compose restart`

**Container shows "unhealthy"**
- Open WebUI takes ~60 seconds to start on ARM. Wait and check again.
- Check logs: `docker logs open-webui`

**Out of memory**
- Stop the 7B model and use 3B: `ollama stop qwen2.5:7b`
- Check memory: `free -h`

**High temperature**
- Monitor with `vcgencmd measure_temp`
- Reduce concurrent usage
- Ensure adequate ventilation around the Pi
