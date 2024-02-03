# Output the aws instance ip address 
output "aws_instance_public_ip" {
  value = aws_instance.ec2_instance.public_ip
}

# Output the KMS key ID
output "webui_lb_s3_bucket_kms_key_id" {
  value = aws_kms_key.sd_webui_lb_s3_bucket_key.id
}

output "app_logs_bucket_kms_key_id" {
  value = aws_kms_key.sd_webui_app_logs_bucket_key.id
  }