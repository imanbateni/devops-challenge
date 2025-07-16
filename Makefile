.PHONY: help up down logs test clean build vault-creds status restart

# Default target
help:
	@echo "DevOps Challenge - Available commands:"
	@echo "  make up          - Start all services"
	@echo "  make down        - Stop all services"
	@echo "  make logs        - View service logs"
	@echo "  make test        - Run API tests"
	@echo "  make clean       - Clean up volumes and containers"
	@echo "  make build       - Build/rebuild services"
	@echo "  make vault-creds - Get Vault credentials"
	@echo "  make status      - Show service status"
	@echo "  make restart     - Restart all services"

# Start all services
up:
	@echo "Starting all services..."
	docker-compose up -d
	@echo "Waiting for services to be healthy..."
	@sleep 10
	@echo "Services are starting. Check status with 'make status'"
	@echo ""
	@echo "Access points:"
	@echo "  - Traefik Dashboard: http://localhost:8080"
	@echo "  - healthcheck API:   http://localhost/api/health"
	@echo "  - getUsers API:      http://localhost/api/users"
	@echo "  - Vault UI:          http://localhost:8200 (Token: myroot)"

# Stop all services
down:
	@echo "Stopping all services..."
	docker-compose down

# View logs
logs:
	docker-compose logs -f

# Run tests
test:
	@echo "Running API tests..."
	@./scripts/test-api.sh

# Clean everything
clean:
	@echo "Cleaning up..."
	docker-compose down -v
	docker system prune -f

# Build services
build:
	@echo "Building services..."
	docker-compose build --no-cache

# Get Vault credentials
vault-creds:
	@echo "Retrieving Vault credentials..."
	@docker exec devops-vault sh -c 'vault read -field=role_id auth/approle/role/backend/role-id'
	@docker exec devops-vault sh -c 'vault write -field=secret_id -f auth/approle/role/backend/secret-id'

# Show service status
status:
	@echo "Service Status:"
	@docker-compose ps
	@echo ""
	@echo "Health Checks:"
	@curl -s http://localhost:8443/api/health | jq . || echo "Backend not ready"

# Restart services
restart: down up

# Initialize infrastructure (used by ansible)
init:
	@echo "Initializing infrastructure..."
	@docker-compose up -d vault postgres
	@sleep 5
	@docker-compose up vault-init
	@echo "Infrastructure initialized!"