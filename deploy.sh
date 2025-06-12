#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if config file exists
if [ ! -f "config.sh" ]; then
    log_error "config.sh not found! Please create one from config.example.sh"
    exit 1
fi

# Load configuration
source config.sh

# Validate required variables
REQUIRED_VARS=(
    "REPO_URL"
    "APP_NAME"
    "DOMAIN_NAME"
    "EMAIL"
    "APP_PORT"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        log_error "Required variable $var is not set in config.sh"
        exit 1
    fi
done

# Set defaults for optional variables
SWAP_SIZE=${SWAP_SIZE:-"2G"}
CONTAINER_RUNTIME=${CONTAINER_RUNTIME:-"podman"}
APP_DIR=${APP_DIR:-~/$APP_NAME}

log_info "Starting deployment for $APP_NAME..."

# Update system packages
log_info "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Add Swap Space
if ! swapon --show | grep -q '^/swapfile'; then
    log_info "Adding swap space ($SWAP_SIZE)..."
    sudo fallocate -l $SWAP_SIZE /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
else
    log_info "Swapfile already active, skipping creation."
fi

# Install Podman and podman-compose
log_info "Installing Podman and podman-compose..."
sudo apt install -y podman podman-compose

podman --version
if [ $? -ne 0 ]; then
    log_error "Podman installation failed."
    exit 1
fi

podman-compose --version
if [ $? -ne 0 ]; then
    log_error "podman-compose installation failed."
    exit 1
fi

# Clone or update repository
if [ -d "$APP_DIR" ]; then
    log_info "Directory $APP_DIR already exists. Pulling latest changes..."
    cd $APP_DIR && git pull
else
    log_info "Cloning repository from $REPO_URL..."
    git clone $REPO_URL $APP_DIR
    cd $APP_DIR
fi

# Create .env file if ENV_VARS is provided
if [ ! -z "$ENV_VARS" ]; then
    log_info "Creating .env file..."
    echo "$ENV_VARS" > "$APP_DIR/.env"
fi

# Install Nginx
log_info "Installing Nginx..."
sudo apt install nginx -y

# Stop Nginx temporarily for SSL certificate generation
sudo systemctl stop nginx

# Obtain SSL certificate
log_info "Obtaining SSL certificate for $DOMAIN_NAME..."
sudo apt install certbot -y
sudo certbot certonly --standalone -d $DOMAIN_NAME --non-interactive --agree-tos -m $EMAIL

# Download SSL configuration files if needed
if [ ! -f /etc/letsencrypt/options-ssl-nginx.conf ]; then
    sudo wget https://raw.githubusercontent.com/certbot/certbot/refs/heads/main/certbot-nginx/src/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf -P /etc/letsencrypt/
fi

if [ ! -f /etc/letsencrypt/ssl-dhparams.pem ]; then
    sudo openssl dhparam -out /etc/letsencrypt/ssl-dhparams.pem 2048
fi

# Create Nginx configuration
log_info "Creating Nginx configuration..."
sudo cat > /etc/nginx/sites-available/$APP_NAME <<EOL
limit_req_zone \$binary_remote_addr zone=${APP_NAME}_limit:10m rate=10r/s;

server {
    listen 80;
    server_name $DOMAIN_NAME;

    # Redirect all HTTP requests to HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN_NAME;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # Enable rate limiting
    limit_req zone=${APP_NAME}_limit burst=20 nodelay;

    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;

        # Disable buffering for streaming support
        proxy_buffering off;
        proxy_set_header X-Accel-Buffering no;
        
        # Forward real IP
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Enable Nginx site
sudo ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/$APP_NAME

# Test Nginx configuration
sudo nginx -t
if [ $? -ne 0 ]; then
    log_error "Nginx configuration test failed."
    exit 1
fi

# Restart Nginx
sudo systemctl restart nginx

# Build and deploy containers
cd $APP_DIR

log_info "Cleaning up existing containers..."
podman-compose down --remove-orphans 2>/dev/null || true

log_info "Building container images..."
if ! podman-compose build; then
    log_error "Container build failed."
    exit 1
fi

log_info "Starting services..."
if ! podman-compose up -d; then
    log_error "Failed to start services."
    exit 1
fi

# Wait a moment for containers to start
sleep 5

# Check if services are running
if ! podman-compose ps | grep -q "Up\|running"; then
    log_warning "Containers might not be running properly. Check logs with 'podman-compose logs'."
fi

# Setup automatic SSL certificate renewal
log_info "Setting up automatic SSL renewal..."
(crontab -l 2>/dev/null | grep -v "certbot renew"; echo "0 */12 * * * certbot renew --quiet && systemctl reload nginx") | crontab -

# Output final message
echo ""
log_info "======================================"
log_info "Deployment complete!"
log_info "======================================"
echo ""
echo "Application: $APP_NAME"
echo "URL: https://$DOMAIN_NAME"
echo "Directory: $APP_DIR"
echo ""
echo "Useful commands:"
echo "  View logs:       cd $APP_DIR && podman-compose logs -f"
echo "  Stop services:   cd $APP_DIR && podman-compose down"
echo "  Restart services: cd $APP_DIR && podman-compose restart"
echo "  Rebuild:         cd $APP_DIR && podman-compose up -d --build"
echo ""