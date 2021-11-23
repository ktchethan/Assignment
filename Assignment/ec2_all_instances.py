import boto3
def get_running_instances():
    ec2_client = boto3.client("ec2", region_name="us-east-1")
    reservations = ec2_client.describe_instances(Filters=[
        {
            "Name": "instance-state-name",
            "Values": ["running"],
        },
        {
            'Name': 'vpc-id',
            'Values': ['default']
        },
    ]).get("Reservations")

    for reservation in reservations:
        for instance in reservation["Instances"]:
            instance_id = instance["InstanceId"]
            instance_type = instance["InstanceType"]
            if instance_type=='m5.large':
                if tags['Key'] == 'Name':
                    instancename = tags['Value']
                    print(f"{instancename},{instance_id}")