pipeline {
    agent any

    environment {
        IMAGE_NAME = "apache-image"
        TAR_FILE = "${IMAGE_NAME}.tar"
        LOCAL_SAVE_PATH = "/shared_data/apache-image"
        DEPLOYG_HOST = "192.168.44.30"
        APACHE_USER = "apache"  // Define your SSH user here
    }

    stages {
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
    }

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
}
