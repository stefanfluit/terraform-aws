### Terraform AWS&nbsp;


To use:
========
Make sure you have Git and JQ installed:
```
sudo apt-get update && sudo apt-get install git jq -y
```

Clone this repo:
```
git clone https://github.com/stefanfluit/terraform-aws.git
```

cd into the repo
```
cd terraform-aws
```

Add user and Gitlab API key here, and Discord API URL if you want a Discord alert:
```
vim src/config.sh
```



To create the EC2 and VPC infrastructure:
```
./run.sh --run
```

To destroy and rebuild the server and infrastructure:
```
./run.sh --reset
```

To destroy the server and infrastructure:
```
./run.sh --destroy
```

Before you run:
It's best to install Terraform and AWS yourself. Run "aws configure" after installing.
```
https://learn.hashicorp.com/tutorials/terraform/install-cli
```
```
https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html#cliv2-linux-install
```
Tested on Fedora Desktop 33 and WSL 2 on Windows 10 20h2.