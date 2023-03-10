---
layout: post
title:  "Amazon ECS Finally Support Task Definition Deletion"
author: eason
categories: [Amazon Elastic Container Service (ECS), Container]
image: assets/images/2023/ecs-support-task-definition-deletion/cover.png
---

Dating back to 2015, Amazon ECS was officially GA and start to support run container workload on AWS.[^ecs-ga]; However, it only had the `DeregisterTaskDefinition`[^DeregisterTaskDefinition-API] API to deregister the specific task definition revision. 

While working with ECS, you might have come across situations where you need to delete an outdated or unused task definition. Until recently, ECS still did not support deleting task definitions, leaving many users interested to know when is task definition deletion supported.

Fortunately, AWS has now added support for task definition deletion, making it easier for users to manage their ECS environments.[^ecs-fr-685]

## What's the change?

On February 27, 2023, Amazon ECS announced now it supports deletion of inactive task definition revisions.[^whats-new-ecs-task-definition-deletion]

When a user creates a task definition, a new revision is automatically created for it(e.g. `myTaskDefinition:1`, `myTaskDefinition:2` ... etc). Each revision is immutable, which means that it cannot be deleted or modified once it is created. This was the main reason why task definition deletion was not supported earlier. Even if a user deleted all the tasks that used a specific task definition revision, the revision would still be present, taking up storage space and cluttering the ECS console.

Before this change, users could only mark the task definition revision as `INACTIVE` but cannot delete. Previously, `INACTIVE` task definition revisions remained discoverable in user's account indefinitely.

Now this change enables customers to delete inactive task definition revisions programmatically or via the Amazon ECS console. With this new capability, customers can now programmatically delete inactive task definition revisions or delete them via the Amazon ECS console. This change simplifies resource management and improves security posture by enabling customers to permanently delete task definition revisions that are no longer needed or contain undesirable configurations

![Task definition deletion option](/assets/images/2023/ecs-support-task-definition-deletion/ecs-console-deletion-option.png)

## Why having task definition deletion is so important?

When you store your credential pass it to your container through the environment variables, you may expose the unwanted security concern if you realize that the task definition will not be deleted. Here is an example of how this could happen:

```json
{
    "family": "",
    "containerDefinitions": [
        {
            "name": "",
            "image": "mysql",
            ...
            "environment": [
                {
                    "name": "MYSQL_ROOT_PASSWORD",
                    "value": "mySecretPassword"
                }
            ],
            ...
        }
    ],
    ...
}
```

In the past, the task definition could only be set as `INACTIVE` status and could not be removed. If an IAM user or IAM role had permission to describe the task definition, they could see the credential data that you might not expect them to have access to.

```bash
$ aws ecs describe-task-definition --task-definition myTaskDefinition:2

{
    "taskDefinition": {
        "containerDefinitions": [
            {
                "name": "web-service",
                "environment": [
                    {
                        "name": "MYSQL_ROOT_PASSWORD",
                        "value": "mySecretPassword"
                    }
                ],
                ...
            }
        ],
        "family": "myTaskDefinition",
        "revision": 2,
        "status": "INACTIVE",
        ...
}
```

As task definition can leak sensitive detail even when they are in `INACTIVE` status, it is recommended to use AWS Secrets Manager or AWS Systems Manager Parameter Store, both of which support injection as environment variables in the container.

Regardless of whether you store the credential in AWS Secrets Manager or AWS Systems Manager Parameter Store, you now have the option to permanently delete the task definition on the AWS Console, using programmable DeleteTaskDefinitions[^DeleteTaskDefinitions-API] API or AWS CLI command:

```
$ aws ecs delete-task-definitions --task-definitions <task name:revision>
```

## Conclusion

After 8 years, Amazon ECS finally has the support for task definition deletion. Task definition deletion in Amazon ECS helps reduce clutter in your ECS console, automate the task definition deletion process, and keep your environment clean.

What an exciting feature launch!

## References

[^ecs-ga]: [Amazon ECS history](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/document_history.html)
[^DeregisterTaskDefinition-API]: [Amazon ECS API - DeregisterTaskDefinition](https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_DeregisterTaskDefinition.html)
[^ecs-fr-685]: [\[ECS\] \[request\]: Delete task definitions #685](https://github.com/aws/containers-roadmap/issues/685)
[^whats-new-ecs-task-definition-deletion]: [Amazon ECS now supports deletion of inactive task definition revisions](https://aws.amazon.com/about-aws/whats-new/2023/02/amazon-ecs-deletion-inactive-task-definition-revisions/)
[^DeleteTaskDefinitions-API]: [Amazon ECS API - DeleteTaskDefinitions](https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_DeleteTaskDefinitions.html)


