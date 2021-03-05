# Simple (Cheap) AWS Installation

The goal of this project is to launch an AWS VPC that costs under $2/month in the 1st year (while your account is in the "free tier") and supports hosting 1 server and 1 database.

To start you'll need terraform installed, as well as have AWS credentials available in your local environment or installed using the AWS CLI.

### VPC

This creates a new VPC in (by default) us-east-1 with 4 availability zones and a public and private subnet in each availability zone.

#### IP Ranges

The IP range of this VPC is `172.18.0.0/16`

This creates 8 `/20` subnets, 4 private and 4 public.

The private subnets are `172.18.0.0/20`, `172.18.32.0/20`, `172.18.64.0/20`, and `172.18.96.0/20` The public subnets are `172.18.16.0/20`, `172.18.48.0/20`, `172.18.80.0/20`, `172.18.112.0/20`.

No NAT gateway is created by default for the private subnets, so anything put inside the private subnets will not have access to the public internet.

### DNS

This creates 2 new Route53 zones. You'll need to provide your own public domain when you first create your VPC. The second is a private zone called `services.private` that resources will be attached to.

When you run the command terraform is going to spit out an output called `route53_public_nameserver` that has the 4 nameservers you'll need to change your domain to use.

### EC2

This creates a new `t2.micro` instance in the first public subnet. This is in the public subnet so that it has access to the public internet, as we don't create NAT gateways above.

It runs the AMI `ami-042e8287309f5df03` which is Ubuntu 20.04 LTS in us-east-1. **If you launch this in another region you'll need to use a different AMI**.

You're going to be asked for an IP range to whitelist as well as a SSH key. You'll need to enter `{your ip}/32` as the IP range, and then any SSH key you want. This will expose the data on.

The public (elastic) IP of this instance will be `free.yourdomain.com`. The private IP will be added as `free.services.private` and addressable within the VPC.

If you want to grant the instance access to any additional AWS services, a new IAM role is created called `webserver-role` that you can modify as you wish.

### Load Balancer

A new elastic load balancer is created and put on the domain `free-lb.{your public domain}`. The EC2 instance above is added to a target group that the load balancer can route traffic to.

An attempt is made to create a new public wildcard certificate for your

### RDS

This creates a new postgres RDS instance on your private subnet.

After it's created you can address it from within the vpc under the name `postgres.services.private` with the username `root`, password `ChangeMeLater`, and port of `5432` (using the EC2 as a bastion host is fine)
