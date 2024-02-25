---
layout: post
title:  "使用 EKS Access Entry 拯救並恢復叢集的存取權限"
author: eason
categories: [Amazon Elastic Kubernetes Service (EKS), Kubernetes]
image: assets/images/2024/recover-permission-using-eks-cluster-access-entry/cover.png
lang: tw
canonical_url: https://easontechtalk.com/tw/utilize-eks-cluster-health-status/
---

在過去，管理 Amazon Elastic Kubernetes Service (EKS) 叢集的存取權限通常需要依賴 AWS IAM Authenticator 和 aws-auth ConfigMap 的組合。然而，這樣的管理方式可能遇到格式錯誤、自動化更新困難以及 IAM 用戶被刪除等限制和問題。

為了解決這些問題，EKS 釋出了一項新的驗證方式 — **EKS Access Entry**，提供了一個新的優化的解決方案。通過 EKS Access Entry，簡化了 aws-auth ConfigMap 的管理配置，甚至在某些場景下恢復 EKS 叢集的存取權限。

## 為什麼這個功能這麼重要

在過去，Amazon EKS 整合了 IAM 作為主要的身份認證，然而，其中的身份認證仍依賴運行在 EKS 中的 AWS IAM Authenticator 進行驗證，這項驗證機制需要透過 aws-auth ConfigMap 進行管理。通常，這樣的工作流程並不是什麼大問題，但隨著 EKS 不同使用場景的增加，衍生了幾個限制和問題：

- 直接編輯 aws-auth ConfigMap 很容易遇到一些格式問題，例如：縮排錯誤、不正確的語法和格式、新版的 yaml 與目前線上環境中套用的不一致，新的 yaml 文件導致覆蓋了過去的設定，以上種種都有可能不小心造成災難。
- 整合 CI/CD pipeline 要達到自動化更新需要依賴 Kubernetes 資源的更新 (aws-auth ConfigMap)。不論是 AWS Lambda、Terraform、CloudFormation 或是 CDK，在過去，必須得透過呼叫 Kubernetes API 達到資源更新控制，難以透過 AWS EKS 本身提供的 API 完成自動化和權限管理，同時，在使用較嚴謹的 Kubernetes Role-Based Access Control (RBAC) 集群的安全管理下，團隊中的開發者使用有限的 Kubernetes 用戶身份可能難以透過 Kubernetes API 更新 aws-auth ConfigMap
- 當初建立 EKS Cluster 的 IAM 用戶被刪除使得團隊無法訪問 EKS Cluster，也就是本篇內容討論的主題。常見於整合 AWS Single-Sign On (AWS SSO) 或是同事離職的情境。即使是 AWS 的 Root 帳號也沒有辦法恢復 Kubernetes Cluster 的存取權限

為了解決這個問題，我們可以導入使用 EKS Access Entry 優化 EKS 叢集的權限管理，甚至在上述情況中，拯救並恢復叢集的存取權限。EKS Access Entry 是一個解決方案，可以讓管理者在無需 IAM 用戶的情況下，恢復對 EKS 叢集的存取權限。

## 深入瞭解 EKS Access Entry 的新功能

EKS Access Entry 是一種用於管理 Amazon EKS 叢集存取權限的新解決方案。它提供了一個優化的方式來管理叢集的驗證模式和存取策略，並解決了過去使用 IAM Authenticator 和 aws-auth ConfigMap 管理存取權限所遇到的限制和問題。

預設情況下，在建立 EKS 叢集時，會自動賦予操作建立 EKS Cluster 的 IAM 身份在 Kubernetes 的 Role-Based Access Control (RBAC) 中建立規則和 Kubernetes User，並且賦予 `system:master` 的操作身份。

### Kubernetes Role-Based Access Control (RBAC) 是什麼？

Kubernetes Role-Based Access Control (RBAC) 是一種在 Kubernetes 叢集中實現授權和權限管理的機制。使用 RBAC，您可以定義角色和角色綁定，以授予使用者或服務帳戶對叢集資源的特定權限。

### EKS 驗證身份驗證機制

回顧前面所提，在 EKS 中，預設只為建立 EKS Cluster 的 IAM 身份 (比如：`arn:aws:iam::123456789:user/eason`) 賦予 `system:master` 群組操作身份。如果要允許一個新的 IAM 用戶 (比如：`arn:aws:iam::123456789:user/developer`) 能夠操作 EKS Cluster，**在 IAM 主控台中設定任何的 IAM 策略，是無法授權任何 EKS Cluster 的訪問權限**，而是需要透過更新 `aws-auth` ConfigMap 資源來賦予其他 IAM 身份的訪問：

