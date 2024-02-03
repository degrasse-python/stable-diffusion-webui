# Output the aws instance ip address 
output "aws_instance_public_ip" {
  value = aws_instance.ec2_instance.public_ip
}

