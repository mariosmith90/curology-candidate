######################
# IAM
######################

resource "aws_iam_role" "curology_role" {
  name = "${var.environment}-curology-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "curology_role_policy_attachment" {
  role       = aws_iam_role.curology_role.name
  policy_arn = aws_iam_policy.curology_policy.arn
}

resource "aws_iam_role_policy_attachment" "curology_ecs_task_execution_role" {
  role       = aws_iam_role.curology_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "curology_policy" {
  name        = "${var.environment}-curology-policy"
  description = "Policy for ECS tasks to interact with ECR, CloudWatch Logs, and Target Groups."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetAuthorizationToken",
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "*"
      }
    ]
  })
}

######################
# ECS
######################

resource "aws_ecs_cluster" "curology_cluster" {
  name = "${var.environment}-curology-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "curology_service_log_group" {
  name = "${var.environment}/curology/log-group"

  tags = {
    Environment = var.environment
    Application = "${var.environment}-service"
  }
}

resource "aws_ecs_service" "curology_service" {
  name            = "${var.environment}-curology-service"
  cluster         = aws_ecs_cluster.curology_cluster.id
  task_definition = aws_ecs_task_definition.curology_definition.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  depends_on = [
    aws_iam_policy.curology_policy
  ]

  network_configuration {
    assign_public_ip = true

    subnets = [
      module.vpc.public_subnets[0],
      module.vpc.public_subnets[1],
      module.vpc.public_subnets[2]
    ]

    security_groups = [
      aws_security_group.curology_ecs_security_group.id    
    ]
  }
}

resource "aws_secretsmanager_secret" "curoloy_rds_password" {
  name = "${var.environment}/rds/password"
}

resource "aws_ecr_repository" "curology_repo" {
  name                 = "${var.environment}-hello-world"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecs_task_definition" "curology_definition" {
  family                   = "${var.environment}-curology-definition"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 2048
  memory                   = 4096
  execution_role_arn       = aws_iam_role.curology_role.arn
  container_definitions = templatefile("${path.module}/definitions/task_definition.json", {
    db_name     = "curology"
    db_user     = "curology"
    revision    = var.revision
    environment = var.environment
    db_host     = module.db.db_instance_endpoint
    db_password = aws_secretsmanager_secret.curoloy_rds_password.arn
    log_group   = aws_cloudwatch_log_group.curology_service_log_group.name
  })

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
}

######################
# AUTOSCALING
######################

resource "aws_appautoscaling_target" "curology_scaling_target" {
  max_capacity       = 100
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.curology_cluster.name}/${aws_ecs_service.curology_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "curology_scaling_policy" {
  name               = "${var.environment}-curology-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.curology_scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.curology_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.curology_scaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 75.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

######################
# VPC COMPONENTS
######################

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.us-west-2.ecr.dkr"
  vpc_endpoint_type = "Interface"
  subnet_ids        = module.vpc.public_subnets

  security_group_ids = [
    aws_security_group.curology_ecs_security_group.id    
  ]

  private_dns_enabled = true
  tags = {
    Name = "${var.environment}-ecr-dkr-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.us-west-2.ecr.api"
  vpc_endpoint_type = "Interface"
  subnet_ids        = module.vpc.public_subnets

  security_group_ids = [
    aws_security_group.curology_ecs_security_group.id    
  ]

  private_dns_enabled = true
  tags = {
    Name = "${var.environment}-ecr-api-endpoint"
  }
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.us-west-2.logs"
  vpc_endpoint_type = "Interface"
  subnet_ids        = module.vpc.public_subnets

  security_group_ids = [
    aws_security_group.curology_ecs_security_group.id    
  ]

  private_dns_enabled = true
  tags = {
    Name = "${var.environment}-logs-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.us-west-2.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids        = module.vpc.public_subnets

  security_group_ids = [
    aws_security_group.curology_ecs_security_group.id    
  ]

  private_dns_enabled = true
  tags = {
    Name = "${var.environment}-ssm-endpoint"
  }
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.us-west-2.secretsmanager"
  vpc_endpoint_type = "Interface"
  subnet_ids        = module.vpc.public_subnets

  security_group_ids = [
    aws_security_group.curology_ecs_security_group.id    
  ]

  private_dns_enabled = true
  tags = {
    Name = "${var.environment}-secretsmanager-endpoint"
  }
}


resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.us-west-2.s3"
  vpc_endpoint_type = "Gateway"

  tags = {
    Name = "${var.environment}-s3-endpoint"
  }
}

resource "aws_security_group" "curology_ecs_security_group" {
  name        = "${var.environment}-hello-world"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = module.vpc.vpc_id
}


resource "aws_security_group_rule" "allow_https_inbound" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.curology_ecs_security_group.id
}

resource "aws_security_group_rule" "allow_https_outbound" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.curology_ecs_security_group.id
}
