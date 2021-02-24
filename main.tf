module "ecr" {
  source  = "cloudposse/ecr/aws"
  version = "0.29.2"
  enabled = var.codepipeline_enabled

  attributes          = ["ecr"]
  scan_images_on_push = var.ecr_scan_images_on_push

  context = module.this.context
}

resource "aws_cloudwatch_log_group" "app" {
  count = var.cloudwatch_log_group_enabled ? 1 : 0

  name              = module.this.id
  tags              = module.this.tags
  retention_in_days = var.log_retention_in_days
}


module "container_definition" {
  source                       = "cloudposse/ecs-container-definition/aws"
  version                      = "0.47.0"
  container_name               = module.this.id
  container_image              = var.use_ecr_image ? module.ecr.repository_url : var.container_image
  container_memory             = var.container_memory
  container_memory_reservation = var.container_memory_reservation
  container_cpu                = var.container_cpu
  start_timeout                = var.container_start_timeout
  stop_timeout                 = var.container_stop_timeout
  healthcheck                  = var.healthcheck
  environment                  = var.container_environment
  map_environment              = var.map_container_environment
  port_mappings                = var.port_mappings
  privileged                   = var.privileged
  secrets                      = var.secrets
  system_controls              = var.system_controls
  ulimits                      = var.ulimits
  entrypoint                   = var.entrypoint
  command                      = var.command
  mount_points                 = var.mount_points
  container_depends_on         = local.container_depends_on

  log_configuration = var.cloudwatch_log_group_enabled ? {
    logDriver = var.log_driver
    options = {
      "awslogs-region"        = var.aws_logs_region
      "awslogs-group"         = join("", aws_cloudwatch_log_group.app.*.name)
      "awslogs-stream-prefix" = var.aws_logs_prefix == "" ? module.this.name : var.aws_logs_prefix
    }
    secretOptions = null
  } : null
}

locals {
  init_container_definitions = [
    for init_container in var.init_containers : lookup(init_container, "container_definition")
  ]

  container_depends_on = [
    for init_container in var.init_containers :
    {
      containerName = lookup(jsondecode(init_container.container_definition), "name"),
      condition     = init_container.condition
    }
  ]

  # override container_definition if var.container_definition is supplied
  main_container_definition = coalesce(var.container_definition, module.container_definition.json_map_encoded)
  # combine all container definitions
  all_container_definitions = "[${join(",", concat(local.init_container_definitions, [local.main_container_definition]))}]"
}

# Deviation from CloudPosse module allows launching service without ALB.
# module "ecs_service_task" {
#   source                            = "./ecs_service_task"

#   name                              = "${var.name}"
#   namespace                         = "${var.namespace}"
#   stage                             = "${var.stage}"
#   attributes                        = "${var.attributes}"

#   container_definition_json         = local.all_container_definitions
#   desired_count                     = var.desired_count
#   health_check_grace_period_seconds = var.health_check_grace_period_seconds
#   task_cpu                          = coalesce(var.task_cpu, var.container_cpu)
#   task_memory                       = coalesce(var.task_memory, var.container_memory)
#   ignore_changes_task_definition    = var.ignore_changes_task_definition
#   ecs_cluster_arn                   = var.ecs_cluster_arn
#   capacity_provider_strategies      = var.capacity_provider_strategies
#   service_registries                = var.service_registries
#   launch_type                       = var.launch_type
#   platform_version                  = var.platform_version
#   vpc_id                            = var.vpc_id
#   assign_public_ip                  = var.assign_public_ip
#   security_group_ids                = var.ecs_security_group_ids
#   subnet_ids                        = var.ecs_private_subnet_ids
#   container_port                    = var.container_port
#   volumes                           = var.volumes
#   deployment_controller_type        = var.deployment_controller_type

#   context = module.this.context
# }

module "ecs_service_task" {
  source  = "cloudposse/ecs-alb-service-task/aws"
  version = "0.44.0"

  alb_security_group                = ""
  use_alb_security_group            = false
  container_definition_json         = local.all_container_definitions
  desired_count                     = var.desired_count
  health_check_grace_period_seconds = var.health_check_grace_period_seconds
  task_cpu                          = coalesce(var.task_cpu, var.container_cpu)
  task_memory                       = coalesce(var.task_memory, var.container_memory)
  ignore_changes_task_definition    = var.ignore_changes_task_definition
  ecs_cluster_arn                   = var.ecs_cluster_arn
  capacity_provider_strategies      = var.capacity_provider_strategies
  service_registries                = var.service_registries
  launch_type                       = var.launch_type
  platform_version                  = var.platform_version
  vpc_id                            = var.vpc_id
  assign_public_ip                  = var.assign_public_ip
  security_group_ids                = var.ecs_security_group_ids
  subnet_ids                        = var.ecs_private_subnet_ids
  container_port                    = var.container_port
  volumes                           = var.volumes
  ecs_load_balancers                = []
  deployment_controller_type        = var.deployment_controller_type

  context = module.this.context
}

module "ecs_codepipeline" {
  enabled = var.codepipeline_enabled
  source  = "cloudposse/ecs-codepipeline/aws"
  version = "0.23.0"

