# backupViaTag

Create Amazon Machine Images (AMIs) based on tags assigned to instances

## Summary
This script will create backups of instances in all regions that have a tag that matches key:value (eg: Key=Backup, Value=Production). This allows you configure the backups via the tags on the instances themselves, rather than having to edit a list of instances to be backed up. The script also creates an expiration tag on the AMIs so they can later be deleted. 

## Features

### Tag Based

Using different tags allows for a variety of backup schedules and retention periods to be configured. You could have a daily backup with an expiry of 30 days for instances with the tag Backup:ProductionDaily while having a weekly backup on Sunday with an expiry of 6 months for instances with the tag Backup:ProductionWeekly. Cron jobs for this example look like:
```
# .---------------- minute (0 - 59)
# |  .------------- hour (0 - 23)
# |  |  .---------- day of month (1 - 31)
# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
# |  |  |  |  |
# *  *  *  *  * user-name command to be executed
0 23 *  *  *  * ec2-user amiBackup.sh -t Backup:ProductionDaily -e "+30 days"
0 3  *  *  *  7 ec2-user amiBackup.sh -t Backup:ProductionWeekly -e "+6 months"
```
### Optional reboot

By default the script will not reboot instances when it creates the backup. If you have an instance that requires a reboot to ensure filesystem integrity, you can add the tag BackupReboot:yes

## Usage

You can then go and tag instances as required and optionally add the BackupReboot:yes tag where appropriate.

## Requirements
### AWS CLI
https://aws.amazon.com/cli/

### Permissions
This script requires several IAM permissions to operate. The recommended method to grant these permissions is to create an IAM policy and then create an IAM EC2 Role that uses the policy. Finally, you launch an instance using the Role. API calls made from this instance are granted the permissions defined in the policy which removes the requirement to create and manage access keys.

IAM Policy
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "backupViaTagPolicy",
            "Effect": "Allow",
            "Action": [
                "ec2:CreateImage",
                "ec2:CreateTags",
                "ec2:DeleteSnapshot",
                "ec2:DeregisterImage",
                "ec2:DescribeImages",
                "ec2:DescribeInstances",
                "ec2:DescribeRegions"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
```
