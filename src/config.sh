#!/usr/bin/env bash

# Change before running
export GITLAB_API_KEY=""

# Sets SSH user to your name, or keep it like this. In this situation it will use your TTY user.
export SSH_USER="$(whoami)"
export DISCORD_WEBHOOK=""

# SSH
# Provide a path to a pub key, e.g., /home/fluit/.ssh/id_rsa.pub or leave empty to create a new one.
export SSH_KEY="/home/${SSH_USER}/.ssh/id_rsa.pub"
export SSH_KEY_OUTPUT=$(<${SSH_KEY})
export SSH_ID_RSA=$(echo "${SSH_KEY}" | cut -f1,2 -d'.')

# No need to change
export TMP_DIR="/tmp/pnd-server"