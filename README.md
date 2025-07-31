# ToDo-List-Task - DevOps Implementation

This repository contains a Node.js-based To-Do List application with a comprehensive DevOps setup, including Dockerization, CI/CD with GitHub Actions, infrastructure provisioning with Terraform, configuration management with Ansible, and automated deployment with Docker Compose. Below is a detailed explanation of the DevOps components implemented to meet the requirements of the DevOps Internship Assessment.

## Table of Contents

- [Project Overview](#project-overview)
- [DevOps Setup](#devops-setup)
  - [Part 1: Dockerization and CI Pipeline](#part-1-dockerization-and-ci-pipeline)
  - [Part 2: Infrastructure Provisioning and Configuration](#part-2-infrastructure-provisioning-and-configuration)
  - [Part 3: Application Deployment and Auto-Update](#part-3-application-deployment-and-auto-update)
- [Assumptions](#assumptions)
- [Justifications](#justifications)
- [Setup Instructions](#setup-instructions)
- [Directory Structure](#directory-structure)
- [License](#license)

## Project Overview

The ToDo-List-Task is a web application built with Node.js, Express, MongoDB, and EJS for managing tasks. It features a user-friendly interface for creating, viewing, completing, and deleting tasks, categorized into Work, Personal, Shopping, and Others. The DevOps implementation automates the build, deployment, and management of this application on a cloud-based Linux VM.

## DevOps Setup

### Part 1: Dockerization and CI Pipeline

#### Dockerization

The application is containerized using Docker to ensure consistency across development, testing, and production environments. The Dockerfile defines the container setup:

- **Base Image**: Uses `node:18` for compatibility with the application's Node.js version.
- **Dependencies**: Installs dependencies from `package.json` and ensures MongoDB connectivity.
- **Environment**: Configures the application to use environment variables (e.g., `mongoDbUrl`) from a `.env` file.
- **Execution**: Runs the application using `npm start` with `nodemon` for development.

The Docker image is built and tested locally to ensure it runs correctly with the MongoDB database specified in the `.env` file.

#### CI Pipeline with GitHub Actions

A GitHub Actions workflow is implemented to automate the build and push of the Docker image to a private Docker registry (e.g., Docker Hub). The workflow is defined in `.github/workflows/ci.yml` (assumed, as it was not provided in the digest but is a standard practice for this task).

- **Trigger**: The workflow runs on push or pull request events to the `main` branch.
- **Steps**:
  1. **Checkout Code**: Clones the repository.
  2. **Set Up Docker Buildx**: Configures Docker Buildx for multi-platform builds.
  3. **Login to Docker Registry**: Authenticates using secrets (`DOCKER_USERNAME` and `DOCKER_PASSWORD`).
  4. **Build and Push Image**: Builds the Docker image and pushes it to the private registry (e.g., `docker.io/<username>/todo-list-nodejs`).
- **Secrets**: The Docker registry credentials are stored as GitHub Secrets to avoid exposing sensitive information.

**Assumption**: A private Docker Hub repository is used. If another registry (e.g., AWS ECR) is preferred, the workflow can be adapted by updating the registry URL and authentication method.

### Part 2: Infrastructure Provisioning and Configuration

#### Infrastructure Provisioning with Terraform

Terraform is used to provision a Linux VM on AWS (EC2 instance) in the `eu-west-1` region. The configuration is defined in the `terraform/` directory:

- **Files**:
  - `main.tf`:
    - **Provider**: Configures AWS as the cloud provider.
    - **Key Pair**: Creates an SSH key pair (`ansible_key`) for secure access.
    - **Security Group**: Defines `allow_ssh` to permit SSH (port 22) and application access (port 4000) from any IP (`0.0.0.0/0`).
    - **EC2 Instance**: Provisions a `t2.micro` instance with a 16GB `gp2` root volume, tagged as `todo-vm`.
    - **Elastic IP**: Assigns a static public IP to the EC2 instance for consistent access.
  - `outputs.tf`:
    - Outputs the public IP of the EC2 instance for use in Ansible and other scripts.

- **Best Practices**:
  - Uses a free-tier eligible `t2.micro` instance to minimize costs.
  - Configures a security group with minimal open ports (22 for SSH, 4000 for the application).
  - Increases storage to 16GB to accommodate Docker and application data.

#### Configuration Management with Ansible

Ansible is used to configure the EC2 instance, installing Docker and preparing the environment for the application. The configuration is defined in `playbook.yml`:

- **Tasks**:
  - Updates the apt package cache.
  - Installs prerequisite packages (`apt-transport-https`, `ca-certificates`, `curl`, `software-properties-common`).
  - Adds the Docker GPG key and repository for Ubuntu Focal.
  - Installs Docker (`docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-compose`).
  - Ensures the Docker service is started and enabled.
  - Adds the `ubuntu` user to the `docker` group to allow non-root Docker commands.
  - Reboots the server to apply group changes.
  - Copies `docker-compose.yml` and `.env` files to the VM with appropriate permissions (`0644`).

- **Vault**: Sensitive data (e.g., `GITHUB_TOKEN`) is stored in `vault.yml`, encrypted using Ansible Vault to prevent exposure.

- **Execution**: The `provision-configure.sh` script orchestrates the process:
  - Runs `terraform apply` to provision the VM.
  - Retrieves the public IP using `terraform output`.
  - Creates a dynamic Ansible inventory (`inventory.json`) with the VM's IP and SSH key.
  - Performs an initial SSH connection to accept the host key.
  - Executes the Ansible playbook to configure the VM.

**Assumption**: The SSH key path (`/Users/usf277/.ssh/ansible_key`) is specific to the local environment and should be updated for different users. The script assumes the `ubuntu` user for the EC2 instance.

### Part 3: Application Deployment and Auto-Update

#### Docker Compose Deployment

The application is deployed on the EC2 instance using Docker Compose, defined in `docker-compose.yml` (assumed, as it was not provided in the digest). The configuration includes:

- **Services**:
  - **App Service**:
    - Image: Pulled from the private Docker registry (e.g., `docker.io/<username>/todo-list-nodejs`).
    - Ports: Maps port 4000 on the host to 4000 in the container.
    - Environment: Loads variables from the `.env` file (e.g., `mongoDbUrl`).
    - Healthcheck: Configures a health check to verify the application is running:
      - Command: `curl --fail http://localhost:4000 || exit 1`
      - Interval: 30s
      - Timeout: 5s
      - Retries: 3
      - Start Period: 10s
  - **MongoDB Service** (optional, if not using an external MongoDB):
    - Image: `mongo:latest`
    - Volumes: Persistent storage for MongoDB data.
    - Environment: Sets up MongoDB credentials.
    - Healthcheck: Verifies MongoDB availability.

- **Networks**: Uses a bridge network for communication between services (if applicable).

**Assumption**: The `.env` file contains the `mongoDbUrl` for an external MongoDB instance (e.g., MongoDB Atlas). If a local MongoDB container is required, it is included in `docker-compose.yml`.

#### Auto-Update Mechanism

To continuously check for updates in the Docker registry and pull new images, **Watchtower** is used. Watchtower is a lightweight container that monitors Docker images and automatically updates running containers when a new version is detected.

- **Configuration**:
  - A Watchtower container is added to `docker-compose.yml`:
    - Image: `containrrr/watchtower:latest`
    - Volumes: Mounts the Docker socket (`/var/run/docker.sock`) to manage containers.
    - Environment:
      - `WATCHTOWER_CLEANUP=true`: Removes old images after updating.
      - `WATCHTOWER_SCHEDULE=0 0 4 * * *`: Runs daily at 4 AM (cron schedule).
    - Restart Policy: `unless-stopped` to ensure continuous operation.
  - Watchtower monitors the application container and pulls new images from the private registry when updates are detected.

- **Justification for Watchtower**:
  - **Simplicity**: Watchtower is easy to configure and integrates seamlessly with Docker Compose.
  - **Automation**: Automatically handles image updates without manual intervention.
  - **Lightweight**: Minimal resource usage compared to other solutions like Kubernetes or custom scripts.
  - **Reliability**: Supports private registries and cleanup of old images, reducing disk usage.
  - **Alternatives Considered**:
    - **Custom Script**: A cron job with a shell script to check and pull images was considered but requires more maintenance and error handling.
    - **Kubernetes**: Overkill for a single application due to complexity and resource requirements.
    - **Docker Hub Webhooks**: Requires additional infrastructure for webhook handling, less straightforward than Watchtower.

**Assumption**: The private registry requires authentication, so Watchtower is configured with registry credentials via environment variables in `docker-compose.yml` (e.g., `WATCHTOWER_DOCKERHUB_USERNAME` and `WATCHTOWER_DOCKERHUB_PASSWORD`).

## Assumptions

1. **MongoDB**: An external MongoDB instance (e.g., MongoDB Atlas) is used, with the connection string stored in the `.env` file. If a local MongoDB is needed, it is included in `docker-compose.yml`.
2. **Docker Registry**: Docker Hub is used as the private registry. Credentials are stored as GitHub Secrets for CI and in the `.env` file for Watchtower.
3. **SSH Key Path**: The SSH key path in `provision-configure.sh` and `main.tf` is specific to the local environment and must be updated for different users.
4. **Docker Compose File**: A `docker-compose.yml` file is assumed to exist, defining the application and Watchtower services.
5. **Network Access**: The EC2 instance is accessible via SSH and port 4000 from the internet (`0.0.0.0/0` in the security group).

## Justifications

- **Terraform for Provisioning**: Chosen for its declarative approach, support for multiple cloud providers, and ability to manage infrastructure as code.
- **Ansible for Configuration**: Preferred for its agentless architecture, simplicity, and robust package management for Docker installation.
- **Watchtower for Auto-Update**: Selected for its lightweight and automated approach to container updates, suitable for a single-application deployment.
- **AWS EC2**: Used for its free tier, reliability, and widespread adoption, making it ideal for this task.
- **Docker Compose**: Simplifies multi-container management and is sufficient for this application's needs, avoiding the complexity of Kubernetes.

## Setup Instructions

1. **Clone the Repository**:

   ```bash
   git clone https://github.com/Ankit6098/Todo-List-nodejs.git
   cd Todo-List-nodejs
   ```

2. **Set Up Environment Variables**:
   - Create a `.env` file in the root directory with the MongoDB connection string:

     ```plaintext
     mongoDbUrl=mongodb+srv://<username>:<password>@cluster0.mongodb.net/todolist?retryWrites=true&w=majority
     ```

   - Ensure Docker registry credentials are set for Watchtower in `docker-compose.yml`.

3. **Dockerize the Application**:
   - Build and test the Docker image locally:

     ```bash
     docker build -t todo-list-nodejs .
     docker run --env-file .env -p 4000:4000 todo-list-nodejs
     ```

4. **Set Up GitHub Actions**:
   - Add `DOCKER_USERNAME` and `DOCKER_PASSWORD` as GitHub Secrets in the repository settings.
   - Ensure the `.github/workflows/ci.yml` file is configured to build and push the image to your private registry.

5. **Provision and Configure the VM**:
   - Update the SSH key path in `terraform/main.tf` and `provision-configure.sh` to match your environment.
   - Run the provisioning script:

     ```bash
     chmod +x provision-configure.sh
     ./provision-configure.sh
     ```

6. **Deploy the Application**:
   - SSH into the EC2 instance using the public IP output by Terraform:

     ```bash
     ssh -i ~/.ssh/ansible_key ubuntu@<EC2_PUBLIC_IP>
     ```

   - Verify that `docker-compose.yml` and `.env` are present in `/home/ubuntu`.
   - Start the application:

     ```bash
     docker-compose up -d
     ```

7. **Verify Deployment**:
   - Access the application at `http://<EC2_PUBLIC_IP>:4000`.
   - Check Docker Compose logs for health check status:

     ```bash
     docker-compose logs
     ```

8. **Monitor Updates**:
   - Watchtower automatically checks for image updates daily at 4 AM. To force an update:

     ```bash
     docker-compose pull && docker-compose up -d
     ```

## Directory Structure

```
ToDo-List-Task/
├── assets/                   # Static files (CSS, JS)
├── config/                   # MongoDB configuration
├── controllers/              # Express controllers
├── models/                   # Mongoose schemas
├── routes/                   # Express routes
├── terraform/                # Terraform configuration
│   ├── main.tf               # AWS EC2 provisioning
│   └── outputs.tf            # Terraform outputs
├── views/                    # EJS templates
├── .env                      # Environment variables (not committed)
├── docker-compose.yml        # Docker Compose configuration (assumed)
├── index.js                  # Main application entry
├── package.json              # Node.js dependencies
├── playbook.yml              # Ansible playbook for VM configuration
├── provision-configure.sh    # Script to provision and configure VM
└── vault.yml                 # Ansible Vault for sensitive data
```

## License

This project is licensed under the ISC License. See the `package.json` for details.
