terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
}

# Generate a unique suffix for resources
resource "random_string" "resource_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_security_group" "deepseek_sg" {
  name        = "deepseek_sg_${random_string.resource_suffix.result}"
  description = "Allow inbound traffic for DeepSeek Model"
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "deepseek_role" {
  name = "Deep-seek-role-${random_string.resource_suffix.result}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Attach necessary policies to the role
resource "aws_iam_role_policy_attachment" "deepseek_ssm_policy" {
  role       = aws_iam_role.deepseek_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "deepseek_instance_profile" {
  name = "Deep-seek-instance-profile-${random_string.resource_suffix.result}"
  role = aws_iam_role.deepseek_role.name
}

resource "aws_instance" "deepseek_model" {
  ami           = "ami-00bb6a80f01f03502"  # Update with latest Ubuntu AMI
  instance_type = "g4dn.xlarge"
  key_name      = "my-key"
  
  vpc_security_group_ids = [aws_security_group.deepseek_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.deepseek_instance_profile.name
  
  tags = {
    Name = "DeepSeekModelR1-${random_string.resource_suffix.result}"
  }
}

resource "aws_lb" "deepseek_lb" {
  name               = "deepseek-lb-${random_string.resource_suffix.result}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.deepseek_sg.id]
  
  subnets = ["subnet-0e6c7ccb2e0b9e48e", "subnet-01f42a6cc1087ab87"]
  
  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_target_group" "deepseek_target_group" {
  name     = "deepseek-target-group-${random_string.resource_suffix.result}"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = "vpc-0c1ae7114c8b95d15"
}

resource "aws_lb_listener" "deepseek_listener" {
  load_balancer_arn = aws_lb.deepseek_lb.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.deepseek_target_group.arn
  }
}

resource "aws_lb_target_group_attachment" "deepseek_attachment" {
  target_group_arn = aws_lb_target_group.deepseek_target_group.arn
  target_id        = aws_instance.deepseek_model.id
  port             = 8080
}

# Outputs
output "ec2_public_ip" {
  value = aws_instance.deepseek_model.public_ip
}

output "load_balancer_dns" {
  value = aws_lb.deepseek_lb.dns_name
}