![EKS 預設驗證機制](/assets/images/2024/recover-permission-using-eks-cluster-access-entry/auth-workflow.png)

例如：要為我的 IAM 用戶授權訪問 EKS Cluster，可以透過使用 kubectl 命令為 `aws-auth` ConfigMap 中新增一個 `mapUsers` 區塊，其中包含了指定了一個使用者的 ARN (`arn:aws:iam::123456789:user/developer`) ，並且關聯 `system:master` 群組，表示 `developer` 使用者現在具有訪問 EKS Cluster 的存取權限。

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

### 支援 EKS Access Entry 後的叢集驗證模式變更

這項更新支援以下 Kubernetes 和平台之後版本的 EKS Cluster：

| Kubernetes version | Platform version |
| --- | --- |
| 1.28 | eks.6 |
| 1.27 | eks.10 |
| 1.26 | eks.11 |
| 1.25 | eks.12 |
| 1.24 | eks.15 |
| 1.23 | eks.17 |

將可以支援兩種不同的驗證模式：

1. **IAM 叢集驗證模式**：這是 Amazon EKS 的預設驗證模式，它基於 IAM 進行身份驗證，並且依賴於 `aws-auth` ConfigMap。
2. **EKS 叢集驗證模式 (Access Entry)**：這是 EKS Access Entry 引入的新驗證模式。它基於 Kubernetes 的原生身份驗證機制，但透過 EKS 本身的 API 完成，使得在 EKS 控制台介面上點一點就能完成允許一個 IAM User/Role 的操作成可能。

在新建立的 EKS Cluster 中，您可能會注意到多了以下選項的更新：

![EKS 驗證模式](/assets/images/2024/recover-permission-using-eks-cluster-access-entry/cover.png)

## EKS Access Entry 的驗證方法

### 先決條件

在使用 EKS Access Entry 之前，您需要確保以下先決條件已滿足：

- 您的 Amazon EKS 叢集有啟用 EKS Access Entry 功能 (前面提到的驗證模式支援 EKS API 而不是只有 ConfigMap)。
- 您具有適當的 IAM 權限，以執行與 EKS Access Entry 相關的操作 (例如：`eks:CreateAccessEntry`、`eks:AssociateAccessPolicy`、`eks:DeleteAccessEntry`、`eks:DescribeAccessEntry` 等)。

在啟用 Access Entry 驗證後，便可以使用這個新的驗證方式來管理叢集的存取權限。

### 存取策略的存取權限

每個 access entry 都有一個關聯的存取策略，該策略定義了對叢集資源的存取權限。存取策略使用 AWS Identity and Access Management (IAM) 的 JSON 格式來定義。以下是存取策略示例：

| 存取策略 | 描述 | Kubernetes verb |
| --- | --- | --- |
| AmazonEKSAdminPolicy | 完全管理權限 | * |
| AmazonEKSClusterAdminPolicy | 叢集管理權限 | - |
| AmazonEKSEditPolicy | 讀寫權限 | create, update, delete, get, list |
| AmazonEKSViewPolicy | 只讀權限 | get, list |

上述表格可能會隨著版本更新有所變化，詳情請參考[^access-policy-permissions]。

## 實施並利用 EKS Access Entry 管理或恢復 EKS 叢集存取權限

在遇到當初建立 EKS Cluster 的 IAM 用戶被刪除使得團隊無法訪問 EKS Cluster 的情況下，若當前的 IAM User/Role 具備 Access Entry 的操作權限，則可以透過這項功能恢復 EKS Cluster 的存取權限 (或是撤銷存取權限)。EKS Access Entry 可以使用 AWS CLI 或 AWS Management Console 進行操作。

**EKS 主控台 (AWS Management Console)**

(1) 在 EKS 叢集詳細資訊頁面中，點選 "Access" 選項。

(2) 在 “IAM Access Entries" 頁面中，點選右上方的 "Create access entry" 按鈕。

![新增 EKS Access Entry](/assets/images/2024/recover-permission-using-eks-cluster-access-entry/create-access-entry.png)

(3) 在 "Create access entry" 的對話框中，輸入以下資訊：
    - IAM Principal ARN: 指定 IAM User 或 IAM Role 的 ARN。
    - Kubernetes groups: 這個欄位用於關聯 IAM User/Role 使用 Kubernetes RBAC 裡面已經定義的 Kubernetes 群組 (Role & Rolebinding)。若要直接關聯預先定義好的 Access Entry Policy (例如：`AmazonEKSClusterAdminPolicy`)，可以略過
    - Kubernetes username: 您希望該 IAM 使用者或角色在 Kubernetes 中的使用者名稱，這裡可以輸入您希望的名稱或是省略，例如 `admin`。

