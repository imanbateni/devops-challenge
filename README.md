## 📋 Table of Contents

    Architecture Overview
    Quick Start
    Project Structure
    API Documentation
    Monitoring & Health Checks
    Accessing the services and testing the Solution
    Logs
    Testing
    Maintenance
    Traefik Configuration
    Additional Resources

----------------------------------------------------------------------------------------------------------------------------

## 🏗️ Architecture Overview

Edge Layer = Traefik(Load Balancer)

Application Layers = Backend1(Node.js) + Backend2(Node.js)

Data Layer = PostgreSQL(Database) + HashiCorp-Vault(Secrets Manager)

    Client -->|HTTP| Traefik
    Traefik -->|Load Balance| Backend1
    Traefik -->|Load Balance| Backend2
    Backend1 -->|Query| Postgres
    Backend2 -->|Query| Postgres
    Backend1 -.->|Get Secrets| Vault
    Backend2 -.->|Get Secrets| Vault

----------------------------------------------------------------------------------------------------------------------------

## 🚀 Quick Start

    Prerequisites:
    
    Docker & Docker Compose (v2.0+)
    Make (optional, but recommended)
    Ansible (for automated setup)

## Option 1: Using Make (Recommended)

  Clone the repository:

    git clone <repository-url>
    cd devops-challenge

  Make scripts executable:
    
    chmod +x scripts/*.sh

  Start all services
    
    make up

  Check service status
    
    make status

  View logs
    
    make logs

  Run tests
  
    make test

## Option 2: Using Ansible
  Run the automated setup for provisioning:
    
    ansible-playbook ansible/setup.yml

  Run the automated destroy for removing components:

    ansible-playbook ansible/destroy.yml

   This will:
   - Initialize Vault with policies and secrets
   - Configure AppRole authentication
   - Start all services
   - Run initial health checks

----------------------------------------------------------------------------------------------------------------------------

## 📁 Project Structure
~~~
  devops-challenge/
  ├── backend/
  │   ├── src/
  │   │   └── index.ts        # Main application
  │   ├── Dockerfile          # Multi-stage build
  │   ├── package.json        # Dependencies
  │   └── tsconfig.json       # TypeScript config
  ├── scripts/
  │   ├── init-vault.sh       # Vault initialization
  │   └── test-api.sh         # API test suite
  ├── ansible/
  │   └── setup.yml           # Automated setup playbook
  ├── docker-compose.yml      # Service orchestration
  ├── Makefile               # Convenience commands
  ├── .env.example           # Environment template
  └── README.md              # This file
~~~
----------------------------------------------------------------------------------------------------------------------------

## 📡 API Documentation

 Endpoints:

  Health Check:
  
    GET /api/health

    Sample Response:
    {
      "status": "healthy",
      "timestamp": "2024-01-20T10:30:00Z",
      "services": {
        "api": "running",
        "database": "connected"
      }
    }

  Create User:

    POST /api/users
    Content-Type: application/json
    {
      "username": "johndoe",
      "email": "john@example.com"
    }

    Sample Response (201):
    {
      "success": true,
      "data": {
        "id": 1,
        "username": "johndoe",
        "email": "john@example.com",
        "created_at": "2024-01-20T10:30:00Z"
      }
    }

  List Users:
  
    GET /api/users
  
    Sample Response (200):
    {
      "success": true,
      "data": [...],
      "count": 10
    }

  Error Responses:

    400 - Validation error
    409 - Duplicate user
    500 - Internal server error
    503 - Service unavailable

----------------------------------------------------------------------------------------------------------------------------

## 🏥 Monitoring & Health Checks

Service Health Checks:
  All services include Docker health checks:
  ~~~
  healthcheck:
    test: ["CMD", "command"]
    interval: 30s
    timeout: 10s
    retries: 3
~~~
----------------------------------------------------------------------------------------------------------------------------

## 🧪 Accessing the services and testing the Solution:

  - Traefik Dashboard: http://localhost:8080
  - Vault UI:          http://localhost:8200 (Token: myroot)

Create a user:
~~~
  curl -X POST http://localhost/api/users \
    -H "Content-Type: application/json" \
    -d '{"username":"johndoe","email":"john@example.com"}'
~~~
List all users:
~~~
  curl http://localhost/api/users
~~~
HealthCheck:
~~~
  curl http://localhost/api/health
~~~
View Vault secrets:
~~~
  docker exec devops-vault vault kv get secret/database/postgres
~~~
----------------------------------------------------------------------------------------------------------------------------

## 🧪 Logs

All services:

    make logs

Specific service:

    docker-compose logs -f backend-1

Last 100 lines:

    docker-compose logs --tail=100

----------------------------------------------------------------------------------------------------------------------------

## 🧪 Testing

Automated Tests:

    make test

 * Testing health endpoint 
 * Testing user creation 
 * Testing user listing 
 * Testing input validation 
 * Testing duplicate user handling

Manual Testing:

Create a user:
~~~
    curl -X POST http://localhost/api/users \
      -H "Content-Type: application/json" \
      -d '{"username":"test","email":"test@example.com"}'
~~~
List users:
~~~
    curl http://localhost/api/users
~~~
----------------------------------------------------------------------------------------------------------------------------

## 🛠️ Maintenance

Updating Services

Rebuild and restart:
~~~
make build
make restart
~~~

Stop services:
~~~
make down
~~~

Remove everything (including volumes):
~~~
make clean
~~~

Backup database:
~~~
docker exec devops-postgres pg_dump -U dbadmin userdb > backup.sql
~~~
Backup Vault (export policies and configuration):
~~~
docker exec devops-vault vault policy list
~~~
----------------------------------------------------------------------------------------------------------------------------

## 🛠️ Traefik Configuration

The Traefik service is set up as a reverse proxy and load balancer:
~~~
  traefik:
    image: traefik:v3.0
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
~~~

Key configuration points:

  Uses Docker provider to automatically discover services
  Services must be explicitly enabled (exposedbydefault=false)
  Listens on port 80 for incoming requests

Backend Service Labels:

Both backend-1 and backend-2 services have identical Traefik labels:
~~~  
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.backend.rule=PathPrefix(`/api`)"
    - "traefik.http.services.backend.loadbalancer.server.port=3000"
    - "traefik.http.services.backend.loadbalancer.sticky.cookie=true"
~~~

How Load Balancing Works:

  Service Discovery: Traefik automatically discovers both backend containers through Docker labels
  Routing Rule: All requests with path prefix /api are routed to the backend service group
  Load Balancing: Since both containers share the same service name (backend) in the labels, Traefik treats them as instances of the same service and load balances between them
  Sticky Sessions: The sticky.cookie=true setting ensures that once a client is assigned to a backend instance, subsequent requests from that client go to the same instance

Traffic Flow:
~~~
  Client sends request to http://localhost/api/something
  Traefik receives the request on port 80
  Traefik matches the /api path prefix rule
  Traefik forwards the request to either backend-1:3000 or backend-2:3000
  With sticky sessions enabled, the same client will consistently hit the same backend instance
~~~
----------------------------------------------------------------------------------------------------------------------------

## 📚 Additional Resources

  Vault Documentation
  https://www.vaultproject.io/docs

  Traefik Documentation
  https://doc.traefik.io/traefik/

  Docker Best Practices
  https://docs.docker.com/build/building/best-practices/

  TypeScript Handbook
  https://www.typescriptlang.org/docs/


