#!/bin/bash

# Enables Bash options: -e exits immediately on error, and -u treats unset variables as errors.
set -eu

# Variables to be used in the script

# Maximum number of retries for installing laravel dependencies
MAX_RETRIES=3
# Environment variable to prevent interactive prompts to restart services
WITHOUT_RESTART="DEBIAN_FRONTEND=noninteractive"
# Linux user to be used for Laravel application
CURRENT_LINUX_USER="azureuser"
# Directory where Laravel application files are to be stored
LARAVEL_DIR="/var/www/html/laravel"
# Root user password for MySQL
DB_ROOT_USER_PASSWORD="vagrant7"
# Name of the MySQL database to be used by the Laravel application
DB_NAME="laravel"
# New user name to be set for MySQL database access
LARAVEL_DB_USER="lamp"
# New user password to be set for MySQL database access
LARAVEL_DB_PASSWORD="lamproject7"
# Desired Apache configuration file for the Laravel application
DESIRED_APACHE_CONF_FILE="lamp-project.conf"
# Email address of the Apache server administrator
APACHE_SERVER_ADMIN_EMAIL="webmaster@localhost"
# Server name or IP address for the Apache server
APACHE_SERVER_DOMAIN_NAME_OR_IP= # Public IP of server this script is run on or domain name if you have one and it resolves to the server
# Directory where Apache logs are stored
APACHE_LOG_DIR="/var/log/apache2"

# Function to print script progress to the terminal and also log it in a file
print_and_log() {
    local message="$1"
    local log_file="/var/log/lamp_deployment.log"

    # Print the progress message with as a bold text on the terminal (for when the script is run manually)
    echo "--------------------------------------------------"
    echo -e "\033[1m$message\033[0m"  # Bold text
    echo "--------------------------------------------------"

    # Log the message to the log file with a timestamp (for debugging purposes especially when the script is run remotely)
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" | sudo tee -a "$log_file" > /dev/null
}

# Function to install required packages
install_packages() {
    print_and_log "Installing required packages..."
    # Adds PHP repository for updated PHP versions.
    sudo apt-add-repository ppa:ondrej/php -y
    # Updates package list.
    sudo apt-get update
    # Upgrades pre-installed packages without interactive prompts to restart services.
    sudo $WITHOUT_RESTART apt-get upgrade -y
    # Installs required packages without interactive prompts to restart services.
    sudo $WITHOUT_RESTART apt-get install -y expect apache2 mysql-server php php-mysql libapache2-mod-php
    # Installs necessary PHP packages without interactive prompts to restart services.
    sudo $WITHOUT_RESTART apt install -y php-pear php-common php-mbstring php-zip php-gd php-xml php-curl
    print_and_log "Packages installed successfully."
}

# Function to install Composer for PHP package management
install_composer() {
    print_and_log "Installing Composer..."
    # Downloads and installs Composer globally.
    curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
    print_and_log "Composer installed successfully."
}

# Function to clone Laravel repository from GitHub and set necessary permissions
clone_laravel() {
    print_and_log "Cloning Laravel repository from GitHub..."
    # Clones Laravel repository to the specified directory.
    sudo git clone https://github.com/laravel/laravel.git $LARAVEL_DIR
    # Sets ownership and permissions for Laravel directories in case you decide to clone it in a directory owned by root (like /var/www/html) where you have to run sudo to install laravel dependencies (composer install).
    sudo chown -R $CURRENT_LINUX_USER:$CURRENT_LINUX_USER $LARAVEL_DIR
    # Gives Apache access to Laravel's storage directory.
    sudo chown -R www-data:www-data $LARAVEL_DIR/storage
    sudo chmod -R 775 $LARAVEL_DIR/storage
    print_and_log "Laravel repository cloned successfully."
}

# Function to install Laravel dependencies using Composer
install_laravel_dependencies() {
    print_and_log "Installing Laravel dependencies using Composer..."
    local retries=0
    while [ $retries -lt $MAX_RETRIES ]; do
        # Attempts to install Laravel dependencies using Composer.
        if composer install; then
            print_and_log "Laravel dependencies installed successfully."
            return 0
        else
            # If installation fails, this increments the retry count and sleeps for a while before retrying.
            ((retries++))
            print_and_log "Composer install failed. Retrying... Attempt $retries of $MAX_RETRIES"
            sleep 5
        fi
    done
    # Exits if maximum retries is reached.
    print_and_log "Maximum number of retries reached. Exiting..."
    exit 1
}

# Function to secure MySQL installation using Expect tool
secure_mysql_installation() {
    print_and_log "Securing MySQL installation..."
    # Automates answering MySQL secure installation prompts using Expect.
    sudo expect -c '
    spawn sudo mysql_secure_installation
    expect {
        "Press y|Y for Yes, any other key for No:" { send "y\r"; exp_continue }
        "Please enter 0 = LOW, 1 = MEDIUM and 2 = STRONG:" { send "0\r"; exp_continue }
        "Remove anonymous users?" { send "\r"; exp_continue }
        "Disallow root login remotely?" { send "\r"; exp_continue }
        "Remove test database and access to it?" { send "\r"; exp_continue }
        "Reload privilege tables now?" { send "\r"; exp_continue }
        timeout { puts "Timeout: Unexpected prompt encountered"; exit 1 }
    }
    expect eof
    '
    print_and_log "MySQL installation secured successfully."
}

