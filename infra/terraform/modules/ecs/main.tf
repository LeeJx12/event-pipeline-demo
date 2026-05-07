locals {
  namespace_name       = "${var.name_prefix}.local"
  kafka_dns_name       = "kafka.${local.namespace_name}"
  enrichment_dns_name  = "enrichment.${local.namespace_name}"
  producer_log_group   = "/ecs/${var.name_prefix}/producer"
  enrichment_log_group = "/ecs/${var.name_prefix}/enrichment"
  kafka_log_group      = "/ecs/${var.name_prefix}/kafka"

  common_environment = [
    { name = "SPRING_PROFILES_ACTIVE", value = "aws" },
    { name = "MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE", value = "health,info,metrics,prometheus" }
  ]

  # W3-4: Kafka runs as an ephemeral single-node ECS/Fargate service and is
  # discoverable through Cloud Map. Producer should use the Cloud Map DNS name,
  # not localhost and not the old placeholder variable.
  producer_environment = concat(local.common_environment, [
    { name = "SERVER_PORT", value = "9080" },
    { name = "SPRING_KAFKA_BOOTSTRAP_SERVERS", value = "${local.kafka_dns_name}:9092" },
    { name = "KAFKA_BOOTSTRAP_SERVERS", value = "${local.kafka_dns_name}:9092" },
    { name = "APP_KAFKA_BOOTSTRAP_SERVERS", value = "${local.kafka_dns_name}:9092" }
  ])

  enrichment_environment = concat(local.common_environment, [
    { name = "GRPC_SERVER_PORT", value = "9090" },
    { name = "MANAGEMENT_SERVER_PORT", value = "9091" },
    { name = "SPRING_R2DBC_URL", value = "r2dbc:postgresql://${var.db_host}:${var.db_port}/${var.db_name}" },
    { name = "SPRING_R2DBC_USERNAME", value = var.db_username },
    { name = "SPRING_R2DBC_PASSWORD", value = var.db_password },
    { name = "SPRING_FLYWAY_URL", value = "jdbc:postgresql://${var.db_host}:${var.db_port}/${var.db_name}" },
    { name = "SPRING_FLYWAY_USER", value = var.db_username },
    { name = "SPRING_FLYWAY_PASSWORD", value = var.db_password },
    { name = "SPRING_DATA_REDIS_HOST", value = var.redis_host },
    { name = "SPRING_DATA_REDIS_PORT", value = tostring(var.redis_port) }
  ])

  kafka_environment = [
    # Confluent Kafka KRaft single-node config for dev-only ECS/Fargate smoke tests.
    # Keep Cloud Map DNS in advertised.listeners so producer can connect inside the VPC.
    { name = "CLUSTER_ID", value = var.kafka_cluster_id },
    { name = "KAFKA_NODE_ID", value = "1" },
    { name = "KAFKA_PROCESS_ROLES", value = "broker,controller" },
    { name = "KAFKA_CONTROLLER_QUORUM_VOTERS", value = "1@127.0.0.1:9093" },
    { name = "KAFKA_LISTENERS", value = "PLAINTEXT://0.0.0.0:9092,CONTROLLER://127.0.0.1:9093" },
    { name = "KAFKA_ADVERTISED_LISTENERS", value = "PLAINTEXT://${local.kafka_dns_name}:9092" },
    { name = "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP", value = "PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT" },
    { name = "KAFKA_CONTROLLER_LISTENER_NAMES", value = "CONTROLLER" },
    { name = "KAFKA_INTER_BROKER_LISTENER_NAME", value = "PLAINTEXT" },
    { name = "KAFKA_AUTO_CREATE_TOPICS_ENABLE", value = "true" },
    { name = "KAFKA_NUM_PARTITIONS", value = tostring(var.kafka_num_partitions) },
    { name = "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR", value = "1" },
    { name = "KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR", value = "1" },
    { name = "KAFKA_TRANSACTION_STATE_LOG_MIN_ISR", value = "1" },
    { name = "KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS", value = "0" }
  ]
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.name_prefix}-cluster"
  }
}

