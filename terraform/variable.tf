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
  description = "Existing EC2 key pair name"
  type        = string
}
 
variable "my_ip" {
  description = "Your public IP in CIDR format (example: 49.xx.xx.xx/32)"
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
