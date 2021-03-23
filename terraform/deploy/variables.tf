variable "aws_region" {
    default = "ap-northeast-3"
}

variable "ec2_count" {
  default = "1"
}

variable "instance_type" {
  default = "t3.nano"
}

variable "key_name" {
  default = "aws_key_stefan"
}

// variable "subnet_id" {}