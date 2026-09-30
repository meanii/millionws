"""Cost watchdog: terminate benchmark instances that outlived their deadline.

Runs from EventBridge every few minutes, outside the instances, so it still
works if cloud-init failed or the on-instance shutdown timer was removed.
Only instances tagged Project=<TAG_VALUE> are ever touched.
"""
import datetime
import os

TAG_VALUE = os.environ.get("TAG_VALUE", "millionws-bench")
MAX_AGE_MINUTES = int(os.environ.get("MAX_AGE_MINUTES", "255"))


def expired(instances, now, max_age_minutes):
    """IDs of instances launched more than max_age_minutes before now."""
    limit = datetime.timedelta(minutes=max_age_minutes)
    return [i["InstanceId"] for i in instances if now - i["LaunchTime"] > limit]


def handler(event=None, context=None, ec2=None, now=None):
    if ec2 is None:
        import boto3  # provided by the Lambda runtime; imported lazily so tests need no boto3

        ec2 = boto3.client("ec2")
    now = now or datetime.datetime.now(datetime.timezone.utc)
    instances = []
    pages = ec2.get_paginator("describe_instances").paginate(
        Filters=[
            {"Name": "tag:Project", "Values": [TAG_VALUE]},
            {"Name": "instance-state-name", "Values": ["pending", "running", "stopping", "stopped"]},
        ]
    )
    for page in pages:
        for reservation in page["Reservations"]:
            instances.extend(reservation["Instances"])
    doomed = expired(instances, now, MAX_AGE_MINUTES)
    if doomed:
        print(f"terminating {len(doomed)} instance(s) older than {MAX_AGE_MINUTES} min: {doomed}")
        ec2.terminate_instances(InstanceIds=doomed)
    else:
        print(f"{len(instances)} tagged instance(s), none past {MAX_AGE_MINUTES} min")
    return {"checked": len(instances), "terminated": doomed}
