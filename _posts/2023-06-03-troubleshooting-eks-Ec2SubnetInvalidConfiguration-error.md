---
layout: post
title:  "Troubleshooting EKS Managed Node Group Ec2SubnetInvalidConfiguration Error"
author: eason
categories: [Amazon Elastic Kubernetes Service (EKS), Kubernetes]
image: assets/images/2023/troubleshooting-eks-Ec2SubnetInvalidConfiguration-error/cover.png
---

Amazon Elastic Kubernetes Service (EKS) is a managed Kubernetes service that allows many Kubernetes administrators to quickly create and easily run Kubernetes clusters on AWS in a matter of minutes via commands, simplifying many operations. In 2019, EKS released new API support for Managed Node Groups [^eks-managed-nodegroup], which can automatically create and manage EC2 instances and add them to Kubernetes clusters, making it easier for users to add and expand computational nodes required by Kubernetes clusters, and even upgrade node versions via API or one-click integration.

However, during the process of adding or upgrading Managed Node Groups, it is possible to encounter the `Ec2SubnetInvalidConfiguration` error. Therefore, this article will further analyze the cause, common scenarios, and solutions of this error.

## How to identify this issue?

To check whether there is an `Ec2SubnetInvalidConfiguration` error in EKS Managed Node Groups, you can confirm whether there are any health issues through the EKS Console or AWS CLI commands. For example, by clicking on the "Compute" tab under `Cluster` > `Node groups` to enter the detailed page of the node group, you can check whether there is any error message in the `Health Issues` tab:

![/assets/images/2023/troubleshooting-eks-Ec2SubnetInvalidConfiguration-error/nodegroup-create-failed.png](/assets/images/2023/troubleshooting-eks-Ec2SubnetInvalidConfiguration-error/nodegroup-create-failed.png)

According to the EKS Managed Node Group upgrade process [^eks-managed-nodegroup-update-behavior], if node upgrades or new nodes are stuck after 15-20 minutes, there may be some problems with the work nodes during operation, and there is an opportunity to further troubleshoot possible causes through this information after a period of time. The example below shows the use of AWS CLI commands:

```
$ aws eks describe-nodegroup --nodegroup-name broken-nodegroup --cluster eks --region eu-west-1
{
    "nodegroup": {
        "nodegroupName": "broken-nodegroup",
        "clusterName": "eks",
        "version": "1.25",
        "releaseVersion": "1.25.9-20230526",
        "status": "CREATE_FAILED",
        "capacityType": "ON_DEMAND",
        "subnets": [
            "subnet-AAAAAAAAAAAAAAAAA",
            "subnet-BBBBBBBBBBBBBBBBB"
        ],
        "amiType": "AL2_x86_64",
        "health": {
            "issues": [
                {
                    "code": "Ec2SubnetInvalidConfiguration",
                    "message": "One or more Amazon EC2 Subnets of [subnet-AAAAAAAAAAAAAAAAA, subnet-BBBBBBBBBBBBBBBBB] for node group broken-nodegroup does not automatically assign public IP addresses to instances launched into it. If you want your instances to be assigned a public IP address, then you need to enable auto-assign public IP address for the subnet. See IP addressing in VPC guide: <https://docs.aws.amazon.com/vpc/latest/userguide/vpc-ip-addressing.html#subnet-public-ip>",
                    "resourceIds": [
                        "subnet-AAAAAAAAAAAAAAAAA",
                        "subnet-BBBBBBBBBBBBBBBBB"
                    ]
                }
            ]
        },
        "updateConfig": {
            "maxUnavailable": 1
        },
        ...
    }
}

```

The above example shows that when creating a node group, it failed and is in a `CREATE_FAILED` state.

## Common scenarios and causes

According to the definition of error exceptions [^eks-issues], it is easy to know that this error is usually caused by the subnet specified by EKS Managed Node Group not enabling auto-assign public IP address.

By default, when Managed Node Groups create EC2 instances, they need to rely on the subnet itself to enable this function. If the subnet does not enable auto-assign public IP address, EC2 instances will not be able to obtain public IPv4 addresses and will be unable to communicate with the Internet, leading to this error. Therefore, this gives rise to two different usage scenarios: Public Subnet and Private Subnet.

Public Subnet and Private Subnet refer to different subnets set in Amazon Virtual Private Cloud (VPC). Public Subnet means that resources in this subnet can communicate directly with the Internet and connect to the public Internet, while Private Subnet cannot communicate with the Internet directly:

![/assets/images/2023/troubleshooting-eks-Ec2SubnetInvalidConfiguration-error/subnet-diagram.png](/assets/images/2023/troubleshooting-eks-Ec2SubnetInvalidConfiguration-error/subnet-diagram.png)

(Image Source: Amazon Virtual Private Cloud User Guide [^subnet-diagram])

In short, if a subnet has a route pointing to an Internet Gateway resource (`0.0.0.0/0`), it can usually be considered that this subnet will be able to directly connect to the Internet. Otherwise, this subnet is expected to exist in a limited and private network environment.

### Encountering this error in Public Subnet

Previously, EKS would enable auto-assign public IPv4 addresses for all Node Groups under Managed Node Groups when creating them, regardless of whether they were in a Public Subnet or Private Subnet. However, this feature was updated in 2020 [^eks-feature-request-607]. Therefore, if you expect the EKS Managed Node Groups you deploy to be assigned public IPv4 addresses and allow direct connection to the Internet, you need to ensure that the Subnet you use to create or upgrade Managed Node Groups with Public Subnet enables auto-assign public IPv4 addresses (`MapPublicIpOnLaunch`):

