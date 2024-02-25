---
layout: post
title:  "Recover cluster permission with EKS Access Entry"
author: eason
categories: [Amazon Elastic Kubernetes Service (EKS), Kubernetes]
image: assets/images/2024/recover-permission-using-eks-cluster-access-entry/cover.png
---

In the past, granting access permissions to Amazon Elastic Kubernetes Service (EKS) clusters typically relied on a combination of AWS IAM Authenticator and the aws-auth ConfigMap. However, this method of management could encounter limitations and issues such as formatting errors, difficulties with automated updates, and the accidental deletion of IAM users.

To address these issues, EKS has released a new authentication method — **EKS Access Entry**, offering an optimized solution. EKS Access Entry simplifies the management configuration of the aws-auth ConfigMap and can even restore access permissions to EKS clusters in certain scenarios.

## Why is this feature so important?

Previously, Amazon EKS integrated IAM as the primary identity authentication system. However, the authentication still relied on AWS IAM Authenticator running in EKS for verification, and this authentication mechanism needed to be managed through the aws-auth ConfigMap. Typically, this workflow isn't a significant issue, but with the increase in different EKS usage scenarios, several limitations and problems have arisen:

- Directly editing the aws-auth ConfigMap often encounters formatting issues, such as indentation errors, incorrect syntax and formatting, inconsistencies between the new version of yaml and the current online environment, and overwriting of past settings by the new yaml file. Any of these could inadvertently cause disaster.
- Integrating the CI/CD pipeline to achieve automated updates requires updates to Kubernetes resources (aws-auth ConfigMap). Whether using AWS Lambda, Terraform, CloudFormation, or CDK, in the past, it was necessary to call the Kubernetes API to achieve resource control updates. This could not be accomplished through the APIs provided by AWS EKS itself for automation and permission management. Meanwhile, under the stricter security management of Kubernetes Role-Based Access Control (RBAC) clusters, developers in the team with limited Kubernetes user identities may struggle to update the aws-auth ConfigMap through the Kubernetes API.
- The IAM user who initially created the EKS Cluster gets deleted, preventing the team from accessing the EKS Cluster. This is a common occurrence when integrating AWS Single-Sign On (AWS SSO) or when a colleague leaves the company. Even AWS's Root account cannot restore access permissions to the Kubernetes Cluster.

To solve this problem, we can introduce EKS Access Entry to optimize EKS cluster permission management and even rescue and restore cluster access permissions in the above scenarios. EKS Access Entry is a solution that allows administrators to restore access to EKS clusters without needing an IAM user.

## Digging Deeper into the New Features of EKS Access Entry

EKS Access Entry is a new solution for managing Amazon EKS cluster access permissions. It offers an optimized way to manage cluster authentication modes and access policies, and it addresses the limitations and problems encountered when using IAM Authenticator and aws-auth ConfigMap to manage access permissions.

By default, when creating an EKS cluster, the operation to create the EKS Cluster is automatically assigned to an IAM identity in Kubernetes's Role-Based Access Control (RBAC) to create rules and a Kubernetes User, and to assign the `system:master` operating identity.

### What is Kubernetes Role-Based Access Control (RBAC)?

Kubernetes Role-Based Access Control (RBAC) is a mechanism for implementing authorization and permission management in Kubernetes clusters. Using RBAC, you can define roles and role bindings to grant specific permissions on cluster resources to users or service accounts.

### Default EKS Authentication

Looking back at what was mentioned earlier, in EKS, the default is only to give the IAM identity that created the EKS Cluster (for example: `arn:aws:iam::123456789:user/eason`) the `system:master` group operating identity. If you want to allow a new IAM user (for example: `arn:aws:iam::123456789:user/developer`) to operate the EKS Cluster, **setting any IAM policy in the IAM console cannot grant any access permissions to the EKS Cluster**. Instead, you need to update the `aws-auth` ConfigMap resource to grant access to other IAM identities:

![EKS authentication workflow](/assets/images/2024/recover-permission-using-eks-cluster-access-entry/auth-workflow.png)

