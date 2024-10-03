provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "us-east-2"
  region = "us-east-2"
}

# Create a VPC in us-east-1
resource "aws_vpc" "norton_vpc" {
  provider   = aws.us-east-1
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "norton-vpc"
  }
}

# Create subnets in us-east-1
resource "aws_subnet" "public_subnet_1a" {
  provider                  = aws.us-east-1
  vpc_id                    = aws_vpc.norton_vpc.id
  cidr_block                = "10.0.1.0/24"
  map_public_ip_on_launch   = true
  availability_zone         = "us-east-1a"
  tags = {
    Name = "public-subnet-1a"
  }
}

resource "aws_subnet" "public_subnet_1b" {
  provider                  = aws.us-east-1
  vpc_id                    = aws_vpc.norton_vpc.id
  cidr_block                = "10.0.3.0/24"
  map_public_ip_on_launch   = true
  availability_zone         = "us-east-1b"
  tags = {
    Name = "public-subnet-1b"
  }
}

# Create an Internet Gateway in us-east-1
resource "aws_internet_gateway" "igw" {
  provider = aws.us-east-1
  vpc_id   = aws_vpc.norton_vpc.id
  tags = {
    Name = "internet-gateway"
  }
}

# Create a Route Table in us-east-1
resource "aws_route_table" "public_rt" {
  provider = aws.us-east-1
  vpc_id   = aws_vpc.norton_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate Route Table with Subnet in us-east-1
resource "aws_route_table_association" "public_rt_assoc_1a" {
  provider        = aws.us-east-1
  subnet_id       = aws_subnet.public_subnet_1a.id
  route_table_id  = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_assoc_1b" {
  provider        = aws.us-east-1
  subnet_id       = aws_subnet.public_subnet_1b.id
  route_table_id  = aws_route_table.public_rt.id
}

# Security Group in us-east-1
resource "aws_security_group" "web_sg" {
  provider = aws.us-east-1
  vpc_id   = aws_vpc.norton_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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
    Name = "web-sg"
  }
}

# IAM Role in us-east-1
resource "aws_iam_role" "ec2_role" {
  provider = aws.us-east-1
  name     = "ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# IAM Role Policy in us-east-1
resource "aws_iam_role_policy" "ec2_policy" {
  provider = aws.us-east-1
  name     = "ec2-policy"
  role     = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = "ec2:Describe*",
      Effect   = "Allow",
      Resource = "*"
    }]
  })
}

# IAM Instance Profile in us-east-1
resource "aws_iam_instance_profile" "ec2_profile" {
  provider = aws.us-east-1
  name     = "ec2-profile"
  role     = aws_iam_role.ec2_role.name
}

# EC2 Instances in us-east-1 Web server
resource "aws_instance" "web_instance_1a_1" {
  provider                 = aws.us-east-1
  ami                      = "ami-0b72821e2f351e396" # Amazon Linux 2 AMI
  instance_type            = "t2.micro"
  subnet_id                = aws_subnet.public_subnet_1a.id
  vpc_security_group_ids   = [aws_security_group.web_sg.id]
  iam_instance_profile     = aws_iam_instance_profile.ec2_profile.name
 

  tags = {
    Name = "web-instance-1a-1"
  }
}

# EC2 Instances in us-east-1 Application server

resource "aws_instance" "web_instance_1a_2" {
  provider                 = aws.us-east-1
  ami                      = "ami-0b72821e2f351e396" # Amazon Linux 2 AMI
  instance_type            = "t2.micro"
  subnet_id                = aws_subnet.public_subnet_1a.id
  vpc_security_group_ids   = [aws_security_group.web_sg.id]
  iam_instance_profile     = aws_iam_instance_profile.ec2_profile.name
   user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd mysql
              systemctl start httpd
              systemctl enable httpd
              echo "Hello World from $(hostname -f)" > /var/www/html/index.html
              echo "RDS Endpoint: ${aws_db_instance.default.endpoint}" >> /var/www/html/index.html
              EOF

  tags = {
    Name = "web-instance-1a-2"
  }
}

# Auto Scaling Group for Web Instances in us-east-1a
resource "aws_autoscaling_group" "web_asg_us_east_1a" {
  provider                 = aws.us-east-1
  desired_capacity         = 2
  max_size                 = 4
  min_size                 = 1
  vpc_zone_identifier      = [aws_subnet.public_subnet_1a.id] # us-east-1a
  launch_configuration     = aws_launch_configuration.web_lc_us_east_1a.id
  target_group_arns        = [aws_lb_target_group.web_tg_us_east_1.id]
  

  tag {
    key                    = "Name"
    value                  = "web-instance"
    propagate_at_launch    = true
  }
}

