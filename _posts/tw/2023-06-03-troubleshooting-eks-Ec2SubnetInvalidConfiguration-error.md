---
layout: post
title:  "EKS Managed Node Group: 解決 Ec2SubnetInvalidConfiguration 錯誤"
author: eason
categories: [Amazon Elastic Kubernetes Service (EKS), Kubernetes]
image: assets/images/2023/troubleshooting-eks-Ec2SubnetInvalidConfiguration-error/cover.png
lang: tw
canonical_url: https://easontechtalk.com/tw/troubleshooting-eks-Ec2SubnetInvalidConfiguration-error/
---

Amazon Elastic Kubernetes Service（EKS）是一個託管的 Kubernetes 服務，使許多 Kubernetes 的管理者能夠在數十分鐘內透過命令快速建立及輕鬆在 AWS 上運行 Kubernetes Cluster，並且簡化了許多操作；2019 年 EKS 釋出了新的 API 支援 Managed Node Groups (託管式工作節點) [^eks-managed-nodegroup]，並且能夠自動建立和管理 EC2 instances，並將這些 instances 加入到 Kubernetes 集群中，使得用戶能夠更輕鬆新增、擴展 Kubernetes Cluster 所需要的運算節點數量，甚至能夠透過 API 或一鍵集成的方式升級節點的版本。

然而，在新增、升級 Managed Node Groups 的過程，有可能會遇到 `Ec2SubnetInvalidConfiguration` 錯誤，因此，本文將進一步分析這個錯誤的原因、常見情境以及解決方法。

## 如何確認該問題

要檢查 EKS Managed Node Groups 是否存在 `Ec2SubnetInvalidConfiguration` 錯誤，可以透過 EKS Console 或是 AWS CLI 命令確認是否存在任何健康檢查錯誤 (Health Issue)。例如，透過點擊 Cluster 底下的 `Compute` 頁籤 > 點擊 `Node groups` 進入到節點組的詳細頁面後，可以檢查 `Health Issues` 頁籤是否存在相關的錯誤訊息：

![](/assets/images/2023/troubleshooting-eks-Ec2SubnetInvalidConfiguration-error/nodegroup-create-failed.png)

根據文件提到 EKS Managed Node Group 的升級流程 [^eks-managed-nodegroup-update-behavior]，如果升級或是新建節點超過 15-20 分鐘後卡住，很可能是某些原因使得工作節點在運作時存在一些問題，過一段時間後，通常有機會透過這些資訊進一步排查可能的原因。以下是使用 AWS CLI 命令的範例：

```bash
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
                    "message": "One or more Amazon EC2 Subnets of [subnet-AAAAAAAAAAAAAAAAA, subnet-BBBBBBBBBBBBBBBBB] for node group broken-nodegroup does not automatically assign public IP addresses to instances launched into it. If you want your instances to be assigned a public IP address, then you need to enable auto-assign public IP address for the subnet. See IP addressing in VPC guide: https://docs.aws.amazon.com/vpc/latest/userguide/vpc-ip-addressing.html#subnet-public-ip",
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

上述範例為在建立節點組時發生失敗並且處於 `CREATE_FAILED` 狀態。

## 常見情境和發生原因

按照錯誤例外的定義 [^eks-issues]，可以簡單得知這個錯誤通常是由於 EKS Managed Node Group 所指定的 subnet 沒有啟用 auto-assign public IP address (自動分配 IP 地址) 導致。

預設情況下，當 Managed Node Group 在建立 EC2 instances 時，會需要依賴 Subnet 本身啟用這項功能，如果 subnet 沒有啟用 auto-assign public IP address，EC2 instances 會無法獲取到公開的 IP 位址 (Public IPv4)，因此將無法與 Internet 進行通訊。EKS Managed Node Groups 的這項檢查同時衍生了兩個不同的使用情境：Public Subnet (公有子網) 跟 Private Subnet (私有子網)。

Public Subnet 與 Private Subnet 是指在 Amazon Virtual Private Cloud (VPC) 中設定不同的 Subnet。其中，Public Subnet 意味著在這個 Subnet 中的資源可以直接與 Internet 進行通訊、連到公開的網際網路，而 Private Subnet 則無法直接與 Internet 進行通訊：

![](/assets/images/2023/troubleshooting-eks-Ec2SubnetInvalidConfiguration-error/subnet-diagram.png)

(圖片來源：Amazon Virtual Private Cloud 使用手冊 [^subnet-diagram])

**簡單來說，如果 Subnet 存在指向 Internet Gateway 資源的路由 (`0.0.0.0/0`)，通常可以視為預期這個 Subnet 將能夠直接通往 Internet 的大門，反之，這個 Subnet 預計規劃存在有限且私有的網路環境中。**

### 在 Public Subnet (公有子網) 遇到這個錯誤

在之前，由於 EKS 在建立 Managed Node Groups 時預設會幫所有節點組底下的 Node Groups 啟用跟配發 Public IPv4 地址 (不論是否放在 Public Subnet 或是 Private Subnet)，但目前這項功能已經於 2020 年得到更新 [^eks-feature-request-607]。因此，如果你預期你部署的 EKS Managed Node Groups 需要配發公開的 IPv4 地址，並且允許直接與網際網路連線。

在這種情況下，在建立或是升級 Managed Node Groups 使用 Public Subnet 時，需要確保 Subnet 本身的設定允許自動配發 Public IPv4 地址 (`MapPublicIpOnLaunch`)：

```bash
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

