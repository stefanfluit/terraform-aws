module "vpc" {
    source = "github.com/robogeek/terraform-aws-modules//modules/vpc-simple"
    vpc_name = "vpc-pnd"
    vpc_cidr = "192.168.0.0/16"
    public_cidr = "192.168.1.0/24"
    private_cidr = "192.168.2.0/24"
}

resource "aws_instance" "public-ec2" {
    ami           = data.aws_ami.ubuntu.id
    instance_type = var.instance_type
    subnet_id     = module.vpc.subnet_public_id
    vpc_security_group_ids = [ aws_security_group.ec2-sg.id ]
    associate_public_ip_address = true

    tags = {
        Name = "ec2-main"
    }

    user_data = file("user_data.yml")

    depends_on = [ module.vpc.vpc_id, module.vpc.igw_id ]
}

resource "aws_security_group" "ec2-sg" {
  name        = "security-group"
  description = "allow inbound access to the Application task from NGINX"
  vpc_id      = module.vpc.vpc_id

  ingress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
