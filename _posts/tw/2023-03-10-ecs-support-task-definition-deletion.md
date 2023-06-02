---
layout: post
title:  "怦然心動的功能性更新：Amazon ECS 終於支援任務定義 (Task Definition) 刪除"
author: eason
categories: [Amazon Elastic Container Service (ECS), Container]
image: assets/images/2023/ecs-support-task-definition-deletion/cover.png
lang: tw
canonical_url: https://easontechtalk.com/tw/ecs-support-task-definition-deletion/
---

自 2015 年 Amazon ECS 正式釋出，提供了支援在 AWS 上運行容器工作負載的成熟解決方案。然而，僅支援 DeregisterTaskDefinition API[^DeregisterTaskDefinition-API] 可以取消註冊特定的任務定義 (Task Definition) 版本。

但是，在這樣的設計下，不免會遇到需要刪除過時或未使用的任務定義 (Task Definition) 的情況。即使過了多年，Amazon ECS 仍不支持刪除任務定義 (Task Definition) 資源，這讓許多 Amazon ECS 使用者想知道究竟什麼時候 ECS 才會支任務定義 (Task Definition) 的刪除功能。[^ecs-fr-685]

千呼萬盼，Amazon ECS 終於支持對任務定義 (Task Definition) 刪除功能。

## 有哪些改變？

2023 年 2 月 27 日，Amazon ECS 正式宣布支援刪除未使用 (`INACTIVE`) 狀態的任務定義版本 (Task Definition Revisions)。[^whats-new-ecs-task-definition-deletion]

使用 ECS 並且當你建立一個任務定義 (Task Definition) 時，每次都會自動為其建立一個新版本 (例如：`myTaskDefinition:1`, `myTaskDefinition:2` ... 等)。每個版本都是不可變更，這意味著，一旦該資源被建立，它就不能被刪除或修改。即使你爲任務定義 (Task Definition) 刪除所有的版本 (Revision)，也只是將版本的狀態由 `ACTIVE` 更改為 `INACTIVE`，該版本仍然存在，並且在 AWS 帳號中仍然可以被檢視。

在這個功能被支援之前，使用者只能將任務定義版本 (Task Definition Revision) 標記為 `INACTIVE`，但無法刪除。

現在這項功能改進可以讓你通過 Amazon ECS 控制台或通過編寫程式的方式刪除未使用的任務定義版本 (Task Definition Revision)。可以永久刪除不再需要或包含不需要的配置的任務定義版本 (Task Definition Revision)，簡化了資源管理並改善了安全問題。

![Task definition deletion option](/assets/images/2023/ecs-support-task-definition-deletion/ecs-console-deletion-option.png)

## 為什麼能刪任務定義 (Task Definition) 這麼重要？

一種常見的場景即為當容器程式於運行階段存在需要存取特定資訊、憑證或是密文資訊時，常使用環境變數做為參數傳遞 (例如：連接到特定的資料庫)。

透過環境變數將您的憑證傳遞給容器時，如果沒有意識到任務定義 (Task Definition) 不會被刪除，可能會使得你意外地將帳號密碼留在可讀的資源中，暴露不必要的安全風險。例如：

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

在過去，任務定義 (Task Definition) 僅能設定為 `INACTIVE` 狀態，並且無法刪除。

如果帳號中的任一 IAM User 或 IAM Role 具有描述任務定義 (Task Definition) 的權限，則他們就可以查看你可能不希望他們訪問的憑證數據。

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

由於任務定義 (Task Definition) 可能會在 `INACTIVE` 狀態下洩露敏感細節，因此，針對這項問題，通常建議使用 AWS Secrets Manager 或 AWS Systems Manager Parameter Store，這兩個 AWS 服務都支援將敏感資訊注入到容器環境變數中而不會直接地被看到相關的敏感資訊。

但現在，無論你是否有使用 AWS Secrets Manager 或 AWS Systems Manager Parameter Store 存放這些敏感資訊，你都可以在 AWS 控制台上永久刪除任務定義 (Task Definition)，或是使用 DeleteTaskDefinitions [^DeleteTaskDefinitions-API] API 以程式方法呼叫或是採用 AWS CLI 命令執行刪除：

```
$ aws ecs delete-task-definitions --task-definitions <task name:revision>
```

## 總結

在 Amazon ECS 釋出的 8 年後，ECS 終於支援任務定義 (Task Definition) 刪除功能，不必再煩惱看到一堆 `INACTIVE` 狀態的資源以及不小心暴露憑證資訊的安全性風險。

多麽讓人怦然心動的功能性更新！

## 參考資源

[^ecs-ga]: [Amazon ECS history](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/document_history.html)
[^DeregisterTaskDefinition-API]: [Amazon ECS API - DeregisterTaskDefinition](https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_DeregisterTaskDefinition.html)
[^ecs-fr-685]: [\[ECS\] \[request\]: Delete task definitions #685](https://github.com/aws/containers-roadmap/issues/685)
[^whats-new-ecs-task-definition-deletion]: [Amazon ECS now supports deletion of inactive task definition revisions](https://aws.amazon.com/about-aws/whats-new/2023/02/amazon-ecs-deletion-inactive-task-definition-revisions/)
[^DeleteTaskDefinitions-API]: [Amazon ECS API - DeleteTaskDefinitions](https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_DeleteTaskDefinitions.html)