# Launch Configuration for ASG in us-east-1a
resource "aws_launch_configuration" "web_lc_us_east_1a" {
  provider                  = aws.us-east-1
  image_id                  = "ami-0b72821e2f351e396"
  instance_type             = "t2.micro"
  security_groups           = [aws_security_group.web_sg.id]
  iam_instance_profile      = aws_iam_instance_profile.ec2_profile.name

  lifecycle {
    create_before_destroy   = true
  }

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "Hello World from $(hostname -f)" > /var/www/html/index.html
              EOF
}

# Create VPC, Subnet, and Resources in us-east-2
resource "aws_vpc" "norton_vpc_us_east_2" {
  provider   = aws.us-east-2
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "norton-vpc-us-east-2"
  }
}

resource "aws_subnet" "public_subnet_us_east_2a" {
  provider                  = aws.us-east-2
  vpc_id                    = aws_vpc.norton_vpc_us_east_2.id
  cidr_block                = "10.0.1.0/24"
  map_public_ip_on_launch   = true
  availability_zone         = "us-east-2a"
  tags = {
    Name = "public-subnet-us-east-2a"
  }
}

resource "aws_internet_gateway" "igw_us_east_2" {
  provider = aws.us-east-2
  vpc_id   = aws_vpc.norton_vpc_us_east_2.id
  tags = {
    Name = "internet-gateway-us-east-2"
  }
}

resource "aws_route_table" "public_rt_us_east_2" {
  provider = aws.us-east-2
  vpc_id   = aws_vpc.norton_vpc_us_east_2.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_us_east_2.id
  }

  tags = {
    Name = "public-route-table-us-east-2"
  }
}

resource "aws_route_table_association" "public_rt_assoc_us_east_2a" {
  provider        = aws.us-east-2
  subnet_id       = aws_subnet.public_subnet_us_east_2a.id
  route_table_id  = aws_route_table.public_rt_us_east_2.id
}

resource "aws_security_group" "web_sg_us_east_2" {
  provider = aws.us-east-2
  vpc_id   = aws_vpc.norton_vpc_us_east_2.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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
    Name = "web-sg-us-east-2"
  }
}

resource "aws_iam_role" "ec2_role_us_east_2" {
  provider = aws.us-east-2
  name     = "ec2-role-us-east-2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "ec2_policy_us_east_2" {
  provider = aws.us-east-2
  name     = "ec2-policy-us-east-2"
  role     = aws_iam_role.ec2_role_us_east_2.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = "ec2:Describe*",
      Effect   = "Allow",
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile_us_east_2" {
  provider = aws.us-east-2
  name     = "ec2-profile-us-east-2"
  role     = aws_iam_role.ec2_role_us_east_2.name
}
# EC2 Instances in us-east-2 Web server
resource "aws_instance" "web_instance_us_east_2a_1" {
  provider                 = aws.us-east-2
  ami                      = "ami-00db8dadb36c9815e" # Amazon Linux 2 AMI for us-east-2
  instance_type            = "t2.micro"
  subnet_id                = aws_subnet.public_subnet_us_east_2a.id
  vpc_security_group_ids   = [aws_security_group.web_sg_us_east_2.id]
  iam_instance_profile     = aws_iam_instance_profile.ec2_profile_us_east_2.name

  tags = {
    Name = "web-instance-us-east-2a-1"
  }
}
# EC2 Instances in us-east-2 Web server
resource "aws_instance" "web_instance_us_east_2a_2" {
  provider                 = aws.us-east-2
  ami                      = "ami-00db8dadb36c9815e" # Amazon Linux 2 AMI for us-east-2
  instance_type            = "t2.micro"
  subnet_id                = aws_subnet.public_subnet_us_east_2a.id
  vpc_security_group_ids   = [aws_security_group.web_sg_us_east_2.id]
  iam_instance_profile     = aws_iam_instance_profile.ec2_profile_us_east_2.name

  tags = {
    Name = "web-instance-us-east-2a-2"
  }
}

resource "aws_autoscaling_group" "web_asg_us_east_2a" {
  provider                 = aws.us-east-2
  desired_capacity         = 2
  max_size                 = 4
  min_size                 = 1
  vpc_zone_identifier      = [aws_subnet.public_subnet_us_east_2a.id] # us-east-2a
  launch_configuration     = aws_launch_configuration.web_lc_us_east_2a.id
  target_group_arns        = [aws_lb_target_group.web_tg_us_east_2.id]

  tag {
    key                    = "Name"
    value                  = "web-instance"
    propagate_at_launch    = true
  }
}

