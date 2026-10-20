#!/usr/bin/env bash
# ==============================================================================
# Learning Goal 11.12: Advanced Network Traffic Analysis
# Script: simulate_traffic.sh
# Purpose: Generate varied microservice network traffic (HTTP, REST, JSON,
#          errors, DNS queries) for live analysis and filtering in Kubeshark.
# ==============================================================================

set -euo pipefail

TARGET_HOST="${1:-localhost}"
TARGET_PORT="${2:-8080}"
BASE_URL="http://${TARGET_HOST}:${TARGET_PORT}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo "================================================================="
echo "   Goal 11.12 Network Traffic Analysis - Lab Traffic Generator"
echo "   Target Base URL: ${BASE_URL}"
echo "================================================================="

# --- Step 1: Standard REST API GET Queries ---
log_info "1. Sending standard GET queries (Health check & user endpoints)..."
curl -s -X GET "${BASE_URL}/api/v1/health" \
  -H "User-Agent: LabClient/1.0" \
  -H "Accept: application/json" > /dev/null || true

curl -s -X GET "${BASE_URL}/api/v1/users?role=developer&status=active" \
  -H "User-Agent: LabClient/1.0" > /dev/null || true
log_success "Standard GET traffic sent."
sleep 1

# --- Step 2: REST POST with JSON Payload & Bearer Authentication ---
log_info "2. Transmitting authenticated POST request with JSON body..."
curl -s -X POST "${BASE_URL}/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test-jwt-token-xyz987" \
  -H "X-Request-ID: req-uuid-550e8400-e29b" \
  -d '{"username":"devops_admin","action":"authenticate","scope":"cluster:read"}' > /dev/null || true
log_success "Authenticated POST payload sent."
sleep 1

# --- Step 3: Triggering HTTP Client Errors (404 Not Found) ---
log_warn "3. Generating HTTP 404 client error traffic..."
# Query web-frontend (Nginx) for a non-existent path to trigger genuine 404 Not Found
kubectl exec -n demo-workload deploy/traffic-generator -- curl -s http://web-frontend.demo-workload.svc.cluster.local/missing-page-404 > /dev/null 2>&1 || true
curl -s -X GET "${BASE_URL}/non-existent-api-path/v99" \
  -H "User-Agent: BugFinder/2.1" > /dev/null || true
log_success "HTTP 404 request sent."
sleep 1

# --- Step 4: Triggering HTTP Server Errors (500 Internal Error) ---
log_warn "4. Generating HTTP 500 server error traffic..."
curl -s -X POST "${BASE_URL}/api/v1/crash-test?trigger=500" \
  -H "Content-Type: application/json" \
  -d '{"error_simulation": true}' > /dev/null || true
log_success "HTTP 500 error request sent."
sleep 1

# --- Step 5: DNS Resolution Queries ---
log_info "5. Generating DNS resolution traffic..."
nslookup kubernetes.default.svc.cluster.local 2>/dev/null || true
nslookup web-frontend.demo-workload.svc.cluster.local 2>/dev/null || true
log_success "DNS resolution traffic sent."

echo ""
log_info "Traffic generation complete."
log_info "Use these sample KFL filters in Kubeshark to inspect:"
echo "  • Filter HTTP POSTs:           http && method == \"POST\""
echo "  • Filter Errors (>= 400):       http && status_code >= 400"
echo "  • Filter URL Path:             http && url.contains(\"/api/v1\")"
echo "  • Filter Auth Header:          http && \"Authorization\" in request.headers"
echo "  • Filter Specific Token:       http && request.headers[\"Authorization\"].contains(\"Bearer\")"
echo "  • Filter DNS traffic:          dns"

