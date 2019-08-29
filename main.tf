module "default_label" {
  source     = "git::https://github.com/cloudposse/terraform-terraform-label.git?ref=tags/0.2.1"
  name       = "${var.name}"
  namespace  = "${var.namespace}"
  stage      = "${var.stage}"
  attributes = "${var.attributes}"
}

module "ecr" {
  enabled    = "${var.codepipeline_enabled}"
  source     = "git::https://github.com/cloudposse/terraform-aws-ecr.git?ref=tags/0.5.0"
  name       = "${var.name}"
  namespace  = "${var.namespace}"
  stage      = "${var.stage}"
  attributes = "${compact(concat(var.attributes, list("ecr")))}"
}

resource "aws_cloudwatch_log_group" "app" {
  name = "${module.default_label.id}"
  tags = "${module.default_label.tags}"
}


module "container_definition" {
  source                       = "git::https://github.com/cloudposse/terraform-aws-ecs-container-definition.git?ref=tags/0.9.1"
  container_name               = "${module.default_label.id}"
  container_image              = "${var.container_image}"
  container_memory             = "${var.container_memory}"
  container_memory_reservation = "${var.container_memory_reservation}"
  container_cpu                = "${var.container_cpu}"
  healthcheck                  = "${var.healthcheck}"
  environment                  = "${var.environment}"
  port_mappings                = "${var.port_mappings}"
  secrets                      = "${var.secrets}"

  log_options = {
    "awslogs-region"        = "${var.aws_logs_region}"
    "awslogs-group"         = "${aws_cloudwatch_log_group.app.name}"
    "awslogs-stream-prefix" = "${var.name}"
  }
}

module "ecs_service_task" {
  source                            = "./ecs_service_task"
  name                              = "${var.name}"
  namespace                         = "${var.namespace}"
  stage                             = "${var.stage}"
  attributes                        = "${var.attributes}"
  container_definition_json         = "${module.container_definition.json}"
  container_name                    = "${module.default_label.id}"
  desired_count                     = "${var.desired_count}"
  health_check_grace_period_seconds = "${var.health_check_grace_period_seconds}"
  task_cpu                          = "${var.container_cpu}"
  task_memory                       = "${var.container_memory}"
  ecs_cluster_arn                   = "${var.ecs_cluster_arn}"
  launch_type                       = "${var.launch_type}"
  vpc_id                            = "${var.vpc_id}"
  security_group_ids                = ["${var.ecs_security_group_ids}"]
  private_subnet_ids                = ["${var.ecs_private_subnet_ids}"]
  container_port                    = "${var.container_port}"
  tags                              = "${var.tags}"
}

module "ecs_codepipeline" {
  enabled               = "${var.codepipeline_enabled}"
  source                = "git::https://github.com/cloudposse/terraform-aws-ecs-codepipeline.git?ref=tags/0.7.0"
  name                  = "${var.name}"
  namespace             = "${var.namespace}"
  stage                 = "${var.stage}"
  attributes            = "${var.attributes}"
  github_oauth_token    = "${var.github_oauth_token}"
  github_webhook_events = "${var.github_webhook_events}"
  repo_owner            = "${var.repo_owner}"
  repo_name             = "${var.repo_name}"
  branch                = "${var.branch}"
  badge_enabled         = "${var.badge_enabled}"
  build_image           = "${var.build_image}"
  build_timeout         = "${var.build_timeout}"
  buildspec             = "${var.buildspec}"
  image_repo_name       = "${module.ecr.repository_name}"
  service_name          = "${module.ecs_service_task.service_name}"
  ecs_cluster_name      = "${var.ecs_cluster_name}"
  privileged_mode       = "true"
  poll_source_changes   = "${var.poll_source_changes}"

  webhook_enabled             = "${var.webhook_enabled}"
  webhook_target_action       = "${var.webhook_target_action}"
  webhook_authentication      = "${var.webhook_authentication}"
  webhook_filter_json_path    = "${var.webhook_filter_json_path}"
  webhook_filter_match_equals = "${var.webhook_filter_match_equals}"

  environment_variables = [{
    "name"  = "CONTAINER_NAME"
    "value" = "${module.default_label.id}"
  }]
}

