provider "aws" {
  region = "us-east-2" # Modify to your desired region
  access_key = var.AWS_ACCESS_KEY_ID 
  secret_key = var.AWS_SECRET_ACCESS_KEY
}

data "aws_vpc" "default_vpc" {
  default = true
}

data "aws_subnet" "subnet_a" {
  vpc_id = data.aws_vpc.default.id
  cidr_block = "172.31.64.0/16"
}

data "aws_subnet" "subnet_b" {
  vpc_id = data.aws_vpc.default.id
  cidr_block = "172.31.64.1/16"
}

data "aws_ami" "ubuntuServer_ami" {
  most_recent = true
  owners      = ["ubuntu"]
  virtualization_type = "hvm"
  filter {
    name   = "architecture"
    values = ["arm64"]
  }
  filter {
    name   = "name"
    values = ["ami-*"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_ec2_spot_price" "example" {
  instance_type     = "p2.xlarge"
  availability_zone = "us-east-1a"

  filter {
    name   = "product-description"
    values = ["Linux/UNIX"]
  }
}

resource "aws_s3_bucket" "s3_sd_webui_app_logs" {
  bucket = "s3_sd_webui_app_logs"

  tags = {
    Name        = "sd_webui_accesslogs"
    Environment = "prod"
  }
}

resource "aws_s3_bucket" "s3_sd_webui_lbaccess_logs" {
  bucket = "sd-webui-lblogs-bucket"

  tags = {
    Name        = "s3_sd_webui_lbaccess_logs"
    Environment = "prod"
  }
}

# KMS Keys
## sd_webui_lb_s3_bucket_key KMS key to secure the S3 bucket
resource "aws_kms_key" "sd_webui_lb_s3_bucket_key" {
  description             = "KMS key for securing NLB S3 bucket"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket_ownership_controls" "s3_bucket_key_onwership_controls" {
  bucket = aws_s3_bucket.s3_sd_webui_app_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Create an S3 bucket with server-side encryption using the KMS key
resource "aws_s3_bucket_acl" "secure_bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.s3_bucket_key_onwership_controls] 
  bucket = "sd-webui-accesslogs-bucket"
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sd_webui_sse_config" {
  bucket = aws_s3_bucket.s3_sd_webui_lbaccess_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.sd_webui_lb_s3_bucket_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

## sd_webui_app_logs_bucket_key KMS key to secure the S3 bucket
resource "aws_kms_key" "sd_webui_app_logs_bucket_key" {
  description             = "KMS key for securing S3 bucket"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket_ownership_controls" "s3_app_logs_bucket_key_onwership_controls" {
  bucket = aws_s3_bucket.s3_sd_webui_lbaccess_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

## server-side encryption using the KMS key
resource "aws_s3_bucket_acl" "secure_app_logs_bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.s3_app_logs_bucket_key_onwership_controls] 
  bucket = "sd-webui-applogs-bucket"
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sd_webui_app_logs_sse_config" {
  bucket = aws_s3_bucket.s3_sd_webui_app_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.sd_webui_app_logs_bucket_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}


resource "aws_security_group" "security_group" {
  name = "sd-webui-sg"
  description = "Security group for Stable Diffusion WebUI EC2 instance"
  ingress = [
    {
      protocol = "tcp"
      from_port = 22
      to_port = 22
      cidr_blocks = "0.0.0.0/0"
    },
    {
      protocol = "tcp"
      from_port = 7860
      to_port = 7860
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}


# create a new EC2 instance with ubuntu server 20.04 LTS with a gpu instance type
# and attach the security group created above to it and run the user data script 
# to install the webui and start the server on port 7860 
resource "aws_instance" "ec2_instance" {
  ami = "ami-0a75bd84854bc95c9"
  instance_type = "g4dn.xlarge"
  security_groups = [
    aws_security_group.security_group.name
  ]
  user_data =  <<-EOF
                #!/bin/bash
                cd /home/ubuntu
                git clone
                bash stable-diffusion-webui/setup.sh -y
              EOF
  tags = { 
    Name = "sd-webui-cf"
  }
}

resource "aws_instance" "sd_webui_spot_instance" {
  ami           = data.aws_ami.ubuntuServer_ami.id
  # instance_type Specs: 4core Intel Xeon E5-2686 v4 Processor, 61GB mem, GPU 12GiB
  instance_type = "p2.xlarge"  
  key_name      = "sd-webui-key" 
  instance_market_options {
    spot_options {
      max_price = 0.115
    }
  }

  tags = {
    Name = "SDWebUISpotInstance"
  }
}

resource "aws_lb" "network_load_balancer" {
  name               = "sd-webui-nlb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [subnet_a.id, subnet_b] 
  enable_deletion_protection = true

  access_logs {
    bucket  = aws_s3_bucket.s3_sd_webui_lbaccess_logs.id
    prefix  = "sd-webui-nlb"
    enabled = true
  }

  tags = {
    Name = "SDWebUISpotInstance"
    Environment = "prod"

  }
}

resource "aws_lb_target_group" "nlb_target_group" {
  name     = "nlb-target-group"
  port     = 7860
  protocol = "TCP"
  vpc_id   = data.aws_vpc.default_vpc.id  

  health_check {
    interval            = 30
    port                = "traffic-port"
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
    protocol            = "TCP"
  }
}

resource "aws_lb_listener" "sd_webui_listener" {
  load_balancer_arn = aws_lb.network_load_balancer.arn
  port              = "7860"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_target_group.arn
  }
}

resource "aws_lb_target_group_attachment" "attach_instances" {
  target_group_arn = aws_lb_target_group.nlb_target_group.arn
  target_id        = aws_instance.sd_webui_spot_instance.id
  port             = 7860
}

