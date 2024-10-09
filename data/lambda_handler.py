import boto3
import jwt
import rsa
from botocore.exceptions import ClientError


def lambda_handler(event, context):
    response = {"statusCode": 401, "body": "Unauthorized"}

    return response
