output "database_address" {
  value = aws_db_instance.example.address
  description = "Connect to the database at this endpoint"
}

output "database_port" {
  value = aws_db_instance.example.port
  description = "The port the database is listening on"
}
