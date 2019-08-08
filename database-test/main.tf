provider "aws" {
region = "us-east-1"
}

resource "aws_db_instance" "example" {
identifier_prefix = "terraform-up-and-running"
engine = "mysql"
allocated_storage = 10
instance_class = "db.t2.micro"
name = "example_database"
username = "admin"
password = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["mysql-master-password-stage"]
}

data "aws_secretsmanager_secret" "db_password" {
name = "mysql-master-password-stage"
}

data "aws_secretsmanager_secret_version" "db_password" { 
secret_id = "${data.aws_secretsmanager_secret.db_password.id}" 
}