resource "aws_launch_configuration" "web_lc_us_east_2a" {
  provider                  = aws.us-east-2
  image_id                  = "ami-00db8dadb36c9815e" # Amazon Linux 2 AMI for us-east-2
  instance_type             = "t2.micro"
  security_groups           = [aws_security_group.web_sg_us_east_2.id]
  iam_instance_profile      = aws_iam_instance_profile.ec2_profile_us_east_2.name

  lifecycle {
    create_before_destroy   = true
  }

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "Hello World from $(hostname -f)" > /var/www/html/index.html
              EOF
}

resource "aws_lb_target_group" "web_tg_us_east_1" {
  provider = aws.us-east-1
  name     = "web-target-group-us-east-1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.norton_vpc.id

  health_check {
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "web-target-group-us-east-1"
  }
}

resource "aws_lb_target_group" "web_tg_us_east_2" {
  provider = aws.us-east-2
  name     = "web-target-group-us-east-2"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.norton_vpc_us_east_2.id

  health_check {
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "web-target-group-us-east-2"
  }
}
provider "aws" {
  alias  = "us-west-1"
  region = "us-west-1"
}
resource "aws_db_instance" "default" {
  provider = aws.us-east-1

  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  name                 = "mydatabase"
  username             = "admin"
  password             = "password"
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name

  tags = {
    Name = "my-rds-instance"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  provider = aws.us-east-1

  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.public_subnet_1a.id, aws_subnet.public_subnet_1b.id]

  tags = {
    Name = "rds-subnet-group"
  }
}

resource "aws_security_group" "rds_sg" {
  provider = aws.us-east-1
  vpc_id   = aws_vpc.norton_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
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
    Name = "rds-sg"
  }
}
resource "aws_vpc" "norton_vpc_us_west_1" {
  provider   = aws.us-west-1
  cidr_block = "10.1.0.0/16"
  tags = {
    Name = "norton-vpc-us-west-1"
  }
}

resource "aws_subnet" "public_subnet_us_west_1a" {
  provider                  = aws.us-west-1
  vpc_id                    = aws_vpc.norton_vpc_us_west_1.id
  cidr_block                = "10.1.1.0/24"
  map_public_ip_on_launch   = true
  availability_zone         = "us-west-1a"
  tags = {
    Name = "public-subnet-us-west-1a"
  }
}

resource "aws_subnet" "public_subnet_us_west_1b" {
  provider                  = aws.us-west-1
  vpc_id                    = aws_vpc.norton_vpc_us_west_1.id
  cidr_block                = "10.1.2.0/24"
  map_public_ip_on_launch   = true
  availability_zone         = "us-west-1a"
  tags = {
    Name = "public-subnet-us-west-1b"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group_us_west_1" {
  provider = aws.us-west-1

  name       = "rds-subnet-group-us-west-1"
  subnet_ids = [aws_subnet.public_subnet_us_west_1a.id, aws_subnet.public_subnet_us_west_1b.id]

  tags = {
    Name = "rds-subnet-group-us-west-1"
  }
}

resource "aws_security_group" "rds_sg_us_west_1" {
  provider = aws.us-west-1
  vpc_id   = aws_vpc.norton_vpc_us_west_1.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg-us-west-1"
  }
}

resource "aws_db_instance" "read_replica" {
  provider               = aws.us-west-1
  identifier             = "mydatabase-replica"
  replicate_source_db    = aws_db_instance.default.arn
  instance_class         = "db.t3.micro"
  storage_type           = "gp2"
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group_us_west_1.name
  vpc_security_group_ids = [aws_security_group.rds_sg_us_west_1.id]

  tags = {
    Name = "my-rds-instance-replica"
  }
}


resource "aws_s3_bucket" "primary_backup_bucket" {
  provider = aws.us-east-1
  bucket   = "primary-backup-bucket"

  tags = {
    Name = "primary-backup-bucket"
  }
}

resource "aws_s3_bucket" "secondary_backup_bucket" {
  provider = aws.us-west-1
  bucket   = "secondary-backup-bucket"

  tags = {
    Name = "secondary-backup-bucket"
  }
}

# Server-side encryption for the primary bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "primary_backup_encryption" {
  bucket = aws_s3_bucket.primary_backup_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# Server-side encryption for the secondary bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "secondary_backup_encryption" {
  bucket = aws_s3_bucket.secondary_backup_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}


