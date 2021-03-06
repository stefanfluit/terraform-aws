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
    local interval_
    interval_="1"
    # The interval is for the amount of sleep between commands, to give you time to cancel if you feel like you have to. 

    case "${arg_}" in
        --read)
            read -p "PnD Binance Server - ${timestamp_}: Please enter value for ${missing_value}: " "${bash_var}"
            sleep "${interval_}"
            ;;

        --no-log)
            printf "PnD Binance Server - %s: %s\n" "${timestamp_}" "${2}"
            sleep "${interval_}"
            ;;

        --error)
            printf "PnD Binance Server - %s: %s\n" "${timestamp_}" "ERROR!" && \
            printf "PnD Binance Server - %s: %s\n" "${timestamp_}" "${2}" && \
            exit 1;
            ;;

        --exit)
            printf "PnD Binance Server - %s: %s\n" "${timestamp_}" "${2}" && \
            exit 0;
        ;;

        *)
            printf "PnD Binance Server - %s: %s\n" "${timestamp_}" "${arg_}"
            printf "PnD Binance Server - %s: %s\n" "${timestamp_}" "${arg_}" &>> "${LOG_LOC}"
            sleep "${interval_}"
    esac
}

check_bash_version() {
  if ((BASH_VERSINFO[0] < 4)); then 
      cli_log --error "Sorry, you need at least bash-4.0 to run this script." 
  else
      cli_log --no-log "Bash version is fine, proceeding.."
  fi
}

usage_() {
  cli_log "Run: ./run.sh --run --config-file=/path/to/config to create the infra in AWS."
  cli_log "Run: ./run.sh --destroy --config-file=/path/to/config.sh to destroy the infra in AWS."
  cli_log "Run: ./run.sh --reset --config-file=/path/to/config.sh to destroy and rebuild the infra in AWS."
  cli_log "Run: ./run.sh --test --config-file=/path/to/config.sh to test the repo local in Vagrant."
  cli_log "Run: ./run.sh --ssh-test --config-file=/path/to/config.sh to SSH in to the machine in Vagrant."
  cli_log --exit "Run: ./run.sh --destroy-test --config-file=/path/to/config.sh to destroy the machine in Vagrant."
}

install_aws() {
    local arg_
    arg_="${1}"
    case "${arg_}" in
      --run)
          if ! [ -x "$(command -v aws)" ]; then
            cli_log "Installing AWS CLI.."
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
            unzip /tmp/awscliv2.zip &>> "${LOG_LOC}"
            cd /tmp && sudo ./aws/install &>> "${LOG_LOC}"
            printf "%s\n" "aws_access_key_id=${AWS_ACCES}" >> /home/${SSH_USER}/.aws/credentials
            printf "%s\n" "aws_secret_access_key=${AWS_SECRET}" >> /home/${SSH_USER}/.aws/credentials
            printf "%s\n" "region=${AWS_REGION}" >> /home/${SSH_USER}/.aws/config && \
            cli_log --no-log "Done installing AWS CLI."
          else
            cli_log --no-log "AWS CLI is already installed, proceeding.."
          fi
          ;;

      --build)
          if ! [ -x "$(command -v aws)" ]; then
            cli_log "Installing AWS CLI.."
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
            unzip /tmp/awscliv2.zip &>> "${LOG_LOC}"
            cd /tmp && sudo ./aws/install &>> "${LOG_LOC}"
            printf "%s\n" "aws_access_key_id=${AWS_ACCES}" >> /home/vagrant/.aws/credentials
            printf "%s\n" "aws_secret_access_key=${AWS_SECRET}" >> /home/vagrant/.aws/credentials
            printf "%s\n" "region=${AWS_REGION}" >> /home/vagrant/.aws/config && \
            cli_log --no-log "Done installing AWS CLI."
          else
            cli_log --no-log "AWS CLI is already installed, proceeding.."
          fi
          ;;

      *)
          cli_log --error "Error in install_aws function."
  esac
}

install_virtualbox() {
  wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add - &>> "${LOG_LOC}"
  sudo add-apt-repository "deb [arch=amd64] http://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib" &>> "${LOG_LOC}"
  cli_log --no-log "Updating apt.." && sudo apt-get update &>> "${LOG_LOC}"
  cli_log --no-log "Installing VirtualBox.." && sudo apt-get install virtualbox -y &>> "${LOG_LOC}"
}

stamp_logfile() {
  local TOOL_TAG
  TOOL_TAG="${1}"
  # Print stamp to the log file
  local DATE_STAMP
  DATE_STAMP=$(date '+%d/%m/%Y %H:%M:%S')
  printf "%s ##################################### %s\n" "${TOOL_TAG}" "${DATE_STAMP}" &>> "${LOG_LOC}"
}

