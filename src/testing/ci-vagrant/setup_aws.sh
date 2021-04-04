#!/usr/bin/env bash

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip /tmp/awscliv2.zip
cd /tmp && sudo ./aws/install
printf "%s\n" "aws_access_key_id=${AWS_ACCES}" >> /home/vagrant/.aws/credentials
printf "%s\n" "aws_secret_access_key=${AWS_SECRET}" >> /home/vagrant/.aws/credentials
printf "%s\n" "region=${AWS_REGION}" >> /home/vagrant/.aws/config