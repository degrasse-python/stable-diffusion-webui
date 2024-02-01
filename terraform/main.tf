# Configure terraform cloud
terraform {
    cloud {
        organization = "5thCinematic"

        workspaces {
            name = "Foresight-SD-Web-UI"
        }
    }
}

module "aws" {
    source = "./modules/aws"
}

variable "AWS_ACCESS_KEY_ID" {
    type        = string
    description = "AWS access key ID"
}

variable "AWS_SECRET_ACCESS_KEY" {
    type        = string
    description = "AWS secret access key"
}
