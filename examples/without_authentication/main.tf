provider "aws" {
  region = var.region
}

module "vpc" {
  source  = "cloudposse/vpc/aws"
  version = "0.18.0"

  cidr_block = "172.16.0.0/16"

  context = module.this.context
}

data "aws_availability_zones" "available" {
}

locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "subnets" {
  source                   = "cloudposse/dynamic-subnets/aws"
  version                  = "0.32.0"
  availability_zones       = local.availability_zones
  vpc_id                   = module.vpc.vpc_id
  igw_id                   = module.vpc.igw_id
  cidr_block               = module.vpc.vpc_cidr_block
  nat_gateway_enabled      = true
  nat_instance_enabled     = false
  aws_route_create_timeout = "5m"
  aws_route_delete_timeout = "10m"

  context = module.this.context
}

# ECS Cluster (needed even if using FARGATE launch type)
resource "aws_ecs_cluster" "default" {
  name = module.this.id
}

resource "aws_cloudwatch_log_group" "app" {
  name = module.this.id
  tags = module.this.tags
}

module "app" {
  source = "../../"

  region      = var.region
  launch_type = "FARGATE"
  vpc_id      = module.vpc.vpc_id

  container_environment = [
    {
      name  = "LAUNCH_TYPE"
      value = "FARGATE"
    },
    {
      name  = "VPC_ID"
      value = module.vpc.vpc_id
    }
  ]

  desired_count    = 1
  container_image  = var.default_container_image
  container_cpu    = 256
  container_memory = 512
  container_port   = 80
  build_timeout    = 5

  codepipeline_enabled = false
  webhook_enabled      = false
  badge_enabled        = false
  ecs_alarms_enabled   = false
  autoscaling_enabled  = false

  autoscaling_dimension             = "cpu"
  autoscaling_min_capacity          = 1
  autoscaling_max_capacity          = 2
  autoscaling_scale_up_adjustment   = 1
  autoscaling_scale_up_cooldown     = 60
  autoscaling_scale_down_adjustment = -1
  autoscaling_scale_down_cooldown   = 300

  aws_logs_region        = var.region
  ecs_cluster_arn        = aws_ecs_cluster.default.arn
  ecs_cluster_name       = aws_ecs_cluster.default.name
  ecs_security_group_ids = [module.vpc.vpc_default_security_group_id]
  ecs_private_subnet_ids = module.subnets.private_subnet_ids

  context = module.this.context
}
