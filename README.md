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

Copy the config template to your home directory:
```
cp src/config.sh "/home/$(whoami)/pnd-config.sh"
```

Edit the variables:
```
vim "/home/$(whoami)/pnd-config.sh"
```

Make sure your config is working correctly for the first time:
```
./run.sh --test-config
```

To create the infra after, run:
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

To run with a different config:
```
./run.sh --run --config-file=/path/to/config/file.sh
```

To run on your localhost as a VM (Virtualbox must be installed), run:
```
./run.sh --test
```

To SSH into that machine, run:
```
./run.sh --ssh-test
```

If you want the script to be accessible at all times, put this in your ~/.bashrc at the end of it:

```
terraform-aws() {
  local args_1
  args_1="${1}"
  local args_2
  args_2="${2}"
  cd /path/to/the/repo/terraform-aws && ./run.sh "${args_1}" "${args_2}"
}
```
Make sure that the path to the script is correct. Run a `pwd` in the directory of the script.