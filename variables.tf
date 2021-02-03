variable "primary_fqdn" {
    type = string
    description = "Primary fully qualified domain name"
}

variable "dns_zone" {
    type = string
    description = "DNS zone name"
}

variable "aliases" {
    type = list
    description = "Additional aliases within the same DNS zone"
    default = []
}

variable "tags" {
    type = map
    description = "AWS resource tags"
    default = {}
} 