```
$ aws ec2 describe-subnets --subnet-ids subnet-XXXXXXXXX
"Subnets": [
        {
            "CidrBlock": "192.168.64.0/19",
            "MapPublicIpOnLaunch": true,
            "State": "available",
            "SubnetId": "subnet-XXXXXXXXXXX",
            "VpcId": "vpc-XXXXXXXXXXX",
            ...
        }
    ]

```

### Encountering this error in Private Subnet

You may say, "I originally expected this subnet to be a Private Subnet, and maybe it was normal when I first created it." You may wonder why EKS Managed Groups may report that the subnet specified by my Node Groups does not automatically associate public IPv4 addresses during runtime or upgrade.

For Amazon EKS, the VPC associated subnet properties still apply to the principles mentioned earlier [^eks-vpc-subnet-considerations], so in many cases, this usually involves routing table settings related to the Subnet:

- A public subnet is a subnet with a route table that includes a route to an Internet gateway, whereas a private subnet is a subnet with a route table that doesn't include a route to an Internet gateway.

For example, the following is an example of a node group in the environment that is in a `DEGRADED` state due to subnet configuration issues after running Node Groups for a period of time, and there is an error message:

![/assets/images/2023/troubleshooting-eks-Ec2SubnetInvalidConfiguration-error/nodegroup-degraded.png](/assets/images/2023/troubleshooting-eks-Ec2SubnetInvalidConfiguration-error/nodegroup-degraded.png)

## Solutions and Steps

### Public Subnet

To solve this problem, if you choose Public Subnet to deploy Managed Node Groups, you need to ensure that the Subnet enables the Auto-assign Public IP address function. [Refer to the following steps](https://docs.aws.amazon.com/vpc/latest/userguide/modify-subnets.html#subnet-public-ip):

1. Log in to the AWS Console and go to the [VPC Management Console](https://console.aws.amazon.com/vpc/).
2. Choose the Subnet you want to use > Edit Subnet Settings, and select "Enable auto-assign public IPv4 address".
3. Check the option and click Save.

![/assets/images/2023/troubleshooting-eks-Ec2SubnetInvalidConfiguration-error/enable-auto-assign-up-settings.png](/assets/images/2023/troubleshooting-eks-Ec2SubnetInvalidConfiguration-error/enable-auto-assign-up-settings.png)

After completing these steps, if the node status fails, you can delete the failed Managed Node Groups and create a new one again, selecting the above Subnet. When EKS starts these EC2 instances, they can obtain Public IP addresses correctly based on the Subnet settings.

If the problem you encounter is not caused by the subnet not enabling auto-assign public IP address, please refer to the error information. [^eks-issues]

### Private Subnet

In the previous content, we described an error that can occur when encountering an expected private subnet. This is usually because EKS tries to start or check the subnet used by Managed Node Groups and assumes that the subnet belongs to the Public Subnet property due to the route pointing to the Internet Gateway, rather than the expected Private Subnet property, resulting in the following exception message:

![/assets/images/2023/troubleshooting-eks-Ec2SubnetInvalidConfiguration-error/incorrect-private-subnet-route.png](/assets/images/2023/troubleshooting-eks-Ec2SubnetInvalidConfiguration-error/incorrect-private-subnet-route.png)

To resolve this issue, you can configure the Route Table corresponding to the Private Subnet correctly, preserve internal requests within the VPC, and set the correct non-VPC request routing (such as removing the Internet Gateway for the `0.0.0.0/0` route) to point to other targets such as the [NAT Gateway](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html), which provides the ability to access the internet only internally from outside, ensuring that the worker nodes can still download images from other sources (such as Docker Hub) and interact with the EKS API Server when starting up.

## Summary

In this content, we mentioned common scenarios and causes of the `Ec2SubnetInvalidConfiguration` error when creating or upgrading an EKS Managed Node Group. In the case of Public Subnets, it is necessary to ensure that the Subnet has the "Auto-assign Public IP address" feature enabled; in the case of Private Subnets, it is necessary to correctly configure the Route Table corresponding to the Private Subnet and keep the internal requests within the VPC, while setting the correct non-VPC request routing to other targets, such as NAT Gateway.

By following the above solutions and related steps, we hope to help you, who are reading this content, to troubleshoot and solve this error more effectively, ensuring that the Managed Node Group runs smoothly.

## Reference Resources

[^eks-managed-nodegroup]: [Extending the EKS API: Managed Node Groups](https://aws.amazon.com/blogs/containers/eks-managed-node-groups/)
[^eks-issues]: [Amazon EKS resource Issue](https://docs.aws.amazon.com/eks/latest/APIReference/API_Issue.html)
[^eks-managed-nodegroup-update-behavior]: [Managed node update behavior - Scale up phase](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-update-behavior.html#managed-node-update-scale-up)
[^subnet-diagram]: [Subnets for your VPC - Subnet diagram](https://docs.aws.amazon.com/vpc/latest/userguide/configure-subnets.html#subnet-diagram)
[^eks-feature-request-607]: [[EKS] [request]: Remove requirement of public IPs on EKS managed worker nodes #607](https://github.com/aws/containers-roadmap/issues/607)
[^eks-vpc-subnet-considerations]: [Amazon EKS VPC and subnet requirements and considerations - Subnet requirements and considerations](https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html#network-requirements-subnets)