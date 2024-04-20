---
layout: post
title:  "深入探討 kubecost 是如何取得整個 AWS 帳號的未使用磁碟資訊"
author: eason
categories: [Amazon Elastic Kubernetes Service (EKS), Kubernetes]
image: assets/images/2024/how-kubecost-get-all-aws-disks/cover.png
lang: tw
canonical_url: https://easontechtalk.com/tw/how-kubecost-get-all-aws-disks/
---

本文將深入研究 kubecost 是如何蒐集整個 AWS 帳號中未使用磁碟的資訊。kubecost 是一個廣受歡迎的工具，用於管理 Kubernetes 環境的成本和資源。本文將解釋 kubecost 如何與 AWS API 進行互動，並使用各種技術和方法來識別和收集未使用的磁碟資源。

## Kubecost 簡介

Kubecost 是 Stackwatch 開發的專案，專門用於監控和分析 Kubernetes 的成本。並且提供開源版本（Opencost）以及付費訂閱的版本（Kubecost Enterprise）。其主要用例，在於實現 Kubernetes 叢集的整體成本可見度。Kubecost 的開源版本將計費結果的儲存週期限定為 15 天。如果需要將指標保留 15 天以上，您必須升級至付費版本。

Amazon EKS 免費支援由 AWS 與 Kubecost 協同合作提供自訂版本的 Kubecost（Amazon EKS-optimized Kubecost），透過 Kubecost 可以查看集群的成本分布，並了解哪些應用或服務在消耗最多的資源，可讓監控按 Kubernetes 資源（包括 Pods、節點、命名空間和標籤）進行細部的成本監控和分析，幫助團隊視覺化 Amazon EKS 費用明細、分配成本，以及向應用程式團隊等組織單位收取費用。

此外，Kubecost 還可以提供未使用的磁碟空間資訊，這對於資源管理和成本控制非常有幫助。

## Kubecost 如何取得未使用磁碟資訊

不過 kubecost 的未使用磁碟訊息功能設計讓我也收到一個很有趣的問題，有使用者在安裝 Amazon EKS 安裝優化版本的 kubecost 後，安裝後他發現 kubecost 可以獲得整個帳號的未使用磁碟信息。

他懷疑是否預設的權限是否過大了，而且除了依照 EKS 官方的文件安裝 kubecost，他並沒有提供任何帳號等級的權限，因此特別好奇是否存在安全性疑慮，而提出這項問題：

```bash
helm upgrade -i kubecost oci://public.ecr.aws/kubecost/cost-analyzer --version kubecost-version \
    --namespace kubecost --create-namespace \
    -f https://raw.githubusercontent.com/kubecost/cost-analyzer-helm-chart/develop/cost-analyzer/values-eks-cost-monitoring.yaml
```

要了解 kubecost 其中獲取 AWS 帳號底下所有 EBS 磁碟的機制，就得先分析 kubecost 實際是如何獲取磁碟資訊，並且了解其中是否涉及相關的權限設定。

為了幫助分析，本文將以 kubecost 的基礎開源 opencost 專案的進行分析，以 2.2 版本為例，獲取是否存在閒置 AWS EBS 磁碟的相關分析被定義在 `GetOrphanedResources()` 方法中 [^kubecost-getorphanedresource]：

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

如果再近一步檢視，可以注意到 `getAllDisks()` 作為要方法透過迴圈遍歷了所有帳號底下 AWS 區域，並且執行另一個操作為 `getDisksForRegion()` 獲取單一區域中的 [^kubecost-getdisk]，這裡使用了 EC2 提供的 `DescribeVolumes` API [^aws-api-ec2-describe-volumes] 操作獲取這些資訊：

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

因此，答案似乎顯而易見，kubecost 在底層實作上仍必須依賴 AWS 提供的 `DescribeVolumes` 獲取這項訊息，但這個權限是哪裡來的呢？

在 kubecost 的部署中，cost-analyzer 包含了 `cost-model` 其中一個容器應用，負責前面提到的副程式進行相關 AWS API 的呼叫：