install_terraform() {
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add - &>> "${LOG_LOC}"
    sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" &>> "${LOG_LOC}"
    sudo apt-get update &>> "${LOG_LOC}" && sudo apt-get install terraform -y &>> "${LOG_LOC}"
}

check_installed() {
    local -a progrs=("${@}")
    if [[ $# -eq 0 ]]
    then
      cli_log --error "No arguments supplied. Syntax is like: check_installed <Program 1..> <Program 2..> <Etc..>"
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

check_update_param() {
  if [ "${SKIP_UPDATE}" = "enabled" ]; then
    cli_log "Skipping update.."
  else
    cli_log "Checking for update.."
    check_version
  fi
}

check_gitlab_key() {
    if [ -n "${GITLAB_API_KEY}" ]; then
      cli_log "Gitlab API Key found: ${GITLAB_API_KEY}"
    else
      cli_log --read "Gitlab API key" "GITLAB_API_KEY"
        if [[ -z "${GITLAB_API_KEY}" ]]; then
          cli_log --error "No input entered, exit script."
        else
          cli_log "Gitlab API key detected."
        fi
    fi
}

check_wan_ip() {
    if [ -n "${WAN_IP}" ]; then
      cli_log "WAN IP detected, IP is: ${WAN_IP}"
    else
      cli_log --read "What is your WAN IP: " "WAN_IP"
        if [[ -z "${WAN_IP}" ]]; then
          cli_log --error "No input entered, exit script."
        else
          cli_log "WAN IP detected."
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
        ssh-keygen -b 4096 -t rsa -f /home/${SSH_USER}/.ssh/id_rsa -C "${SSH_USER}" -N "" &>> /dev/null
          if [ -n "${SSH_KEY}" ]; then
            cli_log "SSH key found."
          else
            cli_log --error "Unknown error, exit."
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
        cli_log --error "No SSH username detected, exit script."
      else
        cli_log "SSH username detected, user is ${SSH_USER}"
      fi
  fi
}

check_region() {
  if [ -n "${AWS_REGION}" ]; then
    cli_log "AWS Region found: ${AWS_REGION}"
  else
    cli_log --read "AWS Region" "AWS_REGION"
      if [[ -z "${AWS_REGION}" ]]; then
        cli_log --error "No AWS Region detected, exit script."
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
        cli_log --error "No AWS Instance detected, exit script."
      else
        cli_log "AWS Instance type detected."
      fi
  fi
}

check_version() {
  local repo_url="https://raw.githubusercontent.com/stefanfluit/terraform-aws/master/VERSION"
  local version
  version=$(wget -O- -q ${repo_url} | grep -Eo '[0-9].{1,4}')
  local local_version
  local_version=$(cat "${DIR}/VERSION" | grep -Eo '[0-9].{1,4}')

  if (( $(bc <<<"${version} > ${local_version}") )); then
      cli_log "Updating script to ${version}.."
      cd "${DIR}" && git pull &>> "${LOG_LOC}"
      cli_log --exit "Done, please rerun the script."
  else
      cli_log "On latest version, proceeding.."
  fi
}

check_logfile() {
    local arg_
    arg_="${1}"
    case "${arg_}" in
      --run)
        if [ -f "${LOG_LOC}" ]; then
            cli_log "Log file found, proceeding."
        else 
            cli_log "Log file not found, creating.."
            touch "${LOG_LOC}"
        fi
        # Check directory
        if [ -d "${TMP_DIR}" ]; then
            cli_log "Log dir found, proceeding."
        else
            cli_log "Log dir not found, creating.."
            mkdir -pv "${TMP_DIR}" &>> "${LOG_LOC}"
        fi
        ;;

      --build)
        if [ -f "${LOG_LOC_BUILD}" ]; then
            cli_log "Log file found, proceeding."
        else 
            cli_log "Log file not found, creating.."
            touch "${LOG_LOC_BUILD}"
        fi
        # Check directory
        if [ -d "${TMP_DIR}" ]; then
            cli_log "Log dir found, proceeding."
        else
            cli_log "Log dir not found, creating.."
            mkdir -pv "${TMP_DIR}" &>> "${LOG_LOC}"
        fi
        ;;

      *)
          cli_log --error "Error in check_logfile function."
    esac
}

