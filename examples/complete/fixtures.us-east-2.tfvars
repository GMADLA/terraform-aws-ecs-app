region = "us-east-2"

availability_zones = ["us-east-2a", "us-east-2b"]

namespace = "eg"

stage = "test"

name = "ecs-app"

vpc_cidr_block = "172.16.0.0/16"

container_image = "cloudposse/default-backend"

container_cpu = 256

container_memory = 512

container_memory_reservation = 128

container_port = 80

container_port_mappings = [
  {
    containerPort = 80
    hostPort      = 80
    protocol      = "tcp"
  }
]

desired_count = 1

launch_type = "FARGATE"

aws_logs_region = "us-east-2"

log_driver = "awslogs"

ecs_alarms_enabled = true

ecs_alarms_cpu_utilization_high_threshold = 80

ecs_alarms_cpu_utilization_high_evaluation_periods = 1

ecs_alarms_cpu_utilization_high_period = 300

ecs_alarms_cpu_utilization_low_threshold = 20

ecs_alarms_cpu_utilization_low_evaluation_periods = 1

ecs_alarms_cpu_utilization_low_period = 300

ecs_alarms_memory_utilization_high_threshold = 80

ecs_alarms_memory_utilization_high_evaluation_periods = 1

ecs_alarms_memory_utilization_high_period = 300

ecs_alarms_memory_utilization_low_threshold = 20

ecs_alarms_memory_utilization_low_evaluation_periods = 1

ecs_alarms_memory_utilization_low_period = 300

autoscaling_enabled = true

autoscaling_dimension = "memory"

autoscaling_min_capacity = 1

autoscaling_max_capacity = 2

autoscaling_scale_up_adjustment = 1

autoscaling_scale_up_cooldown = 60

autoscaling_scale_down_adjustment = -1

autoscaling_scale_down_cooldown = 300

poll_source_changes = false

webhook_enabled = false

webhook_target_action = "Source"

webhook_filter_json_path = "$.ref"

webhook_filter_match_equals = "refs/heads/{Branch}"

codepipeline_enabled = true

codepipeline_s3_bucket_force_destroy = true

codepipeline_github_oauth_token = "test"

codepipeline_github_webhook_events = ["push"]

codepipeline_repo_owner = "cloudposse"

codepipeline_repo_name = "default-backend"

codepipeline_branch = "master"

codepipeline_badge_enabled = false

codepipeline_build_image = "aws/codebuild/docker:17.09.0"

codepipeline_build_timeout = 20

container_environment = []