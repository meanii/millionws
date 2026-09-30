# Cost watchdog. Independent of the instances: an EventBridge schedule runs a
# Lambda that terminates any Project=millionws-bench instance older than
# max_runtime_minutes + guard_grace_minutes. It backs up the on-instance
# shutdown timer and survives a forgotten `tofu destroy` (the Lambda itself
# costs effectively nothing while idle).

data "archive_file" "guard" {
  type        = "zip"
  source_file = "${path.module}/guard/guard.py"
  output_path = "${path.module}/guard/guard.zip"
}

resource "aws_iam_role" "guard" {
  name = "millionws-bench-guard"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "guard" {
  name = "millionws-bench-guard"
  role = aws_iam_role.guard.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "ec2:DescribeInstances"
        Effect   = "Allow"
        Resource = "*"
      },
      {
        # Terminate only what this project tagged.
        Action   = "ec2:TerminateInstances"
        Effect   = "Allow"
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = {
          StringEquals = { "aws:ResourceTag/Project" = "millionws-bench" }
        }
      },
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

resource "aws_lambda_function" "guard" {
  function_name    = "millionws-bench-guard"
  role             = aws_iam_role.guard.arn
  runtime          = "python3.12"
  handler          = "guard.handler"
  filename         = data.archive_file.guard.output_path
  source_code_hash = data.archive_file.guard.output_base64sha256
  timeout          = 60
  environment {
    variables = {
      TAG_VALUE       = "millionws-bench"
      MAX_AGE_MINUTES = var.max_runtime_minutes + var.guard_grace_minutes
    }
  }
}

resource "aws_cloudwatch_event_rule" "guard" {
  name                = "millionws-bench-guard"
  schedule_expression = "rate(10 minutes)"
}

resource "aws_cloudwatch_event_target" "guard" {
  rule = aws_cloudwatch_event_rule.guard.name
  arn  = aws_lambda_function.guard.arn
}

resource "aws_lambda_permission" "guard" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.guard.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guard.arn
}
