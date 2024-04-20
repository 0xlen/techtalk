---
layout: post
title:  "How Kubecost Retrieves Unused Disk Information across an Entire AWS Account"
author: eason
categories: [Amazon Elastic Kubernetes Service (EKS), Kubernetes]
image: assets/images/2024/how-kubecost-get-all-aws-disks/cover.png
---

This article will dive into how Kubecost collects information on unused disks across an entire AWS account. Kubecost is a popular tool for managing cost and resources in Kubernetes environments. We will explain how Kubecost identify and collect unused disk resources.

## Kubecost Introduction

Kubecost is a project developed by Stackwatch, specifically for monitoring and analyzing the cost of Kubernetes. It offers both an open-source version (Opencost) and a paid subscription version (Kubecost Enterprise). Its primary use case lies in achieving overall cost visibility for Kubernetes clusters. The open-source version of Kubecost limits the storage period of billing results to 15 days. If you need to keep the metrics for more than 15 days, you will need to upgrade to the paid version.

Amazon EKS supports a custom version of Kubecost (Amazon EKS-optimized Kubecost), co-developed by AWS and Kubecost. With Kubecost, you can view the cost distribution of the cluster, understand which applications or services are consuming the most resources, and allow monitoring based on Kubernetes resources (including Pods, Nodes, Namespaces, and Labels) for detailed cost monitoring and analysis. This helps teams visualize Amazon EKS invoice details, allocate costs, and charge fees to organizational units such as application teams.

In addition, Kubecost can provide information on unused disk space, which is very helpful for resource management and cost control.

## How Kubecost Retrieves Unused Disk Information

An interesting question arose around the design of Kubecost's unused disk information feature. One day, a user installing the Amazon EKS-optimized version of Kubecost found that Kubecost could obtain the unused disk information for the entire account.

This user wondered if the default permissions were too broad. Besides installing Kubecost according to the EKS official document, the user did not provide any account-level permissions, thus raising this question out of curiosity about potential security concerns:

```bash
helm upgrade -i kubecost oci://public.ecr.aws/kubecost/cost-analyzer --version kubecost-version \
    --namespace kubecost --create-namespace \
    -f https://raw.githubusercontent.com/kubecost/cost-analyzer-helm-chart/develop/cost-analyzer/values-eks-cost-monitoring.yaml
```

To understand the mechanism by which Kubecost obtains all EBS disks under an AWS account, we first need to analyze how Kubecost obtains disk information and understand the relevant permission settings involved.

In order to demystify how it works and do analysis, I used the open-source project opencost as sample, specifically version 2.2. By digging further, the implementation of looking idle AWS EBS disks is defined in the `GetOrphanedResources()` method [^kubecost-getorphanedresource]:

```go
func (aws *AWS) GetOrphanedResources() ([]models.OrphanedResource, error) {
	volumes, volumesErr := aws.getAllDisks()
	addresses, addressesErr := aws.getAllAddresses()

  ...

	for _, volume := range volumes {
		if aws.isDiskOrphaned(volume) {
			cost, err := aws.findCostForDisk(volume)
			if err != nil {
				return nil, err
			}
      ...

```

If we look further, we can see that `getAllDisks()` is a method that traverses all regions under the account through a loop, and performs another operation to `getDisksForRegion()` to get the information in a single region [^kubecost-getdisk]. Here, the `DescribeVolumes` API provided by EC2 [^aws-api-ec2-describe-volumes] is used to obtain this information:

```go
func (aws *AWS) getDisksForRegion(ctx context.Context, region string, maxResults int32, nextToken *string) (*ec2.DescribeVolumesOutput, error) {
	aak, err := aws.GetAWSAccessKey()
	if err != nil {
		return nil, err
	}

	cfg, err := aak.CreateConfig(region)
	if err != nil {
		return nil, err
	}

	cli := ec2.NewFromConfig(cfg)
	return cli.DescribeVolumes(ctx, &ec2.DescribeVolumesInput{
		MaxResults: &maxResults,
		NextToken:  nextToken,
	})
}

func (aws *AWS) getAllDisks() ([]*ec2Types.Volume, error) {
	regions := aws.Regions()
	volumeCh := make(chan *ec2.DescribeVolumesOutput, len(regions))

	// Get volumes from each AWS region
	for _, r := range regions {
		// Fetch volume response and send results and errors to their
		// respective channels
		go func(region string) {
		   ...

			// Query for first page of volume results
			resp, err := aws.getDisksForRegion(context.TODO(), region, 1000, nil)
      ...

```

