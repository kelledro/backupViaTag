# backupViaTag
Create Amazon Machine Images (AMIs) based on tags assigned to instances

## Summary
This script will create backups of instances in all regions that have a tag that matches key:value (eg: Key=Backup, Value=Production). This allows you configure the backups via the tags on the instances themselves, rather than having to edit a list of instances to be backed up. The script also creates an expiration tag on the AMIs so they can later be deleted. 

## Features
### Tag Based
Using different tags allows for a variety of backup schedules and retention periods to be configured. You could have a daily backup with an expiry of 30 days for instances with the tag Backup:ProductionDaily while having a weekly backup on Sunday with an expiry of 6 months for instances with the tag Backup:ProductionWeekly. 

### Optional reboot
By default the script will not reboot instances when it creates the backup. If you have an instance that requires a reboot to ensure filesystem integrity, you can add the tag BackupReboot:yes to the instance. Read more about about the `--no-reboot` option here - http://docs.aws.amazon.com/cli/latest/reference/ec2/create-image.html

### Automatic purge
Each time the script is run, it will look for expired backups and remove them. This means that if you schedule backupViaTag to create daily backups, it will also run the purge job daily. Only backups that have expired will actually be purged.

## Usage
### Quick examples
Backup instances tagged Backup:ProductionDaily with an expiry of 30 days:

`backupViaTag -t Backup:ProductionDaily -e "+30 days"`

Backup instances tagged Backup:ProductionWeekly with an expiry of 6 months:

`backupViaTag -t Backup:ProductionWeekly -e "+6 months"`

Backup instances tagged VeryImportant:KeepBackups for ever:

`backupViaTag -t VeryImportant:KeepBackups -e "never"`

### Tagging instances

### Scheduling
Cron jobs for the above example look like:
```
# .---------------- minute (0 - 59)
# |  .------------- hour (0 - 23)
# |  |  .---------- day of month (1 - 31)
# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
# |  |  |  |  |
# *  *  *  *  * user-name command to be executed

# Daily backup at 11pm for instances tagged Backup:ProductionDaily with an expiry of 30 days
0 23 *  *  *  * ec2-user backupViaTag -t Backup:ProductionDaily -e "+30 days"

# Weekly backup on Sunday at 3am for instances tagged Backup:ProductionWeekly with an expiry of 6 months
0 3  *  *  *  7 ec2-user backupViaTag -t Backup:ProductionWeekly -e "+6 months"

```

## Requirements
### AWS CLI
http://docs.aws.amazon.com/cli/latest/userguide/installing.html

### Permissions
This script requires several IAM permissions to operate. The recommended method to grant these permissions is to create an IAM policy and then create an IAM EC2 Role that uses the policy. Finally, you launch an instance using the Role and run backupViaTag from this instance. API calls made from this instance are granted the permissions defined in the policy which removes the requirement to create and manage access keys.

#### IAM Policy
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
#### CLI command to create IAM policy
```
aws iam create-policy --policy-name backupViaTagPolicy \
  --policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\": \
  \"backupViaTagPolicy\",\"Effect\": \"Allow\",\"Action\": \
  [\"ec2:CreateImage\",\"ec2:CreateTags\",\"ec2:DeleteSnapshot\", \
  \"ec2:DeregisterImage\",\"ec2:DescribeImages\",\"ec2:DescribeInstances\", \
  \"ec2:DescribeRegions\"],\"Resource\":[\"*\"]}]}"
```

#### CLI command to create IAM role
```
aws iam create-role --role-name backupViaTagRole \
  --assume-role-policy-document "{\"Version\":\"2012-10-17\", \
  \"Statement\":[{\"Sid\":\"backupViaTagTrustPolicy\", \
  \"Effect\":\"Allow\",\"Principal\":{\"Service\": \
  \"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
```
#### CLI command to attach role to policy where 12345678912 is your AWS Account ID
```
aws iam attach-role-policy --role-name backupViaTagRole \
  --policy-arn arn:aws:iam::123456789012:policy/backupViaTagPolicy
```
#### CLI command to create an instance profile
```
aws iam create-instance-profile --instance-profile-name backupViaTagProfile`
```
#### CLI command to add the role to the profile
```
aws iam add-role-to-instance-profile --instance-profile-name backupViaTagProfile --role-name backupViaTagRole
```
#### CLI command to launch an instance using the IAM role 
```
aws ec2 run-instances --region ap-southeast-2 \
  --image-id ami-c11856fb --instance-type t2.micro \
  --iam-instance-profile "Name=backupViaTagProfile" \
  --key-name myKeypair 
```

