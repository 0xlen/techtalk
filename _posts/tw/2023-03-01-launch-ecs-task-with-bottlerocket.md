---
layout: post
title:  "Amazon ECS Bottlerocket 簡介: 在 Bottlerocket 上運行容器和任務 (Task)"
author: eason
categories: [Amazon Elastic Container Service (ECS), Container]
image: assets/images/2023/launch-ecs-task-with-bottlerocket/cover.jpg
lang: tw
---

Amazon Elastic Container Service (ECS) 是用於管理在 Amazon Web Services (AWS) 上以容器化方式運行的容器調度服務。類似於 Kubernetes、Docker Swarm 等集成方案，Amazon ECS 提供了一種簡單的功能性來幫助你啟動和擴展容器化應用程式，這樣簡單的特性使得 ECS 成為許多企業用戶快速且有效部署其容器應用程式的理想選擇。

Bottlerocket 則是由 AWS 釋出以 Linux 為基礎的一個新的開源作業系統，專為運行容器而設計。在本篇內容，我們將延伸簡介如何在 Amazon ECS 使用 Bottlerocket 作業系統啟動容器任務 (Task)。

## 簡介

### Amazon ECS Bottlerocket 概覽

Bottlerocket 旨在提供安全且高效、適用於運行容器執行環境優化的作業系統。提供一個輕量、不可任意修改且易於更新的作業系統，以適合大規模運行容器工作負載時使用。通過在 Amazon ECS 中使用 Bottlerocket，由於他僅提供最基本所有運行容器環境的執行需求，最主要的優化將是減少系統和容器啟動的時間。

### 使用 Bottlerocket 和 Amazon ECS 的好處 (與一般的 ECS-optimized AMI 的區別)

最主要區別在於 Bottlerocket 以安全及輕量為宗旨設計，因此，如果你是第一次使用，通常會注意到一些顯著的安全性功能差異。例如以下是在使用該 Bottlerocket 時需要知道的一些注意事項:

- Bottlerocket 的檔案系統 (Root filesystem) 被是唯讀 (Read-only)，不能被 User space 的應用程式 (一般的 process) 直接修改。
- 預設並沒有開啟 SSH 功能，除非有設定，否則無法直接 SSH 運行 Bottlerocket 的環境中。

## 開始使用 Bottlerocket

接下來就讓我們來看看如何著手運行第一個以 Bottlerocket 為執行基礎的容器部署環境。

### 建立 Task definition

要使用 Amazon ECS 和 Bottlerocket 啟動容器應用，首先，你會需要先建立一個任務定義 (Task definition)，這個 Task definition 用於描述容器化應用程式 (包含：Image、CPU、Memory 等規格)。

如果您過去使用過並且已經熟悉 Amazon ECS，則在 Task definition 的建立過程中與使用一般的 ECS-optimized AMI 沒有區別，運行於 Bottlerocket 環境中通常並不需要做任何修改。如果您已經有 Task definition，則可以跳過到下一部分。

任務定義 (Task definition) 可以視為一個在 Amazon ECS 上運行你容器藍圖，用於描述容器規格和運行方式。在 Amazon ECS 上，容器應該被封裝為運行單元，稱為任務 (**Task**)，這就是為什麼我們需要有一個任務定義 (**Task definition**) 的原因。在任務定義 (Task definition) 中，您可以指定應用程式需要運行的 Image、資源、環境變數和其他設置。完成定義後，您可以建立一個任務 (ECS Task)，這時候你的容器才會真正被運行。

讓我們首先建立一個任務定義 (Task definition)。只需前往 **Task definition** 頁面，然後選擇 **Create new task definition with JSON** 建立：

![Create new task definition with JSON](/assets/images/2023/launch-ecs-task-with-bottlerocket/ecs-create-task-definition-with-json.png)

這個範例中，描述了如何啟動一個容器並且使用我自定義的 Image (`easoncao/ecs-demo-app`)，請求了 `128 vCPU` 單位的 CPU 資源和 `128 MB` 單位的記憶體資源。並且將 `hostPort` 設置為 `0`，以將容器服務的端口 (Port) `80` 對應到到在 EC2 instance 上會啟動的動態端口 (Port)，當在 Bottlerocket instance 上運行任務時，這可以將容器服務公開到這個動態的端口設定。以下是我的 Task definition 相關 JSON 片段：

```bash
{
    "containerDefinitions": [
        {
            "name": "demo",
            "image": "easoncao/ecs-demo-app:latest",
            "cpu": 128,
            "memory": 128,
            "portMappings": [
                {
                    "containerPort": 80,
                    "hostPort": 0,
                    "protocol": "tcp"
                }
            ],
            "essential": true
        }
    ],
    "family": "easontechtalk-demo",
    "requiresCompatibilities": [
        "EC2"
    ]
}
```

