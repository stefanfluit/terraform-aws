#!/usr/bin/env bash

declare AWS_DIR
AWS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

. "${AWS_DIR}/../../build-config.sh"

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip /tmp/awscliv2.zip &> /dev/null
sudo ./tmp/aws/install

mkdir /home/vagrant/.aws
printf "[default]\n" > /home/vagrant/.aws/credentials
printf "[default]\n" > /home/vagrant/.aws/config

printf "%s\n" "aws_access_key_id=${AWS_ACCES}" >> /home/vagrant/.aws/credentials
printf "%s\n" "aws_secret_access_key=${AWS_SECRET}" >> /home/vagrant/.aws/credentials
printf "%s\n" "region=${AWS_REGION}" > /home/vagrant/.aws/config