# Versioning for the primary bucket
resource "aws_s3_bucket_versioning" "primary_backup_versioning" {
  bucket = aws_s3_bucket.primary_backup_bucket.bucket

  versioning_configuration {
    status = "Enabled"
  }
}

# Versioning for the secondary bucket
resource "aws_s3_bucket_versioning" "secondary_backup_versioning" {
  bucket = aws_s3_bucket.secondary_backup_bucket.bucket

  versioning_configuration {
    status = "Enabled"
  }
}

# Cross-region replication configuration
resource "aws_s3_bucket_replication_configuration" "replication" {
  provider = aws.us-east-1
  role     = aws_iam_role.s3_replication_role.arn
  bucket   = aws_s3_bucket.primary_backup_bucket.bucket

  rule {
    id     = "replication-rule"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.secondary_backup_bucket.arn
      storage_class = "STANDARD"
    }

    filter {
      prefix = ""
    }
  }
}

resource "aws_iam_role" "s3_replication_role" {
  name = "s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "s3.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "s3_replication_policy" {
  name = "s3-replication-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = [
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.primary_backup_bucket.arn,
          "${aws_s3_bucket.primary_backup_bucket.arn}/*"
        ]
      },
      {
        Action   = "s3:ReplicateObject"
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.secondary_backup_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_replication_policy_attachment" {
  role       = aws_iam_role.s3_replication_role.name
  policy_arn = aws_iam_policy.s3_replication_policy.arn
}

# Enable automated RDS snapshot backups
resource "aws_rds_cluster" "norton_rds_cluster" {
  provider = aws.us-east-1
  cluster_identifier = "norton-rds-cluster"
  engine = "aurora-mysql"
  backup_retention_period = 7
  preferred_backup_window = "07:00-09:00"
  # Additional RDS settings
}

# Snapshot copies to secondary region
resource "aws_db_cluster_snapshot" "norton_rds_snapshot" {
  provider = aws.us-east-1
  db_cluster_identifier = aws_rds_cluster.norton_rds_cluster.id
  db_cluster_snapshot_identifier = "norton-rds-snapshot"
}

resource "aws_s3_bucket_object" "rds_snapshot_backup" {
  provider = aws.us-west-1
  bucket = aws_s3_bucket.secondary_backup_bucket.bucket
  key    = "rds-backup/${aws_db_cluster_snapshot.norton_rds_snapshot.id}.snap"

  source = aws_db_cluster_snapshot.norton_rds_snapshot.db_cluster_snapshot_identifier
}

# Create the IAM Developer Group
resource "aws_iam_group" "developer_group" {
  name = "developer-group"
}

# Attach EC2, RDS, S3, API Gateway, and CodePipeline policies to the group

# EC2 Policy
resource "aws_iam_group_policy" "developer_ec2_policy" {
  group = aws_iam_group.developer_group.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = [
          "ec2:Describe*",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:RebootInstances",
          "ec2:TerminateInstances"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# RDS Policy
resource "aws_iam_group_policy" "developer_rds_policy" {
  group = aws_iam_group.developer_group.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = [
          "rds:Describe*",
          "rds:StartDBInstance",
          "rds:StopDBInstance",
          "rds:ModifyDBInstance"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# S3 Policy
resource "aws_iam_group_policy" "developer_s3_policy" {
  group = aws_iam_group.developer_group.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::*",
          "arn:aws:s3:::*/*"
        ]
      }
    ]
  })
}

# API Gateway Policy
resource "aws_iam_group_policy" "developer_api_gateway_policy" {
  group = aws_iam_group.developer_group.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = [
          "apigateway:GET",
          "apigateway:POST",
          "apigateway:DELETE",
          "apigateway:PUT"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# CodePipeline Policy
resource "aws_iam_group_policy" "developer_codepipeline_policy" {
  group = aws_iam_group.developer_group.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = [
          "codepipeline:StartPipelineExecution",
          "codepipeline:GetPipelineState",
          "codepipeline:GetPipelineExecution",
          "codepipeline:ListPipelines"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
# Attach an existing IAM user to the developer group
resource "aws_iam_group_membership" "developer_group_membership" {
  name = "developer-group-membership"
  group = aws_iam_group.developer_group.name

  users = [
    "developer1",
    "developer2" # Add more user names as needed
  ]
}
# Create API Gateway
resource "aws_api_gateway_rest_api" "developer_api" {
  name        = "DeveloperAPI"
  description = "API Gateway for Developer Group"
}

# Create API Gateway Resource (Example resource under the root)
resource "aws_api_gateway_resource" "developer_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.developer_api.id
  parent_id   = aws_api_gateway_rest_api.developer_api.root_resource_id
  path_part   = "developer-resource"
}

# Method for the resource
resource "aws_api_gateway_method" "developer_api_method" {
  rest_api_id   = aws_api_gateway_rest_api.developer_api.id
  resource_id   = aws_api_gateway_resource.developer_api_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# Integration with a Lambda (or other backend, example placeholder)
resource "aws_api_gateway_integration" "developer_api_integration" {
  rest_api_id = aws_api_gateway_rest_api.developer_api.id
  resource_id = aws_api_gateway_resource.developer_api_resource.id
  http_method = aws_api_gateway_method.developer_api_method.http_method
  type        = "MOCK"
}
# S3 Bucket for CodePipeline Artifact Storage
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "developer-codepipeline-artifacts"
}

# IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
    }]
  })
}

