# backupViaTag
Create Amazon Machine Images (AMIs) based on tags assigned to instances

## Summary
This script will create backups of instances in all regions that have a tag that matches key:value (eg: Key=Backup, Value=Production). This allows you configure the backups via the tags on the instances themselves, rather than having to maintain a list of instances to be backed up. The script also creates an expiration tag on the AMIs so they can later be deleted. 

## Features
### Tag Based
Using different tags allows for a variety of backup schedules and retention periods to be configured. You could have a daily backup with an expiry of 30 days for instances with the tag Backup:ProductionDaily while having a weekly backup on Sunday with an expiry of 6 months for instances with the tag Backup:ProductionWeekly. 

### Optional reboot
By default the script will not reboot instances when it creates the backup. If you have an instance that requires a reboot to ensure filesystem integrity, you can add the tag BackupReboot:yes to the instance. Read more about about the `--no-reboot` option here - http://docs.aws.amazon.com/cli/latest/reference/ec2/create-image.html

### Automatic purge
Each time the script is run, it will look for expired backups and remove them. This means that if you schedule backupViaTag to create daily backups, it will also run the purge job daily. Only backups that have expired will actually be purged. If you want to run a purge job without creating any backups you can just specify a non-existent tag. The `-e` flag has no impact in this scenario. Eg:

`backupViaTag -t thisCrazyTag:DoesntExist -e "10000 days"`

## Usage
### Quick examples
Backup instances tagged Backup:ProductionDaily with an expiry of 30 days:

`backupViaTag -t Backup:prodDaily -e "30 days"`

Backup instances tagged Backup:ProductionWeekly with an expiry of 6 months:

`backupViaTag -t Backup:prodWeekly -e "6 months"`

Backup instances tagged VeryImportant:KeepBackups and keep them forever:

`backupViaTag -t VeryImportant:KeepBackups -e "never"`

The syntax for the time until expiry follows the GNU date tool:
https://www.gnu.org/software/coreutils/manual/html_node/Examples-of-date.html

### Tagging instances
Instances can be tagged using the EC2 Console. Select the instance in the instance list and on the bottom pane choose the "Tags" tab. From there you can add new tags for instances you want backed up or even multiple tags to have an instance covered by more than one backup schedule. Eg:

![tags](https://cloud.githubusercontent.com/assets/15039809/10413501/eaab2e02-6ff6-11e5-9ee6-1a9a5d1a3958.png)

You can also create a tag of **BackupReboot:yes** to tell backupsViaTag to reboot the instance when creating the AMI to ensure filesystem integrity. 

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
0 23 *  *  *  * ec2-user backupViaTag -t Backup:prodDaily -e "30 days"

# Weekly backup on Sunday at 3am for instances tagged Backup:ProductionWeekly with an expiry of 6 months
0 3  *  *  *  7 ec2-user backupViaTag -t Backup:prodWeekly -e "6 months"

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
#### CLI command to create the above IAM policy
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
#### CLI command to attach the role to the policy 
```
aws iam attach-role-policy --role-name backupViaTagRole \
  --policy-arn arn:aws:iam::$(aws ec2 describe-instances \
  --output text --instance-id $(curl -s http://169.254.169.254/latest/meta-data/instance-id) \
  --region $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | rev | cut -c 2- | rev) \
  --query 'Reservations[0].{AccoundID:OwnerId}'):policy/backupViaTagPolicy
```
#### CLI command to create an instance profile
```
aws iam create-instance-profile --instance-profile-name backupViaTagProfile
```
#### CLI command to add the role to the profile
```
aws iam add-role-to-instance-profile --instance-profile-name backupViaTagProfile \
    --role-name backupViaTagRole
```
#### CLI command to launch an instance using the IAM role 
```
aws ec2 run-instances --region ap-southeast-2 \
  --image-id ami-c11856fb --instance-type t2.micro \
  --iam-instance-profile "Name=backupViaTagProfile" \
  --key-name myKeypair 
```
## TODO
- Implement CloudFormation template that:
  - Creates IAM policies, roles and profiles
  - Creates a datapipeline with a schedule based on user input that executes the script 
- Some kind of notification option(s)
