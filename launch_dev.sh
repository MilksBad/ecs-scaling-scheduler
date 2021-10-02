#!/bin/bash
# Description: Script used for deployingESC Scaling Scheduler

set -e

echo
echo "======== Launch Script ========"
echo

# check to see if we are creating a new stack or updating an existing
## sets the aws cli stack operation -- create or update
## enables rollback for the update-stack command
read -p "Is this an update to an existing stack? (y/n)?"
echo
case "$REPLY" in 
  y|Y ) STACK_OPERATION="update"; DISABLE_ROLLBACK=""; echo "$STACK_OPERATION stack";;
  n|N ) STACK_OPERATION="create"; DISABLE_ROLLBACK=" --disable-rollback"; echo "$STACK_OPERATION stack";;
  * ) echo "invalid response... exiting"; return;;
esac
echo

# Check if any required environment variables were passed in, if not use good defaults
if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME="xxx"
fi

if [ -z "$CFT_ROOT_URL" ]; then
    CFT_ROOT_URL="s3.xxx.amazonaws.com"
fi

if [ -z "$AWS_REGION" ]; then
    AWS_REGION="us-west-1"
fi

if [ -z "$ENV_NAME" ]; then
    ENV_NAME="dev"
fi

if [ -z "$S3_BUCKET" ]; then
    S3_BUCKET="xxx-dev-ecs-scaling-scheduler-cft"
fi

if [ -z "$CODE_BUCKET" ]; then
    CODE_BUCKET="xxx-dev-ecs-scaling-scheduler-cft"
fi

if [ -z "$CF_STACK_NAME" ]; then
    CF_STACK_NAME="xxx-dev-ecs-scaling-scheduler"
fi

if [ -z "$CLOUD_BROKER" ]; then
    CLOUD_BROKER="xxx"
fi


# Establish the Environment Variables
echo "=== Environment Variables ==="
echo
echo "Provided Project Name         - "$PROJECT_NAME""
echo "Provided Root Template URL    - "$CFT_ROOT_URL""
echo "AWS Region                    - "$AWS_REGION""
echo "Provided Env Name             - "$ENV_NAME""
echo "Provided Bucket Name          - "$S3_BUCKET""
echo "Provided Code Bucket Name     - "$CODE_BUCKET""
echo "Provided Stack Name           - "$CF_STACK_NAME""
echo "Provided Cloud Broker         - "$CLOUD_BROKER""

echo
echo "============================="
echo

# Pause to check provided variables before proceeding
read -p "Continue using the provided variabls? (y/n)?"
echo
if [ "$REPLY" = "n" ]; then
  echo "Exiting"
  exit 1
fi
echo

echo "=== Deploying into "$AWS_REGION" ==="
echo

# Check if S3 Bucket exists already, if so do nothing, if not create it
echo "=== Checking if S3 Bucket exists === "
echo
if [[ $(aws s3api list-buckets --query "Buckets[?Name == \`${S3_BUCKET}\`].[Name]" --output text) = ${S3_BUCKET} ]]; then
    echo "Bucket Exists. Doing nothing.";
    echo "Bucket name is: ${S3_BUCKET}"
    echo
else
    # Create a S3 bucket
    echo
    echo "=== Creating S3 Bucket === "
    echo
    aws s3api create-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION" --create-bucket-configuration LocationConstraint="$AWS_REGION"
    aws s3api put-bucket-encryption --bucket "$S3_BUCKET" --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
    aws s3api put-bucket-tagging --bucket "$S3_BUCKET" --tagging 'TagSet=[{Key=Project,Value='$PROJECT_NAME'},{Key=Environment,Value='$ENV_NAME'}]'
    aws s3api put-public-access-block --bucket "$S3_BUCKET" --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    echo
fi

echo "=== Uploading into S3 Bucket "$S3_BUCKET""
echo
aws s3 sync . s3://"$S3_BUCKET"/ --region="$AWS_REGION"

# Deploy the main cloudformation
echo
echo "=== Launching Stack ==="
echo
aws cloudformation "$STACK_OPERATION"-stack --region "$AWS_REGION" --stack-name "$CF_STACK_NAME" --template-url  https://"${S3_BUCKET}".s3."$AWS_REGION".amazonaws.com/base.yaml \
--parameters ParameterKey=ProjectName,ParameterValue="$PROJECT_NAME" \
ParameterKey=EnvName,ParameterValue="$ENV_NAME" \
ParameterKey=Codebucket,ParameterValue="$CODE_BUCKET" \
ParameterKey=TemplateBucket,ParameterValue="$S3_BUCKET" \
ParameterKey=TemplateRootURL,ParameterValue="$CFT_ROOT_URL" \
--capabilities CAPABILITY_NAMED_IAM$DISABLE_ROLLBACK
echo
echo "=== Please Wait ==="
echo
aws cloudformation wait stack-"$STACK_OPERATION"-complete --region "$AWS_REGION" --stack-name "$CF_STACK_NAME"
echo
echo
echo "=== Script Finished ==="
