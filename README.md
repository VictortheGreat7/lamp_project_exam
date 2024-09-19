# LAMP Setup and Automation Project

This project automates the setup of a LAMP stack (Linux, Apache, MySQL, and PHP) on a remote Ubuntu server, deploys a Laravel application, and configures a daily cron job to log the server's uptime via Ansible and a Bash Script.

## Project Structure

The setup involves the following:

### With the Bash Script [`lamp_setup.sh`](./lamp_setup.sh)

- **Environment Setup**: Configures necessary environment variables and settings for the LAMP stack deployment.
- **Package Installation**: Installs Apache, MySQL, PHP, and related dependencies.
- **Composer Installation**: Installs Composer, a PHP dependency management tool.
- **Laravel Setup**: Clones the Laravel repository from GitHub and sets appropriate permissions for project files.
- **Laravel Dependencies**: Installs Laravel dependencies using Composer, with a retry mechanism for failures.
- **MySQL Security**: Secures the MySQL installation by running the `mysql_secure_installation` script.
- **Database Configuration**: Creates a MySQL database and user for the Laravel application.
- **Laravel Configuration**: Links the Laravel app to the MySQL database.
- **Apache Configuration**: Sets up an Apache virtual host for the Laravel app.
- **Timezone Setting**: Configures the system timezone to Africa/Lagos for the cron job set later to be accurate. Edit the timezone as needed.
- **Error Handling**: Implements basic error handling to halt the script if critical steps fail.
- **Logging**: Logs progress to the console and `/var/log/lamp_deployment.log` for monitoring and debugging.

### With the Ansible Playbook [`lamp_playbook.yaml`](./lamp_playbook.yaml)

- **Target Hosts**: Runs on hosts defined as "remote_nodes."
- **Script Transfer**: Copies the LAMP setup Bash script from the main node to the remote nodes.
- **Script Execution**: Executes the transferred LAMP setup script on the remote nodes.
- **Accessibility Check**: Verifies that the remote node is accessible via HTTP.
- **Cron Job Creation**: Sets up a daily cron job to log the server's uptime at midnight.

## Setup Instructions

### Prerequisites

1. **Ansible**: Install [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html) on your control node. Recommended version: 2.16.11 or later.
2. **Ubuntu Server**: The remote node must be running Ubuntu (preferably 22.04 LTS or later).
3. **Bash**: [`lamp_setup.sh`](./lamp_setup.sh) requires Bourne Again Shell to execute.

### Running the Setup

#### 1. SSH Configuration

Set up passwordless SSH access by generating an SSH key pair on your control node and copying the public key to the remote host:

    ```bash
    # Generate keypair
    ssh-keygen -t rsa -b 4096

    # Copy the public key to the remote host
    ssh-copy-id username@remote_host_ip
    ```

Replace `username` with the appropriate user and `remote_host_ip` with the remote node's IP address (either public or private, depending on your network setup).

#### 2. Configure Inventory

Edit the [`myhosts`](./myhosts) file to define your remote host. Add the IP address of your remote node under `[remote_nodes]`:

    ```txt
    [remote_nodes]
    remote_host_ip
    ```

#### 3. Update Variables

Modify the [`variables.yaml`](./variables.yaml) and [`lamp_setup.sh`](./lamp_setup.sh) files to define:

- **`hostname`**: Either a domain name (with DNS resolution) or the remote node's public IP for accessing the Laravel application.
- **`APACHE_SERVER_DOMAIN_NAME_OR_IP`**: The same hostname should be set in the [`lamp_setup.sh`](./lamp_setup.sh) file.
- **`CURRENT_LINUX_USER`**: The username of the user running the script. Use the username you ran `ssh-copy-id` with.

#### 4. Configure Ansible

Edit the [`ansible.cfg`](./ansible.cfg) file to set the `remote_user` and `become_user` to the same username used when you ran ```ssh-copy-id``` in step 1.

#### 5. Run the Ansible Playbook

Execute the following command to deploy the LAMP stack and Laravel app:

    ```bash
    ansible-playbook -i myhosts lamp_playbook.yaml
    ```

#### 6. Verify the Laravel Application

After the playbook finishes, check if the Laravel application is accessible at `http://<hostname>`.

#### 7. Check Uptime Logs

Review the server uptime logs by accessing `/var/log/lamp_uptime.log` on the remote node.

## Files

- **[lamp_playbook.yaml](./lamp_playbook.yaml)**: Ansible playbook that installs the LAMP stack, deploys Laravel, and configures a cron job.
- **[lamp_setup.sh](./lamp_setup.sh)**: Bash script for installing and configuring the LAMP stack and Laravel.
- **[variables.yaml](./variables.yaml)**: Contains variables used in the playbook and script.
- **[myhosts](./myhosts)**: Ansible inventory file defining the target hosts.
- **[ansible.cfg](./ansible.cfg)**: Configuration file for Ansible settings.

## Security Considerations

If you decide to implement these, you have to do it manually. Check the variables in [`lamp_setup.sh`](./lamp_setup.sh) for needed passwords. You can also change them if you want.

- **MySQL Security**: Use `mysql_secure_installation` to restrict MySQL root access and remove test databases.
- **Firewall Configuration**: Ensure that only necessary ports (80 for HTTP and 443 for HTTPS) are open. Restrict MySQL access (port 3306) to localhost.

## Logging and Debugging

The `lamp_setup.sh` script logs its progress to `/var/log/lamp_deployment.log`. In case of issues, review the log file for error messages and status updates.

For more verbose output during the playbook execution, run the playbook with the following command:

    ```bash
    ansible-playbook -i myhosts lamp_playbook.yaml -vvv
    ```

## Maintenance and Future Updates

- **Updating Laravel**: Use Composer to update Laravel or its dependencies by running `composer update` inside the Laravel directory which will be the `/var/www/html/laravel` directory.
- **Server Maintenance**: Ensure regular backups of the MySQL database and logs, and monitor server uptime via the cron job logs.