在此任務定義 (Task definition) 中，我們定義了一個名為 `demo` 的容器，該容器使用 `easoncao/ecs-demo-app` 運行，並且有 `128 vCPU` 和 `128 MB` 的資源使用單位。此外，我們還將容器端口 (Port) `80` 對應到主機端口 `0`，並使用 TCP 協定。

完成建立後，後續你就可以使用這個任務定義 (Task definition) 來運行 ECS Task。

### 建立一個 ECS cluster

為了使用 Bottlerocket 啟動 ECS Task，你同時也會需要建立一個 ECS Cluster 並將使用 Bottlerocket 為作業系統基礎的 EC2 instances 註冊到其中。

如果你是使用新版的 ECS Cosnole，新的 ECS Console 簡化了建立的使用體驗。要建立一個 ECS Cluster，你可以前往 [ECS Console](https://console.aws.amazon.com/ecs/v2/clusters)，選擇 **Clusters** 並點擊 **Create cluster** 按鈕，即可按照說明步驟完成建立：

![Create an ECS Cluster in ECS Console](/assets/images/2023/launch-ecs-task-with-bottlerocket/ecs-create-cluster-console.png)

如果你偏好使用 CLI，也可以使用 AWS CLI 提供的 ECS 命令[^aws-cli-ecs-create-cluster] 完成。以下是在 `eu-west-1` 區域中建立一個名為 `easontechtalk-bottlerocket` 的 ECS Cluster 資源的範例命令：

```bash
aws ecs create-cluster --cluster-name easontechtalk-bottlerocket --region eu-west-1
```

如果你是使用 AWS 控制台 (ECS Console)，在建立階段的 **Infrastructure** 選項底下下，可以勾選 **Amazon ECS instances** 選項，這個選項會提示你設定 EC2 Auto Scaling Group 和啟動 EC2 instances 的細節。要使用 Bottlerocket 啟動，選擇 **Create new ASG** 會有 **Operating system/Architecture** 一欄出現選項供你選擇 Bottlerocket 作為您的操作系統：

![Create cluster and select Bottlerocket OS](/assets/images/2023/launch-ecs-task-with-bottlerocket/ecs-create-cluster-asg-select-bottlerocket-os.png)

但如果你想自己啟動 EC2 instances，也可以稍後參考後面的步驟再建立這些資源。

### 註冊 Bottlerocket instances

如果你要自己啟動 EC2 instance，首先第一步是需要找到不同 AWS 區域中提供對應最新版的 Bottlerocket AMI ID。這部分你可以使用 AWS CLI 命令或使用 AMI 對應的快速連結[^bottlerocket-ami-links]來獲得 AMI ID 的資訊。以下是幾個範例和 AWS CLI 命令：

```
https://console.aws.amazon.com/systems-manager/parameters/aws/service/bottlerocket/aws-ecs-1/x86_64/latest/image_id/description?region=<REGION>#
```

例如，以下是在 `eu-west-1` 地區取得最新的 Bottlerocket x86_64 AMI ID 的範例。在這個範例中返回了 AMI ID `ami-0d5571466e5537410`：

- [https://console.aws.amazon.com/systems-manager/parameters/aws/service/bottlerocket/aws-ecs-1/x86_64/latest/image_id/description?region=eu-west-1](https://console.aws.amazon.com/systems-manager/parameters/aws/service/bottlerocket/aws-ecs-1/x86_64/latest/image_id/description?region=eu-west-1)

(AWS CLI)
```bash
aws ssm get-parameter --region eu-west-1 \
    --name "/aws/service/bottlerocket/aws-ecs-1/x86_64/latest/image_id" \
        --query Parameter.Value --output text

# Output
ami-0d5571466e5537410
```

在取得 Bottlerocket 作業系統的 AMI ID 之後，下一個步驟便是啟動 EC2 instance，並透過內建的啟動程序機制自動的將 EC2 instance 註冊到我們前面建立的 ECS Cluster 中 (`easontechtalk-bottlerocket`)。你可以前往啟動 EC2 實例的頁面，並輸入剛剛取得的 AMI ID 資訊，並且選擇它：

![Select Bottlerocket AMI](/assets/images/2023/launch-ecs-task-with-bottlerocket/ec2-launch-select-bottlerocket-ami.png)
![Using Bottlerocket AMI Overview](/assets/images/2023/launch-ecs-task-with-bottlerocket/ec2-launch-ami-overview.png)

在設定的頁面也記得確保選擇了必須的 IAM Profle (IAM Role)，以允許 EC2 instance 啟動階段有權限具備註冊到 ECS Cluster 的權限 (名稱通常是 `ecsInstanceRole`。有關如何檢查 IAM Role 的詳細資訊，請參考[^ecs-container-instance-iam-role]）。

此外，要特別注意的地方是，如果你過去熟悉如何使用一般的 ECS-optimized AMI 註冊 EC2 instance 至 ECS Cluster，使用 Bottlerocket 系統的區別在於 UserData 內容：

(General ECS-optimized AMI)

```bash
#!/bin/bash
echo "ECS_CLUSTER=CLUSTER_NAME" >> /etc/ecs/ecs.config
```

(Bottlerocket AMI: 如果你使用 Bottlerocket 需要使用這個方法啟動)

```bash
[settings.ecs]
cluster = "CLUSTER_NAME"
```

請將 `CLUSTER_NAME` 取代為您自己的集群名稱。在這個範例中，我將我的集群名稱（`easontechtalk-bottlerocket`）貼到進階選項 (**Advanced details**) 中的 UserData 設定：

![Configure UserData for Bottlerocket AMI Bootstrapping process](/assets/images/2023/launch-ecs-task-with-bottlerocket/ec2-launch-bottlerocket-userdata.png)

一旦 EC2 Instance 成功啟動，將會自動註冊到 ECS Cluster 並且加入到集群中。要檢查 EC2 instance 是否有加入 ECS Cluster，你也可以在 ECS Console 中的 **Infrastructure** 選項中查看到詳細的資訊：

![View the container instance](/assets/images/2023/launch-ecs-task-with-bottlerocket/ecs-cluster-view-container-instance.png)

### 在 Bottlerocket 上運行一個 ECS Task

現在，你可以直接透過 ECS Console 上運行 ECS Task，點擊 **Run new task**：

![Run new task](/assets/images/2023/launch-ecs-task-with-bottlerocket/ecs-console-run-new-task.png)

在詳細設定頁面中，我選擇了前面步驟所建立的任務定義 (Task definition) 版本，然後在 Desired Tasks 選項中，指定運行 1 個 ECS Task 任務數量：

![Run new task detail](/assets/images/2023/launch-ecs-task-with-bottlerocket/ecs-console-run-task-detail.png)

一旦 ECS Task 啟動，可以透過 ECS Console 或 AWS CLI 來監控容器運行的狀態狀態。如果在主控台頁面，你可以直接點擊 ECS Task 的詳細信息，以檢視更多容器的詳細資訊，甚至可以獲取我們前面所設定有關網路相關的選項，可以看到容器對應的端口 (Container Port 以及 Host Port)。

在這個範例中，我的容器部署在 Bottlerocket instance 上，並公開服務端口 (Port) `49153`：

![View container network binding detail](/assets/images/2023/launch-ecs-task-with-bottlerocket/view-ecs-task-container-detail.png)

因為 ECS task 使用的是預設的容器 bridge 網路，要測試應用，我可以直接訪問 EC2 instance 對應的公開 IP 地址，並且使用 ECS 上面所分配的動態端口 (`49153`) 來連接我的容器。要注意由於端口可能是動態的，需要確保在你嘗試連接到容器之前，需要設定好對應的 Security Group (安全組) 防火牆規則，以允許你的用戶端請求通過訪問。

如果你使用這個範例的 Task definition 並且正確連接上，這個範例程式會透過網頁顯示 ECS Task 的詳細信息：

![View the task service web page](/assets/images/2023/launch-ecs-task-with-bottlerocket/view-exposed-task-webpage.png)

## 總結

在這篇內容中，簡介了 AWS 所釋出的 Bottlerocket 作業系統、簡介 Bottlerocket 以輕量和安全為設計訴求所帶來跟一般 ECS-optimized AMI 的顯著差異。並且分享了如何 Amazon ECS 上使用 Bottlerocket 作業系統運行一個容器應用程式 (ECS Task)，並且了解相關流程。

## 參考資源
- [Bootstrapping container instances with Amazon EC2 user data](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/bootstrap_container_instance.html)

[^aws-cli-ecs-create-cluster]: [AWS CLI - ECS Create Cluster](https://docs.aws.amazon.com/cli/latest/reference/ecs/create-cluster.html)
[^bottlerocket-ami-links]: [Using Bottlerocket with Amazon ECS - Retrieving an Amazon ECS-optimized Bottlerocket AMI](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-bottlerocket.html#ecs-bottlerocket-retrieve-ami)
[^ecs-container-instance-iam-role]: [Amazon ECS container instance IAM role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/instance_IAM_role.html)
