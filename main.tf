

variable "server_port" {
    description = "The port the server will use for HTTP requests"
    default = "8080"
  
}

provider "aws" {
    region = "us-east-1"
}

resource "aws_launch_configuration" "example" {
    image_id = "ami-40d28157"
    instance_type = "t2.micro"
    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World" > index.html
                nohup busybox httpd -f -p ${var.server_port} &
                EOF


    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_security_group" "instance" {
    name = "terraform-example-instance"

    ingress {
        from_port = "${var.server_port}"
        to_port =   "${var.server_port}"
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    lifecycle {
        create_before_destroy = true
    }
}

data "aws_availability_zones" "all" {
}

data "aws_subnet" "primary" {
    availability_zone = "${data.aws_availability_zones.all.names[0]}"
}

data "aws_subnet" "secondary" {
     availability_zone = "${data.aws_availability_zones.all.names[1]}"
}

resource "aws_alb" "example" {
    name = "terraform-asg-example"
    internal = false
    subnets = ["${data.aws_subnet.primary.id}", "${data.aws_subnet.secondary.id}"]
    security_groups = ["${aws_security_group.lb.id}"]  
}

resource "aws_autoscaling_group" "example" {
    name = "example-auto-scaling-group"
    launch_configuration = "${aws_launch_configuration.example.id}"
    min_size = 2
    max_size = 4
    load_balancers = ["${aws_alb.example.name}"]
    #vpc_zone_identifier = ["${data.aws_subnet.primary.id}", "${data.aws_subnet.secondary.id}"]
    health_check_type = "ELB"
    tag {
        key = "Name"
        value = "terraform-asg-example"
        propagate_at_launch = true
    }

    lifecycle {
     create_before_destroy = true
    }

    depends_on = [
        "aws_alb.example"
    ]
  
}
resource "aws_alb_target_group" "alb_target_group" {
    name = "example-alb-target-group"
    port = 8080
    protocol = "HTTP"
    stickiness {    
        type            = "lb_cookie"    
        cookie_duration = 1800    
        enabled         =  true 
    }
    health_check {    
        healthy_threshold   = 3    
        unhealthy_threshold = 3    
        timeout             = 2
        interval            = 5    
        path                = "/"    
        port                = "8080"  
        matcher = "200" # Must be HTTP 200 response else fail
    }  

    lifecycle {
        create_before_destroy = true
    }
}


resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = "${aws_alb.example.arn}"
  port = "80"
  protocol = "http"
  
  default_action {
      target_group_arn = "${aws_alb_target_group.alb_target_group.arn}"
      type = "forward"
  }
}

resource "aws_alb_listener_rule" "alb_listener_rule" {
    action {
        target_group_arn = "${aws_alb_target_group.alb_target_group.arn}"
        type = "forward"
    }
    condition { 
         field = "path-pattern" 
         values = ["/"] 
    }
    listener_arn = "${aws_alb_listener.alb_listener.id}"
   
}


resource "aws_security_group" "lb" {
    name = "terraform-example-elb"
    
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}