So, the answer seems obvious. Kubecost still relies on the `DescribeVolumes` provided by AWS to obtain this information at the underlying implementation. But where is this permission from?

In the deployment of Kubecost, the kubecost-cost-analyzer includes a `cost-model` container application that is responsible for calling the AWS API in the subroutine mentioned above:

```bash
NAME                                              READY   STATUS    RESTARTS   AGE
pod/kubecost-cost-analyzer-688d699b88-w5d8f       0/4     Pending   0          21s
pod/kubecost-forecasting-6c6456668f-tlhv7         0/1     Pending   0          20s
pod/kubecost-prometheus-server-6b584dc478-6kd7q   0/1     Pending   0          20s

NAME                                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)             AGE
service/kubecost-aggregator          ClusterIP   10.100.10.104    <none>        9004/TCP            23s
service/kubecost-cloud-cost          ClusterIP   10.100.193.45    <none>        9005/TCP            23s
service/kubecost-cost-analyzer       ClusterIP   10.100.26.236    <none>        9003/TCP,9090/TCP   22s
service/kubecost-forecasting         ClusterIP   10.100.169.241   <none>        5000/TCP            22s
service/kubecost-prometheus-server   ClusterIP   10.100.185.108   <none>        80/TCP              21s

NAME                                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/kubecost-cost-analyzer       0/1     1            0           22s
deployment.apps/kubecost-forecasting         0/1     1            0           22s
deployment.apps/kubecost-prometheus-server   0/1     1            0           21s

NAME                                                    DESIRED   CURRENT   READY   AGE
replicaset.apps/kubecost-cost-analyzer-688d699b88       1         1         0       22s
replicaset.apps/kubecost-forecasting-6c6456668f         1         1         0       21s
replicaset.apps/kubecost-prometheus-server-6b584dc478   1         1         0       21s

```

Therefore, to figure out where the permission come from, there's a high probability that we need to look into two permission settings:

- Service Account: Whether the IAM Role for Service Account (IRSA) feature supported by EKS is being used.
- The IAM permissions (Instance Profile IAM Role) of the Worker Node (EC2 instance) itself.

In the earlier Helm installation steps, we didn't set any related IRSA permissions. As expected, no IAM Role is associated when I'm looking the service account details. The default Service Account for kubecost is only used to grant Kubecost permissions to access Kubernetes resources (for example, getting permissions for resources like Pod, Node, PV, PVC, and so on). This is defined in the associated Helm Chart [^kubecost-cost-analyzer-cluster-role-template].

```bash
$ kubectl get pod/kubecost-cost-analyzer-688d699b88-w5d8f -n kubecost -o yaml | grep -i serviceaccount
  serviceAccount: kubecost-cost-analyzer
  serviceAccountName: kubecost-cost-analyzer

$ kubectl describe sa/kubecost-cost-analyzer -n kubecost
Name:                kubecost-cost-analyzer
Namespace:           kubecost
Labels:              app=cost-analyzer
                     app.kubernetes.io/instance=kubecost
                     app.kubernetes.io/managed-by=Helm
                     app.kubernetes.io/name=cost-analyzer
                     helm.sh/chart=cost-analyzer-2.2.0
Annotations:         meta.helm.sh/release-name: kubecost
                     meta.helm.sh/release-namespace: kubecost
Image pull secrets:  <none>
Mountable secrets:   <none>
Tokens:              <none>
Events:              <none>

```

So if it's not an IRSA setting, we can be more certain that it's probably related to the IAM permissions associated with the EC2 instance itself. By default, every EKS Worker Node will use some default IAM permission settings (IAM Policy), which include [^eks-worker-node-iam-role]:

- [AmazonEKSWorkerNodePolicy](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEKSWorkerNodePolicy.html)
- [AmazonEKS_CNI_Policy](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEKS_CNI_Policy.html)

