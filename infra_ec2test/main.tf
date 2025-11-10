
provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "all" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "test-ec2-sg"
  description = "Allow HTTP from Leumi proxy only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow HTTP from Leumi proxy"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["91.231.246.50/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "test_ec2" {
  ami           = "ami-0c02fb55956c7d316" 
  instance_type = "t3.micro"
  key_name      = "my-key-pair"          
  subnet_id     = data.aws_subnets.all.ids[0]  
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd
              sudo systemctl enable httpd
              sudo systemctl start httpd
              EOF

  tags = {
    Name = "test-ec2"
  }
}

resource "aws_eip" "vip" {
  instance = aws_instance.test_ec2.id
}

resource "aws_lb" "nlb" {
  name               = "test-ec2-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = data.aws_subnets.all.ids
}

resource "aws_lb_target_group" "tg" {
  name        = "test-ec2-tg"
  port        = 80
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_lb_target_group_attachment" "ec2_attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.test_ec2.id
  port             = 80
}
