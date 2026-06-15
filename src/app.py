import boto3
from flask import Flask

app = Flask(__name__)
@app.route('/')
def read_s3():
    # ANTI-PATTERN: Relies entirely on the node's underlying IAM role
    s3 = boto3.client('s3', region_name='us-east-1')
    try:
        response = s3.list_buckets()
        buckets = [bucket['Name'] for bucket in response['Buckets']]
        return f"I can see all these buckets: {', '.join(buckets)}"
    except Exception as e:
        return str(e)
if __name__ == '__main__':
    # ANTI-PATTERN: Running as root on all interfaces
    app.run(host='0.0.0.0', port=8080)