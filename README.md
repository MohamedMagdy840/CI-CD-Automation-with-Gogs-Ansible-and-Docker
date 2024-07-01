# Project: CI/CD Automation with Jenkins, Gogs, Ansible, and Docker

## Project Overview

This project aims to automate CI/CD processes using Jenkins for pipeline orchestration, Gogs for Git repository management, Ansible for configuration management, and Docker for containerization. The setup involves provisioning three VMs: VM1 for Jenkins, VM2 for Gogs, and VM3 for Apache server deployment.

### VM Setup Details

1. **VM1: Jenkins Server**
   - **IP Address:** 192.168.44.10
   - **Port:** 8080
   - **Username:** VM1

2. **VM2: Gogs Server**
   - **IP Address:** 192.168.44.20
   - **Port:** 3000
   - **Username:** VM2

3. **VM3: Apache Server**
   - **IP Address:** 192.168.44.10
   - **Port:** 8080
   - **Username:** apache

### Project Components

1. **User Management on VM3**

   - Use the `CreateUsers.sh` script to create users (Devo, Testo, Prodo) on VM3.
   - Add these users to the "deployG" group for centralized access control.

2. **Gogs Integration with Jenkins**

   - Configure webhooks in Gogs to trigger Jenkins pipelines upon code commits.
   - Jenkins monitors the Gogs repository for changes and initiates CI/CD workflows.

3. **Git Repository Setup on Gogs**

   - Create a Git repository on Gogs containing:
     - `InstallApache.yml`: Ansible playbook for Apache installation on VM3.
     - `NotGroupMembers.sh`: Bash script to list users not in the "deployG" group on VM3.

4. **CI/CD Pipeline Configuration**

   - Define a `Jenkinsfile` with stages:
     - **Stage 1: Ansible Execution**
       - Runs `InstallApache.yml` to install and configure Apache on VM3.
     - **Stage 2: Docker Image Build and Archive**
       - Builds a Docker image using a specified Dockerfile.
       - Saves the Docker image locally as `<image_name>.tar`.
       - Archives the Docker image tar file.
     - **Stage 3: Email Notification**
       - Sends email notifications on pipeline status.
       - Includes:
         - List of users in the "deployG" group.
         - Date and time of pipeline execution.
         - Path to the Docker image tar file.
