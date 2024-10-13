terraform {
  backend "s3" {
    key            = "state/dev/terraform.tfstate"
    region         = "us-west-2"
    bucket         = "curology-state-bucket"
    dynamodb_table = "curology-dynamo-table"
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.environment}-curology-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "${var.environment}-curology-database"

  engine            = "postgres"
  engine_version    = "16.3"
  family            = "postgres16"
  instance_class    = "db.m5d.large"
  allocated_storage = 20

  db_name  = "curology"
  username = "curology"
  port     = "5432"

  apply_immediately                   = true
  publicly_accessible                 = true
  deletion_protection                 = true
  manage_master_user_password         = true
  iam_database_authentication_enabled = false

  vpc_security_group_ids = [
    module.vpc.default_security_group_id
  ]

  maintenance_window     = "Mon:00:00-Mon:03:00"
  backup_window          = "03:00-06:00"
  monitoring_interval    = "30"
  monitoring_role_name   = "MyRDSMonitoringRole"
  create_monitoring_role = true

  tags = {
    Owner       = "curology"
    Environment = var.environment
  }

  create_db_subnet_group = true

  subnet_ids = [
    module.vpc.public_subnets[0],
    module.vpc.public_subnets[1],
    module.vpc.public_subnets[2],
    module.vpc.private_subnets[1],
    module.vpc.private_subnets[2]
  ]
}