For example: To grant my IAM user access to the EKS Cluster, you can add a `mapUsers` block to the `aws-auth` ConfigMap using the kubectl command, which includes a specified user's ARN (`arn:aws:iam::123456789:user/developer`), and associates the `system:master` group, indicating that the `developer` user now has access to the EKS Cluster.

```bash
$ kubectl get cm/aws-auth -o yaml -n kube-system
apiVersion: v1
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::123456789:role/EKSManagedNodeWorkerRole
      username: system:node:{{EC2PrivateDNSName}}
  mapUsers: |
    - groups:
      - system:masters
      userarn: arn:aws:iam::123456789:user/developer
      username: developer

```

### Changes in Cluster Authentication Mode after Supporting EKS Access Entry

This update supports EKS Clusters of the following Kubernetes and platform versions:

| Kubernetes version | Platform version |
| --- | --- |
| 1.28 | eks.6 |
| 1.27 | eks.10 |
| 1.26 | eks.11 |
| 1.25 | eks.12 |
| 1.24 | eks.15 |
| 1.23 | eks.17 |

Two different authentication modes can be supported:

1. **IAM Cluster Authentication Mode**: This is the default authentication mode of Amazon EKS, which is based on IAM for identity authentication and relies on the `aws-auth` ConfigMap.
2. **EKS Cluster Authentication Mode (Access Entry)**: This is a new authentication mode introduced by EKS Access Entry. It is based on Kubernetes's native identity authentication mechanism but is completed via EKS's own API, making it possible to permit an IAM User/Role operation with a few clicks on the EKS console interface.

In newly created EKS Clusters, you may notice the update of the following options:

![EKS authentication modes](/assets/images/2024/recover-permission-using-eks-cluster-access-entry/cover.png)

## EKS Access Entry Authentication Method

### Prerequisites

Before using EKS Access Entry, ensure that the following prerequisites are met:

- Your Amazon EKS cluster has the EKS Access Entry feature enabled (as mentioned earlier, the authentication mode supports EKS API and not just ConfigMap).
- You have the appropriate IAM permissions to perform operations related to EKS Access Entry (for example: `eks:CreateAccessEntry`, `eks:AssociateAccessPolicy`, `eks:DeleteAccessEntry`, `eks:DescribeAccessEntry`, etc.).

After enabling Access Entry authentication, you can use this new authentication method to manage cluster access permissions.

### Access Policy Access Permissions

Each access entry has an associated access policy that defines access permissions to cluster resources. Access policies use the JSON format of AWS Identity and Access Management (IAM) for definition. The following are examples of access policies:

| Access Policy | Description | Kubernetes verb |
| --- | --- | --- |
| AmazonEKSAdminPolicy | Full administration permissions | * |
| AmazonEKSClusterAdminPolicy | Cluster administration permissions | - |
| AmazonEKSEditPolicy | Read-write permissions | create, update, delete, get, list |
| AmazonEKSViewPolicy | Read-only permissions | get, list |

The above table may vary with version updates, for details, please refer to [access-policy-permissions].

## Implementing and Using EKS Access Entry to Manage or Restore EKS Cluster Access Permissions

In situations where the IAM user who initially created the EKS Cluster gets deleted, preventing the team from accessing the EKS Cluster, if the current IAM User/Role has the operating permissions of Access Entry, then access permissions to the EKS Cluster can be restored (or revoked) through this feature. EKS Access Entry can be operated through AWS CLI or AWS Management Console.

**EKS Console (AWS Management Console)**

(1) On the EKS cluster details page, click the "Access" option.

(2) On the “IAM Access Entries" page, click the "Create access entry" button in the upper right corner.

![Create EKS Access Entry](/assets/images/2024/recover-permission-using-eks-cluster-access-entry/create-access-entry.png)

(3) In the "Create access entry" dialog box, enter the following information:

- IAM Principal ARN: Specify the ARN of the IAM User or IAM Role.
- Kubernetes groups: This field is used to associate the IAM User/Role with the Kubernetes Group (Role & Rolebinding) that is predefined in Kubernetes RBAC. If you want to directly associate the predefined Access Entry Policy (for example: `AmazonEKSClusterAdminPolicy`), you can skip this.
- Kubernetes username: The username you want this IAM user or role to have in Kubernetes. You can enter the name you want here or leave it blank. For example, `admin`.