```go
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

因此，在這種情況下，我們很大概率可以看看是否跟兩個權限設定有關了

- Service Account：是否使用了 EKS 支援的 IAM Role for Service Account（IRSA）功能
- Worker Node（EC2 instance）本身的 IAM 權限（Instance Profile IAM Role）

在前面的 Helm 安裝步驟中，我們並未設定相關 IRSA 的權限，看了看果然符合預期，並沒有關聯任何的 IAM Role。預設的 Service Account 是用於賦予 kubecost 進行 Kubernetes 資源訪問權限的設定（例如：獲取 Pod, Node, PV, PVC 等等資源的權限），並且在相關的 Helm Chart 中被定義 [^kubecost-cost-analyzer-cluster-role-template]：

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

既然不是 IRSA 的設定，這樣我們可以更確定可能跟 EC2 instance 本身關聯的 IAM 權限有關了。預設情況下，每個 EKS 的 Worker Node 都會使用預設的一些 IAM 權限設定（IAM Policy），包含 [^eks-worker-node-iam-role]：

- [AmazonEKSWorkerNodePolicy](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEKSWorkerNodePolicy.html)
- [AmazonEKS_CNI_Policy](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEKS_CNI_Policy.html)

這些權限目的是可以讓運行在 EC2 上面的必要 Kubernetes 應用可以正常工作（例如：kubelet 和 CNI Plugin）等。因此，可以預期在運行 kubecost 部署到 Worker Node 上面運行，其通常將使用預設對應 EKS 節點的 IAM 權限，從預設的策略 `AmazonEKSWorkerNodePolicy` 可以注意到以下資訊：

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

為了驗證是否跟上述權限有關，我在 Worker Node 對應的 IAM Role 中加入拒絕策略進行測試：

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

當 Kubecost 擷取磁碟資料時，可以看到預期的錯誤：

```bash
$ kubectl logs $KUBECOST_POD cost-model -n kubecost

INF unable to get addresses: %s logged 5 times: suppressing future logs
WRN unable to get disks: operation error EC2: DescribeVolumes, https response error StatusCode: 403, RequestID: b1eb2ada-8813-441c-a2f9-64847e14f6cd, api error UnauthorizedOperation: You are not authorized to perform this operation.
WRN unable to get disks: operation error EC2: DescribeVolumes, https response error StatusCode: 403, RequestID: 46053624-5c2d-4ef3-a145-f01917eeec84, api error UnauthorizedOperation: You are not authorized to perform this operation.
```

因此我們可以了解 kubecost 是如何是在無需賦予相關權限的情況下獲取所有區域的 EBS 磁碟資源。預設的 `ec2:DescribeVolumes` 權限確保 kubelet 運行和 EKS-Optimized AMI 中相應組件必須的運作權限，以獲取 EC2 instance 和該區域關聯資源的運作信息（例如：使用 EBS CSI Driver 部署 EBS Volume 的需求），並作為相關 Kubernetes 物件資源 Label 數據的一部分（例如：PersistentVolume 以及 PersistentVolumeClaim），並且只提供讀取權限，未包含相關的寫入操作，這項權限無法修改任何 EBS 資源。

Kubecost 在運作階段透過使用 Worker Node 本身的 IAM 身份和權限掃描 AWS 帳戶區域中閒置的EBS 資源（未附加至任何 EC2 instance 的 EBS 卷），將這些資源篩選出來進行成本節省的優化建議。

## 總結

本文深入探討了 Kubecost 如何收集 AWS 帳號中未使用磁碟的資訊，分享了使用者可能在安裝 Kubecost 後對於 Kubecost 可以獲得整個帳號的未使用磁碟訊息的疑慮。除了進行相關的程式碼分析，也解釋了 Kubecost 如何與 AWS API 互動，以及如何使用各種技術和方法來識別和收集未使用的磁碟資源。

經過深入分析和驗證，我們確認 Kubecost 是使用 Worker Node 本身的 IAM 身份和權限來獲取 AWS 帳號中未使用的 EBS 磁碟資訊。這種做法並沒有越權或違反安全原則，因為 Kubecost 僅使用了預設的 `ec2:DescribeVolumes` 權限，這是為了確保 Kubernetes 運行所必要的權限，並且只有讀取權限，沒有修改任何 EBS 資源的寫入操作。

希望透過本篇文章，能讓讀者對 Kubecost 如何獲取 AWS 未使用磁碟資訊有更深入的理解，並釐清對相關安全性的疑慮。

## 參考資料

[^eks-kubecost]: [Amazon EKS Cost monitoring](https://docs.aws.amazon.com/eks/latest/userguide/cost-monitoring.html)
[^kubecost-getorphanedresource]: [opencost v2.2 GetOrphanedResources()](https://github.com/opencost/opencost/blob/088f891d8ed6c48d688c31028542ea7ac34331ed/pkg/cloud/aws/provider.go#L1836C1-L1858C1)
[^kubecost-getdisk]: [opencost v2.2 Get Disks](https://github.com/opencost/opencost/blob/088f891d8ed6c48d688c31028542ea7ac34331ed/pkg/cloud/aws/provider.go#L1702-L1834)
[^aws-api-ec2-describe-volumes]: [AWS API - EC2 DescribeVolumes](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_DescribeVolumes.html)
[^kubecost-cost-analyzer-cluster-role-template]: [kubecost v2.2 cost-analyzer-cluster-role-template.yaml](https://github.com/kubecost/cost-analyzer-helm-chart/blob/b6d32237dbb80b10dd851dbcc07441171b27a701/cost-analyzer/templates/cost-analyzer-cluster-role-template.yaml)
[^eks-worker-node-iam-role]: [Amazon EKS node IAM role](https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html)