# Configure terraform cloud
terraform {
    cloud {
        organization = "5thCinematic"

        workspaces {
            name = "stable-diffusion-webui"
        }
    }
}

module "aws" {
    source = "./modules/aws"
    AWS_ACCESS_KEY_ID  = var.AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY  = var.AWS_SECRET_ACCESS_KEY 
}

variable "AWS_ACCESS_KEY_ID" {
    type        = string
    description = "AWS access key ID"
}

variable "AWS_SECRET_ACCESS_KEY" {
    type        = string
    description = "AWS secret access key"
}