validate_config() {
  local config_file_param
  config_file_param="${1}"
  local config_file
  config_file=$(echo ${config_file_param} | grep -oP '=\K.*')
  local static_config_file="/home/$(whoami)/pnd-config.sh"

  if [ -f "${config_file}" ]; then
      cli_log --no-log "Sourcing passed config file.."
      source "${config_file}" &>> "${LOG_LOC}" && test_config
  else 
       if [ -f "${static_config_file}" ]; then
        cli_log --no-log "${static_config_file} detected."
        source "${static_config_file}" && test_config
      else 
        cli_log --no-log "No config file parameter detected, no personal config found, defaulting to config in repo.."
        source "${DIR}/src/config.sh" &>> "${LOG_LOC}" && test_config
      fi
  fi
}

test_config() {
    if [ -n "${GITLAB_API_KEY}" ]; then
        cli_log "Config seems to be valid."
    else
        cli_log --error "Config is not valid!"
    fi
}

run_init() {
    local arg_
    arg_="${1}"
    case "${arg_}" in
      --terraform)
          check_bash_version
          check_logfile --run
          check_update_param
          check_installed "terraform"
          install_aws --run
          check_gitlab_key
          check_ssh_key
          check_username
          check_region
          check_aws_instance_type
          ;;

      --vagrant)
          check_bash_version
          check_installed "virtualbox"
          check_logfile --run
          check_update_param
          check_gitlab_key
          ;;

      --build)
          check_bash_version
          check_logfile --build
          check_update_param
          ;;

      *)
          cli_log --error "Error in run_init script."
    esac
}

#####################################################################
# Vagrant functions
#####################################################################

run_test() {
  cli_log "Determining current state of the Box.."
  cd "${DIR}/src/testing" && vagrant status &>> "${LOG_LOC}"
  if [ "${?}" == "running" ]; then
    cli_log "Test build is running already, use ./run.sh --ssh-test to SSH into the machine."
  else
    cli_log "VM not running. Building.."
    cli_log "Adding your Username to user_data.yml.." && sed "s|sshuser|vagrant|g" "${DIR}"/templates/user_data.yml > /tmp/pnd-server/cloud-init.yml
    cli_log "Destroying previous box if existing, creating new box and rebuilding.."
    cd "${DIR}/src/testing" && destroy_vagrant --test && \
    cli_log "Building new box.." && vagrant up &>> "${LOG_LOC}"
    setup_vagrant_box --test && cli_log "Cleaning up.." rm -rf /tmp/pnd-server/cloud-init.yml && \
    cli_log "Test build is done, run ./run.sh --ssh-test to SSH into the machine."
  fi
}

run_build() {
  cli_log "Determining current state of the Box.."
  cd "${DIR}/src/testing/ci-vagrant" && vagrant status &>> "${LOG_LOC_BUILD}"
  if [ "${?}" == "running" ]; then
    cli_log "Build machine is running already, use ./run.sh --ssh-build to SSH into the machine."
  else
    cli_log "Build VM not running. Building.."
    cli_log "Adding Vagrant username to user_data.yml.." && sed "s|sshuser|vagrant|g" "${DIR}"/templates/user_data_build.yml > /tmp/pnd-server/cloud-init-ci.yml
    cli_log "Destroying previous box if existing, creating new box and rebuilding.."
    cd "${DIR}/src/testing/ci-vagrant" && destroy_vagrant --build && \
    cli_log "Building new box.." && vagrant up &>> "${LOG_LOC_BUILD}"
    setup_vagrant_box --build && cli_log "Cleaning up.." 
    cli_log "Test build is done, run ./run.sh --ssh-build to SSH into the machine."
  fi
}

