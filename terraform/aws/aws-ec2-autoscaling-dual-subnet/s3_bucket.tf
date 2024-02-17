resource "aws_s3_bucket" "routes" {
  bucket_prefix = substr(local.name, 0, 37)
  tags          = local.tags

  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "routes" {
  bucket = aws_s3_bucket.routes.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# resource "aws_s3_bucket_policy" "routes" {
#   bucket = aws_s3_bucket.routes.id
#   policy = <<-EOT
#   {
#     "Version": "2012-10-17",
#     "Statement": [
#       {
#         "Sid": "Allow-access-from-specific-VPC",
#         "Effect": "Deny",
#         "Principal": "*",
#         "Action": [
#           "s3:PutObject",
#           "s3:GetObject"
#         ],
#         "Resource": [
#           "${aws_s3_bucket.routes.arn}",
#           "${aws_s3_bucket.routes.arn}/*"
#         ],
#         "Condition": {
#           "StringNotEquals": {
#             "aws:SourceVpc": "${module.vpc.vpc_id}"
#           }
#         }
#       }
#     ]
#   }
#   EOT
# }

resource "aws_iam_policy" "routes" {
  tags   = local.tags
  policy = <<-EOT
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        "Resource": [
          "${aws_s3_bucket.routes.arn}",
          "${aws_s3_bucket.routes.arn}/*"
        ]
      }
    ]
  }
  EOT
}

resource "aws_iam_role" "ec2_role" {
  name = "${local.name}-ec2_s3_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.routes.arn
}
resource "aws_iam_instance_profile" "routes" {
  name = "${local.name}-routes"
  role = aws_iam_role.ec2_role.name
}