# Function to run MySQL commands
run_mysql() {
    local mysql_command="$1"
    # Uses Expect to automate MySQL command execution.
    expect -c "
        spawn sudo mysql -u root -p -e \"$mysql_command\"
        expect \"Enter password: \"
        send \"$DB_ROOT_USER_PASSWORD\r\"
        interact
    "
}

# Function to setup database for Laravel application
setup_database() {
    print_and_log "Setting up database for Laravel application..."
    # Changes MySQL root user password and makes it effective immediately. Note: Make sure your server is secure because anyone with sudo privileges, with this command, can change the MySQL root user password without needing to know the current one.
    run_mysql "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_USER_PASSWORD'; FLUSH PRIVILEGES;"
    # Creates a database and a user for the Laravel application.
    run_mysql "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
    run_mysql "CREATE USER IF NOT EXISTS '$LARAVEL_DB_USER'@'localhost' IDENTIFIED BY '$LARAVEL_DB_PASSWORD'; GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$LARAVEL_DB_USER'@'localhost'; FLUSH PRIVILEGES;"
    print_and_log "Database setup completed."
}

# Function to configure Laravel application to use MySQL database.
configure_laravel() {
    print_and_log "Configuring Laravel application..."
    # Copies .env.example to .env and generates application key.
    sudo cp .env.example .env
    sudo php artisan key:generate
    # Modifies .env file to use prepared MySQL database.
    sudo sed -i 's/DB_CONNECTION=sqlite/DB_CONNECTION=mysql/' .env
    sudo sed -i 's/# DB_HOST=127.0.0.1/DB_HOST=127.0.0.1/' .env
    sudo sed -i 's/# DB_PORT=3306/DB_PORT=3306/' .env
    sudo sed -i 's/# DB_DATABASE=laravel/DB_DATABASE='$DB_NAME'/' .env
    sudo sed -i 's/# DB_USERNAME=root/DB_USERNAME='$LARAVEL_DB_USER'/' .env
    sudo sed -i 's/# DB_PASSWORD=/DB_PASSWORD='$LARAVEL_DB_PASSWORD'/' .env
    sudo php artisan migrate
    print_and_log "Laravel configured successfully."
}

# Function to configure Apache virtual host
configure_apache() {
    print_and_log "Configuring Apache virtual host..."
    # Creates and edits Apache virtual host configuration file.
    sudo tee /etc/apache2/sites-available/$DESIRED_APACHE_CONF_FILE > /dev/null <<EOF
<VirtualHost *:80>
    ServerAdmin $APACHE_SERVER_ADMIN_EMAIL
    ServerName $APACHE_SERVER_DOMAIN_NAME_OR_IP
    DocumentRoot $LARAVEL_DIR/public

    <Directory $LARAVEL_DIR/public>
       Options +FollowSymlinks
       AllowOverride All
       Require all granted
    </Directory>

    ErrorLog $APACHE_LOG_DIR/error.log
    CustomLog $APACHE_LOG_DIR/access.log combined
</VirtualHost>
EOF
    # Enables Apache modules and the newly created virtual host.
    sudo a2enmod rewrite
    sudo a2ensite $DESIRED_APACHE_CONF_FILE
    # Restarts Apache to apply changes made.
    sudo systemctl restart apache2
    print_and_log "Apache virtual host configured successfully."
}

# Main function to orchestrate LAMP stack setup
main() {
    # Sets the timezone to the required timezone.
    sudo timedatectl set-timezone Africa/Lagos
    print_and_log "---- LAMP Stack Setup Started ----"
    install_packages || { print_and_log "Failed to install packages. Exiting..."; exit 1; }
    install_composer || { print_and_log "Failed to install Composer. Exiting..."; exit 1; }
    clone_laravel || { print_and_log "Failed to clone Laravel repository. Exiting..."; exit 1; }
    cd $LARAVEL_DIR || { print_and_log "Failed to change directory to $LARAVEL_DIR. Exiting..."; exit 1; }
    install_laravel_dependencies || { print_and_log "Failed to install Laravel dependencies. Exiting..."; exit 1; }
    secure_mysql_installation || { print_and_log "Failed to secure MySQL installation. Exiting..."; exit 1; }
    setup_database || { print_and_log "Failed to setup database. Exiting..."; exit 1; }
    configure_laravel || { print_and_log "Failed to configure Laravel application. Exiting..."; exit 1; }
    configure_apache || { print_and_log "Failed to configure Apache virtual host. Exiting..."; exit 1; }
    print_and_log "---- LAMP Stack Setup Completed ----"
}

# Execute main function
main