setup_vagrant_box() {
    local arg_
    arg_="${1}"
    case "${arg_}" in
      --test)
        cli_log "Fetching key from server.."
        scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "${DIR}/src/testing/.vagrant/machines/binance-pnd/virtualbox/private_key" -P 2222  vagrant@127.0.0.1:/home/vagrant/.ssh/id_ed25519.pub "${TMP_DIR}/vagrant_key.pub" &>> "${LOG_LOC}"
        local ROOT_KEY_VAGRANT
        ROOT_KEY_VAGRANT=$(head -1 "${TMP_DIR}/vagrant_key.pub")
        cli_log "Adding fetched SSH pub key as Gitlab deploy key.."
        curl --request POST --header "PRIVATE-TOKEN: ${GITLAB_API_KEY}" --header "Content-Type:application/json" --data "{\"title\": \"pnd-server-vagrant\", \"key\": \"${ROOT_KEY_VAGRANT}\", \"can_push\": \"true\"}" "https://gitlab.com/api/v4/projects/24216317/deploy_keys" &>> "${LOG_LOC}"
        cli_log "Cloning repo to the test server.."
        vagrant_ssh --test-command "git clone --single-branch --branch master ${DEPLOY_REPO} /home/vagrant/repos/${BASENAME_REPO} --depth=1" &>> "${LOG_LOC}"
        cli_log "Fetching rest of the repo.."
        vagrant_ssh --test-command "cd /home/vagrant/repos/${BASENAME_REPO} && git fetch --depth=${GIT_DEPTH}" &>> "${LOG_LOC}"
        cli_log "Installing Python requirements.."
        vagrant_ssh --test-command "cd /home/vagrant/repos/${BASENAME_REPO} && pip3 install -r requirements.txt" &>> "${LOG_LOC}"
        if [ "${ENABLE_MONGO}" = "enabled" ]; then
          check_wan_ip && \
          cli_log "Adding your WAN IP to the MongoDB server.."
          ssh "${MONGO_SSH_USER}"@"${MONGO_HOST}" "sudo ufw allow from ${WAN_IP} to any port ${MONGO_PORT} && sudo ufw reload" &>> "${LOG_LOC}" && \
          cli_log "Done, firewall reloaded."
        else
          cli_log "Not adding test build to MongoDB, did not read parameter."
        fi
        ;;

      --build)
      # Need to change this to a static directory
        scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "${DIR}/src/testing/ci-vagrant/.vagrant/machines/binance-pnd-build/virtualbox/private_key" -P 2222  "/home/${SSH_USER}/Documents/scripts/terraform-aws/src/configs/build-config.sh" vagrant@127.0.0.1:/home/vagrant/repos/terraform-aws/src/build-config.sh >> "${LOG_LOC_BUILD}"
        vagrant_ssh --build-command "cd /home/vagrant/repos/terraform-aws/src && ./build-config.sh && cd /home/vagrant/repos/terraform-aws/src/testing/ci-vagrant && ./setup_aws.sh"
        vagrant_ssh --build-command "cd /home/vagrant/repos/terraform-aws && ./run.sh --run --config-file=/home/vagrant/repos/terraform-aws/src/build-config.sh" &>> "${LOG_LOC_BUILD}"
        local AWS_IP_BUILD
        AWS_IP_BUILD=$(grep -P 'ssh vagrant@*' "${LOG_LOC_BUILD}" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
        cli_log "IP to check status is: ${AWS_IP_BUILD}"
        if ssh -o StrictHostKeyChecking=no -i /home/fluit/.ssh/id_ed25519_terraform_aws_builder vagrant@${AWS_IP_BUILD} "test -e /home/vagrant/repos/pnd-binance/requirements.txt"; then
          cli_log "Build succesful!"
          export SUCCES_STATUS="0"
        else
          cli_log "Build NOT succesful!"
          destroy_build
          export SUCCES_STATUS="1"
        fi
        if [ "${SUCCES_STATUS}" = "0" ]; then
          cli_log "Destroying build.."
          destroy_build
        fi
        ;;

      *)
          cli_log "Error in setup_vagrant_box function."
    esac
}

destroy_build() {
  vagrant_ssh --build-command "cd /home/vagrant/repos/terraform-aws && ./run.sh --destroy --config-file=/home/vagrant/repos/terraform-aws/src/build-config.sh" &>> "${LOG_LOC_BUILD}"
  destroy_vagrant --build
}

vagrant_ssh() {
    local arg_
    arg_="${1}"
    local commands_
    commands_="${2}"

    case "${arg_}" in
      --test)
          cd "${DIR}/src/testing" && vagrant ssh
          ;;

      --build)
          cd "${DIR}/src/testing/ci-vagrant" && vagrant ssh
          ;;

      --test-command)
          cd "${DIR}/src/testing" && vagrant ssh -- -t "${commands_}" &>> "${LOG_LOC}"
          ;;

      --build-command)
          cd "${DIR}/src/testing/ci-vagrant" && vagrant ssh -- -t "${commands_}" &>> "${LOG_LOC_BUILD}"
          ;;

      *)
          cli_log "Error in vagrant_ssh function."
    esac
}

