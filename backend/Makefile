# Makefile for Django Quotes Collector Project
PYTHON := .venv/bin/python

.PHONY: help dev-db dev-db-stop dev-db-clean dev-db-logs migrate runserver shell test

# Default target
help:
	@echo "Available commands:"
	@echo "  dev-db          - Start PostgreSQL database in Docker"
	@echo "  dev-db-stop     - Stop PostgreSQL database"
	@echo "  dev-db-clean    - Stop and remove PostgreSQL container and volumes"
	@echo "  dev-db-logs     - Show PostgreSQL container logs"
	@echo "  migrate         - Run Django migrations"
	@echo "  runserver       - Start Django development server"
	@echo "  shell           - Open Django shell"
	@echo "  test            - Run tests"

# Python Environment Setup
setup:
	@echo "🐍 Installing Python dependencies..."
	./scripts/setup.sh

# Install production dependencies only
install:
	pip install -r requirements.txt

# Install development dependencies
install-dev:
	pip install -r requirements-dev.txt

# Start PostgreSQL database in Docker
dev-db:
	@echo "Starting PostgreSQL database..."
	docker compose -f docker-compose.dev.yml up -d postgres
	@echo "Waiting for database to be ready..."
	@sleep 5
	@echo "Database is ready!"

# Stop PostgreSQL database
dev-db-stop:
	@echo "Stopping PostgreSQL database..."
	docker compose -f docker-compose.dev.yml down

# Clean up PostgreSQL containers and volumes
dev-db-clean:
	@echo "Cleaning up PostgreSQL database..."
	docker compose -f docker-compose.dev.yml down -v
	docker system prune -f

# Show PostgreSQL logs
dev-db-logs:
	docker compose -f docker-compose.dev.yml logs -f postgres

# Django management commands
migrate:
	$(PYTHON) manage.py migrate

runserver: migrate
	$(PYTHON) manage.py runserver 0.0.0.0:8000

shell:
	$(PYTHON) manage.py shell

test:
	$(PYTHON) manage.py test

# Combined commands
start: dev-db migrate
	@echo "Database started and migrations applied!"

dev: start runserver
