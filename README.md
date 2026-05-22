# Polyglot Sandbox Automator

A containerized, automated code-execution platform — a simplified LeetCode/Replit backend.

## Features

- **TypeScript REST API** (`POST /execute`) that writes code to a temp file and executes it inside isolated Docker runners
- **Secure Python & Node.js runners** — non-root users, resource limits (`--memory=256m --cpus=0.5`)
- **Redis** for result caching and rate limiting (ready to extend)
- **Full lifecycle automation** via `scripts/manage.sh`
- **Docker Compose** orchestration
- **Git feature-branch** workflow compatible

## Project Structure

```
/src                    ← TypeScript Runner API
  index.ts              ← Express entry point (POST /execute)
  runner.ts             ← Docker execution logic
  cache.ts              ← Redis caching module
/scripts
  manage.sh             ← Automation CLI
/containers
  api/Dockerfile        ← Multi-stage API image
  python/Dockerfile     ← Python runner (non-root)
  nodejs/Dockerfile     ← Node.js runner (non-root)
docker-compose.yml      ← API + Redis orchestration
```

## Quick Start

```bash
# 1. Check prerequisites and pull base images
./scripts/manage.sh setup

# 2. Build all images (tagged with Git commit SHA)
./scripts/manage.sh build

# 3. Start services and run Hello World integration tests
./scripts/manage.sh test

# 4. (Bonus) Real-time log monitor with colored ERROR/CRITICAL
./scripts/manage.sh logs
```

## API Usage

### Health Check
```bash
curl http://localhost:3000/health
# {"status":"ok","timestamp":"..."}
```

### Execute Code
```bash
# Python
curl -X POST http://localhost:3000/execute \
  -H "Content-Type: application/json" \
  -d '{"language":"python","code":"print(\"Hello, World!\")"}'

# Node.js
curl -X POST http://localhost:3000/execute \
  -H "Content-Type: application/json" \
  -d '{"language":"nodejs","code":"console.log(\"Hello, World!\")"}'
```

**Response:**
```json
{
  "language": "python",
  "stdout": "Hello, World!",
  "stderr": "",
  "exitCode": 0,
  "cached": false,
  "executionTime": 342
}
```

## Available Commands

| Command | Description |
|---------|-------------|
| `setup` | Verify Docker/Git, create temp dir, pull base images |
| `build` | Build & tag all images with current Git commit SHA |
| `test`  | Start services + run Hello World integration tests |
| `clean` | Remove containers, images, volumes, temp files |
| `logs`  | Tail logs with ERROR/CRITICAL highlighted in red |

## Security Best Practices

- All runner containers run as **non-root users**
- **Ephemeral containers** per execution (`--rm`)
- **Resource limits**: `--memory=256m --cpus=0.5`
- **No network access** for runner containers (`--network none`)
- **Read-only filesystem** with tmpfs for scratch space
- Temp files cleaned automatically after execution

## Learning Objectives

- Environment parity with Docker
- CI/CD fundamentals via shell scripts
- Infrastructure as Code (Docker Compose)
- Container security & isolation
- Redis caching patterns

## Cleanup

```bash
./scripts/manage.sh clean
```
