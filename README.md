# Introduction
The ecs-scaling-scheduler uses CloudFormation to provision the AWS resources required to fasilitate the scheduled "shutdown" and "start-up" of the services assiged to a ECS Cluster.  The Dev, Test, and UAT environments are not used after normal working hours and so to save on operating costs the ECS services (app and proxy) can be set to "0" desired running during these peiords of non-use. 

## Original scripts and method
The solution mostly uses the following, but was incomple and required some modification to get working and other changes to fit into ProjectX. 
* Originaly found on = https://towardsaws.com/start-stop-aws-ecs-services-on-a-schedule-b35e14d8d2d5
* Original github = https://github.com/ThomasTusche/ecs-scaling-scheduler

## RTK - Edits / Changes
* Added launch scripts per environment
* Added "base.yaml" for cluster CloudFormation
* Customized names to include project name and enviroment (xxx-dev-thingname) so that resources won't conflict with eacheoother and easily be identified. 
* "AWS::Lambda::Permission" are required for each rule but was not original included. 

## Potential Improvements
* Only one Lambda is needed per cloud provider, but in this set up one is created per enviroment. 
* Curently a ".zip" verion of the python script for Lambda is included. If the Lambd script is updated, the .zip need to be updated manualy. Idealy the launch script would take the exsising scripty and build the zip. 



# ecs-scaling-scheduler
Scales all ecs service to 0 or 1 on a specific schedule

## main.yaml
Deploys the following resources to AWS:
1. AWS Lamba -> for scaling the ECS Services
1. AWS Cloudwatch rules -> one to send start command to Lambda, one for sending a stop command
1. AWS IAM Role -> IAM Role to attach to the Lambda Function
1. AWS IAM Policy -> Permissions for Lambda to write to CloudWatch Loggroups, and full ECS permissions

## lambda_function.py
Python3.8 script to scale all ECS services of a specific cluster either to 0 or 1.
The lambda takes the Cloudwatch Rule parameter for 'action' and 'cluster' to determine,
if the services should start or stop and on which cluster.

### lambda workflow
The lambda receives an 'action' value from Cloudwatch which is set to 'start' or 'stop'.
Additionally, the Cloudwatch rules submit the ECS Cluster name to the lambda.

Lambda uses the cluster name to query all services and put them into a list. Afterward
it iterates over this list and set the 'desired task count' to 1 or 0, depending on the 'action' value.

## lambda_function.zip
The zip file has to be uploaded to an S3 bucket before we run the Cloudformation code. 
The bucket name and the file key, needs to be entered in cloudformation. The cloudformation template
uses this information to pass the python code to the lambda function during its creation.

