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
  region  = "ap-south-1"
  
}

resource "aws_security_group" "deepseek_sg" {
  name        = "deepseek_sg"
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
}

resource "aws_iam_role" "deepseek_role" {
  name = "Deep-seek-role"
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

resource "aws_iam_instance_profile" "deepseek_instance_profile" {
  name = "Deep-seek-instance-profile"
  role = aws_iam_role.deepseek_role.name
}

resource "aws_key_pair" "my_key" {
  key_name   = "my-key"
  public_key = file("~/.ssh/id_rsa.pub")  # Use the path to your existing public key
}

resource "aws_instance" "deepseek_model" {
  ami           = "ami-00bb6a80f01f03502"
  instance_type = "g4dn.xlarge"
  key_name      = aws_key_pair.my_key.key_name
  security_groups = [aws_security_group.deepseek_sg.name]
  
  iam_instance_profile = aws_iam_instance_profile.deepseek_instance_profile.name
  tags = {
    Name = "DeepSeekModelR1"
  }
}
resource "aws_lb" "deepseek_lb" {
  name               = "deepseek-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups   = [aws_security_group.deepseek_sg.id]
  subnets            = ["subnet-0e6c7ccb2e0b9e48e", "subnet-01f42a6cc1087ab87"]
  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true
}
resource "aws_lb_target_group" "deepseek_target_group" {
  name     = "deepseek-target-group"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = "vpc-0c1ae7114c8b95d15"
}
resource "aws_lb_listener" "deepseek_listener" {
  load_balancer_arn = aws_lb.deepseek_lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "fixed-response"
    fixed_response {
      status_code = 200
      message_body = "Welcome to DeepSeek Model!"
      content_type = "text/plain"
    }
  }
}

##