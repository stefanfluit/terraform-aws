#!/usr/bin/env bash

export GITLAB_API_KEY="1ot4ZTqqn7EmzG-Dc23R"
export SSH_USER="frank"
export TMP_DIR="/tmp/pnd-server"

# SSH
# Provide a path to a pub key, e.g., /home/fluit/.ssh/id_rsa.pub or leave empty to create a new one.
export SSH_KEY="/home/fluit/.ssh/id_rsa.pub"
export SSH_KEY_OUTPUT=$(<${SSH_KEY})
export SSH_ID_RSA=$(echo "${SSH_KEY}" | cut -f1,2 -d'.')