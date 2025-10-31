#Defining Variables with existing VPC & Subnet Values. These VPC & Subnets are attached to the EC2 instances accordingly.

variable "vpc_id" {
  default = "vpc-0ca05f224f382d4a4"
}

variable "public_subnet_a_id" {
  default = "subnet-0b59f4b880a573dc3"
}

variable "public_subnet_b_id" {
  default = "subnet-0d00695ecef50043e"
}

variable "private_subnet_a_id" {
  default = "subnet-062c4399716e7df15"
}

variable "private_subnet_b_id" {
  default = "subnet-044a57f7fc03c51c4"
}

variable "ami" {
  default = "ami-0c02fb55956c7d316" # Amazon Linux 2
}

variable "instance_type" {
  default = "t3.micro"
}

variable "key_name" {
  default = "sriram-access-key"
}

#Generated an SSL Key-pair to access Bahion Host

variable "public_key" {
  description = "SSH public key for Bastion"
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC3SzgXhS6NFikSNNdYczJKZaKGf6rakEdWw4AiBNuPvtxgMYuvtQk+zHq6KIgRQp0zVQNnXgEaK2fbBl31lQZuW8CDNm3pIeZkwPCT0+BcuQTRmazU2hIuqb8A/qcH0jIf+kpTIZMZ4ZQur4m3hEut/E9qGKl3eQvEvqcHzkX5IG/mOT8TzMYfs7hLhlBcGu+6G1+jA4xzeyClhnjrLEZNIY58/oX9Gj47vhSiOjxQsygT7U9ltUM5JQPg6uW4v2Eis4aYTAtBOtADtlvDdzCXheQqtiInhM8sNTrmRDPxCMlbFSu15Vm5AU+F7TlNRy9HZ4T/W1qEsAVSx1BDybzoOaVd/LKHhkuPY6W5rxZesxuO/OaMLi/8i35iGJpt4EZy78gL5e0WvWtZkdApkUgKSiUOisAWYzKoeNV+0L8xiWvVmKf/VHEAIXkKLOlDcza0TTZW5rHMpDwlPOLPoSvBFHUT/Vbhexd11Lujgu76K6SX0QBrrkpGkHNTykZtqLdOXOjOl3RfbIKfh3XDietcH238zL6OjlCkm00KNrhOWQy2kyEcIk88VealbGkifOMsKXxJ1ctXK8u7MbB2+4HZ/4yY6PuMLSzXUJoUA/JEY9HamqyuxkoqlFlmmMPYq+ZYlDJMtsSCQaCn8F4rAHMN9KJwOxs8u76aD2yayV6g4Q== srira@sriram"
}


#Fetches the current public IP dynamically.

data "http" "myip" {
  url = "https://api.ipify.org"
}

locals {
  my_ip = "${chomp(data.http.myip.response_body)}/32"
}

#Key Pair
resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = var.public_key
}


#Creating the Security Groups

resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "bastion host security group"
  vpc_id      = var.vpc_id

#Allows only whitelisted IP which is my localIP to access bashion host for SSH on port 22

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_ip]
  }

#Enables full internet on the bashion host for outgoing 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "private_sg" {
  name        = "private-sg"
  description = "Allow all traffic within VPC and all egress"
  vpc_id      = var.vpc_id

#Allow all traffic within VPC and all egress
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.10.0.0/16"]
  }

#Enables full internet on the bashion host for outgoing
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "public_web_sg" {
  name        = "public-web-sg"
  description = "Allow HTTP from my IP"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [local.my_ip]
  }

#Enables full internet on the bashion host for outgoing
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


#Creating EC2 Instances and attaching the appropriate security groups

resource "aws_instance" "bastion" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_a_id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = { Name = "bastion-host" }
}

resource "aws_instance" "jenkins" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_a_id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = { Name = "jenkins-server" }
}

resource "aws_instance" "app" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_b_id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = { Name = "app-server" }
}

#Creating Application Load Balancer for incoming http traffic over internet

resource "aws_lb" "app_alb" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [var.public_subnet_a_id, var.public_subnet_b_id]
  security_groups    = [aws_security_group.public_web_sg.id]

  tags = { Name = "app-alb" }
}

resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "app_attach" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.app.id
  port             = 80
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}