provider "aws" {
  region = "${var.region}"
}

module "vpc" {
  source     = "git::https://github.com/cloudposse/terraform-aws-vpc.git?ref=tags/0.3.4"
  namespace  = "${var.namespace}"
  stage      = "${var.stage}"
  name       = "${var.name}"
  cidr_block = "172.16.0.0/16"
}

data "aws_availability_zones" "available" {}

locals {
  availability_zones = "${slice(data.aws_availability_zones.available.names, 0, 2)}"
}

module "subnets" {
  source              = "git::https://github.com/cloudposse/terraform-aws-dynamic-subnets.git?ref=tags/0.3.6"
  availability_zones  = "${local.availability_zones}"
  namespace           = "${var.namespace}"
  stage               = "${var.stage}"
  name                = "${var.name}"
  region              = "${var.region}"
  vpc_id              = "${module.vpc.vpc_id}"
  igw_id              = "${module.vpc.igw_id}"
  cidr_block          = "${module.vpc.vpc_cidr_block}"
  nat_gateway_enabled = "true"
}

module "ecs_cluster_label" {
  source     = "git::https://github.com/cloudposse/terraform-terraform-label.git?ref=tags/0.2.1"
  name       = "${var.name}"
  namespace  = "${var.namespace}"
  stage      = "${var.stage}"
  tags       = "${var.tags}"
  attributes = "${var.attributes}"
  delimiter  = "${var.delimiter}"
}

# ECS Cluster (needed even if using FARGATE launch type)
resource "aws_ecs_cluster" "default" {
  name = "${module.ecs_cluster_label.id}"
}

module "web_app" {
  source     = "../../"
  namespace  = "${var.namespace}"
  stage      = "${var.stage}"
  name       = "${var.name}"
  attributes = ["${compact(concat(var.attributes, list("app")))}"]

  launch_type = "FARGATE"
  vpc_id      = "${module.vpc.vpc_id}"

  environment = [
    {
      name  = "LAUNCH_TYPE"
      value = "FARGATE"
    },
    {
      name  = "VPC_ID"
      value = "${module.vpc.vpc_id}"
    },
  ]

  desired_count    = 1
  container_image  = "${var.default_container_image}"
  container_cpu    = "256"
  container_memory = "512"
  container_port   = "80"
  build_timeout    = 5

  port_mappings = [{
    "containerPort" = 80
    "hostPort"      = 80
    "protocol"      = "tcp"
  }]

  codepipeline_enabled = "false"
  webhook_enabled      = "false"
  badge_enabled        = "false"
  ecs_alarms_enabled   = "false"
  autoscaling_enabled  = "false"

  autoscaling_dimension             = "cpu"
  autoscaling_min_capacity          = 1
  autoscaling_max_capacity          = 2
  autoscaling_scale_up_adjustment   = "1"
  autoscaling_scale_up_cooldown     = "60"
  autoscaling_scale_down_adjustment = "-1"
  autoscaling_scale_down_cooldown   = "300"

  aws_logs_region        = "${var.region}"
  ecs_cluster_arn        = "${aws_ecs_cluster.default.arn}"
  ecs_cluster_name       = "${aws_ecs_cluster.default.name}"
  ecs_security_group_ids = ["${module.vpc.vpc_default_security_group_id}"]
  ecs_private_subnet_ids = ["${module.subnets.private_subnet_ids}"]

}
