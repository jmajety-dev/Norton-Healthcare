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

# EC2 Instances in us-east-1
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

resource "aws_instance" "web_instance_1a_2" {
  provider                 = aws.us-east-1
  ami                      = "ami-0b72821e2f351e396" # Amazon Linux 2 AMI
  instance_type            = "t2.micro"
  subnet_id                = aws_subnet.public_subnet_1a.id
  vpc_security_group_ids   = [aws_security_group.web_sg.id]
  iam_instance_profile     = aws_iam_instance_profile.ec2_profile.name

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
