#!/bin/bash

# ============================================
# REQUIRED CONFIGURATION
# ============================================

# Git repository URL
REPO_URL="https://github.com/username/your-app"

# Application name (used for directory and nginx config)
APP_NAME="myapp"

# Domain name for your application
DOMAIN_NAME="example.com"

# Email for Let's Encrypt SSL certificate
EMAIL="admin@example.com"

# Port your application runs on (inside the container)
APP_PORT="3000"

# ============================================
# OPTIONAL CONFIGURATION
# ============================================

# Swap size (default: 2G)
SWAP_SIZE="2G"

# Application directory (default: ~/$APP_NAME)
APP_DIR="~/myapp"

# ============================================
# ENVIRONMENT VARIABLES
# ============================================
# Add your application-specific environment variables here
# This will be written to .env file in the application directory

ENV_VARS="
# Database Configuration
DATABASE_URL=postgres://user:password@db:5432/myapp_db

# Application Settings
NODE_ENV=production
API_KEY=your-api-key-here

# Add any other environment variables your app needs
"

# ============================================
# NOTES
# ============================================
# 1. Copy this file to config.sh and fill in your values
# 2. Keep config.sh private (add it to .gitignore)
# 3. Your repository must contain:
#    - Dockerfile
#    - docker-compose.yml or compose.yml
# 4. Make sure APP_PORT matches the port exposed in your compose file