![Configure IAM Access Entry](/assets/images/2024/recover-permission-using-eks-cluster-access-entry/config-iam-access-entry.png)

(4) In this step, you can choose the default Access Entry to grant IAM identity access permissions to the EKS Cluster. For example: `arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy`.

- Access Scope: Used to grant the scope of influence of the associated policy, for example, specifying that the IAM
User or Role should have permissions to all namespaces or to a specific namespace.

(5) Click "Add Policy" to associate the policy。

![設定 Access Policy](/assets/images/2024/recover-permission-using-eks-cluster-access-entry/access-policy.png)

**AWS CLI**

Alternatively, you can use the AWS CLI to create an access entry. Below are the steps to use AWS CLI to add a Cluster Admin to the EKS cluster via EKS Access Entry (using 'eks-cluster' as an example for the cluster name):

(1) Update your EKS cluster configuration to enable EKS Access Entry authentication mode (if you've already done this step, you can skip it).

```bash
aws eks update-cluster-config \
          --name eks-cluster  \
          --access-config authenticationMode=API_AND_CONFIG_MAP
```

(2) Create an Access Entry, and specify the IAM principal ARN (e.g., IAM User or IAM Role, here we use `arn:aws:iam::0123456789012:role/eks-admin` as an example)

```bash
 aws eks create-access-entry \
  --cluster-name eks-cluster \
  --principal-arn "arn:aws:iam::0123456789012:role/eks-admin"
```

(3) Associate the access policy with the Access Entry you just created. Here we use `AmazonEKSAdminPolicy` (which provides full administrative permissions) as an example.

```bash
 aws eks associate-access-policy \
  --cluster-name eks-cluster \
  --principal-arn "arn:aws:iam::0123456789012:role/eks-admin" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy \
  --access-scope '{"type": "cluster"}

```

After completing the above steps, you have successfully added a Cluster Admin to the EKS cluster via EKS Access Entry.

**Other Permission Settings**

Another use case is to link the EKS Access Entry feature with Kubernetes RBAC's own permissions.

For instance, we can create a Kubernetes Cluster called 'pod-and-config-viewer', and grant this role the permission to view Kubernetes Pods.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-viewer-role
rules:
  - apiGroups: ['']
    resources: ['pods', 'pods/log']
    verbs: ['list', 'get', 'watch']

```

Then, we bind this role to the 'pod-viewers' group.

Note: The Kubernetes Group ('pod-viewers') does not need to be created in advance.

```bash
kubectl create clusterrolebinding pod-viewer \
  --clusterrole=pod-viewer-role \
  --group=pod-viewers
```

Finally, you can directly use the corresponding feature of EKS Access Entry to associate the IAM role `arn:aws:iam::0123456789012:role/eks-pod-viewer` with the Kubernetes group `pod-viewers`, further enhancing the flexibility of permission settings.

```bash
aws eks create-access-entry \
  --cluster-name eks-cluster \
  --principal-arn "arn:aws:iam::0123456789012:role/eks-pod-viewer" \
  --kubernetes-group pod-viewers
```

## Summary

The release of EKS Access Entry introduces a new, more flexible mechanism for managing access permissions to EKS clusters. By integrating directly with Kubernetes's native identity authentication mechanism and providing a straightforward user interface, it simplifies the process of managing IAM users and roles. Moreover, in scenarios where access to the EKS Cluster is lost due to the deletion of the IAM user who initially created it, EKS Access Entry can restore access permissions, providing a safety net for teams using EKS.

It is important to note that EKS Access Entry doesn't replace the use of the `aws-auth` ConfigMap, but provides an additional, more flexible way to manage access permissions. This feature is currently supported in EKS clusters of Kubernetes version 1.23 and higher. For more information, refer to the official AWS documentation.

## Reference

[^access-policy-permissions]: [Access policy permissions](https://docs.aws.amazon.com/eks/latest/userguide/access-policies.html#access-policy-permissions)