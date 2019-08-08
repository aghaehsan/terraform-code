terraform {
    backend "s3" {
        encrypt = true
        bucket = "ehsanz-remote-state-bucket"
        dynamodb_table = "terraform-state-lock-dynamo"
        region = "us-east-1"
        key = "my-terraform"
    }
}