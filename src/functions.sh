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
          cli_log "Input detected, API key is: ${GITLAB_API_KEY}"
        fi
    fi
}

check_wan_ip() {
    if [ -n "${WAN_IP}" ]; then
      cli_log "WAN IP detected, IP is: ${WAN_IP}"
    else
      cli_log --read "What is your WAN IP: " "WAN_IP"
        if [[ -z "${WAN_IP}" ]]; then
          cli_log "No input entered, exit script."
          exit 1;
        else
          cli_log "WAN IP detected, IP is: ${WAN_IP}"
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

check_region() {
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
  # /tmp/pnd-server/cloud-init.yml
    cli_log "VM not running. Building.."
    cli_log "Adding your Username to user_data.yml.." && sed "s|sshuser|vagrant|g" "${DIR}"/templates/user_data.yml > /tmp/pnd-server/cloud-init.yml
    cli_log "Destroying previous box if existing, creating new box and rebuilding.."
    cd "${DIR}/src/testing" && destroy_vagrant && \
    cli_log "Building new box.." && vagrant up &> "${LOG_LOC}"
    setup_vagrant_box && cli_log "Cleaning up.." rm -rf /tmp/pnd-server/cloud-init.yml && \
    cli_log "Test build is done, run ./run.sh --ssh-test to SSH into the machine."
  fi
}

vagrant_ssh() {
  cd "${DIR}/src/testing" && vagrant ssh
}

destroy_vagrant() {
  cli_log "Destroying Vagrant setup.."
  cd "${DIR}/src/testing" && vagrant destroy --force &> "${LOG_LOC}"
  # Rm folder or Virtualbox will cry
  local VBOX_DIR
  VBOX_DIR="/home/${SSH_USER}/VirtualBox VMs/binance-pnd"
  if [ -d "${VBOX_DIR}" ]; then
    rm -rf "${VBOX_DIR}" &> /dev/null
    rm -rf /tmp/pnd-server/cloud-init.yml &> /dev/null
  fi
  cli_log "Destroyed Vagrant setup."
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
  # Check directory
  if [ -d "/path/to/dir" ]; then
    cli_log "Log dir found, proceeding."
  else
    cli_log "Log dir not found, creating.."
    mkdir -pv "${TMP_DIR}" &> "${LOG_LOC}"
  fi
}

vagrant_command() {
  local command_
  command_="${1}"
  cd "${DIR}/src/testing" && vagrant ssh -- -t "${command_}" &> "${LOG_LOC}"
}

setup_vagrant_box() {
  cli_log "Fetching key from server.."
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "${DIR}/src/testing/.vagrant/machines/binance-pnd/virtualbox/private_key" -P 2222  vagrant@127.0.0.1:/home/vagrant/.ssh/id_ed25519.pub "${TMP_DIR}/vagrant_key.pub" &> "${LOG_LOC}"
  local ROOT_KEY_VAGRANT
  ROOT_KEY_VAGRANT=$(head -1 "${TMP_DIR}/vagrant_key.pub")
  cli_log "Adding fetched SSH pub key as Gitlab deploy key.."
  curl --request POST --header "PRIVATE-TOKEN: ${GITLAB_API_KEY}" --header "Content-Type:application/json" --data "{\"title\": \"pnd-server-vagrant\", \"key\": \"${ROOT_KEY_VAGRANT}\", \"can_push\": \"true\"}" "https://gitlab.com/api/v4/projects/24216317/deploy_keys" &> "${LOG_LOC}"
  cli_log "Cloning repo to the test server.."
  vagrant_command "git clone --single-branch --branch master ${DEPLOY_REPO} /home/vagrant/repos/${BASENAME_REPO} --depth=1" &> "${LOG_LOC}"
  cli_log "Fetching rest of the repo.."
  vagrant_command "cd /home/vagrant/repos/${BASENAME_REPO} && git fetch --depth=${GIT_DEPTH}" &> "${LOG_LOC}"
  cli_log "Installing Python requirements.."
  vagrant_command "cd /home/vagrant/repos/${BASENAME_REPO} && pip3 install -r requirements.txt" &> "${LOG_LOC}"
  if [ "${ENABLE_MONGO}" = "enable" ]; then
    check_wan_ip && \
    cli_log "Adding your WAN IP to the MongoDB server.."
    ssh "${MONGO_SSH_USER}"@"${MONGO_HOST}" "sudo ufw allow from ${WAN_IP} to any port ${MONGO_PORT} && sudo ufw reload" &> "${LOG_LOC}" && \
    cli_log "Done, firewall reloaded."
  else
    cli_log "Not adding test build to MongoDB, did not read parameter."
  fi
}

run_init() {
    local arg_
    arg_="${1}"
    case "${arg_}" in
      --terraform)
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
          ;;
      --vagrant)
          check_logfile
          check_version
          check_gitlab_key
          ;;
      *)
          cli_log "Error in run_init script."
    esac
}