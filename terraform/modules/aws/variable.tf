
variable "AWS_ACCESS_KEY_ID" {
  description = "The aws_access_key"
  type        = string
  default = "value"
  /*validation {
    condition = length(var.AWS_ACCESS_KEY_ID) > 10
    error_message = "The file must be more than 10 chars"
  }*/
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "The id aws_secret_key"
  type        = string
  default = "value"
  /*validation {
    condition = length(var.AWS_SECRET_ACCESS_KEY) > 10
    error_message = "The file must be more than 10 chars"
  }*/
}


# Output the KMS key ID
output "webui_lb_s3_bucket_kms_key_id" {
  value = aws_kms_key.sd_webui_lb_s3_bucket_key.id
}

output "app_logs_bucket_kms_key_id" {
  value = aws_kms_key.sd_webui_app_logs_bucket_key.id
  }