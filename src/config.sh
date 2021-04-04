#!/usr/bin/env bash

# Git variables
export GITLAB_API_KEY=""                                                                                # Gitlab API key.
export DEPLOY_REPO="git@gitlab.com:Santralos/pnd-binance.git"                                           # The Git repo URL.
export BASENAME_REPO=$(basename "${DEPLOY_REPO}" .git)                                                  # Basename of the repo. 
export GIT_DEPTH="10"                                                                                   # The depth of the git clone to not fetch the whole repo, it's to big and will give errors. 
export SSH_USER="$(whoami)"                                                                             # This can be editted if you run this as a different user. 

# Alerting, only set what you want to use.
export DISCORD_WEBHOOK=""                                                                               # If this is set, the script will notify using Discord.
export SLACK_WEBHOOK=""                                                                                 # If this is set, the script will notify using Slack.
export SLACK_CHANNEL=""                                                                                 # Set this if the channel differantiate from the Slack default channel for the API key. 

# AWS
export AWS_REGION="ap-northeast-3"                                                                      # Change region here, it will use sed to replace it in the file of Terraform. Overriden by ~/.aws/config.
export AWS_PROFILE="default"                                                                            # Usually your AWS profile is default. 
export AWS_INSTANCE="t3.nano"                                                                           # The AWS instance, change here but don't go lower as it is not compatible with the projects region.
export AWS_COUNT="1"                                                                                    # Defines the amount of EC2 instances. Setting a value higher than 1 will break the script but not creation of VM's. Will add later, if needed.

# SSH Key
export SSH_KEY="/home/${SSH_USER}/.ssh/id_rsa.pub"                                                      # The path to pubkey, here to be changed if it does not equal to your username.
export SSH_KEY_OUTPUT=$(<${SSH_KEY})                                                                    # The pubkey without useless cat.
export SSH_ID_RSA=$(echo "${SSH_KEY}" | cut -f1,2 -d'.')                                                # Get the name of the id_rsa without the .pub part
export SSH_BUILD_KEY="/home/${SSH_USER}/.ssh/id_ed25519.pub"                                            # The path to pubkey, here to be changed if it does not equal to your username.

# No need to change
export TMP_DIR="/tmp/pnd-server"                                                                        # Just a tmp dir to put some files.
export VERSION_URL="https://raw.githubusercontent.com/stefanfluit/terraform-aws/master/VERSION"         # A version file in the repo to check if you're on the latest.
export LOG_LOC="/home/${SSH_USER}/.pnd-binance-builder.log"                                             # The log location for this script.
export LOG_LOC_BUILD="${LOG_LOC}.build"                                                                 # The log location for the build script.

# MongoDB
export ENABLE_MONGO=""                                                                                  # Set to 'enabled' and fill in the variables below to add the EC2 IP to the the MongoDB server UFW firewall and allow traffic on MONGO_PORT
export MONGO_HOST=""                                                                                    # The Mongo host.
export MONGO_SSH_USER=""                                                                                # The user you use to log in to the Mongo host.
export MONGO_PORT="27017"                                                                               # Mongo default port

# Vagrant options
export VAGRANT_EXPERIMENTAL="cloud_init,disks"                                                          # Enable experimental for cloud-init

# Other variables
export WAN_IP=$(dig TXT +short o-o.myaddr.l.google.com @ns1.google.com | awk -F'"' '{ print $2}')       # Attempt to get your IP for the Vagrant file > gitlab
export SKIP_UPDATE="disabled"                                                                           # set to 'enabled' to skip update.

# Build variables, or if you didn't configure AWS CLI yet.
export AWS_SECRET=""                                                                                    # AWS Secret Key
export AWS_ACCES=""                                                                                     # AWS Acces Key