module "autoscaling" {
  enabled               = "${var.autoscaling_enabled}"
  source                = "git::https://github.com/cloudposse/terraform-aws-ecs-cloudwatch-autoscaling.git?ref=tags/0.1.0"
  name                  = "${var.name}"
  namespace             = "${var.namespace}"
  stage                 = "${var.stage}"
  attributes            = "${var.attributes}"
  service_name          = "${module.ecs_service_task.service_name}"
  cluster_name          = "${var.ecs_cluster_name}"
  min_capacity          = "${var.autoscaling_min_capacity}"
  max_capacity          = "${var.autoscaling_max_capacity}"
  scale_down_adjustment = "${var.autoscaling_scale_down_adjustment}"
  scale_down_cooldown   = "${var.autoscaling_scale_down_cooldown}"
  scale_up_adjustment   = "${var.autoscaling_scale_up_adjustment}"
  scale_up_cooldown     = "${var.autoscaling_scale_up_cooldown}"
}

locals {
  cpu_utilization_high_alarm_actions    = "${var.autoscaling_enabled == "true" && var.autoscaling_dimension == "cpu" ? module.autoscaling.scale_up_policy_arn : ""}"
  cpu_utilization_low_alarm_actions     = "${var.autoscaling_enabled == "true" && var.autoscaling_dimension == "cpu" ? module.autoscaling.scale_down_policy_arn : ""}"
  memory_utilization_high_alarm_actions = "${var.autoscaling_enabled == "true" && var.autoscaling_dimension == "memory" ? module.autoscaling.scale_up_policy_arn : ""}"
  memory_utilization_low_alarm_actions  = "${var.autoscaling_enabled == "true" && var.autoscaling_dimension == "memory" ? module.autoscaling.scale_down_policy_arn : ""}"
}

module "ecs_alarms" {
  source     = "git::https://github.com/cloudposse/terraform-aws-ecs-cloudwatch-sns-alarms.git?ref=tags/0.4.0"
  name       = "${var.name}"
  namespace  = "${var.namespace}"
  stage      = "${var.stage}"
  attributes = "${var.attributes}"
  tags       = "${var.tags}"

  enabled      = "${var.ecs_alarms_enabled}"
  cluster_name = "${var.ecs_cluster_name}"
  service_name = "${module.ecs_service_task.service_name}"

  cpu_utilization_high_threshold          = "${var.ecs_alarms_cpu_utilization_high_threshold}"
  cpu_utilization_high_evaluation_periods = "${var.ecs_alarms_cpu_utilization_high_evaluation_periods}"
  cpu_utilization_high_period             = "${var.ecs_alarms_cpu_utilization_high_period}"
  cpu_utilization_high_alarm_actions      = "${compact(concat(var.ecs_alarms_cpu_utilization_high_alarm_actions, list(local.cpu_utilization_high_alarm_actions)))}"
  cpu_utilization_high_ok_actions         = "${var.ecs_alarms_cpu_utilization_high_ok_actions}"

  cpu_utilization_low_threshold          = "${var.ecs_alarms_cpu_utilization_low_threshold}"
  cpu_utilization_low_evaluation_periods = "${var.ecs_alarms_cpu_utilization_low_evaluation_periods}"
  cpu_utilization_low_period             = "${var.ecs_alarms_cpu_utilization_low_period}"
  cpu_utilization_low_alarm_actions      = "${compact(concat(var.ecs_alarms_cpu_utilization_low_alarm_actions, list(local.cpu_utilization_low_alarm_actions)))}"
  cpu_utilization_low_ok_actions         = "${var.ecs_alarms_cpu_utilization_low_ok_actions}"

  memory_utilization_high_threshold          = "${var.ecs_alarms_memory_utilization_high_threshold}"
  memory_utilization_high_evaluation_periods = "${var.ecs_alarms_memory_utilization_high_evaluation_periods}"
  memory_utilization_high_period             = "${var.ecs_alarms_memory_utilization_high_period}"
  memory_utilization_high_alarm_actions      = "${compact(concat(var.ecs_alarms_memory_utilization_high_alarm_actions, list(local.memory_utilization_high_alarm_actions)))}"
  memory_utilization_high_ok_actions         = "${var.ecs_alarms_memory_utilization_high_ok_actions}"

  memory_utilization_low_threshold          = "${var.ecs_alarms_memory_utilization_low_threshold}"
  memory_utilization_low_evaluation_periods = "${var.ecs_alarms_memory_utilization_low_evaluation_periods}"
  memory_utilization_low_period             = "${var.ecs_alarms_memory_utilization_low_period}"
  memory_utilization_low_alarm_actions      = "${compact(concat(var.ecs_alarms_memory_utilization_low_alarm_actions, list(local.memory_utilization_low_alarm_actions)))}"
  memory_utilization_low_ok_actions         = "${var.ecs_alarms_memory_utilization_low_ok_actions}"
}
