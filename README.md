## Project Description



## Prerequisites

1. VM1: A dedicated Jenkins server for orchestrating the CI/CD pipeline.
2. VM2: A Gogs server for hosting Git repositories.
3. VM3: To instal Apache Web Server  (ensure the service is up and running)

## Setup

1. **Create users named "DevTeam" and "OpsTeam" on VM3**:
- checkers.sh bash script:
    #### Function takes a parameter with the username and returns 0 if the requested user is the same as the current user. Otherwise, it returns 1.
        function checkUser {
            RUSER=${1}
            [ ${RUSER} == ${USER} ] && return 0
            return 1 
        }
    #### Function takes a parameter with the username and returns 0 if the user does not exist. Otherwise, it returns 1.
        function userExist {
            NUSER=${1}
            cat /etc/passwd | grep -w ${NUSER} > /dev/null 2>&1
            [ ${?} -ne 0 ] && return 0
            return 1
        }
    #### Function takes a parameter with the group name and returns 0 if the group does not exist. Otherwise, it returns 1.
        function groupExist {
            NGRP=${1}
            cat /etc/group | grep -w ${NGRP} > /dev/null 2>&1
            [ ${?} -ne 0 ] && return 0
            return 1
        }

- CreateUsers.sh bash script:
    #### Check if the script is executed with root privileges:
   ```bash
    source ./checkers.sh
    checkUser "root"
    if [ $? -ne 0 ]; then
    echo "Script must be executed with sudo privileges"
    exit 1
    fi
    ```
    #### Define the list of users to be created
   ```bash
    users=("Devo" "Testo" "Prodo")
    ```
    #### Initialize arrays to track created users and groups
    ```bash
    created_users=()
    created_group=""
    ```
    #### Check and create users if they do not exist
   ```bash 
    for user in "${users[@]}"; do
    userExist "$user"
    if [ $? -eq 0 ]; then
        echo "User '$user' already exists"
    else
        useradd "$user"
        echo "User '$user' created"
        created_users+=("$user")
    fi
    done
    ```
    #### Check and create the group "deployG" if it does not exist
   ```bash
    groupExist "deployG"
    if [ $? -eq 0 ]; then
    echo "Group 'deployG' already exists"
    created_group="deployG"
    else
    groupadd deployG
    echo "Group 'deployG' created"
    created_group="deployG"
    fi
    ```
    #### Add users to the group if they are not already members
    ```bash
    for user in "${created_users[@]}"; do
    if groups "$user" | grep -q "\b$created_group\b"; then
        echo "User '$user' is already a member of group '$created_group'"
    else
        usermod -aG "$created_group" "$user"
        echo "User '$user' added to group '$created_group'"
    fi
    done
    echo "Users '${created_users[@]}' have been added to group '$created_group'"
    exit 0
    ```

2. **Fetch a list of users from the "deployG" group on VM3**:
- checkers.sh bash script:
    #### Function to check if script is executed with root privileges
        function checkUser {
            RUSER=${1}
            [ ${RUSER} == ${USER} ] && return 0
            return 1
        }

    #### Function to check if group exists
        function groupExist {
            NGRP=${1}
            grep -q "^${NGRP}:" /etc/group
            return $?
        }

- NotGroupMembers.sh bash script:
    #### Check if script is executed with root privileges
   ```bash
    checkUser "root"
    if [ $? -ne 0 ]; then
        echo "Script must be executed with sudo privilege"
        exit 1
    fi
    ```
    #### Check if the group "deployG" exists
   ```bash
    groupExist "deployG"
    if [ $? -ne 0 ]; then
        echo "Group 'deployG' does not exist"
        exit 2
    fi
    ```
    #### Get the list of group members
   ```bash
    GROUP_MEMBERS=$(groupmems -l -g deployG)
    ```
    #### Get the list of all users with UID >= 1000
   ```bash
    ALL_USERS=$(awk -F: '$3 >= 1000 { print $1 }' /etc/passwd)
    ```
    #### Filter out users who are not in GROUP_MEMBERS
   ```bash
    for user in $ALL_USERS; do
        if ! echo "$GROUP_MEMBERS" | grep -qw "$user"; then
            echo "$user"
        fi
    done
    exit 0
    ```

3. **Creating a Git repository on Gogs**:
    - Create a Git repository in Gogs.
    - Push all files (Ansible playbook, Jenkinsfile, Dockerfile) to that repository. 

4. **Gogs Integration with Jenkins**:
    #### In Gogs Instance
    - Generate Access Token from the account settings. 
    #### In Jenkins web console
    - Install Gogs Plugin.

5. **Detect a code commit from Github repo to trigger the Jenkins pipeline**:

    #### In Gogs Instance
    - Add a Webhook in the repo from the repo settings.

6. **Dockerfile**:
    - Build a Docker image using the provided Dockerfile, then save it locally using the command docker save <image_name> > <image_name>.tar, and archive the tar file.

7. **Jenkins Configuration**:

    #### To Make the ansible playbook reach VM3
    - Add a credential of kind "SSH Username with private key" include a private key which its public key is on VM3.
    - Add a credential of kind "Secret text" include the VM3 apache user sudo password.

    #### To send the email notification successfully
    - Install (Email Extension, Email Extension Template) Plugins.
    - Add a credential of kind "Username with password" include the app password which generated in email app (Gmail).
   
