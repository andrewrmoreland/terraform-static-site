data "aws_route53_zone" "site" {
    name = var.dns_zone
}

resource "aws_acm_certificate" "site" {
    provider = aws.us_east_1
    domain_name = var.primary_fqdn
    subject_alternative_names = var.aliases
    validation_method = "DNS"
    lifecycle {
        create_before_destroy = true
    }
    tags = var.tags
}

resource "aws_route53_record" "cert_validation" {
    for_each = {
        for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
            name = dvo.resource_record_name
            record = dvo.resource_record_value
            type = dvo.resource_record_type
        }
    }

    allow_overwrite = true
    name = each.value.name
    records = [each.value.record]
    ttl = 3600
    type = each.value.type
    zone_id = data.aws_route53_zone.site.zone_id
} 

resource "aws_acm_certificate_validation" "site" {
    provider = aws.us_east_1
    certificate_arn = aws_acm_certificate.site.arn
    validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_cloudfront_origin_access_identity" "site" {
    comment = "${var.primary_fqdn} OAI"
}

resource "aws_s3_bucket" "site" {
    bucket = var.primary_fqdn
    force_destroy = true
    tags = var.tags
    policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "${aws_cloudfront_origin_access_identity.site.iam_arn}"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${var.primary_fqdn}/*"
        }
    ]
}
POLICY
}

resource "aws_cloudfront_distribution" "site" {
    aliases = concat(var.aliases,[var.primary_fqdn])
    enabled = true
    is_ipv6_enabled = true
    default_root_object = "index.html"
    custom_error_response {
        error_code = 403
        response_code = 404
        response_page_path = "/404.html"
    }
    origin {
        origin_id = var.primary_fqdn
        domain_name = aws_s3_bucket.site.bucket_regional_domain_name
        s3_origin_config {
            origin_access_identity = aws_cloudfront_origin_access_identity.site.cloudfront_access_identity_path
        }
    }
    restrictions {
        geo_restriction {
          restriction_type = "none"
        }
    }
    default_cache_behavior {
        allowed_methods = ["GET","HEAD"]
        cached_methods = ["GET","HEAD"]
        target_origin_id = var.primary_fqdn

        forwarded_values {
            query_string = false
            cookies {
                forward = "none"
            }
        }
        viewer_protocol_policy = "redirect-to-https"
    }
    viewer_certificate {
        acm_certificate_arn = aws_acm_certificate.site.arn
        minimum_protocol_version = "TLSv1.2_2019"
        ssl_support_method = "sni-only"
    }
    tags = var.tags
}

resource "aws_route53_record" "site" {
    zone_id = data.aws_route53_zone.site.zone_id
    name = var.primary_fqdn
    type = "A"
    alias {
        name = aws_cloudfront_distribution.site.domain_name
        zone_id = aws_cloudfront_distribution.site.hosted_zone_id
        evaluate_target_health = false
    }
}

resource "aws_route53_record" "alias" {
    count = length(var.aliases)
    zone_id = data.aws_route53_zone.site.zone_id
    name = var.aliases[count.index]
    type = "A"
    alias {
        name = aws_cloudfront_distribution.site.domain_name
        zone_id = aws_cloudfront_distribution.site.hosted_zone_id
        evaluate_target_health = false
    }
}