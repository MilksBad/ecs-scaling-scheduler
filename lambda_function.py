import json
import boto3
import botocore

region = 'us-west-1'

def lambda_handler(event, context):
    ### The cloudwatch alarm sends a paramater called 'service' which is set to 'ecs_svc' , 'ec2_svc', or 'rds_svc'
    ### Lambda decides depending on the value which service to target
    targetService = event.get('service')

    ### The cloudwatch alarm sends a paramater called 'action' which is set to 'start' or 'stop'
    ### Lambda decides depending on the value whether to start or stop the container
    cloudwatchvalue = event.get('action')

    ### The cloudwatch alarm sends a paramater called 'target' which contains either the 'ecs cluster name' , 'ec2 instance ID', or 'rds id'
    targetName = event.get('target')

##!!! Rewrote so that based on "service type" passed by cloudwatch alarm ; "acction" will happen to "target"
##################################################################################
    if 'ecs_svc' == targetService :
        client = boto3.client('ecs')

        ### Query to the ECS API to get all running services
        ### Output limit is currently set to 50
        try:
            response = client.list_services(
            cluster=targetName,
            maxResults=50,
            launchType='FARGATE',
            schedulingStrategy='REPLICA'
            )
        except:
            print("didnt worked")

        ### Retrieves only the plain service arns from the output
        ### Values are stored in a list
        servicelist = response['serviceArns']
        print(servicelist)
        
        print(cloudwatchvalue)
        
        if 'start' == cloudwatchvalue:   #you can also and check if servicetype == ec2:
            spawncontainer(servicelist,targetName)
            
        elif 'stop' == cloudwatchvalue:
            stopcontainer(servicelist,targetName)
        
        return {
            'statusCode': 200,
            'body': json.dumps('Script finished - ECS')
        }

    elif 'ec2_svc' == targetService :
        ec2 = boto3.client('ec2', region_name=region)

        print(cloudwatchvalue)
        
        if 'start' == cloudwatchvalue: 
            start_ec2(targetName)
            
        elif 'stop' == cloudwatchvalue:
            stop_ec2(targetName)

        return {
            'statusCode': 200,
            'body': json.dumps('Script finished - EC2')
        }

    elif 'rds_svc' == targetService :
        rds = boto3.client('rds')
        print(cloudwatchvalue)
        
        if 'start' == cloudwatchvalue: 
            start_db_instances(targetName)
            
        elif 'stop' == cloudwatchvalue:
            stop_db_instances(targetName)
            
        return {
            'statusCode': 200,
            'body': json.dumps('Script finished - RDS')
        }

########## Action definitions ###########################

##################################################### ECS #############################
### Sets the desired count of tasks per service to 1
### Container will spawn after a few moments
def spawncontainer(servicearns,targetName):
    client = boto3.client('ecs')
    for srv in servicearns:
        responseUpdate = client.update_service(
            cluster=targetName,
            service=srv,
            desiredCount=1,
        )

### Sets the desired count of tasks per service to 0
### Services still runs but without any container
def stopcontainer(servicearns,targetName):
    client = boto3.client('ecs')
    for srv in servicearns:
        responseUpdate = client.update_service(
            cluster=targetName,
            service=srv,
            desiredCount=0,
        )

##################################################### EC2 #############################
#start instances
def start_ec2(targetName):
    ec2 = boto3.client('ec2', region_name=region)
    ec2.start_instances(InstanceIds=[targetName])
    print('started ec2 instances: ' + str(targetName))

#stop instances 
def stop_ec2(targetName):
    ec2 = boto3.client('ec2', region_name=region)
    ec2.stop_instances(InstanceIds=[targetName])
    print('stopped ec2 instances: ' + str(targetName))


##################################################### rds #############################
#start db instances
def start_db_instances(targetName):
    rds = boto3.client('rds')
    rds.start_db_instance(DBInstanceIdentifier=targetName)
    print('started DB instances: ' + str(targetName))

#stop db instances   
def stop_db_instances(targetName):
    rds = boto3.client('rds')
    rds.stop_db_instance(DBInstanceIdentifier=targetName)
    print('stopped DB instances: ' + str(targetName))
