terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
 
provider "aws" {
  region = var.region
}
 
# ---------------------------
# VPC
# ---------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
 
  tags = { Name = "streamline-vpc" }
}
 
# ---------------------------
# Internet Gateway
# ---------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "streamline-igw" }
}
 
# ---------------------------
# Subnets (2 Public, 2 Private)
# ---------------------------
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "streamline-public-${count.index + 1}" }
}
 
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]
  tags              = { Name = "streamline-private-${count.index + 1}" }
}
 
# ---------------------------
# Route Tables (Public + Private)
# ---------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "streamline-public-rt" }
}
 
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}
 
resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
 
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "streamline-private-rt" }
}
 
resource "aws_route_table_association" "private_assoc" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
 
# ---------------------------
# Security Groups
# ---------------------------
resource "aws_security_group" "web_sg" {
  name        = "streamline-web-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.main.id
 
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
 
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  tags = { Name = "streamline-web-sg" }
}
 
resource "aws_security_group" "rds_sg" {
  name        = "streamline-rds-sg"
  description = "Allow MySQL only from web SG"
  vpc_id      = aws_vpc.main.id
 
  ingress {
    description     = "MySQL from web instances"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }
 
  egress {
    description = "All outbound (internal)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  tags = { Name = "streamline-rds-sg" }
}
 
# ---------------------------
# Latest Amazon Linux 2 AMI
# ---------------------------
data "aws_ami" "amzn2" {
  most_recent = true
  owners      = ["amazon"]
 
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
 
  filter {
    name   = "state"
    values = ["available"]
  }
}
 
# ---------------------------
# EC2 Instances (2) in public subnets
# ---------------------------
resource "aws_instance" "web" {
  count                       = 2
  ami                         = data.aws_ami.amzn2.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[count.index].id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
 
  tags = { Name = "streamline-web-${count.index + 1}" }
}
 
# ---------------------------
# ALB + Target Group + Listener
# ---------------------------
resource "aws_lb" "alb" {
  name               = "streamline-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = aws_subnet.public[*].id
 
  tags = { Name = "streamline-alb" }
}
 
resource "aws_lb_target_group" "tg" {
  name     = "streamline-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
 
  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
 
  tags = { Name = "streamline-tg" }
}
 
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
 
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
 
resource "aws_lb_target_group_attachment" "attach" {
  count            = 2
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}
 
# ---------------------------
# RDS (MySQL) in private subnets
# ---------------------------
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "streamline-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  tags       = { Name = "streamline-db-subnet-group" }
}
 
resource "aws_db_instance" "mysql" {
  identifier             = "streamline-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
 
  publicly_accessible = false
  skip_final_snapshot = true
  deletion_protection = false
 
  tags = { Name = "streamline-rds" }
}
 
# ---------------------------
# Outputs
# ---------------------------
output "alb_dns" {
  value = aws_lb.alb.dns_name
}
 
output "ec2_public_ips" {
  value = aws_instance.web[*].public_ip
}
 
output "rds_endpoint" {
  value = aws_db_instance.mysql.endpoint
}
