package test

import (
	"encoding/json"
	"testing"

	"math/rand"
	"strconv"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// Test the Terraform module in examples/complete using Terratest.
func TestExamplesComplete(t *testing.T) {
	t.Parallel()

	rand.Seed(time.Now().UnixNano())

	attributes := []string{strconv.Itoa(rand.Intn(1000))}

	// We need to create these assets first because terraform does not wait for it to be in the ready state before creating ECS target group
	terraformOptions := &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: "../../examples/complete",
		Upgrade:      true,
		// Variables to pass to our Terraform code using -var-file options
		VarFiles: []string{"fixtures.us-east-2.tfvars"},
		Vars: map[string]interface{}{
			"attributes": attributes,
		},
		Targets: []string{"module.this", "module.vpc", "module.subnets"},
	}

	// At the end of the test, run `terraform destroy` to clean up any resources that were created
	defer terraform.Destroy(t, terraformOptions)

	// This will run `terraform init` and `terraform apply` and fail the test if there are any errors
	terraform.InitAndApply(t, terraformOptions)

	terraformOptions.Targets = nil

	// This will run `terraform init` and `terraform apply` and fail the test if there are any errors
	terraform.Apply(t, terraformOptions)

	// Run `terraform output` to get the value of an output variable
	vpcCidr := terraform.Output(t, terraformOptions, "vpc_cidr")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, "172.16.0.0/16", vpcCidr)

	// Run `terraform output` to get the value of an output variable
	privateSubnetCidrs := terraform.OutputList(t, terraformOptions, "private_subnet_cidrs")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, []string{"172.16.0.0/19", "172.16.32.0/19"}, privateSubnetCidrs)

	// Run `terraform output` to get the value of an output variable
	publicSubnetCidrs := terraform.OutputList(t, terraformOptions, "public_subnet_cidrs")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, []string{"172.16.96.0/19", "172.16.128.0/19"}, publicSubnetCidrs)

	// Run `terraform output` to get the value of an output variable
	containerDefinitionJSONMap := terraform.OutputRequired(t, terraformOptions, "container_definition_json_map")
	// Verify we're getting back the outputs we expect
	var jsonObject map[string]interface{}
	err := json.Unmarshal([]byte(containerDefinitionJSONMap), &jsonObject)
	assert.NoError(t, err)
	expectedContainerDefinitionName := "eg-test-ecs-web-app-" + attributes[0]
	assert.Equal(t, expectedContainerDefinitionName, jsonObject["name"])
	assert.Equal(t, "cloudposse/default-backend", jsonObject["image"])
	assert.Equal(t, 512, int((jsonObject["memory"]).(float64)))
	assert.Equal(t, 128, int((jsonObject["memoryReservation"]).(float64)))
	assert.Equal(t, 256, int((jsonObject["cpu"]).(float64)))
	assert.Equal(t, true, jsonObject["essential"])
	assert.Equal(t, false, jsonObject["readonlyRootFilesystem"])

	// Run `terraform output` to get the value of an output variable
	codebuildCacheBucketName := terraform.Output(t, terraformOptions, "codebuild_cache_bucket_name")
	// Verify we're getting back the outputs we expect
	expectedCodebuildCacheBucketName := "eg-test-ecs-web-app-build-" + attributes[0]
	assert.Contains(t, codebuildCacheBucketName, expectedCodebuildCacheBucketName)

	// Run `terraform output` to get the value of an output variable
	codebuildProjectName := terraform.Output(t, terraformOptions, "codebuild_project_name")
	// Verify we're getting back the outputs we expect
	expectedCodebuildProjectName := "eg-test-ecs-web-app-build-" + attributes[0]
	assert.Equal(t, expectedCodebuildProjectName, codebuildProjectName)

	// Run `terraform output` to get the value of an output variable
	codebuildRoleID := terraform.Output(t, terraformOptions, "codebuild_role_id")
	// Verify we're getting back the outputs we expect
	expectedcodebuildRoleID := "eg-test-ecs-web-app-build-" + attributes[0]
	assert.Equal(t, expectedcodebuildRoleID, codebuildRoleID)

	// Run `terraform output` to get the value of an output variable
	codepipelineID := terraform.Output(t, terraformOptions, "codepipeline_id")
	// Verify we're getting back the outputs we expect
	expectedcodepipelineID := "eg-test-ecs-web-app-" + attributes[0] + "-codepipeline"
	assert.Equal(t, expectedcodepipelineID, codepipelineID)

	// Run `terraform output` to get the value of an output variable
	ecrRepositoryName := terraform.Output(t, terraformOptions, "ecr_repository_name")
	// Verify we're getting back the outputs we expect
	expectedEcrRepositoryName := "eg-test-ecs-web-app-ecr-" + attributes[0]
	assert.Equal(t, expectedEcrRepositoryName, ecrRepositoryName)

	// Run `terraform output` to get the value of an output variable
	ecsTaskRoleName := terraform.Output(t, terraformOptions, "ecs_task_role_name")
	// Verify we're getting back the outputs we expect
	expectedEcsTaskRoleName := "eg-test-ecs-web-app-" + attributes[0] + "-task"
	assert.Equal(t, expectedEcsTaskRoleName, ecsTaskRoleName)

	// Run `terraform output` to get the value of an output variable
	ecsTaskExecRoleName := terraform.Output(t, terraformOptions, "ecs_task_exec_role_name")
	// Verify we're getting back the outputs we expect
	expectedEcsTaskExecRoleName := "eg-test-ecs-web-app-" + attributes[0] + "-exec"
	assert.Equal(t, expectedEcsTaskExecRoleName, ecsTaskExecRoleName)

	// Run `terraform output` to get the value of an output variable
	ecsServiceName := terraform.Output(t, terraformOptions, "ecs_service_name")
	// Verify we're getting back the outputs we expect
	expectedEcsServiceName := "eg-test-ecs-web-app-" + attributes[0]
	assert.Equal(t, expectedEcsServiceName, ecsServiceName)

	// Run `terraform output` to get the value of an output variable
	ecsExecRolePolicyName := terraform.Output(t, terraformOptions, "ecs_exec_role_policy_name")
	// Verify we're getting back the outputs we expect
	expectedEcsExecRolePolicyName := "eg-test-ecs-web-app-" + attributes[0] + "-exec"
	assert.Equal(t, expectedEcsExecRolePolicyName, ecsExecRolePolicyName)

	// Run `terraform output` to get the value of an output variable
	ecsCloudwatchAutoscalingScaleDownPolicyArn := terraform.Output(t, terraformOptions, "ecs_cloudwatch_autoscaling_scale_down_policy_arn")
	// Verify we're getting back the outputs we expect
	expectedEcsCloudwatchAutoscalingScaleDownPolicyArn := "policyName/down"
	assert.Contains(t, ecsCloudwatchAutoscalingScaleDownPolicyArn, expectedEcsCloudwatchAutoscalingScaleDownPolicyArn)

	// Run `terraform output` to get the value of an output variable
	ecsCloudwatchAutoscalingScaleUpPolicyArn := terraform.Output(t, terraformOptions, "ecs_cloudwatch_autoscaling_scale_up_policy_arn")
	// Verify we're getting back the outputs we expect
	expectedEcsCloudwatchAutoscalingScaleUpPolicyArn := "policyName/up"
	assert.Contains(t, ecsCloudwatchAutoscalingScaleUpPolicyArn, expectedEcsCloudwatchAutoscalingScaleUpPolicyArn)

	// Run `terraform output` to get the value of an output variable
	ecsAlarmsCPUUtilizationHighCloudwatchMetricAlarmID := terraform.Output(t, terraformOptions, "ecs_alarms_cpu_utilization_high_cloudwatch_metric_alarm_id")
	// Verify we're getting back the outputs we expect
	expectedecsAlarmsCPUUtilizationHighCloudwatchMetricAlarmID := "eg-test-ecs-web-app-cpu-utilization-high-" + attributes[0]
	assert.Equal(t, expectedecsAlarmsCPUUtilizationHighCloudwatchMetricAlarmID, ecsAlarmsCPUUtilizationHighCloudwatchMetricAlarmID)

	// Run `terraform output` to get the value of an output variable
	ecsAlarmsCPUUtilizationLowCloudwatchMetricAlarmID := terraform.Output(t, terraformOptions, "ecs_alarms_cpu_utilization_low_cloudwatch_metric_alarm_id")
	// Verify we're getting back the outputs we expect
	expectedecsAlarmsCPUUtilizationLowCloudwatchMetricAlarmID := "eg-test-ecs-web-app-cpu-utilization-low-" + attributes[0]
	assert.Equal(t, expectedecsAlarmsCPUUtilizationLowCloudwatchMetricAlarmID, ecsAlarmsCPUUtilizationLowCloudwatchMetricAlarmID)

	// Run `terraform output` to get the value of an output variable
	ecsAlarmsMemoryUtilizationHighCloudwatchMetricAlarmID := terraform.Output(t, terraformOptions, "ecs_alarms_memory_utilization_high_cloudwatch_metric_alarm_id")
	// Verify we're getting back the outputs we expect
	expectedecsAlarmsMemoryUtilizationHighCloudwatchMetricAlarmID := "eg-test-ecs-web-app-memory-utilization-high-" + attributes[0]
	assert.Equal(t, expectedecsAlarmsMemoryUtilizationHighCloudwatchMetricAlarmID, ecsAlarmsMemoryUtilizationHighCloudwatchMetricAlarmID)

	// Run `terraform output` to get the value of an output variable
	ecsAlarmsMemoryUtilizationLowCloudwatchMetricAlarmID := terraform.Output(t, terraformOptions, "ecs_alarms_memory_utilization_low_cloudwatch_metric_alarm_id")
	// Verify we're getting back the outputs we expect
	expectedecsAlarmsMemoryUtilizationLowCloudwatchMetricAlarmID := "eg-test-ecs-web-app-memory-utilization-low-" + attributes[0]
	assert.Equal(t, expectedecsAlarmsMemoryUtilizationLowCloudwatchMetricAlarmID, ecsAlarmsMemoryUtilizationLowCloudwatchMetricAlarmID)

	// Run `terraform output` to get the value of an output variable
	httpcodeElb5xxCountCloudwatchMetricAlarmID := terraform.Output(t, terraformOptions, "httpcode_elb_5xx_count_cloudwatch_metric_alarm_id")
	// Verify we're getting back the outputs we expect
	expectedhttpcodeElb5xxCountCloudwatchMetricAlarmID := "eg-test-ecs-web-app-elb-5xx-count-high-" + attributes[0]
	assert.Equal(t, expectedhttpcodeElb5xxCountCloudwatchMetricAlarmID, httpcodeElb5xxCountCloudwatchMetricAlarmID)

	// Run `terraform output` to get the value of an output variable
	httpcodeTarget3xxCountCloudwatchMetricAlarmID := terraform.Output(t, terraformOptions, "httpcode_target_3xx_count_cloudwatch_metric_alarm_id")
	// Verify we're getting back the outputs we expect
	expectedhttpcodeTarget3xxCountCloudwatchMetricAlarmID := "eg-test-ecs-web-app-3xx-count-high-" + attributes[0]
	assert.Equal(t, expectedhttpcodeTarget3xxCountCloudwatchMetricAlarmID, httpcodeTarget3xxCountCloudwatchMetricAlarmID)

	// Run `terraform output` to get the value of an output variable
	httpcodeTarget4xxCountCloudwatchMetricAlarmID := terraform.Output(t, terraformOptions, "httpcode_target_4xx_count_cloudwatch_metric_alarm_id")
	// Verify we're getting back the outputs we expect
	expectedhttpcodeTarget4xxCountCloudwatchMetricAlarmID := "eg-test-ecs-web-app-4xx-count-high-" + attributes[0]
	assert.Equal(t, expectedhttpcodeTarget4xxCountCloudwatchMetricAlarmID, httpcodeTarget4xxCountCloudwatchMetricAlarmID)

	// Run `terraform output` to get the value of an output variable
	httpcodeTarget5xxCountCloudwatchMetricAlarmID := terraform.Output(t, terraformOptions, "httpcode_target_5xx_count_cloudwatch_metric_alarm_id")
	// Verify we're getting back the outputs we expect
	expectedhttpcodeTarget5xxCountCloudwatchMetricAlarmID := "eg-test-ecs-web-app-5xx-count-high-" + attributes[0]
	assert.Equal(t, expectedhttpcodeTarget5xxCountCloudwatchMetricAlarmID, httpcodeTarget5xxCountCloudwatchMetricAlarmID)

	// Run `terraform output` to get the value of an output variable
	targetResponseTimeAverageCloudwatchMetricAlarmID := terraform.Output(t, terraformOptions, "target_response_time_average_cloudwatch_metric_alarm_id")
	// Verify we're getting back the outputs we
	expectedtargetResponseTimeAverageCloudwatchMetricAlarmID := "eg-test-ecs-web-app-target-response-high-" + attributes[0]
	assert.Equal(t, expectedtargetResponseTimeAverageCloudwatchMetricAlarmID, targetResponseTimeAverageCloudwatchMetricAlarmID)
}
