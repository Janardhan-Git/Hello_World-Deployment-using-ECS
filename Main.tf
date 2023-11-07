provider "aws" {
  region = "us-east-1" # Set your desired AWS region
}

# Create a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create subnets
resource "aws_subnet" "my_subnet" {
  count             = 2
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = "us-east-1a" # Adjust the availability zone as needed
}

# Create an Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}

# Create a Route Table
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

# Create a Security Group for the ECS service
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-security-group"
  description = "Security group for ECS"

  # Define your security group rules as needed
  # For example, allow incoming traffic on port 80 for your application
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an ECS cluster
resource "aws_ecs_cluster" "my_cluster" {
  name = "my-ecs-cluster"
}

# Create an IAM role for ECS tasks
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
      },
    ],
  })
}

# Attach an IAM policy to the ECS task execution role (customize as needed)
resource "aws_iam_policy_attachment" "ecs_execution_role_policy" {
  name = "mypolicy"

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
}

# Create a Task Definition for your containerized application
resource "aws_ecs_task_definition" "my_task" {
  family                   = "my-container-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  # Define your container definition
  container_definitions = jsonencode([
    {
      name  = "my-container"
      image = "nginx"
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        },
      ],
    },
  ])

  # Memory and CPU configuration for Fargate
  memory = "512" # Specify the desired memory (in MiB)
  cpu    = "256" # Specify the desired CPU units
}

# Create an ECS service to run the task
resource "aws_ecs_service" "my_service" {
  name            = "my-ecs-service"
  cluster         = aws_ecs_cluster.my_cluster.arn      # Use ARN
  task_definition = aws_ecs_task_definition.my_task.arn # Use ARN
  launch_type     = "FARGATE"

  network_configuration {
    subnets         =[aws_subnet.my_subnet[0].id]
    
      }

  # Configure desired count and other service settings
  desired_count = 1
}

# Output the ECS service name
output "ecs_service_name" {
  value = aws_ecs_service.my_service.name
}