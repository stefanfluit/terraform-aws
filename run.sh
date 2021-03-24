#!/usr/bin/env bash

# Finding the directory we're in
declare DIR
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Sourcing configurations and functions
. "${DIR}/src/config.sh"
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

        *)
            cli_log "No parameter specified."
            cli_log "Run: ./run.sh --destroy, ./run.sh --reset or ./run.sh --run"
            exit 1
esac

# cd to underlying terraform dir and apply all or exit on error
cli_log "Creating Ec2 instance and apply user_data.yml.."
cd "${DIR}"/terraform/deploy && terraform init &> /dev/null && terraform plan &> /dev/null && terraform apply -auto-approve &> /dev/null && cli_log "Done!" || exit 1;

declare AWS_IP
AWS_IP=$(terraform output | grep public-ip | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")

# Sleep to prevent 'refused' error
cli_log "Waiting for server to start.." sleep 10

declare max_timeout="6000"
declare timeout_at
timeout_at=$(( SECONDS + max_timeout )) 

until ssh -o StrictHostKeyChecking=no frank@"${AWS_IP}" '[ -d /home/frank/repos ]'; do
  if (( SECONDS > timeout_at )); then
    cli_log "Maximum time of ${max_timeout} passed, stopping script.." 
    exit 1
  fi
    cli_log "Cloud-init not done yet.." && sleep 30
done

# Fetch generated root key
declare ROOT_KEY
ROOT_KEY=$(ssh -o StrictHostKeyChecking=no frank@${AWS_IP} "cat /home/frank/.ssh/id_ed25519.pub")

# Add deploy key to server
cli_log "Adding fetched SSH pub key as Gitlab deploy key.."
curl --request POST --header "PRIVATE-TOKEN: ${GITLAB_API_KEY}" --header "Content-Type:application/json" --data "{\"title\": \"pnd-server-frank\", \"key\": \"${ROOT_KEY}\", \"can_push\": \"true\"}" "https://gitlab.com/api/v4/projects/24216317/deploy_keys" &> /dev/null

# Clone repo and install requirements
# Cloning in multiple steps, because the repo is to big..
cli_log "Cloning repo on the server.." && ssh -o StrictHostKeyChecking=no frank@"${AWS_IP}" "git clone --single-branch --branch master git@gitlab.com:Santralos/pnd-binance.git /home/frank/repos/pnd-binance --depth=1"

cli_log "Fething rest of the repo..1/5" && ssh -o StrictHostKeyChecking=no frank@"${AWS_IP}" "cd /home/frank/repos/pnd-binance && git fetch --depth=10"
cli_log "Fething rest of the repo..2/5" && ssh -o StrictHostKeyChecking=no frank@"${AWS_IP}" "cd /home/frank/repos/pnd-binance && git fetch --depth=100"
cli_log "Fething rest of the repo..3/5" && ssh -o StrictHostKeyChecking=no frank@"${AWS_IP}" "cd /home/frank/repos/pnd-binance && git fetch --depth=200"
cli_log "Fething rest of the repo..4/5" && ssh -o StrictHostKeyChecking=no frank@"${AWS_IP}" "cd /home/frank/repos/pnd-binance && git fetch --depth=300"
cli_log "Fething rest of the repo..5/5" && ssh -o StrictHostKeyChecking=no frank@"${AWS_IP}" "cd /home/frank/repos/pnd-binance && git fetch --unshallow"

cli_log "Installing Python requirements.." && ssh -o StrictHostKeyChecking=no frank@"${AWS_IP}" "cd /home/frank/repos/pnd-binance && sudo pip3 install requirements.txt" && cli_log "Done."

cli_log "Access server: ssh frank@${AWS_IP}"
