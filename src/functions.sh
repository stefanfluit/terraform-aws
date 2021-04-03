#!/usr/bin/env bash

cli_log() {
    local timestamp_
    timestamp_=$(date +"%H:%M")
    local arg_
    arg_="${1}"
    local missing_value
    missing_value="${2}"
    local bash_var
    bash_var="${3}"

    case "${arg_}" in
        --read)
            read -p "PnD Binance Server - ${timestamp_}: Please enter value for ${missing_value}: " "${bash_var}" 
            ;;

        --no-log)
            printf "PnD Binance Server - %s: %s\n" "${timestamp_}" "${2}" 
            ;;

        *)
            printf "PnD Binance Server - %s: %s\n" "${timestamp_}" "${arg_}"
            printf "PnD Binance Server - %s: %s\n" "${timestamp_}" "${arg_}" >> "${LOG_LOC}"
    esac
}

install_aws() {
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    aws configure
}

stamp_logfile() {
  local TOOL_TAG
  TOOL_TAG="${1}"
  # Print stamp to the log file
  local DATE_STAMP
  DATE_STAMP=$(date '+%d/%m/%Y %H:%M:%S')
  printf "%s ##################################### %s\n" "${TOOL_TAG}" "${DATE_STAMP}" >> "${LOG_LOC}"
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
      cli_log --read "Gitlab API key" "GITLAB_API_KEY"
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
    cli_log --read "SSH public key" "SSH_KEY"
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

status_to_slack() {
    local _text="${1}"
    local _webhook="https://hooks.slack.com/services/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"
    /bin/bash "${DIR}/src/alerting/send_slack.sh" -t "${SSH_USER}" -b "${_text}" -c "${SLACK_CHANNEL}" -u "${SLACK_WEBHOOK}"
}

send_alert() {
    local message_
    message_="${1}"

    if [ -n "${DISCORD_WEBHOOK}" ]; then
        cli_log "Discord webhook URL found, sending alert."
        cd "${DIR}/src/alerting" && ./discord.sh --webhook-url="${DISCORD_WEBHOOK}" --text "${message_}" --username "${SSH_USER}"
    else
        cli_log "Sending alert with Slack."
            if [ -n "${SLACK_WEBHOOK}" ]; then
                cli_log "Slack webhook URL found, sending alert."
                send_slack "${message_}"
            else
                cli_log "No valid alerting configuration found."
            fi
    fi
}

check_username() {
  if [ -n "${SSH_USER}" ]; then
    cli_log "SSH username found: ${SSH_USER}"
  else
    cli_log --read "SSH username" "SSH_USER"
      if [[ -z "${SSH_USER}" ]]; then
        cli_log "No SSH username detected, exit script."
        exit 1;
      else
        cli_log "SSH username, user is ${SSH_USER}"
      fi
  fi
}

check_aws_region() {
  if [ -n "${AWS_REGION}" ]; then
    cli_log "AWS Region found: ${AWS_REGION}"
  else
    cli_log --read "AWS Region" "AWS_REGION"
      if [[ -z "${AWS_REGION}" ]]; then
        cli_log "No AWS Region detected, exit script."
        exit 1;
      else
        cli_log "AWS Region detected."
      fi
  fi
}

check_aws_instance_type() {
  if [ -n "${AWS_INSTANCE}" ]; then
    cli_log "AWS Instance type: ${AWS_INSTANCE}"
  else
    cli_log --read "AWS Instance type" "AWS_INSTANCE"
      if [[ -z "${AWS_INSTANCE}" ]]; then
        cli_log "No AWS Instance detected, exit script."
        exit 1;
      else
        cli_log "AWS Instance type detected."
      fi
  fi
}

check_aws_region_config() {
  if sed -n "/${AWS_PROFILE}{n;p;}" ~/.aws/config | grep -e ${AWS_REGION}; then
    cli_log "Regions match, proceeding."
  else
    cli_log "AWS Regions don't match, aws will override with the default set in ~/.aws/config for profile ${AWS_{PROFILE}."
  fi
}

run_test() {
  cli_log "Determining current state of the Box.."
  cd "${DIR}/src/testing" && vagrant status &> "${LOG_LOC}"
  if [ "${?}" == "running" ]; then
    cli_log "Test build is running already, use ./run.sh --ssh-test to SSH into the machine."
  else
    cli_log "Test build not build yet. Building.."
    cd "${DIR}/src/testing" && vagrant up &> "${LOG_LOC}" && \
    cli_log "Done! Run ./run.sh --ssh-test to SSH into the machine." || cli_log "Something went wrong building the test build. Please check logs at ${LOG_LOC}." && exit 1;
  fi
}

vagrant_ssh() {
  cd "${DIR}/src/testing" && vagrant ssh
}

destroy_vagrant() {
  cd "${DIR}/src/testing" && vagrant destroy --force &> /dev/null
}

check_version() {
  local repo_url="https://raw.githubusercontent.com/stefanfluit/terraform-aws/master/VERSION"
  local version
  version=$(wget -O- -q ${repo_url} | grep -Eo '[0-9].{1,4}')
  local local_version
  local_version=$(cat "${DIR}/VERSION" | grep -Eo '[0-9].{1,4}')

  if (( $(bc <<<"${version} > ${local_version}") )); then 
      cli_log "I reccomend you do a git pull in the repo directory to fetch latest additions."
  else
      cli_log "On latest version, proceeding.."
  fi
}

check_logfile() {
  if [ -f "${LOG_LOC}" ]; then
      cli_log "Log file found, proceeding."
  else 
      cli_log "Log file not found, creating.."
      touch "${LOG_LOC}"
  fi
}

run_init() {
    check_logfile
    check_version
    check_installed "aws" "terraform"
    check_gitlab_key
    check_ssh_key
    check_username
    check_region
    check_aws_region
    check_aws_region_config
    check_aws_instance_type
}