## Ansible Playbook to deploy Apache server

 ### Configure the inventory file:
   ```ini
   [apache_hosts]
    192.168.44.30
   ```
 ### Upade the ansible configuration file:
   ```ini
    [defaults]
    remote_user = apache
    inventory = ./inventory 

    [privilege_escalation]
    become = true
  ```
 ### Install the role with ansible-galaxy command:
    ansible-galaxy init roles/webserver-role
 ### Ansible Playbook (WebServerSetup.yml)
    - name: Playbook to install and configure Apache HTTP Server on VM3
    hosts: webservers
    gather_facts: no
    roles:  
        - webserver-role
 ### Ansible Playbook 
    - name: Install Apache on VM3
    hosts: apache_hosts
    gather_facts: no

    tasks:
        - name: Install Apache web server
        package:
            name: httpd  # Package name for Apache on CentOS
            state: present  # Ensure the package is present

        - name: Start Apache service and enable it on boot
        service:
            name: httpd  # Service name for Apache on CentOS
            state: started
            enabled: yes

        - name: Check if Apache service is enabled
        command: systemctl is-enabled httpd
        register: apache_enabled
        ignore_errors: true  # Ignore errors in case the service is not enabled

        - name: Print Apache service status
        debug:
            msg: "Apache service is {{ 'enabled' if apache_enabled.rc == 0 else 'not enabled' }}"

## Jenkins File to deploy the Ansible Playbook

#### Enviroment Variables
    agent any

    environment {
        IMAGE_NAME = "apache-image"
        TAR_FILE = "${IMAGE_NAME}.tar"
        LOCAL_SAVE_PATH = "/shared_data/apache-image"
        DEPLOYG_HOST = "192.168.44.30"
        APACHE_USER = "apache"  // Define your SSH user here
    }

#### First stage: Run Ansible playbook
    stage('Run Ansible Playbook') {
        steps {
            withCredentials([sshUserPrivateKey(credentialsId: 'apache-vm3', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                script {
                    sh """
                    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook InstallApache.yml --private-key=${SSH_KEY}
                    """
                }
            }
        }
    }

#### Second stage: Build, save ,and tar Docker Image
       stage('Build Docker Image') {
            steps {
                script {
                    // Build the Docker image
                    sh "docker build -t ${IMAGE_NAME} ."
                }
            }
        }

        stage('Save Docker Image Locally') {
            steps {
                script {
                    // Save the Docker image to a tar file locally
                    sh "docker save ${IMAGE_NAME} > ${LOCAL_SAVE_PATH}/${TAR_FILE}"
                }
            }
        }

        stage('Create Tar Archive') {
            steps {
                script {
                    // Create a tar archive of the saved Docker image tar file
                    sh "tar -cvf ${LOCAL_SAVE_PATH}/${TAR_FILE}.tar -C ${LOCAL_SAVE_PATH} ${TAR_FILE}"
                }
            }
        }

#### Send email notification 
    post {
            always {
                script {
                    def status = currentBuild.result ?: 'SUCCESS'
                    def subject = "Pipeline ${status} - ${env.JOB_NAME} #${env.BUILD_NUMBER}"
                    def statusColor = status == 'SUCCESS' ? '#27ae60' : '#c0392b'

                    // Get the list of users in the "deployG" group
                    def usersInDeployG = ""
                    withCredentials([sshUserPrivateKey(credentialsId: 'apache-vm3', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                        usersInDeployG = sh(
                            script: """
                            ssh -i ${SSH_KEY} ${SSH_USER}@${DEPLOYG_HOST} "grep '^deployG:' /etc/group | cut -d: -f4"
                            """,
                            returnStdout: true
                        ).trim()
                    }

                    // Send email notification
                    emailext (
                        to: 'mohamedmagdyy840@gmail.com',
                        subject: subject,
                        body: """
                            <html>
                            <head>
                                <style>
                                    body {
                                        font-family: Arial, sans-serif;
                                        line-height: 1.6;
                                        color: #2c3e50;
                                    }
                                    h2 {
                                        color: #2980b9;
                                        border-bottom: 2px solid #2980b9;
                                        padding-bottom: 5px;
                                    }
                                    p {
                                        margin: 5px 0;
                                    }
                                    .status {
                                        color: ${statusColor};
                                        font-weight: bold;
                                    }
                                    .date {
                                        color: #8e44ad;
                                        font-weight: bold;
                                    }
                                    .path {
                                        color: #e67e22;
                                        font-weight: bold;
                                    }
                                    .users {
                                        color: #3498db;
                                        font-weight: bold;
                                    }
                                </style>
                            </head>
                            <body>
                                <h2>Pipeline Execution Status</h2>
                                <p>Status: <span class="status">${status}</span></p>

                                <h2>Users in "deployG" Group</h2>
                                <p class="users">${usersInDeployG}</p>

                                <h2>Date and Time of Execution</h2>
                                <p class="date">${new Date()}</p>

                                <h2>Path to Docker Image</h2>
                                <p class="path">${LOCAL_SAVE_PATH}/${TAR_FILE}</p>
                            </body>
                            </html>
                        """,
                        mimeType: 'text/html',
                        from: 'jenkins@example.com',
                        replyTo: 'jenkins@example.com'
                    )
                }
            }
        }


