#!/usr/bin/env bash

# Change before running
export GITLAB_API_KEY=""

# Sets SSH user to your name, or keep it like this. In this situation it will use your TTY user.
export SSH_USER="$(whoami)"

# Alerting
export DISCORD_WEBHOOK=""
export SLACK_WEBHOOK=""
export SLACK_CHANNEL=""

# AWS
export AWS_REGION="ap-northeast-3"
export AWS_PROFILE="default"
export AWS_INSTANCE="t3.nano"

# SSH Key
export SSH_KEY="/home/${SSH_USER}/.ssh/id_rsa.pub"
export SSH_KEY_OUTPUT=$(<${SSH_KEY})
export SSH_ID_RSA=$(echo "${SSH_KEY}" | cut -f1,2 -d'.')

# No need to change
export TMP_DIR="/tmp/pnd-server"
export VERSION_URL="https://raw.githubusercontent.com/stefanfluit/terraform-aws/master/VERSION"
export LOG_LOG="/home/${SSH_USER}/.pnd-binance-builder.log"