#!/usr/bin/env bash
# =============================================================================
# manage.sh  —  Polyglot Sandbox Automator CLI
# Usage: ./scripts/manage.sh [setup|build|test|clean|logs]
# =============================================================================

set -euo pipefail

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="${PROJECT_ROOT}/temp"
API_URL="http://localhost:3000"

# ── Command: setup ────────────────────────────────────────────────────────────
cmd_setup() {
  echo -e "\n${BOLD}=== Polyglot Sandbox — Setup ===${RESET}\n"

  # Check Docker
  if ! command -v docker &>/dev/null; then
    die "Docker is not installed. Please install Docker Desktop or Docker Engine."
  fi
  DOCKER_VERSION=$(docker --version)
  success "Docker found: ${DOCKER_VERSION}"

  # Check Docker daemon is running
  if ! docker info &>/dev/null 2>&1; then
    die "Docker daemon is not running. Please start Docker."
  fi
  success "Docker daemon is running"

  # Check Docker Compose
  if docker compose version &>/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version)
    success "Docker Compose (plugin) found: ${COMPOSE_VERSION}"
  elif command -v docker-compose &>/dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    success "docker-compose found: ${COMPOSE_VERSION}"
  else
    die "Docker Compose not found. Please install it."
  fi

  # Check Git
  if ! command -v git &>/dev/null; then
    warn "Git not found — image tagging will use 'latest'"
  else
    GIT_VERSION=$(git --version)
    success "Git found: ${GIT_VERSION}"
  fi

  # Create temp directory
  mkdir -p "${TEMP_DIR}"
  success "Temp directory ready: ${TEMP_DIR}"

  # Pull base images
  info "Pulling base images (this may take a moment)..."
  docker pull python:3.12-alpine  && success "Pulled python:3.12-alpine"
  docker pull node:20-alpine      && success "Pulled node:20-alpine"
  docker pull redis:7-alpine      && success "Pulled redis:7-alpine"

  echo ""
  success "Setup complete! Run: ./scripts/manage.sh build"
}

# ── Command: build ────────────────────────────────────────────────────────────
cmd_build() {
  echo -e "\n${BOLD}=== Polyglot Sandbox — Build ===${RESET}\n"

  # Determine Git commit tag
  if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    GIT_COMMIT=$(git rev-parse --short HEAD)
  else
    GIT_COMMIT="latest"
  fi
  info "Git commit tag: ${GIT_COMMIT}"

  cd "${PROJECT_ROOT}"

  # Build Python runner
  info "Building Python runner image..."
  docker build \
    -t "sandbox-python:${GIT_COMMIT}" \
    -t "sandbox-python:latest" \
    -f containers/python/Dockerfile .
  success "Built sandbox-python:${GIT_COMMIT}"

  # Build Node.js runner
  info "Building Node.js runner image..."
  docker build \
    -t "sandbox-nodejs:${GIT_COMMIT}" \
    -t "sandbox-nodejs:latest" \
    -f containers/nodejs/Dockerfile .
  success "Built sandbox-nodejs:${GIT_COMMIT}"

  # Build API
  info "Building API image..."
  GIT_COMMIT="${GIT_COMMIT}" docker compose build api
  success "Built sandbox-api:${GIT_COMMIT}"

  echo ""
  success "All images built. Run: ./scripts/manage.sh test"
}

