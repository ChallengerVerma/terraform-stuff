provider "aws" {
  region = "us-east-1"  # Change this to your desired AWS region
}

resource "aws_ecs_cluster" "my_cluster" {
  name = "my-ecs-cluster"
}

resource "aws_ecs_task_definition" "my_task_definition" {
  # ... (your task definition configuration)
}

resource "aws_ecs_service" "my_service" {
  name            = "my-app-service"
  cluster         = aws_ecs_cluster.my_cluster.id
  task_definition = aws_ecs_task_definition.my_task_definition.arn
  launch_type     = "FARGATE"
  desired_count   = 2  # Initial number of tasks

  network_configuration {
    # ... (your network configuration)
  }
}

resource "aws_appautoscaling_target" "my_scaling_target" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.my_cluster.name}/${aws_ecs_service.my_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_scheduled_action" "scale_up" {
  name                = "scale-up-action"
  scalable_dimension  = aws_appautoscaling_target.my_scaling_target.scalable_dimension
  service_namespace   = aws_appautoscaling_target.my_scaling_target.service_namespace
  resource_id         = aws_appautoscaling_target.my_scaling_target.resource_id
  scalable_target_action {
    scale_out_cooldown = 300  # 5 minutes
    scale_in_cooldown  = 300  # 5 minutes
    estimated_instance_warmup = 300  # 5 minutes
    target_value        = 4    # Desired task count during the scheduled action
  }
  schedule            = "cron(0 8 * * ? *)"  # Scale up every day at 8 AM UTC, adjust as needed
}

resource "aws_appautoscaling_scheduled_action" "scale_down" {
  name                = "scale-down-action"
  scalable_dimension  = aws_appautoscaling_target.my_scaling_target.scalable_dimension
  service_namespace   = aws_appautoscaling_target.my_scaling_target.service_namespace
  resource_id         = aws_appautoscaling_target.my_scaling_target.resource_id
  scalable_target_action {
    scale_out_cooldown = 300  # 5 minutes
    scale_in_cooldown  = 300  # 5 minutes
    estimated_instance_warmup = 300  # 5 minutes
    target_value        = 2    # Desired task count during the scheduled action
  }
  schedule            = "cron(0 18 * * ? *)"  # Scale down every day at 6 PM UTC, adjust as needed
}

resource "aws_iam_role" "ecs_autoscaling_role" {
  name = "ecs-autoscaling-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      }
    },
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "application-autoscaling.amazonaws.com"
      }
    }
  ]
}
EOF
}

resource "aws_iam_policy" "ecs_autoscaling_policy" {
  name        = "ecs-autoscaling-policy"
  description = "IAM policy for ECS Auto Scaling"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:UpdateService",
        "ecs:DescribeServices",
        "ecs:ListTasks",
        "ecs:DescribeTasks",
        "application-autoscaling:RegisterScalableTarget",
        "application-autoscaling:DeregisterScalableTarget",
        "application-autoscaling:DescribeScalableTargets",
        "application-autoscaling:DescribeScalingActivities",
        "cloudwatch:PutMetricAlarm",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:DeleteAlarms"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_autoscaling_attachment" {
  policy_arn = aws_iam_policy.ecs_autoscaling_policy.arn
  role       = aws_iam_role.ecs_autoscaling_role.name
}