### 在 Private Subnet (私有子網) 遇到這個錯誤

但你可能會說：「我本來預期這個 Subnet 就是 Private Subnet，甚至我可能一開始建立時都正常」您可能會好奇，為什麼 EKS Managed Groups 可能在運行階段或是升級過程會提示我的 Node Groups 指定的 Subnet 沒有自動關聯 Public IPv4 地址。

對於 Amazon EKS，VPC 關聯 Subnet 的屬性仍適用前面所提到的原則 [^eks-vpc-subnet-considerations]，因此，在很大機率下，這通常涉及相關 Subnet 路由表設定的錯誤：

- A public subnet is a subnet with a route table that includes a route to an internet gateway, whereas a private subnet is a subnet with a route table that doesn't include a route to an internet gateway.

例如：以下是一個在環境中 Node Groups 運行一段時間後因為 Subnet 設置問題導致節點組處於 `DEGRADED` 狀態，並存在錯誤訊息。

![](/assets/images/2023/troubleshooting-eks-Ec2SubnetInvalidConfiguration-error/nodegroup-degraded.png)

## 解決方法和相關步驟

### Public Subnet (公有子網)

為了解決這個問題，若你在部署 Managed Node Groups 選擇的是 Public Subnet，需要確保 Subnet 啟用了 Auto-assign Public IP address 功能，[參考以下步驟](https://docs.aws.amazon.com/vpc/latest/userguide/modify-subnets.html#subnet-public-ip)：

1. 登錄 AWS Console，並進入 [VPC 管理頁面](https://console.aws.amazon.com/vpc/)。
2. 選擇您要使用的 Subnet > Edit Subnet Settings，然後選擇「Enable auto-assign public IPv4 address」。
3. 勾選後點擊保存

![](/assets/images/2023/troubleshooting-eks-Ec2SubnetInvalidConfiguration-error/enable-auto-assign-up-settings.png)

完成這些步驟後，如果節點狀態為失敗，可以將失敗的 Managed Node Groups 刪除後再次重新建立一個新的 Managed Node Group，並且選擇上述的 Subnet。在由 EKS 啟動這些 EC2 instances 時，就能根據 Subnet 的設定正確獲取到 Public IP 位址。

如果您遇到的問題不是由於 subnet 沒有啟用 auto-assign public IP address 所導致的，請參考錯誤信息 [^eks-issues]。

### Private Subnet (私有子網)

在前面的內容中描述了一個在預期的私有子網遇到這個錯誤，這通常很可能是因為 EKS 嘗試啟動或是檢查 Managed Node Groups 所使用的 Subnet 時，因為路由指向 Internet Gateway 而認為這個 Subnet 屬於 Public Subnet，而不是預期的 Private Subnet 屬性，最終獲得這樣的例外訊息：

![](/assets/images/2023/troubleshooting-eks-Ec2SubnetInvalidConfiguration-error/incorrect-private-subnet-route.png)

要解決這個問題，可以透過正確的設定 Private Subnet 對應的 Route Table (路由表) 並且保留 VPC 內部的請求，同時設定正確的非 VPC 請求路由 (例如：針對 `0.0.0.0/0` 路由移除 Internet Gateway)，指向其他目標像是 [NAT Gateway](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html) 同樣提供僅內部向外部訪問網際網路的能力，以確保工作節點在啟動時仍可以從其他來源下載 Image (例如：Docker Hub)、跟 EKS API Server 互動等。

## 總結

在這篇內容中，我們提到了當建立或升級 EKS Managed Node Group 時遇到 `Ec2SubnetInvalidConfiguration` 錯誤的常見情境和發生原因。在 Public Subnet 情況下，需要確保 Subnet 啟用了 Auto-assign Public IP address 功能；在 Private Subnet 情況下，需要透過正確的設定 Private Subnet 對應的 Route Table 並且保留 VPC 內部的請求，同時設定正確的非 VPC 請求路由，指向其他目標，像是 NAT Gateway。

透過遵循上述的解決方法和相關步驟，希望能幫助在閱讀這篇內容的你更有方向的排查並且解決這個錯誤，確保 Managed Node Group 正常運行。

## 參考資源

[^eks-managed-nodegroup]: [Extending the EKS API: Managed Node Groups](https://aws.amazon.com/blogs/containers/eks-managed-node-groups/)
[^eks-issues]: [Amazon EKS resource Issue](https://docs.aws.amazon.com/eks/latest/APIReference/API_Issue.html)
[^eks-managed-nodegroup-update-behavior]: [Managed node update behavior - Scale up phase](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-update-behavior.html#managed-node-update-scale-up)
[^subnet-diagram]: [Subnets for your VPC - Subnet diagram](https://docs.aws.amazon.com/vpc/latest/userguide/configure-subnets.html#subnet-diagram)
[^eks-feature-request-607]: [[EKS] [request]: Remove requirement of public IPs on EKS managed worker nodes #607](https://github.com/aws/containers-roadmap/issues/607)
[^eks-vpc-subnet-considerations]: [Amazon EKS VPC and subnet requirements and considerations - Subnet requirements and considerations](https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html#network-requirements-subnets)