# ── Command: test ─────────────────────────────────────────────────────────────
cmd_test() {
  echo -e "\n${BOLD}=== Polyglot Sandbox — Integration Tests ===${RESET}\n"

  cd "${PROJECT_ROOT}"

  # Start services
  info "Starting services..."
  docker compose up -d
  success "Services started"

  # Wait for API to be healthy
  info "Waiting for API to be ready..."
  local retries=20
  until curl -sf "${API_URL}/health" &>/dev/null; do
    retries=$((retries - 1))
    if [[ $retries -le 0 ]]; then
      error "API did not become healthy in time."
      docker compose logs api
      exit 1
    fi
    sleep 1
    echo -n "."
  done
  echo ""
  success "API is healthy"

  # ── Test 1: Python Hello World ──────────────────────────────────────────────
  info "Test 1: Python Hello World"
  PY_RESPONSE=$(curl -sf -X POST "${API_URL}/execute" \
    -H "Content-Type: application/json" \
    -d '{"language":"python","code":"print(\"Hello, World!\")"}')

  PY_OUTPUT=$(echo "${PY_RESPONSE}" | grep -o '"stdout":"[^"]*"' | cut -d'"' -f4)

  if [[ "${PY_OUTPUT}" == "Hello, World!" ]]; then
    success "Python test passed: output = '${PY_OUTPUT}'"
  else
    error "Python test FAILED. Response: ${PY_RESPONSE}"
    exit 1
  fi

  # ── Test 2: Node.js Hello World ────────────────────────────────────────────
  info "Test 2: Node.js Hello World"
  JS_RESPONSE=$(curl -sf -X POST "${API_URL}/execute" \
    -H "Content-Type: application/json" \
    -d '{"language":"nodejs","code":"console.log(\"Hello, World!\")"}')

  JS_OUTPUT=$(echo "${JS_RESPONSE}" | grep -o '"stdout":"[^"]*"' | cut -d'"' -f4)

  if [[ "${JS_OUTPUT}" == "Hello, World!" ]]; then
    success "Node.js test passed: output = '${JS_OUTPUT}'"
  else
    error "Node.js test FAILED. Response: ${JS_RESPONSE}"
    exit 1
  fi

  # ── Test 3: Health endpoint ─────────────────────────────────────────────────
  info "Test 3: Health endpoint"
  HEALTH=$(curl -sf "${API_URL}/health")
  if echo "${HEALTH}" | grep -q '"status":"ok"'; then
    success "Health check passed: ${HEALTH}"
  else
    error "Health check FAILED: ${HEALTH}"
    exit 1
  fi

  echo ""
  success "All tests passed!"
}

# ── Command: clean ────────────────────────────────────────────────────────────
cmd_clean() {
  echo -e "\n${BOLD}=== Polyglot Sandbox — Clean ===${RESET}\n"

  cd "${PROJECT_ROOT}"

  info "Stopping and removing containers..."
  docker compose down -v --remove-orphans 2>/dev/null || true
  success "Containers removed"

  info "Removing sandbox images..."
  docker images --filter "reference=sandbox-*" -q | xargs -r docker rmi -f 2>/dev/null || true
  success "Images removed"

  info "Cleaning temp files..."
  rm -rf "${TEMP_DIR:?}"/*
  success "Temp files cleaned"

  info "Pruning unused Docker resources..."
  docker system prune -f --volumes 2>/dev/null || true
  success "Docker pruned"

  echo ""
  success "Clean complete."
}

# ── Command: logs (Bonus — colored log monitor) ───────────────────────────────
cmd_logs() {
  echo -e "\n${BOLD}=== Polyglot Sandbox — Log Monitor ===${RESET}"
  echo -e "${YELLOW}Highlighting ERROR and CRITICAL in red. Press Ctrl+C to stop.${RESET}\n"

  cd "${PROJECT_ROOT}"

  docker compose logs --follow --timestamps 2>&1 | \
    sed \
      -e "s/\(.*ERROR.*\)/${RED}\1${RESET}/g" \
      -e "s/\(.*CRITICAL.*\)/${RED}\1${RESET}/g" \
      -e "s/\(.*WARN.*\)/${YELLOW}\1${RESET}/g" \
      -e "s/\(.*INFO.*\)/${CYAN}\1${RESET}/g"
}

# ── Entry point ───────────────────────────────────────────────────────────────
COMMAND="${1:-help}"

case "${COMMAND}" in
  setup)  cmd_setup  ;;
  build)  cmd_build  ;;
  test)   cmd_test   ;;
  clean)  cmd_clean  ;;
  logs)   cmd_logs   ;;
  *)
    echo -e "\n${BOLD}Polyglot Sandbox Automator${RESET}"
    echo ""
    echo "Usage: ./scripts/manage.sh <command>"
    echo ""
    echo "Commands:"
    echo "  setup   Check prerequisites, create temp dir, pull base images"
    echo "  build   Build and tag all Docker images with current Git commit"
    echo "  test    Start services and run Hello World integration tests"
    echo "  clean   Remove containers, images, volumes, and temp files"
    echo "  logs    Tail logs with ERROR/CRITICAL highlighted in red (bonus)"
    echo ""
    ;;
esac
