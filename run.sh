#!/usr/bin/env bash

# Finding the directory we're in
declare DIR
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

declare config_file
config_file="${2}"

if [ -f "${config_file}" ]; then
    cli_log "${config_file} exists."
    source "${config_file}"
else 
    cli_log "${config_file} does not exist, defaulting to config in repo."
    source "${DIR}/src/config.sh"
fi

# Sourcing configurations and functions
. "${DIR}/src/functions.sh"

declare args_
args_="${1}"

case "${args_}" in
        --destroy)
            cli_log "Destroying current infra.."
            cd "${DIR}"/terraform/deploy && terraform destroy -force &> /dev/null && \
            cli_log "Destroyed everything." && exit
            ;;

        --reset)
            cli_log "Resetting.." && cli_log "Destroying current infra.."
            cd "${DIR}"/terraform/deploy && terraform destroy -force &> /dev/null && cli_log "Destroyed everything."
            # Without the exit the script will just continue and rebuild the structure
            ;;

        --run)
            cli_log "Building the structure.." && run_init
            # Without the exit the script will just continue and rebuild the structure
            ;;

        --test)
            cli_log "Testing build.." && run_test
            exit
            ;;

        *)
            cli_log "No parameter specified."
            cli_log "Run: ./run.sh --destroy, ./run.sh --reset or ./run.sh --run"
            exit 1
esac

# Add; remove old deploy key
cli_log "Adding variables to configuration files.."
cli_log "Adding your Username to user_data.yml.." && sed "s|sshuser|${SSH_USER}|g" "${DIR}"/templates/user_data.yml > "${DIR}"/terraform/deploy/user_data.yml
cli_log "Adding Provider to Terraform.." && sed "s|sshuser|${AWS_USER}|g" "${DIR}"/templates/provider.tf > "${DIR}"/terraform/deploy/provider.tf
cli_log "Adding Region to Terraform.." && sed -i "s|awsregion|${AWS_REGION}|g" "${DIR}"/terraform/deploy/provider.tf
cli_log "Adding Instance type to Terraform.." && sed "s|instance_type|${AWS_INSTANCE}|g" "${DIR}"/templates/variables.tf > "${DIR}"/terraform/deploy/variables.tf
cli_log "Adding your SSH key to user_data.yml.." && sed -i "s|sshkey|${SSH_KEY_OUTPUT}|g" "${DIR}"/terraform/deploy/user_data.yml

# cd to underlying terraform dir and apply all or exit on error
cli_log "Creating EC2 instance and apply user_data.yml.."
cd "${DIR}"/terraform/deploy && terraform init &> /dev/null && terraform plan &> /dev/null && terraform apply -auto-approve &> /dev/null && cli_log "Done!" || exit 1;

declare AWS_IP
AWS_IP=$(terraform output | grep public-ip | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")

# Sleep to prevent 'refused' error
cli_log "Waiting for server to start.." sleep 10

declare max_timeout="6000"
declare timeout_at
timeout_at=$(( SECONDS + max_timeout ))

until ssh -o StrictHostKeyChecking=no "${SSH_USER}"@"${AWS_IP}" '[ -d /tmp/done ]'; do
  if (( SECONDS > timeout_at )); then
    cli_log "Maximum time of ${max_timeout} passed, stopping script.." 
    send_alert "Maximum time of ${max_timeout} passed, stopping script for ${SSH_USER}.."
    exit 1
  fi
    cli_log "Cloud-init not done yet.." && sleep 30
done

# Fetch generated root key
declare ROOT_KEY
ROOT_KEY=$(ssh -o StrictHostKeyChecking=no ${SSH_USER}@${AWS_IP} "cat /home/${SSH_USER}/.ssh/id_ed25519.pub")

# Add deploy key to server
cli_log "Adding fetched SSH pub key as Gitlab deploy key.."
curl --request POST --header "PRIVATE-TOKEN: ${GITLAB_API_KEY}" --header "Content-Type:application/json" --data "{\"title\": \"pnd-server-${SSH_USER}\", \"key\": \"${ROOT_KEY}\", \"can_push\": \"true\"}" "https://gitlab.com/api/v4/projects/24216317/deploy_keys" &> /dev/null

# Clone repo and install requirements
cli_log "Cloning repo on the server.."
ssh -o StrictHostKeyChecking=no "${SSH_USER}"@"${AWS_IP}" "git clone --single-branch --branch master git@gitlab.com:Santralos/pnd-binance.git /home/${SSH_USER}/repos/pnd-binance --depth=1" &> /dev/null
cli_log "Fetching rest of the repo.."
ssh -o StrictHostKeyChecking=no "${SSH_USER}"@"${AWS_IP}" "cd /home/${SSH_USER}/repos/pnd-binance && git fetch --depth=10" &> /dev/null

cli_log "Installing Python requirements.."
ssh -o StrictHostKeyChecking=no "${SSH_USER}"@"${AWS_IP}" "cd /home/${SSH_USER}/repos/pnd-binance && pip3 install -r requirements.txt" &> /dev/null && cli_log "Done."

# Clean up
cli_log "Archiving old user_data.yml.." && mv "${DIR}"/terraform/deploy/user_data.yml "${TMP_DIR}/user_data.yml_old" &> /dev/null
cli_log "Archiving old Terraform Provider file" && mv "${DIR}"/terraform/deploy/provider.tf "${TMP_DIR}/user_data.yml_old" &> /dev/null

cli_log "Access server: ssh ${SSH_USER}@${AWS_IP}"
send_alert "Access server: ssh ${SSH_USER}@${AWS_IP}"