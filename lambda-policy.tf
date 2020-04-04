data "aws_iam_policy_document" "lambda_policy" {
  version   = "2012-10-17"
  policy_id = "PolicyForLambdaEdgeLogging"
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect    = "Allow"
    resources = ["arn:aws:logs:*:*:*"]
  }
}