destroy_vagrant() {
    local arg_
    arg_="${1}"
    case "${arg_}" in
      --test)
        cli_log "Destroying Vagrant Test setup.."
        cd "${DIR}/src/testing" && vagrant destroy --force &>> "${LOG_LOC}"
        # Rm folder or Virtualbox will cry
        local VBOX_DIR
        VBOX_DIR="/home/${SSH_USER}/VirtualBox VMs/binance-pnd"
        if [ -d "${VBOX_DIR}" ]; then
          rm -rf "${VBOX_DIR}" &> /dev/null
          rm -rf /tmp/pnd-server/cloud-init.yml &> /dev/null
        fi
        cli_log "Destroyed Vagrant setup."
        ;;

      --build)
        cli_log "Destroying Vagrant Build setup.."
        cd "${DIR}/src/testing/ci-vagrant" && vagrant destroy --force &>> "${LOG_LOC_BUILD}"
        # Rm folder or Virtualbox will cry
        local VBOX_DIR
        VBOX_DIR="/home/${SSH_USER}/VirtualBox VMs/binance-pnd-build"
        if [ -d "${VBOX_DIR}" ]; then
          rm -rf "${VBOX_DIR}" &> /dev/null
          #rm -rf /tmp/pnd-server/cloud-init-ci.yml &> /dev/null
        fi
        cli_log "Destroyed Vagrant Build setup."
        ;;

      *)
          cli_log --error "Error in destroy_vagrant function."
    esac
}

#####################################################################
# Prometheus functions
#####################################################################

deploy_prometheus() {
  local repo_="https://github.com/stefanfluit/dockprom.git"
  local basename_repo
  basename_repo=$(basename "${repo_}" .git)
  local arg_
    arg_="${1}"
    case "${arg_}" in
      --build)
        local AWS_IP
        AWS_IP=$(cd "${DIR}"/terraform/deploy && terraform output | grep public-ip | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
        if getent group docker | grep -q "\b${SSH_USER}\b"; then
          cli_log --no-log "User is part of Docker group, proceeding."
        else
          cli_log "User is NOT a part of Docker group, exit."
          cli_log --exit "Command to fix: sudo usermod -a -G docker ${SSH_USER}"
        fi
        local LAN_IP
        LAN_IP="$(hostname -I | cut -d' ' -f1)"
        ## DOWNLOAD DOCKER/COMPOSE/SWARM
        if [ -x "$(which docker)" ]; then
          cli_log --no-log "Docker installed, proceeding.."
        else
          cli_log --no-log "Docker not found, installing.."
          curl -fsSL https://get.docker.com -o get-docker.sh &>> "${LOG_LOC}"
          sudo sh get-docker.sh &>> "${LOG_LOC}" && cli_log --no-log "Installed Docker." || cli_log --error "Could not install Docker."
        fi
        ## DOWNLOAD PROMETHEUS REPO
        # Repo with up-to-date Prometheus Docker stack
        if [ -d "/home/${SSH_USER}/${basename_repo}" ]; then
          docker-compose down &>> "${LOG_LOC}"
          rm -rf "/home/${SSH_USER}/${basename_repo}" &>> "${LOG_LOC}"
          cd "/home/${SSH_USER}" && git clone "${repo_}" &>> "${LOG_LOC}"
          docker network create monitor-net &>> "${LOG_LOC}"
        else
          cd "/home/${SSH_USER}/" && \
          git clone "${repo_}" &>> "${LOG_LOC}" && cli_log --no-log "Cloned Prometheus stack repo."
          docker network create monitor-net &>> "${LOG_LOC}"
        fi
        ## Add the server to the Prometheus configuration file..
        cli_log "Adding server IP to the Prometheus Scrape configurator.." && \
        rm -rf "/home/${SSH_USER}/${basename_repo}/prometheus/prometheus.yml" && \
        sed "s|serverip|${AWS_IP}|g" "${DIR}/templates/prometheus.yml" > "/home/${SSH_USER}/${basename_repo}/prometheus/prometheus.yml"
        cli_log --no-log "Adding Dashboard to Grafana.."
        cp "${DIR}"/templates/node_rev1.json /home/${SSH_USER}/${basename_repo}/grafana/provisioning/dashboards/node_rev1.json
        cli_log "Creating Docker environment.." && \
        cd "/home/${SSH_USER}/${basename_repo}" && \
        ADMIN_USER=admin ADMIN_PASSWORD=admin ADMIN_PASSWORD_HASH=JDJhJDE0JE91S1FrN0Z0VEsyWmhrQVpON1VzdHVLSDkyWHdsN0xNbEZYdnNIZm1pb2d1blg4Y09mL0ZP docker-compose up -d &>> "${LOG_LOC}"
        cli_log "The Grafana Dashboard is now accessible via: http://LAN_IP:3000, I think it is: http://${LAN_IP}:3000"
        cli_log "The username is: admin"
        cli_log "The password is: admin"
        ;;

      --destroy)
        cd "/home/${SSH_USER}/${basename_repo}" && docker-compose down &>> "${LOG_LOC}" && \
        cli_log --no-log "Done destroying the Compose stack."
        ;;

      *)
          cli_log --error "Error in deploy_prometheus function."
    esac
}
