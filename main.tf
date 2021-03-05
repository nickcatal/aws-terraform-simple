terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

# VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = var.vpc_name
  azs    = var.availability_zones

  cidr                 = var.subnet_cidr_block
  private_subnets      = var.private_subnet_cidr_blocks
  public_subnets       = var.public_subnet_cidr_blocks
  enable_vpn_gateway   = false
  enable_nat_gateway   = false
  enable_dns_hostnames = true

  public_subnet_tags = {}

  private_subnet_tags = {}

  tags = {
    Terraform = "true"
  }
}


# Security Groups

resource "aws_security_group" "loadbalancer" {
  vpc_id = module.vpc.vpc_id
  name   = var.load_balancer_name

  ingress {
    description = "Default HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Default HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "webservers" {
  vpc_id = module.vpc.vpc_id
  name   = "webservers"

  ingress {
    description = "Default SSH Whitelist IP"
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = [var.ssh_ip_whitelist]
  }

  ingress {
    description     = "Load Balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "TCP"
    security_groups = [aws_security_group.loadbalancer.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_rds_postgres" {
  name        = "allow_rds_postgres"
  description = "Allow inbound RDS Postgres traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Postgres from webservers"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.webservers.id]
  }

  egress {
    description     = "Postgres to webservers"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.webservers.id]
  }
}

### EC2

resource "aws_iam_role" "webserver_role" {
  name = "webserver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "webserver_profile" {
  name = "webserver-profile"
  role = aws_iam_role.webserver_role.name
}


resource "aws_key_pair" "defaultkey" {
  key_name   = "terraformkey"
  public_key = var.default_key
}

resource "aws_instance" "free" {
  ami           = var.ami
  instance_type = var.ec2_size
  key_name      = aws_key_pair.defaultkey.key_name

  iam_instance_profile = aws_iam_instance_profile.webserver_profile.name

  subnet_id = element(module.vpc.public_subnets, 0)

  vpc_security_group_ids = [aws_security_group.webservers.id]

  root_block_device {
    volume_size = 15
  }

  tags = {
    Name = var.ec2_name
  }
}

resource "aws_eip" "free" {
  vpc      = true
  instance = aws_instance.free.id
}



### DATABASE

# IAM for Enhanced Monitoring

data "aws_iam_policy_document" "rds_enhanced_monitoring" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name_prefix        = "rds-enhanced-monitoring-"
  assume_role_policy = data.aws_iam_policy_document.rds_enhanced_monitoring.json
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

module "free-db-rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 2.0"

  identifier = "free-rds-postgres12"

  engine                = "postgres"
  engine_version        = var.postgres_version
  instance_class        = var.rds_size
  allocated_storage     = 19
  max_allocated_storage = 20
  multi_az              = false
  storage_encrypted     = false

  # DB parameter and option groups
  family               = "postgres12"
  major_engine_version = "12"

  name     = var.rds_database_name
  username = var.rds_database_username
  password = var.rds_database_password
  port     = "5432"

  publicly_accessible    = false
  subnet_ids             = module.vpc.private_subnets
  vpc_security_group_ids = [aws_security_group.allow_rds_postgres.id]

  performance_insights_enabled = true
  monitoring_interval          = "30"
  monitoring_role_arn          = aws_iam_role.rds_enhanced_monitoring.arn

  maintenance_window      = "Sun:06:00-Sun:07:00"
  backup_window           = "03:00-06:00"
  backup_retention_period = 7

  enabled_cloudwatch_logs_exports = ["postgresql"]

  deletion_protection = true
  skip_final_snapshot = true

  tags = {
    Environment = "free"
  }
}


### Domain and Certificate

# ACM Certificate Generation & Route53 Setup


resource "aws_route53_zone" "public" {
  name = var.domain
}

resource "aws_route53_record" "free_public" {
  zone_id         = aws_route53_zone.public.zone_id
  name            = "${var.ec2_subdomain}.${var.domain}"
  type            = "A"
  ttl             = "300"
  records         = [aws_eip.free.public_ip]
  allow_overwrite = true
}

resource "aws_route53_zone" "private" {
  name = var.private_domain

  vpc {
    vpc_id = module.vpc.vpc_id
  }
}

resource "aws_route53_record" "free_private" {
  zone_id         = aws_route53_zone.private.zone_id
  name            = "${var.ec2_subdomain}.${var.private_domain}"
  type            = "A"
  ttl             = "300"
  records         = [aws_instance.free.private_ip]
  allow_overwrite = true
}

resource "aws_route53_record" "rds_private" {
  zone_id         = aws_route53_zone.private.zone_id
  name            = "${var.rds_subdomain}.${var.private_domain}"
  type            = "CNAME"
  ttl             = "300"
  records         = [module.free-db-rds.this_db_instance_address]
  allow_overwrite = true
}

resource "aws_acm_certificate" "public" {
  domain_name               = var.domain
  subject_alternative_names = ["*.${var.domain}"]
  validation_method         = "DNS"
}

resource "aws_route53_record" "acm_public" {
  for_each = {
    for dvo in aws_acm_certificate.public.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.public.zone_id
}


### Load Balancer

resource "aws_lb_target_group" "free" {
  name     = var.target_group_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}

resource "aws_lb_target_group_attachment" "free" {
  target_group_arn = aws_lb_target_group.free.arn
  target_id        = aws_instance.free.id
  port             = 80
}

resource "aws_lb" "free" {
  name               = var.load_balancer_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.loadbalancer.id]
  subnets            = module.vpc.public_subnets
}

### UNCOMMENT AFTER CERTIFICATE HAS BEEN VERIFIED
#resource "aws_lb_listener" "front_end" {
#  load_balancer_arn = aws_lb.free.arn
#  port              = "443"
#  protocol          = "HTTPS"
#  ssl_policy        = "ELBSecurityPolicy-2016-08"
#  certificate_arn   = aws_acm_certificate.public.arn
#
#  default_action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.free.arn
#  }
#}

resource "aws_lb_listener" "front_end_redirect" {
  load_balancer_arn = aws_lb.free.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_route53_record" "free_lb" {
  zone_id         = aws_route53_zone.public.zone_id
  name            = "${var.load_balancer_subdomain}.${var.domain}"
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_lb.free.dns_name
    zone_id                = aws_lb.free.zone_id
    evaluate_target_health = false
  }
}
