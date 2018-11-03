# Cluster name
variable "name" {
  type = "string"
  default = "devopsDemocluster"
}

# Node count
variable "nodeCount" {
  type = "string"
  default = "1"
}

# Project name
variable "project" {
  type = "string"
  default = "devops-miami-demo-1"
}

# Cluster username
variable "username" {
  type = "string"
  default = "root"
}

# Cluster password
variable "password" {
  type = "string"
  default = "REPLACEME"
}

# Availability zones
variable "zone" {
  type = "string"
  default = "us-east1-c"
}

variable "additional_zones" {
  type = "string"
  default = "us-east1-b"
}

# Domain label
variable "domain_label" {
  type = "string"
  default = "demo"
}

# Cluster Tags
variable "tags" {
  type    = "list"
  default = ["blog", "demo", "helm", "terraform"]
}
