# AWS Region Configuration
aws_region = "us-west-2"

# Cluster Configuration
cluster_name = "production-eks"
kubernetes_version = "1.28"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

# Node Group Configuration
desired_nodes = 3
min_nodes = 2
max_nodes = 5
instance_types = ["t3.large"]