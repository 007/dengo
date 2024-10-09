import base64
import json
import os
import time
import urllib

import boto3
import jwt
import rsa
from botocore.exceptions import ClientError

key_pair_id = os.getenv("SIGNING_KEY_ID", "TODO:REPLACEME")
oidc_client_id = os.getenv("OIDC_CLIENT_ID", "TODO:REPLACEME")
oidc_endpoint = os.getenv("OIDC_ENDPOINT", "TODO:REPLACEME")
region = os.getenv("AWS_REGION", os.getenv("AWS_DEFAULT_REGION", "us-east-1"))
secret_path = os.getenv("SIGNING_KEY_SECRET_PATH", "TODO:REPLACEME")
signature_expiration_days = int(os.getenv("SIGNATURE_EXPIRATION_DAYS", 1))


def load_cf_signing_key():
    session = boto3.session.Session()
    sm_client = session.client(service_name="secretsmanager", region_name=region)
    try:
        get_secret_value_response = sm_client.get_secret_value(SecretId=secret_path)
    except ClientError as e:
        raise e
    signing_key_pem = get_secret_value_response["SecretString"]
    return rsa.PrivateKey.load_pkcs1(signing_key_pem.encode("utf8"))


def load_jwks_keys():
    jwks_client = jwt.PyJWKClient(f"https://{oidc_endpoint}/.well-known/jwks.json")
    _ = jwks_client.fetch_data()
    return jwks_client


### exec at init
cloudfront_signing_translation = str.maketrans("+=/", "-_~")
signing_key = load_cf_signing_key()
jwks_client = load_jwks_keys()
### exec at init


def cloudfront_urlsafe_b64(thing):
    b64_string = base64.b64encode(thing).decode()
    return b64_string.translate(cloudfront_signing_translation)


def gen_signature():
    headers = {}
    expiration_time = int(time.time()) + (86400 * signature_expiration_days)
    shared_policy = {"Statement": [{"Condition": {"DateLessThan": {"AWS:EpochTime": expiration_time}}}]}
    # `separators` will remove whitespace within encoded json
    shared_policy_json_bytes = json.dumps(shared_policy, separators=(",", ":")).encode("utf8")
    signature = rsa.sign(shared_policy_json_bytes, signing_key, "SHA-1")
    headers["CloudFront-Policy"] = cloudfront_urlsafe_b64(shared_policy_json_bytes)
    headers["CloudFront-Signature"] = cloudfront_urlsafe_b64(signature)
    headers["CloudFront-Key-Pair-Id"] = key_pair_id
    return headers


def signature_to_cookies(headers):
    cookies = []
    for k, v in headers.items():
        cookies.append(f"{k}={v}; Secure; HttpOnly")
    return cookies


def set_redirect(request):
    params = urllib.parse.parse_qs(request.get("rawQueryString", ""))
    return_target = params.get("target_path", [""])[0]
    if return_target.startswith("/"):
        return_target = return_target[1:]
    return_target_safe = urllib.parse.quote(return_target)
    return f"/{return_target_safe}"


def check_auth(jwt_data):
    try:
        signing_key = jwks_client.get_signing_key_from_jwt(jwt_data)
        data = jwt.decode(jwt_data, signing_key.key, algorithms=["RS256"], audience=oidc_client_id)
        if data.get("email_verified", False):
            # can do data.get('email', 'unknown') to get email as desired
            return True
    except jwt.ExpiredSignatureError:
        pass
    except jwt.InvalidTokenError:
        pass

    return False


def lambda_handler(event, context):
    response = {"statusCode": 401, "body": "Unauthorized"}
    if event.get("requestContext", {}).get("http", {}).get("method", "") == "POST":
        post_data = event.get("body", "")
        if event.get("isBase64Encoded", False):
            post_data = base64.b64decode(post_data).decode("utf8")
        post_data = urllib.parse.parse_qs(post_data)
        if check_auth(post_data.get("id_token", [""])[0]):
            response = {
                "statusCode": 302,
                "headers": {
                    "Location": set_redirect(event),
                },
                "body": "",
                "cookies": signature_to_cookies(gen_signature()),
                "isBase64Encoded": False,
            }

    return response
