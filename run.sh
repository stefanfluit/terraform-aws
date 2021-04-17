#!/usr/bin/env bash

# Uncomment this for verbose output.
#set -x

# Finding the directory we're in
declare DIR
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Sourcing configurations and functions
. "${DIR}/src/functions.sh"

declare config_file_check
config_file_check="${2}"

validate_config "${config_file_check}"

declare args_
args_="${1}"

cli_log "Logs can be found in ${LOG_LOC}"

case "${args_}" in
        --destroy)
            stamp_logfile "terraform"
            cli_log "Destroying current infra.."
            cd "${DIR}"/terraform/deploy 
            terraform destroy -auto-approve >> "${LOG_LOC}"
            cli_log "Destroyed everything." && exit
            ;;

        --reset)
            stamp_logfile "terraform"
            cli_log "Resetting.." && cli_log "Destroying current infra.."
            cd "${DIR}"/terraform/deploy 
            terraform destroy -auto-approve >> "${LOG_LOC}"
            cli_log "Destroyed everything."
            # Without the exit the script will just continue and rebuild the structure
            ;;

        --run)
            stamp_logfile "terraform"
            cli_log "Building the structure.." && run_init --terraform
            # Without the exit the script will just continue and rebuild the structure
            ;;

        --test)
            run_init --vagrant
            stamp_logfile "vagrant"
            cli_log "Building test env locally with Vagrant.."
            run_test && cli_log "Done!"
            exit
            ;;

        --ssh-test)
            vagrant_ssh --test
            exit
            ;;

        --build)
            run_init --build
            run_build
            exit
            ;;

        --destroy-build)
            destroy_build
            exit
            ;;

        --ssh-build)
            vagrant_ssh --build
            exit
            ;;

        --destroy-test)
            destroy_vagrant
            cli_log "Done!"
            exit
            ;;

        --test-config)
            test_config
            exit
            ;;

        *)
            usage_
esac

cli_log "Adding variables to configuration files.."
cli_log "Adding your Username to user_data.yml.." && sed "s|sshuser|${SSH_USER}|g" "${DIR}"/templates/user_data.yml > "${DIR}"/terraform/deploy/user_data.yml

cli_log "Adding Provider to Terraform.." && sed "s|sshuser|${AWS_USER}|g" "${DIR}"/templates/provider.tf > "${DIR}"/terraform/deploy/provider.tf
cli_log "Defining EC2 instance count in Terraform.." && sed -i "s|instancecount|${AWS_COUNT}|g" "${DIR}"/terraform/deploy/provider.tf

cli_log "Defining VPC Region in Terraform.." && sed -i "s|instanceregion|${AWS_REGION}|g" "${DIR}"/terraform/deploy/provider.tf
cli_log "Adding Region to Terraform.." && sed -i "s|awsregion|${AWS_REGION}|g" "${DIR}"/terraform/deploy/provider.tf

cli_log "Adding Instance type to Terraform.." && sed "s|ec2_type|${AWS_INSTANCE}|g" "${DIR}"/templates/variables.tf > "${DIR}"/terraform/deploy/variables.tf
cli_log "Adding Instance type to Terraform.." && sed -i "s|instanceregion|${AWS_REGION}|g" "${DIR}"/terraform/deploy/variables.tf

cli_log "Adding Instance type to Terraform.." && sed -i "s|instancecount|${AWS_COUNT}|g" "${DIR}"/terraform/deploy/variables.tf
cli_log "Adding your SSH key to user_data.yml.." && sed -i "s|sshkey|${SSH_KEY_OUTPUT}|g" "${DIR}"/terraform/deploy/user_data.yml

# cd to underlying terraform dir and apply all or exit on error
cli_log "Creating EC2 instance and apply user_data.yml.."
cd "${DIR}"/terraform/deploy && terraform init >> "${LOG_LOC}" && terraform plan >> "${LOG_LOC}" && \
terraform apply -auto-approve >> "${LOG_LOC}" && cli_log "Done!" || exit 1;

declare AWS_IP
AWS_IP=$(terraform output | grep public-ip | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")

# Sleep to prevent 'refused' error
cli_log "Waiting for server to start.." && sleep 10

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
curl --request POST --header "PRIVATE-TOKEN: ${GITLAB_API_KEY}" --header "Content-Type:application/json" --data "{\"title\": \"pnd-server-${SSH_USER}\", \"key\": \"${ROOT_KEY}\", \"can_push\": \"true\"}" "https://gitlab.com/api/v4/projects/24216317/deploy_keys" &> "${LOG_LOC}"

# Clone repo and install requirements
cli_log "Cloning repo on the server.."
ssh -o StrictHostKeyChecking=no "${SSH_USER}"@"${AWS_IP}" "git clone --single-branch --branch master ${DEPLOY_REPO} /home/${SSH_USER}/repos/${BASENAME_REPO} --depth=1" >> "${LOG_LOC}"
cli_log "Fetching rest of the repo.."
ssh -o StrictHostKeyChecking=no "${SSH_USER}"@"${AWS_IP}" "cd /home/${SSH_USER}/repos/${BASENAME_REPO} && git fetch --depth=${GIT_DEPTH}" >> "${LOG_LOC}"

cli_log "Installing Python requirements.."
ssh -o StrictHostKeyChecking=no "${SSH_USER}"@"${AWS_IP}" "cd /home/${SSH_USER}/repos/${BASENAME_REPO} && pip3 install -r requirements.txt" >> "${LOG_LOC}" && cli_log "Done installing python requirements."

if [ "${ENABLE_MONGO}" = "enable" ]; then
    cli_log "Adding EC2 IP to the MongoDB server.."
    ssh "${MONGO_SSH_USER}"@"${MONGO_HOST}" "sudo ufw allow from ${AWS_IP} to any port ${MONGO_PORT} && sudo ufw reload" >> "${LOG_LOC}" && \
    cli_log "Done, firewall reloaded."
else
    cli_log "Not adding server to MongoDB, did not read parameter."
fi

cli_log "Access server: ssh ${SSH_USER}@${AWS_IP}"
send_alert "Access server: ssh ${SSH_USER}@${AWS_IP}"

stamp_logfile "DONE"