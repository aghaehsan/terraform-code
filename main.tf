
variable "server_port" {
    description = "The port the server will use for HTTP requests"
    default = "8080"
  
}

provider "aws" {
    region = "us-east-1"
    skip_metadata_api_check = true
}

data "aws_vpc" "default" {
  default = true
}

data "aws_availability_zones" "all" {
}

data "aws_subnet" "primary" {
    availability_zone = "${data.aws_availability_zones.all.names[0]}"
}

data "aws_subnet" "secondary" {
     availability_zone = "${data.aws_availability_zones.all.names[1]}"
}


resource "aws_security_group" "instance" {
    name = "terraform-example-instance"
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_security_group_rule" "http-inbound-access-instance"{
  security_group_id = "${aws_security_group.instance.id}"
  type = "ingress"
  from_port = "${var.server_port}"
  to_port = "${var.server_port}"
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}



resource "aws_security_group" "security-group-lb" {
    name = "terraform-example-elb"
    vpc_id = "${data.aws_vpc.default.id}" 
    
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_security_group_rule" "http-inbound-access-lb" {
  security_group_id = "${aws_security_group.security-group-lb.id}"
  type = "ingress"
  from_port = 80
  protocol = "tcp"
  to_port = 80
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "all-outbound-access" {
  security_group_id = "${aws_security_group.security-group-lb.id}"
  type = "egress"
  from_port = 0
  protocol = "-1"
  to_port = 0
  cidr_blocks = ["0.0.0.0/0"]
}


resource "aws_lb" "my-test-lb" {
    name = "my-test-lb"
    internal = false
    load_balancer_type = "application"
    subnets = ["${data.aws_subnet.primary.id}", "${data.aws_subnet.secondary.id}"]
    security_groups = ["${aws_security_group.security-group-lb.id}"]
    enable_deletion_protection = false

    tags = {
        Name = "my-test-lb"
    }
}

resource "aws_lb_target_group" "my-lb-target-group" {
    
    name = "my-lb-target-group"
    port = 8080
    protocol = "HTTP"
    target_type = "instance"
    vpc_id = "${data.aws_vpc.default.id}"
    health_check {
        interval = 30
        path = "/"
        protocol = "HTTP"
        timeout = 5
        healthy_threshold = 5
        unhealthy_threshold = 2
        matcher = "200" #HTTP 200 response else fail
    }
}

resource "aws_autoscaling_group" "my-autoscaling-group" {
  launch_configuration    = "${aws_launch_configuration.my-launch-configuration.id}"
  availability_zones      = ["${data.aws_availability_zones.all.names[0]}", "${data.aws_availability_zones.all.names[1]}"]
  target_group_arns       = ["${aws_lb_target_group.my-lb-target-group.arn}"]
  health_check_type       = "ELB"
  min_size                = "2"
  max_size                = "4"
  tag {
    key = "Name"
    propagate_at_launch = true
    value = "my-terraform-asg-example"
  }
}

resource "aws_autoscaling_attachment" "my-autoscaling-attachment" {
  alb_target_group_arn   = "${aws_lb_target_group.my-lb-target-group.arn}"
  autoscaling_group_name = "${aws_autoscaling_group.my-autoscaling-group.name}"

   depends_on   = ["aws_autoscaling_group.my-autoscaling-group"] 
}


resource "aws_launch_configuration" "my-launch-configuration" {
    image_id = "ami-40d28157"
    instance_type = "t2.micro"
    security_groups = ["${aws_security_group.instance.id}"]
    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World" > index.html
                nohup busybox httpd -f -p ${var.server_port} &
                EOF
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_lb_listener" "my-lb-listener" {  
  load_balancer_arn = "${aws_lb.my-test-lb.arn}"  
  port              = "80"  
  protocol          = "HTTP"
  
  default_action {    
    target_group_arn = "${aws_lb_target_group.my-lb-target-group.arn}"
    type             = "forward"  
  }
}

resource "aws_lb_listener_rule" "listener_rule" {
  depends_on   = ["aws_lb_target_group.my-lb-target-group"]  
  listener_arn = "${aws_lb_listener.my-lb-listener.arn}"  
  #priority     = "${var.priority}"   
  action {    
    type             = "forward"    
    target_group_arn = "${aws_lb_target_group.my-lb-target-group.arn}"  
  }   
  condition {    
    field  = "path-pattern"    
    values = ["/"]  
  }
}


output "load-balancer-dns" {
  value = "${aws_lb.my-test-lb.dns_name}"
}
