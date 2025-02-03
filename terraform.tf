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
resource "aws_instance" "deepseek_model" {
  ami           = "ami-xyz"
  instance_type = "g4dn.xlarge"
  key_name      = "my-key"
  security_groups = [aws_security_group.deepseek_sg.name]
  
  iam_instance_profile = "deepseek-model-iam-profile"
  tags = {
    Name = "DeepSeekModelR1"
  }
}
resource "aws_lb" "deepseek_lb" {
  name               = "deepseek-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups   = [aws_security_group.deepseek_sg.id]
  subnets            = ["subnet-xxxxxx", "subnet-yyyyyy"]
  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true
}
resource "aws_lb_target_group" "deepseek_target_group" {
  name     = "deepseek-target-group"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = "vpc-xxxxxx"
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
    }
  }
}