resource "aws_cloudwatch_log_group" "producer" {
  name              = local.producer_log_group
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "enrichment" {
  name              = local.enrichment_log_group
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "kafka" {
  name              = local.kafka_log_group
  retention_in_days = 3
}

resource "aws_iam_role" "task_execution" {
  name = "${var.name_prefix}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name = "${var.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Allow public HTTP to producer ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-alb-sg"
  }
}

resource "aws_security_group" "service" {
  name        = "${var.name_prefix}-ecs-service-sg"
  description = "Allow ALB to producer and service-to-service traffic"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-ecs-service-sg"
  }
}

resource "aws_security_group_rule" "alb_to_producer" {
  type                     = "ingress"
  description              = "ALB to producer HTTP"
  security_group_id        = aws_security_group.service.id
  source_security_group_id = aws_security_group.alb.id
  from_port                = 9080
  to_port                  = 9080
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "service_to_enrichment_grpc" {
  type              = "ingress"
  description       = "ECS service-to-service gRPC"
  security_group_id = aws_security_group.service.id
  self              = true
  from_port         = 9090
  to_port           = 9090
  protocol          = "tcp"
}

resource "aws_security_group_rule" "service_to_enrichment_actuator" {
  type              = "ingress"
  description       = "ECS service-to-service enrichment actuator"
  security_group_id = aws_security_group.service.id
  self              = true
  from_port         = 9091
  to_port           = 9091
  protocol          = "tcp"
}

resource "aws_security_group_rule" "service_to_kafka" {
  type              = "ingress"
  description       = "ECS service-to-service Kafka"
  security_group_id = aws_security_group.service.id
  self              = true
  from_port         = 9092
  to_port           = 9092
  protocol          = "tcp"
}

resource "aws_lb" "producer" {
  name               = "${var.name_prefix}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "producer" {
  # ALB target group names are limited to 32 chars.
  name        = "ep-${var.environment}-producer-tg"
  port        = 9080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = "/actuator/health"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.producer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.producer.arn
  }
}

resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = local.namespace_name
  description = "Private namespace for ${var.name_prefix} ECS services"
  vpc         = var.vpc_id
}

resource "aws_service_discovery_service" "enrichment" {
  name = "enrichment"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "kafka" {
  name = "kafka"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "kafka" {
  family                   = "${var.name_prefix}-kafka"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.kafka_cpu
  memory                   = var.kafka_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "kafka"
      image     = var.kafka_image
      essential = true
      portMappings = [
        {
          containerPort = 9092
          hostPort      = 9092
          protocol      = "tcp"
        }
      ]
      environment = local.kafka_environment
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.kafka.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "kafka"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "producer" {
  family                   = "${var.name_prefix}-producer"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.producer_cpu
  memory                   = var.producer_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "producer"
      image     = var.producer_image
      essential = true
      portMappings = [
        {
          containerPort = 9080
          hostPort      = 9080
          protocol      = "tcp"
        }
      ]
      environment = local.producer_environment
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.producer.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "producer"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "enrichment" {
  family                   = "${var.name_prefix}-enrichment"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.enrichment_cpu
  memory                   = var.enrichment_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "enrichment"
      image     = var.enrichment_image
      essential = true
      portMappings = [
        {
          containerPort = 9090
          hostPort      = 9090
          protocol      = "tcp"
        },
        {
          containerPort = 9091
          hostPort      = 9091
          protocol      = "tcp"
        }
      ]
      environment = local.enrichment_environment
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.enrichment.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "enrichment"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "kafka" {
  name            = "${var.name_prefix}-kafka"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.kafka.arn
  desired_count   = var.kafka_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.kafka.arn
  }
}

resource "aws_ecs_service" "producer" {
  name            = "${var.name_prefix}-producer"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.producer.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.producer.arn
    container_name   = "producer"
    container_port   = 9080
  }

  depends_on = [
    aws_lb_listener.http,
    aws_ecs_service.kafka
  ]
}

resource "aws_ecs_service" "enrichment" {
  name            = "${var.name_prefix}-enrichment"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.enrichment.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.enrichment.arn
  }
}
