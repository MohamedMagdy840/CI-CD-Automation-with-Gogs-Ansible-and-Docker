#!/bin/bash

# Function takes a parameter with the username and returns 0 if the requested user is the same as the current user.
# Otherwise, it returns 1.
function checkUser {
    RUSER=${1}
    [ ${RUSER} == ${USER} ] && return 0
    return 1 
}

# Function takes a parameter with the username and returns 0 if the user does not exist.
# Otherwise, it returns 1.
function userExist {
    NUSER=${1}
    cat /etc/passwd | grep -w ${NUSER} > /dev/null 2>&1
    [ ${?} -ne 0 ] && return 0
    return 1
}

# Function takes a parameter with the group name and returns 0 if the group does not exist.
# Otherwise, it returns 1.
function groupExist {
    NGRP=${1}
    cat /etc/group | grep -w ${NGRP} > /dev/null 2>&1
    [ ${?} -ne 0 ] && return 0
    return 1
}

############# Create users named "Devo", "Testo", and "Prodo" on VM3 #############
## Exit codes:
#    0: Success
#    1: Script is executed without sufficient privileges
#    2: One or more users already exist
#    3: Group already exists

# Check if the script is executed with root privileges
checkUser "root"
if [ $? -ne 0 ]; then
  echo "Script must be executed with sudo privileges"
  exit 1
fi

# Define the list of users to be created
users=("Devo" "Testo" "Prodo")

# Initialize arrays to track created users and groups
created_users=()
created_group=""

# Check and create users if they do not exist
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

# Check and create the group "deployG" if it does not exist
groupExist "deployG"
if [ $? -eq 0 ]; then
  echo "Group 'deployG' already exists"
  created_group="deployG"
else
  groupadd deployG
  echo "Group 'deployG' created"
  created_group="deployG"
fi

# Add users to the group if they are not already members
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