  region                      = var.region
  github_oauth_token          = var.github_oauth_token
  github_webhooks_token       = var.github_webhooks_token
  github_webhook_events       = var.github_webhook_events
  repo_owner                  = var.repo_owner
  repo_name                   = var.repo_name
  branch                      = var.branch
  badge_enabled               = var.badge_enabled
  build_image                 = var.build_image
  build_compute_type          = var.codepipeline_build_compute_type
  build_timeout               = var.build_timeout
  buildspec                   = var.buildspec
  cache_bucket_suffix_enabled = var.codepipeline_build_cache_bucket_suffix_enabled
  image_repo_name             = module.ecr.repository_name
  service_name                = module.ecs_service_task.service_name
  ecs_cluster_name            = var.ecs_cluster_name
  privileged_mode             = true
  poll_source_changes         = var.poll_source_changes

  webhook_enabled             = var.webhook_enabled
  webhook_target_action       = var.webhook_target_action
  webhook_authentication      = var.webhook_authentication
  webhook_filter_json_path    = var.webhook_filter_json_path
  webhook_filter_match_equals = var.webhook_filter_match_equals

  s3_bucket_force_destroy = var.codepipeline_s3_bucket_force_destroy

  environment_variables = concat(
    var.build_environment_variables,
    [
      {
        name  = "CONTAINER_NAME"
        value = module.this.id
      }
    ]
  )

  context = module.this.context
}

module "ecs_cloudwatch_autoscaling" {
  enabled               = var.autoscaling_enabled
  source                = "cloudposse/ecs-cloudwatch-autoscaling/aws"
  version               = "0.5.1"
  name                  = var.name
  namespace             = var.namespace
  stage                 = var.stage
  attributes            = var.attributes
  service_name          = module.ecs_service_task.service_name
  cluster_name          = var.ecs_cluster_name
  min_capacity          = var.autoscaling_min_capacity
  max_capacity          = var.autoscaling_max_capacity
  scale_down_adjustment = var.autoscaling_scale_down_adjustment
  scale_down_cooldown   = var.autoscaling_scale_down_cooldown
  scale_up_adjustment   = var.autoscaling_scale_up_adjustment
  scale_up_cooldown     = var.autoscaling_scale_up_cooldown
}

locals {
  cpu_utilization_high_alarm_actions    = var.autoscaling_enabled && var.autoscaling_dimension == "cpu" ? module.ecs_cloudwatch_autoscaling.scale_up_policy_arn : ""
  cpu_utilization_low_alarm_actions     = var.autoscaling_enabled && var.autoscaling_dimension == "cpu" ? module.ecs_cloudwatch_autoscaling.scale_down_policy_arn : ""
  memory_utilization_high_alarm_actions = var.autoscaling_enabled && var.autoscaling_dimension == "memory" ? module.ecs_cloudwatch_autoscaling.scale_up_policy_arn : ""
  memory_utilization_low_alarm_actions  = var.autoscaling_enabled && var.autoscaling_dimension == "memory" ? module.ecs_cloudwatch_autoscaling.scale_down_policy_arn : ""
}

module "ecs_cloudwatch_sns_alarms" {
  source  = "cloudposse/ecs-cloudwatch-sns-alarms/aws"
  version = "0.8.1"
  enabled = var.ecs_alarms_enabled

  cluster_name = var.ecs_cluster_name
  service_name = module.ecs_service_task.service_name

  cpu_utilization_high_threshold          = var.ecs_alarms_cpu_utilization_high_threshold
  cpu_utilization_high_evaluation_periods = var.ecs_alarms_cpu_utilization_high_evaluation_periods
  cpu_utilization_high_period             = var.ecs_alarms_cpu_utilization_high_period

  cpu_utilization_high_alarm_actions = compact(
    concat(
      var.ecs_alarms_cpu_utilization_high_alarm_actions,
      [local.cpu_utilization_high_alarm_actions],
    )
  )

  cpu_utilization_high_ok_actions = var.ecs_alarms_cpu_utilization_high_ok_actions

  cpu_utilization_low_threshold          = var.ecs_alarms_cpu_utilization_low_threshold
  cpu_utilization_low_evaluation_periods = var.ecs_alarms_cpu_utilization_low_evaluation_periods
  cpu_utilization_low_period             = var.ecs_alarms_cpu_utilization_low_period

  cpu_utilization_low_alarm_actions = compact(
    concat(
      var.ecs_alarms_cpu_utilization_low_alarm_actions,
      [local.cpu_utilization_low_alarm_actions],
    )
  )

  cpu_utilization_low_ok_actions = var.ecs_alarms_cpu_utilization_low_ok_actions

  memory_utilization_high_threshold          = var.ecs_alarms_memory_utilization_high_threshold
  memory_utilization_high_evaluation_periods = var.ecs_alarms_memory_utilization_high_evaluation_periods
  memory_utilization_high_period             = var.ecs_alarms_memory_utilization_high_period

  memory_utilization_high_alarm_actions = compact(
    concat(
      var.ecs_alarms_memory_utilization_high_alarm_actions,
      [local.memory_utilization_high_alarm_actions],
    )
  )

  memory_utilization_high_ok_actions = var.ecs_alarms_memory_utilization_high_ok_actions

  memory_utilization_low_threshold          = var.ecs_alarms_memory_utilization_low_threshold
  memory_utilization_low_evaluation_periods = var.ecs_alarms_memory_utilization_low_evaluation_periods
  memory_utilization_low_period             = var.ecs_alarms_memory_utilization_low_period

  memory_utilization_low_alarm_actions = compact(
    concat(
      var.ecs_alarms_memory_utilization_low_alarm_actions,
      [local.memory_utilization_low_alarm_actions],
    )
  )

  memory_utilization_low_ok_actions = var.ecs_alarms_memory_utilization_low_ok_actions

  context = module.this.context
}
