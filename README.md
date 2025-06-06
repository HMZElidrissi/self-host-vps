# Self-host your application on a VPS

A portable deployment script for containerized applications on VPS servers. This script automates the setup of your application with Nginx reverse proxy, SSL certificates, and container orchestration.

## Features

- ✅ **Podman & podman-compose**: Rootless container orchestration
- ✅ **SSL Certificates**: Automatic Let's Encrypt SSL setup with auto-renewal
- ✅ **Nginx Reverse Proxy**: Pre-configured with rate limiting and streaming support
- ✅ **Swap Space**: Automatic swap configuration for memory management
- ✅ **Framework Agnostic**: Works with any app that has Dockerfile and compose.yml
- ✅ **Environment Management**: Easy .env file configuration

## Prerequisites

### On Your VPS
- Ubuntu/Debian-based system (tested on Ubuntu 20.04+)
- Root or sudo access
- DNS A record pointing your domain to the VPS IP

### In Your Application Repository
Your application must include:
- `Dockerfile` - Container build instructions
- `docker-compose.yml` or `compose.yml` - Service orchestration

Example compose.yml structure:
```yaml
services:
  web:
    build: .
    ports:
      - "3000:3000"  # Make sure this matches APP_PORT in config
    environment:
      - NODE_ENV=production
    # ... other services like databases
```

## Installation

1. **Download the deployment script**
   ```bash
   wget https://raw.githubusercontent.com/HMZElidrissi/self-host-vps/main/deploy.sh
   wget https://raw.githubusercontent.com/HMZElidrissi/self-host-vps/main/config.example.sh
   chmod +x deploy.sh
   ```

2. **Create your configuration**
   ```bash
   cp config.example.sh config.sh
   nano config.sh  # Edit with your settings
   ```

3. **Run the deployment**
   ```bash
   ./deploy.sh
   ```

## Configuration

### Required Settings

Edit `config.sh` with your application details:

```bash
# Your git repository
REPO_URL="https://github.com/HMZElidrissi/super-cool-app"

# Application name (used for directories and configs)
APP_NAME="super-cool-app"

# Your domain name
DOMAIN_NAME="super-cool-app.com"

# Email for SSL certificates
EMAIL="hamza@super-cool-app.com"

# Port your app runs on (must match your compose file)
APP_PORT="3000"
```

### Optional Settings

```bash
# Swap space size (default: 2G)
SWAP_SIZE="2G"

# Custom application directory (default: ~/$APP_NAME)
APP_DIR="/opt/myapp"
```

### Environment Variables

The `ENV_VARS` section in config.sh will be written to `.env` in your application directory:

```bash
ENV_VARS="
DATABASE_URL=postgres://user:password@db:5432/myapp
NODE_ENV=production
API_KEY=your-secret-key
"
```

**Important**: Keep sensitive data in `config.sh` and never commit it to version control!

## What the Script Does

1. **System Setup**
   - Updates system packages
   - Configures swap space
   - Installs Podman and podman-compose

2. **Application Deployment**
   - Clones/updates your git repository
   - Creates .env file from configuration
   - Builds container images with Podman
   - Starts all services

3. **Web Server Configuration**
   - Installs and configures Nginx
   - Obtains SSL certificate from Let's Encrypt
   - Sets up reverse proxy with:
     - HTTPS redirect
     - Rate limiting (10 req/sec)
     - WebSocket support
     - Streaming support

4. **SSL Auto-Renewal**
   - Configures cron job to renew certificates every 12 hours

## Post-Deployment

After successful deployment, your application will be available at `https://super-cool-app.com`

### Useful Commands

Navigate to your app directory first:
```bash
cd ~/super-cool-app  # or your custom APP_DIR
```

**View logs:**
```bash
podman-compose logs -f
```

**Restart services:**
```bash
podman-compose restart
```

**Stop services:**
```bash
podman-compose down
```

**Rebuild and restart:**
```bash
podman-compose up -d --build
```

**Update application:**
```bash
git pull
podman-compose up -d --build
```

## Troubleshooting

### Containers not starting
```bash
cd ~/super-cool-app
podman-compose logs
```

### SSL certificate issues
- Ensure DNS is properly configured before running script
- Check that port 80 is not blocked by firewall
- Verify email address is valid

### Nginx errors
```bash
sudo nginx -t  # Test configuration
sudo systemctl status nginx  # Check service status
sudo tail -f /var/log/nginx/error.log  # View error logs
```

### Port conflicts
- Ensure APP_PORT in config matches your compose.yml
- Check no other service is using the same port:
```bash
sudo netstat -tlnp | grep :3000
```

## Security Notes

1. **Keep config.sh private** - It may contain sensitive information
2. **Use strong passwords** - For databases and services
3. **Review firewall rules** - Only expose necessary ports:
   ```bash
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw allow 22/tcp
   sudo ufw enable
   ```
4. **Regular updates** - Keep your system and containers updated

## Customization

### Nginx Configuration

The script creates an Nginx config at `/etc/nginx/sites-available/$APP_NAME`. You can customize it after deployment:

```bash
sudo nano /etc/nginx/sites-available/myapp
sudo nginx -t
sudo systemctl reload nginx
```

### Adding Multiple Apps

You can run the script multiple times with different configurations for multiple applications on the same VPS. Just use different:
- APP_NAME
- DOMAIN_NAME  
- APP_PORT
