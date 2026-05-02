import boto3
import pandas as pd
import os
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

BUCKET_NAME = os.getenv('BUCKET_NAME')

if not BUCKET_NAME:
    raise ValueError("BUCKET_NAME is not set in the environment variables.")

s3 = boto3.client('s3')

def build_s3_key(dataset_name: str, file_name: str) -> str:

    now= datetime.now()

    return (
        f"marketing_data/raw/{dataset_name}/"
        f"year={now.year}/month={now.month:02d}/"
        f"{file_name}"
    )

def upload_file_to_s3(local_path: str, dataset_name: str) -> None:

    file_name = os.path.basename(local_path)
    s3_key = build_s3_key(dataset_name, file_name)

    try:
        s3.upload_file(
            Filename=local_path,
            Bucket=BUCKET_NAME,
            Key=s3_key
        )
        print(f"File '{local_path}' uploaded to s3://{BUCKET_NAME}/{s3_key}.")
    except Exception as e:
        print(f"Error uploading '{local_path}' to S3: {e}")
        raise

def main():

    files = [
        ("data/raw/ads_campaigns.csv", "ads_campaigns"),
        ("data/raw/ads_costs.csv", "ads_costs"),
        ("data/raw/site_revenue.csv", "site_revenue"),
    ]

    for local_path, dataset_name in files:
        if os.path.exists(local_path):
            upload_file_to_s3(local_path, dataset_name)
        else:
            print(f"File '{local_path}' does not exist. Skipping.")
    
if __name__ == "__main__":
    main()