The purpose of these permissions is to enable necessary Kubernetes applications running on EC2 to work properly (for example: kubelet and CNI Plugin). Therefore, it can be expected that when deploying Kubecost to run on a Worker Node, it will usually use the default IAM permissions corresponding to the EKS node. From the default policy `AmazonEKSWorkerNodePolicy`, we can notice the following information:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeVolumes",
                ...
            ],
            "Resource": "*"
        }
    ]
}

```

To verify whether it's related to the aforementioned permissions, I added a denial policy to the IAM Role corresponding to the Worker Node for testing:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "TestKubeCostFindAllDisks",
            "Effect": "Deny",
            "Action": "ec2:DescribeVolumes",
            "Resource": "*"
        }
    ]
}

```

Not surprisingly, when Kubecost attempts to extract disk data, the anticipated error can be observed:

```bash
$ kubectl logs $KUBECOST_POD cost-model -n kubecost

INF unable to get addresses: %s logged 5 times: suppressing future logs
WRN unable to get disks: operation error EC2: DescribeVolumes, https response error StatusCode: 403, RequestID: b1eb2ada-8813-441c-a2f9-64847e14f6cd, api error UnauthorizedOperation: You are not authorized to perform this operation.
WRN unable to get disks: operation error EC2: DescribeVolumes, https response error StatusCode: 403, RequestID: 46053624-5c2d-4ef3-a145-f01917eeec84, api error UnauthorizedOperation: You are not authorized to perform this operation.
```

Therefore, we can understand how Kubecost is able to retrieve EBS disk resources from all regions without the need to assign relevant permissions when installing it. The default IAM Role of the worker node associated `ec2:DescribeVolumes` permission that ensures the necessary operational permissions for the kubelet and corresponding components in the EKS-Optimized AMI. This permission is used to obtain operational information related to the EC2 instance and associated resources in the region (for example, the requirements for deploying EBS Volumes using the EBS CSI Driver) and acts as part of the data for related Kubernetes object resources (for example, PersistentVolume and PersistentVolumeClaim), only provides read access and does not include any write operations, hence it cannot modify any EBS resources.

When kubecost is running, it scans for idle EBS resources (EBS volumes not attached to any EC2 instance) in the AWS account region using the Worker Node's own IAM identity and permissions. These resources are then filtered out for cost-saving optimization recommendations.

## Summary

This article dive into how Kubecost collects information on unused disks across an AWS account, addressing potential user concerns after installing Kubecost and discovering that it can access unused disk information for the entire account. In addition to conducting relevant code analyses, I also explain how Kubecost interacts with the AWS API and uses a variety of techniques and methods to identify and collect unused disk resources.

Upon thorough analysis and verification, we confirm that Kubecost uses the IAM identity and permissions of the Worker Node itself to obtain information on unused EBS disks within an AWS account. This approach does not overstep or violate security principles, as Kubecost only uses the default `ec2:DescribeVolumes` permission, a necessary permission to ensure the operation of Kubernetes, and only has read access without the write operation to modify any EBS resources.

Hope this helps and provides readers with a deeper understanding of how Kubecost retrieves information on AWS unused disks, and clarify related security concerns.

## References

[^eks-kubecost]: [Amazon EKS Cost monitoring](https://docs.aws.amazon.com/eks/latest/userguide/cost-monitoring.html)
[^kubecost-getorphanedresource]: [opencost v2.2 GetOrphanedResources()](https://github.com/opencost/opencost/blob/088f891d8ed6c48d688c31028542ea7ac34331ed/pkg/cloud/aws/provider.go#L1836C1-L1858C1)
[^kubecost-getdisk]: [opencost v2.2 Get Disks](https://github.com/opencost/opencost/blob/088f891d8ed6c48d688c31028542ea7ac34331ed/pkg/cloud/aws/provider.go#L1702-L1834)
[^aws-api-ec2-describe-volumes]: [AWS API - EC2 DescribeVolumes](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_DescribeVolumes.html)
[^kubecost-cost-analyzer-cluster-role-template]: [kubecost v2.2 cost-analyzer-cluster-role-template.yaml](https://github.com/kubecost/cost-analyzer-helm-chart/blob/b6d32237dbb80b10dd851dbcc07441171b27a701/cost-analyzer/templates/cost-analyzer-cluster-role-template.yaml)
[^eks-worker-node-iam-role]: [Amazon EKS node IAM role](https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html)