resource "aws_ecr_repository" "soat_backend_image" {
  name = "registry.hub.docker.com/g0tn/soat-tech-challenge-backend"
}

resource "aws_instance" "ecs_host" {
  ami           = "ami-0fa399d9c130ec923"
  instance_type = "t2.micro"
  subnet_id     = var.subnet_a_id
}

resource "aws_ecs_cluster" "soat_ecs_cluster" {
  name = "soat-tech-challenge-ecs-cluster"
}

data "aws_db_instance" "db_instance" {
  db_instance_identifier = "soat-rds-postgres-db"
}

resource "aws_ecs_task_definition" "soat_ecs_cluster_task" {
  family                   = "soat-ecs-cluster-task"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "soat-ecs-cluster-task",
      "image": "${aws_ecr_repository.soat_backend_image.repository_url}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "hostPort": 8080
        }
      ],
      "environment": [
        {
          "name": "DB_USERNAME",
          "value": "${var.ecs_container_db_username}"
        },
        {
          "name": "DB_PASSWORD",
          "value": "${var.ecs_container_db_password}"
        },
        {
          "name": "DB_NAME",
          "value": "${var.ecs_container_db_name}"
        },
        {
          "name": "DB_PORT",
          "value": "${var.ecs_container_db_port}"
        },
        {
          "name": "DB_HOST",
          "value": "${data.aws_db_instance.db_instance.endpoint}"
        }
      ]
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  memory                   = 512
  cpu                      = 256
  execution_role_arn       = aws_iam_role.soat_ecs_task_execution_role.arn
}

resource "aws_ecs_service" "soat_ecs_service" {
  name            = "soat-ecs-service"
  cluster         = aws_ecs_cluster.soat_ecs_cluster.id
  task_definition = aws_ecs_task_definition.soat_ecs_cluster_task.arn
  launch_type     = "EC2"
  desired_count   = 3

  load_balancer {
    target_group_arn = aws_lb_target_group.soat_alb_target_group.arn
    container_name   = "soat-ecs-cluster-task"
    container_port   = var.port
  }

  network_configuration {
    subnets = [
      var.subnet_a_id,
      var.subnet_b_id
    ]
    security_groups = [aws_security_group.soat_ecs_security_group.id]
  }
}

resource "aws_security_group" "soat_ecs_security_group" {
  vpc_id = var.vpc_id
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.soat_alb_security_group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
