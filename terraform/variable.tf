variable "region" {
  type    = string
  default = "us-east-1"
}
 
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
 
variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}
 
variable "public_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}
 
variable "private_subnets" {
  type    = list(string)
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}
 
variable "instance_type" {
  type    = string
  default = "t2.micro"
}
 

 
variable "key_name" {
  description = "ec2"
  type        = string
}

 
variable "db_username" {
  type    = string
  default = "admin"
}
 
variable "db_password" {
  description = "RDS password (8+ chars)"
  type        = string
  default     = "Admin12345!"
}