# CodePipeline definition
resource "aws_codepipeline" "developer_pipeline" {
  name     = "DeveloperPipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        S3Bucket = aws_s3_bucket.codepipeline_bucket.bucket
        S3ObjectKey = "source.zip"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name             = "Deploy"
      category         = "Deploy"
      owner            = "AWS"
      provider         = "CodeDeploy"
      version          = "1"
      input_artifacts  = ["source_output"]
      configuration = {
        ApplicationName = "MyApp"
        DeploymentGroupName = "MyDeploymentGroup"
      }
    }
  }
}

# Create the IAM Database Group
resource "aws_iam_group" "database_group" {
  name = "database-group"
}

# RDS Policy for the Database Group
resource "aws_iam_group_policy" "database_rds_policy" {
  group = aws_iam_group.database_group.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "rds:Describe*",
          "rds:StartDBInstance",
          "rds:StopDBInstance",
          "rds:ModifyDBInstance",
          "rds:CreateDBSnapshot",
          "rds:DeleteDBSnapshot"
        ],
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

# S3 Policy for the Database Group
resource "aws_iam_group_policy" "database_s3_policy" {
  group = aws_iam_group.database_group.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Effect = "Allow",
        Resource = [
          "arn:aws:s3:::my-backup-bucket",   # Replace with your S3 bucket name
          "arn:aws:s3:::my-backup-bucket/*"  # Grant access to the bucket and its objects
        ]
      }
    ]
  })
}

# API Gateway Policy for the Database Group
resource "aws_iam_group_policy" "database_api_gateway_policy" {
  group = aws_iam_group.database_group.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "apigateway:GET",
          "apigateway:POST",
          "apigateway:DELETE",
          "apigateway:PUT"
        ],
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}
# Create KMS Key for encryption
resource "aws_kms_key" "backup_kms_key" {
  description = "KMS key for encrypting RDS and S3 backups"
}

# Create an AWS Backup Vault
resource "aws_backup_vault" "database_backup_vault" {
  name        = "database-backup-vault"
  kms_key_arn = aws_kms_key.backup_kms_key.arn

  tags = {
    Name = "DatabaseBackupVault"
  }
}

# Backup Plan for RDS and S3
resource "aws_backup_plan" "database_backup_plan" {
  name = "database-backup-plan"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.database_backup_vault.name
    schedule          = "cron(0 12 * * ? *)"  # Daily backup at 12 PM UTC
    lifecycle {
      delete_after = 30  # Retain backups for 30 days
    }
  }
}

# Backup selection for RDS
resource "aws_backup_selection" "rds_backup_selection" {
  name          = "rds-backup-selection"
  iam_role_arn  = aws_iam_role.backup_role.arn
  plan_id       = aws_backup_plan.database_backup_plan.id
  resources = [
    "arn:aws:rds:us-east-1:123456789012:db:my-rds-instance"  # Replace with your RDS instance ARN
  ]
}

# Backup selection for S3
resource "aws_backup_selection" "s3_backup_selection" {
  name          = "s3-backup-selection"
  iam_role_arn  = aws_iam_role.backup_role.arn
  plan_id       = aws_backup_plan.database_backup_plan.id
  resources = [
    "arn:aws:s3:::my-backup-bucket"  # Replace with your S3 bucket ARN
  ]
}

# Create IAM Role for AWS Backup
resource "aws_iam_role" "backup_role" {
  name = "BackupServiceRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "backup.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach permissions to the Backup role for RDS and S3
resource "aws_iam_policy" "backup_policy" {
  name = "BackupPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "rds:CreateDBSnapshot",
          "rds:DescribeDBSnapshots",
          "rds:DeleteDBSnapshot",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backup_policy_attach" {
  role       = aws_iam_role.backup_role.name
  policy_arn = aws_iam_policy.backup_policy.arn
}