![設定 IAM Access Entry](/assets/images/2024/recover-permission-using-eks-cluster-access-entry/config-iam-access-entry.png)

(4) 在這個步驟中，可以選擇預設的的 Access Entry 以賦予 IAM 身份存取 EKS Cluster 的權限，例如：`arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy`。
    - Access Scope: 用於賦予關聯策略影響的範圍，例如：指定 IAM 用戶只能使用這個權限操作特定 Kubernetes namespace。如果不限制，則選擇 Cluster 賦予 IAM 用戶可以使用這個權限操作整個叢集。

(5) 點選 "Add Policy" 按鈕以關聯存取策略。

![設定 Access Policy](/assets/images/2024/recover-permission-using-eks-cluster-access-entry/access-policy.png)

至此，您已成功使用 EKS Access Entry 為 EKS 叢集新增了一個 Cluster Admin。

**AWS CLI**

以下是使用 AWS CLI 透過 EKS Access Entry 為 EKS 叢集新增 Cluster Admin 的步驟 (叢集名稱以`eks-cluster` 為例)：

(1) 更新你的 EKS 叢集配置以啟用 EKS Access Entry 驗證模式 (如果已經操作過這步驟可以省略)

```bash
aws eks update-cluster-config \
          --name eks-cluster  \
          --access-config authenticationMode=API_AND_CONFIG_MAP
```

(2) 建立一個 Access Entry，並指定 IAM principal ARN （例如：IAM User 或 IAM Role，這裡使用 `arn:aws:iam::0123456789012:role/eks-admin` 作為範例)

```bash
 aws eks create-access-entry \
  --cluster-name eks-cluster \
  --principal-arn "arn:aws:iam::0123456789012:role/eks-admin"

```

(3) 將存取策略關聯到剛剛建立的 Access Entry。這裡以 AmazonEKSAdminPolicy （提供完全的管理權限）為例

```bash
 aws eks associate-access-policy \
  --cluster-name eks-cluster \
  --principal-arn "arn:aws:iam::0123456789012:role/eks-admin" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy \
  --access-scope '{"type": "cluster"}
```

完成以上步驟後，您已成功透過 EKS Access Entry 為 EKS 叢集新增了一個 Cluster Admin。

**其他權限設定**

另一種使用情境為透過 EKS Access Entry 功能與 Kubernetes RBAC 本身的權限關聯。

例如，我們可以建立一個名為 `pod-and-config-viewer` 的 Kubernetes Cluster，並授予該角色查看 Kubernetes Pods 的權限。

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

接著，我們將此角色綁定到 `pod-viewers` 群組上。

註：Kubernetes Group (`pod-viewers`) 不需要事先建立即可操作。

```bash
kubectl create clusterrolebinding pod-viewer \
  --clusterrole=pod-viewer-role \
  --group=pod-viewers

```

接下來即可直接通過 EKS Access Entry 對應的功能將 IAM 角色 `arn:aws:iam::0123456789012:role/eks-pod-viewer` 關聯到 Kubernetes 群組 `pod-viewers` 上，進一步強化權限設定的靈活性。

```bash
aws eks create-access-entry \
  --cluster-name eks-cluster \
  --principal-arn "arn:aws:iam::0123456789012:role/eks-pod-viewer" \
  --kubernetes-group pod-viewers
```

## 總結

本文介紹了 EKS Access Entry，這是 Amazon Elastic Kubernetes Service (EKS) 叢集的一種新的存取權限管理方法。此功能解決了過去使用 IAM Authenticator 和 aws-auth ConfigMap 進行權限管理時所遇到的問題，例如格式錯誤、自動更新困難以及 IAM 使用者被刪除等問題。相較於傳統的方法，EKS Access Entry 提供了一種更優化的方式來管理驗證模式和存取策略。

此外，本篇內容也詳細說明了如何使用 EKS Access Entry 來管理或恢復 EKS 叢集的存取權限，包括在 AWS Management Console 或 AWS CLI 中進行操作的具體步驟。這些解決方案不僅可以在 IAM 使用者被刪除等緊急情況下恢復叢集的存取權限，也可用於日常的權限管理中，提高效率與靈活性。

總結來說，EKS Access Entry 的出現為 EKS 叢集的權限管理帶來了重大的改進，使得管理者能更有效地實現對 EKS 叢集的權限管理，進一步提升效率和靈活性。

## 參考資料

[^access-policy-permissions]: [Access policy permissions](https://docs.aws.amazon.com/eks/latest/userguide/access-policies.html#access-policy-permissions)