#!/bin/bash

# VPN Billing System Auto-Installation Script with fixes for package manager issues
# Repository: https://github.com/Iscgrou/finone

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to fix package manager
fix_package_manager() {
    print_status "Checking package manager status..."
    
    if [ ! -f /var/lib/dpkg/status ]; then
        print_warning "Package manager status file is missing"
        
        # Try to restore from backup
        if [ -f /var/lib/dpkg/status-old ]; then
            $sudo cp /var/lib/dpkg/status-old /var/lib/dpkg/status
            print_status "Restored from status-old"
        elif [ -f /var/backups/dpkg.status.0 ]; then
            $sudo cp /var/backups/dpkg.status.0 /var/lib/dpkg/status
            print_status "Restored from system backup"
        else
            print_status "Creating new status file"
            $sudo mkdir -p /var/lib/dpkg
            $sudo touch /var/lib/dpkg/status
        fi
        
        # Try to fix package manager
        $sudo dpkg --configure -a
        $sudo apt-get update --fix-missing
    fi
}

# Function to install dependencies with retry
install_dependencies() {
    print_status "Installing system dependencies..."
    
    # First fix package manager
    fix_package_manager
    
    # Try to update and install
    for i in {1..3}; do
        if $sudo apt-get update && \
           $sudo apt-get install -y curl wget git unzip nginx certbot python3-certbot-nginx; then
            print_status "Dependencies installed successfully"
            return 0
        else
            print_warning "Attempt $i failed, retrying..."
            sleep 5
        fi
    done
    
    print_error "Failed to install dependencies after 3 attempts"
    return 1
}

# Main installation function
main() {
    # Check execution environment
    if [ "$EUID" -eq 0 ]; then
        print_warning "Running as root user"
        # Define sudo as empty since we're already root
        sudo=""
    else
        print_status "Running as normal user"
        # Check sudo access
        if ! sudo -v; then
            print_error "This script requires sudo privileges"
            exit 1
        fi
        # Define sudo command
        sudo="sudo"
    fi
    
    print_status "Starting installation with fixes..."
    
    # Test values
    DOMAIN="shire.marfanet.com"
    ADMIN_EMAIL="marfanetw@gmail.com"
    ADMIN_USERNAME="admin"
    ADMIN_PASSWORD="Aa867945"
    DB_NAME="vpn_billing"
    DB_USER="vpn_user"
    DB_PASSWORD="Fa867945"
    TELEGRAM_BOT_TOKEN="8075256802:AAFAjgAh2EwxRBf6SgCqIbVXzex8v_aPH40"
    OPENAI_API_KEY="xai-JqaPaNzxCee15YnFeCNv9LHnVsOoVURjUuThgEGLu90yaQvXSyu5CeM3MlHcJUPky6hc79ZF8ZQS1WkQ"
    GOOGLE_DRIVE_EMAIL="marfanetw@gmail.com"
    INSTALL_DIR="/opt/vpn-billing"
    
    # Install dependencies with package manager fix
    if ! install_dependencies; then
        print_error "Failed to install dependencies"
        exit 1
    fi
    
    print_status "Dependencies installed successfully"
    print_status "Package manager is working correctly"
    
    # Install Node.js
    print_status "Installing Node.js..."
    if ! command -v node >/dev/null 2>&1; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | $sudo bash -
        $sudo apt-get install -y nodejs
    else
        print_status "Node.js is already installed ($(node --version))"
    fi
    
    # Install PostgreSQL
    print_status "Installing PostgreSQL..."
    if ! command -v psql >/dev/null 2>&1; then
        $sudo apt-get install -y postgresql postgresql-contrib
        $sudo systemctl start postgresql
        $sudo systemctl enable postgresql
    else
        print_status "PostgreSQL is already installed"
    fi
    
    # Setup database
    print_status "Setting up database..."
    $sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';" 2>/dev/null || true
    $sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;" 2>/dev/null || true
    $sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" 2>/dev/null || true
    
    # Clone and setup application
    print_status "Setting up application..."
    $sudo mkdir -p "$INSTALL_DIR"
    $sudo chown "$USER:$USER" "$INSTALL_DIR"
    
    if [ -d "$INSTALL_DIR/.git" ]; then
        cd "$INSTALL_DIR"
        git pull origin main
    else
        git clone https://github.com/Iscgrou/finone.git "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi
    
    # Start PostgreSQL service
    print_status "Starting PostgreSQL service..."
    service postgresql start
    
    # Install npm dependencies and build
    print_status "Installing npm dependencies..."
    cd "$INSTALL_DIR"
    npm install
    
    print_status "Building application..."
    npm run build
    
    # Configure nginx
    print_status "Configuring nginx..."
    cat > /etc/nginx/sites-available/vpn-billing <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/vpn-billing /etc/nginx/sites-enabled/
    service nginx restart
    
    # Create environment file
    print_status "Creating environment configuration..."
    cat > "$INSTALL_DIR/.env" <<EOF
NODE_ENV=production
DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME
DOMAIN=$DOMAIN
ADMIN_EMAIL=$ADMIN_EMAIL
TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
OPENAI_API_KEY=$OPENAI_API_KEY
GOOGLE_DRIVE_EMAIL=$GOOGLE_DRIVE_EMAIL
ADMIN_USERNAME=$ADMIN_USERNAME
ADMIN_PASSWORD=$ADMIN_PASSWORD
JWT_SECRET=$(openssl rand -base64 32)
ENCRYPTION_KEY=$(openssl rand -base64 32)
EOF

    print_status "Installation completed successfully!"
    echo
    echo "VPN Billing System is installed at: $INSTALL_DIR"
    echo "Access your system at: http://$DOMAIN"
    echo
    echo "Database Configuration:"
    echo "  Database: $DB_NAME"
    echo "  User: $DB_USER"
    echo
    echo "Admin Login:"
    echo "  Username: $ADMIN_USERNAME"
    echo "  Password: [as provided]"
    echo
    echo "Services:"
    echo "  PostgreSQL: service postgresql status"
    echo "  Nginx: service nginx status"
    echo "  Application: cd $INSTALL_DIR && npm run start"
}

# Run main function
main "$@"
