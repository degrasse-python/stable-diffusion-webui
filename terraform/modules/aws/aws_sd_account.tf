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
  vpc_id = data.aws_vpc.default_vpc.id
  cidr_block = "172.31.64.1/16"
}

data "aws_ami" "ubuntuServer_ami" {
  most_recent = true
  owners      = ["ubuntu"]
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

# create SSL certificate for ELB 
resource "aws_acm_certificate" "cert" {
  domain_name       = "example.com"
  validation_method = "DNS"
}

resource "aws_route53_zone" "zone" {
  name = "example.com"
  private_zone = false
}
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.zone.zone_id
  name    = "www.example.com"
  type    = "A"
  ttl     = 300
  records = [aws_eip.lb.public_ip]
}


resource "aws_route53_record" "cert_validation" {
  zone_id = aws_route53_zone.zone.zone_id
  # name    = aws_acm_certificate.cert.domain_validation_options.0.resource_record_name
  name = aws_acm_certificate.cert.id
  type = aws_acm_certificate.cert.type
  records = [aws_acm_certificate.cert.validation_method.0.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert : record.fqdn]
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

# Security Groups
resource "aws_security_group" "allow_tls_ipv4_sd_webui_sg" {
  name = "sd-webui-sg"
  description = "Security group for Stable Diffusion WebUI EC2 instance"
  vpc_id = data.aws_vpc.default_vpc.id
  ingress = [
    {
      ip_protocol = "tcp"
      from_port = 22
      to_port = 22
      cidr_blocks = "0.0.0.0/0"
    },
    {
      ip_protocol = "tcp"
      from_port = 7860
      to_port = 7860
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

# Security Group for the Network Load Balancer
resource "aws_security_group" "lb_sg" {
  name = "sd-webui-sg"
  description = "Security group for Stable Diffusion WebUI EC2 instance"
  vpc_id = data.aws_vpc.default_vpc.id
  ingress = [
    {
      ip_protocol = "tcp"
      from_port = 22
      to_port = 22
      cidr_blocks = "0.0.0.0/0"
    },
    {
      ip_protocol = "tcp"
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
    aws_security_group.sd-webui-sg.name
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
  subnets            = [subnet_a.id, subnet_b.id] 
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

# Create a new load balancer
resource "aws_elb" "s3_sd_webui_elb" {
  name               = "sd-webui-nlb"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  access_logs {
    bucket  = aws_s3_bucket.s3_sd_webui_lbaccess_logs.id
    interval      = 60
    enabled = true
  }

  listener {
    instance_port     = 22
    instance_protocol = "tcp"
    lb_port           = 22
    lb_protocol       = "tcp"
  }

  listener {
    instance_port      = 7860
    instance_protocol  = "tcp"
    lb_port            = 7860
    lb_protocol        = "tcp"
    # create SSL certificate
    ssl_certificate_id = "arn:aws:iam::123456789012:server-certificate/certName"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:7860/"
    interval            = 30
  }

  instances                   = [aws_instance.ec2_instance.id, aws_instance.sd_webui_spot_instance.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "s3-sd-webui-elb"
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
  certificate_arn = aws_acm_certificate_validation.cert.certificate_arn

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

