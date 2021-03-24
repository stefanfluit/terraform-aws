#!/usr/bin/env bash

# Finding the directory we're in
declare DIR
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

cli_log() {
    local timestamp_
    timestamp_=$(date +"%H:%M")
    local arg_
    arg_="${1}"
    printf "PnD Binance Server - %s: %s\n" "${timestamp_}" "${arg_}"
}

install_aws() {
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    aws configure
}

install_terraform() {
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
    sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
    sudo apt-get update && sudo apt-get install terraform -y
}

check_installed() {
    local -a progrs=("${@}")
    if [[ $# -eq 0 ]]
    then
      cli_log "No arguments supplied. Syntax is like: check_installed <Program 1..> <Program 2..> <Etc..>"
      exit 1;
    fi
    for prog in "${progrs[@]}"; do
      if ! [[ -x "$(command -v "${prog}")" ]]; then
        cli_log "Program ${prog} is not installed, installing.."
        install_${prog}
      else
        cli_log "Program ${prog} is installed, proceeding.."
      fi
    done
}

check_gitlab_key() {
    if [ -n "${GITLAB_API_KEY}" ]; then
      cli_log "Gitlab API Key found: ${GITLAB_API_KEY}"
    else
      cli_log "Set Gitlab API key: " && read -s GITLAB_API_KEY
        if [[ -z "${GITLAB_API_KEY}" ]]; then
          cli_log "No input entered, exit script."
          exit 1;
        else
          cli_log "Input detected, API key is ${GITLAB_API_KEY}"
        fi
    fi
}

check_ssh_key() {
  if [ -n "${SSH_KEY}" ]; then
    cli_log "SSH key found."
  else
    cli_log "Set SSH key: " && read -s SSH_KEY
      if [[ -z "${SSH_KEY}" ]]; then
        cli_log "No SSH key detected, creating one."
        ssh-keygen -b 4096 -t rsa -f /home/${SSH_USER}/.ssh/id_rsa -C "${SSH_USER}" -N "" &> /dev/null
          if [ -n "${SSH_KEY}" ]; then
            cli_log "SSH key found."
          else
            cli_log "Unknown error, exit." && exit 1;
          fi
      else
        cli_log "SSH key found."
      fi
  fi
}

send_alert() {
  local message_
  message_="${1}"
  if [ -n "${DISCORD_WEBHOOK}" ]; then
    cli_log "Discord webhook URL found, sending alert."
    cd "${DIR}/src/alerting" && ./discord.sh --webhook-url="${DISCORD_WEBHOOK}" --text "${message_}" --username "${SSH_USER}"
  else
    cli_log "No Discord URL entered, no alerting possible."
  fi
}

check_username() {
  if [ -n "${SSH_USER}" ]; then
    cli_log "SSH username found: ${SSH_USER}"
  else
    cli_log "Set SSH username: " && read -s SSH_USER
      if [[ -z "${SSH_USER}" ]]; then
        cli_log "No SSH username detected, exit script."
        exit 1;
      else
        cli_log "SSH username, user is ${SSH_USER}"
      fi
  fi
}

run_init() {
    check_installed "aws" "terraform"
    check_gitlab_key
    check_ssh_key
    check_username
}
