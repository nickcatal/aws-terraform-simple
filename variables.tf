variable "vpc_name" {
  description = "Name of the VPC to be created"
  type        = string
  default     = "free-vpc"
}

variable "ec2_name" {
  description = "Value of the Name tag for the EC2 instance"
  type        = string
  default     = "FreeInstance"
}

variable "target_group_name" {
  description = "Name of the target group the instance is in"
  type        = string
  default     = "free-lb-tg"
}

variable "load_balancer_name" {
  description = "Name of the application load balancer the instance is in"
  type        = string
  default     = "free-lb"
}

variable "load_balancer_subdomain" {
  description = "Subdomain of the public domain to put loadbalancer on"
  type        = string
  default     = "free-lb"
}

variable "default_key" {
  description = "SSH key used for the EC2 instance"
  type        = string
}

variable "ssh_ip_whitelist" {
  description = "CIDR range that should be allowed to access port 22 of the EC2 instance (usually `{your IP}/32`)"
  type        = string
}

variable "ami" {
  description = "AMI to use for EC2 instance"
  type        = string
  default     = "ami-042e8287309f5df03"
}

variable "ec2_size" {
  description = "Size of initial EC2 instance (changes may cost money!)"
  type        = string
  default     = "t2.micro"
}

variable "availability_zones" {
  description = "Availability zones used"
  type        = list(string)
  default = [
    "us-east-1a",
    "us-east-1b",
    "us-east-1c",
    "us-east-1d",
  ]
}

variable "subnet_cidr_block" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "172.18.0.0/16"
}

variable "public_subnet_cidr_blocks" {
  description = "Available cidr blocks for public subnets."
  type        = list(string)
  default = [
    "172.18.0.0/20",
    "172.18.32.0/20",
    "172.18.64.0/20",
    "172.18.96.0/20",
  ]
}

variable "private_subnet_cidr_blocks" {
  description = "Available cidr blocks for private subnets."
  type        = list(string)
  default = [
    "172.18.16.0/20",
    "172.18.48.0/20",
    "172.18.80.0/20",
    "172.18.112.0/20",
  ]
}

variable "rds_size" {
  description = "Size of initial RDS instance (changes may cost money!)"
  type        = string
  default     = "db.t2.micro"
}

variable "postgres_version" {
  description = "Initial version of postgres"
  type        = string
  default     = "12.4"
}

variable "rds_database_name" {
  description = "Name of initial RDS database"
  type        = string
  default     = "terraformfree"
}

variable "rds_database_username" {
  description = "Name of initial RDS user"
  type        = string
  default     = "root"
}

variable "rds_database_password" {
  description = "Password of initial RDS user"
  type        = string
  default     = "ChangeMeLater"
}

variable "domain" {
  description = "Public Domain name to attach all public resources to"
  type        = string
}

variable "private_domain" {
  description = "Domain name to attach all private resources to"
  type        = string
  default     = "services.private"
}

variable "ec2_subdomain" {
  description = "Subdomain to use for EC2 instance on public and private domain"
  type        = string
  default     = "free"
}

variable "rds_subdomain" {
  description = "Subdomain to use for RDS instance on private domain"
  type        = string
  default     = "postgres"
}
