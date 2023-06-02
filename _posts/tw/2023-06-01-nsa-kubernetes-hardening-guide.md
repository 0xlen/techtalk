---
layout: post
title:  "解析美國國安局 (NSA) 和 CISA 釋出的 Kubernetes 強化指南"
author: eason
categories: [Kubernetes, Security]
image: assets/images/2023/nsa-kubernetes-hardening-guide/cover.png
lang: tw
canonical_url: https://easontechtalk.com/tw/nsa-kubernetes-hardening-guide/
---

Kubernetes 作為容器化調度平台已經逐漸在許多企業和生產環境中屬於不可或缺的基礎建設一部分。然而，由於其複雜性，Kubernetes 的執行環境也面臨著許多安全挑戰和潛在的問題。美國國安局（NSA）與網路安全暨基礎架構安全署（CISA）在 2022 年釋出了一份名為 Kubernetes Hardening Guidance 的網路安全報告 [^nsa-cisa-press] (完整文件 [^k8s-hardening-guide])。作為強化 Kubernetes 指南，指南中除了旨在為 NSA、CISA 以及對於美國聯邦和公家機關作為運行 Kubernetes 集群關鍵基礎建設的相關強化方針，更詳述了 Kubernetes 環境潛藏的安全威脅，並提供了相關設定指引，以盡可能地降低其安全風險。對於 Kubernetes 管理者來說，該指南實則一份十分有用的參考資源。

## 提供 Kubernetes 強化指南的目的

這份指南的目旨在提供使用 Kubernetes 時的最佳安全實踐，從而降低其面臨的風險。在這份文件中，提及了各種主題，從身份驗證、授權、網路安全以及監控策略，並提供了一些有用的工具和技術，以加強 Kubernetes Cluster 的安全措施。

## 這份指南在說什麼？

在閱讀這份文件後，可以注意到文件的概覽部分直接提及了整份文件圍繞的核心安全性議題，並且由後續數十頁的內容，具體描述了如何設置和保護 Kubernetes 環境以及相關涉及的安全問題。在這份內容中，不但從集群系統管理員 (Cluster Admininstrator)，也從系統開發人員的角度切入，提出相關的設定建議以避免常見的配置錯誤，並且涵蓋了相關的實踐、緩解和強化措施，主要包含：

- 掃描容器和 Pod 以查找漏洞或設定錯誤
- 使用最少的權限運行容器和 Pod
- 使用網路隔離政策 (Network Policy) 來控制威脅的影響範圍
- 使用防火牆限制不必要的網絡連接，並使用加密保護機密性
- 使用健全的身份驗證和授權機制來限制用戶和管理員訪問，以及限制可能的攻擊範圍
- 紀錄和審視活動日誌 (Audit Log)，以便及時發現潛在的惡意活動
- 定期審查所有 Kubernetes 的設定，並使用漏洞掃描工具確保風險得到適當的處理，並定期規劃升級

## Kubernetes 強化指南的主要內容

這份指南主要分為三部分：授權和身份驗證、網絡安全和監控

### 授權和身份驗證 (Authentication and authorization)

授權和身份驗證是保護 Kubernetes 環境的第一步。在這一部分中，指南介紹了一些最佳實踐，包括使用適當的身份驗證方法、限制對 Kubernetes API 的訪問權限和使用適當的角色和權限。常見的設定策略為 Kubernetes 本身的 Role-Based Access Control (RBAC)。

透過多因素身份驗證（MFA）進行訪問保護 Kubernetes 環境。此外，對於權限的設定應遵循使用最小權限原則 (Least Privilege)，以最小化攻擊面。同時強調了使用適當的角色和權限的重要性 (Role-Based Access Control)，以限制對 Kubernetes API 的訪問。

### 網絡安全 (Network separation and hardening)

在這一部分中，指南介紹了一些最佳實踐，包括使用網路隔離、限制對 Kubernetes 網絡的訪問權限和使用加密通信。

在這份文件中，提及了數項建議以使用適當的網路策略，並限制 Pod 與 Pod 之間的通信。這份文件中也涵蓋了使用加密通信的相關建議，以保護敏感數據。

### 監控和威脅偵測 (Audit Logging and Threat Detection)

監控是保護 Kubernetes 環境的關鍵。在這一部分中，指南介紹了一些最佳實踐，包括使用適當的監控工具、關注重要的事件和警報並建立响应計劃。

指南建議使用適當的監控工具，以監控 Kubernetes 環境的狀態和行為。同時，強調了建立响应計劃的必要性，以應對環境中的安全事件。指南提供了一些示例事件，以幫助企業更好地了解哪些事件可能對其環境造成風險。

## Kubernetes 集群可能的威脅和弱點分析 (Threat Model)

隨著 Kubernetes 可以乘載的業務和運算量提高，有越來越多的應用程式和網路服務基於 Kubernetes 做為容器化調度基礎平台運行。在這種情況下，這也意味著運行在 Kubernetes Cluster 中的內容將可能包含許多企業和組織關鍵的資訊，使得 Kubernetes 逐漸成為攻擊者對於資料或計算能力需求盜竊的高價值目標。例如：除了作為 DDoS (拒絕服務攻擊) 的可能攻擊目標外，一種常見的攻擊手法用於部署惡意程式用於比特幣或是加密貨幣的挖掘。CrowdStrike 更同時於今年發佈一篇常見的攻擊手法，指出挖掘攻擊者將挖礦程式偽裝成 Pause Container 使管理者不易察覺[^crowdstrike-cryptojacking-k8s-campaign]。

在這份文件中，針對現有 Kubernetes Cluster 進行威脅建模具體列出了最有可能遭受的一些威脅：

- 供應鏈 (Supply Chain)：上游和三方軟體供應鏈的攻擊向量多樣且難以緩解。這包括幫助提供最終產品的產品組件、服務、人員甚至風險還可能包括用於建立和管理 Kubernetes Cluster 的第三方軟件和供應商，影響包含多個層面：
    - 容器/應用程序級別：由於在 Kubernetes 中可以運行和調度任一種應用程序和容器，這使得一部分的安全威脅非常依賴第三方安全性、開發人員的可信度和對於軟體本身的防禦。一個惡意的容器或應用部署在 Kubernetes 中均有可能造成安全威脅。
    - 容器執行環境 (Container Runtime)：為了運行容器，在每個工作節點 (Node) 上都必須具備容器所需要的執行環境 (Container Runtime)，並且從映像 (Container Image) 來源的儲存位置中下載。Container Runtime 對於容器的生命週期起到關鍵的作用，包含監控系統資源、為容器隔離可用的系統資源。Container Runtime 和相關虛擬化技術本身的漏洞可能導致這項隔離失效，甚至使攻擊者能在系統上獲取更高的權限。
    - 基礎設施：運行 Kubernetes 的基礎系統仍依賴底層硬件和韌體。任何系統層或是 Kubernetes master node 相關的的漏洞都可能為惡意攻擊提供立足點。

- 惡意攻擊者：惡意攻擊者經常利用漏洞或從社交工程 (Social Engineering) 中竊取憑證並獲取權限。 Kubernetes 本身在架構中公開了數項 API，使得攻擊者可能進一步利用這些 API 進行惡意操作，包括：
    - Control Plane - Kubernetes 主節點 (Master Node) 有許多組件，若 API Server 並未適當的設定權限管理，攻擊者則可能任意地存取 Kubernetes Cluster 進行相關的惡意操作。
    - 工作節點 (Node)：除了運行容器引擎外，工作節點通常也運行了 kubelet 和 kube-proxy 等重要服務，若這些服務本身存在漏洞，則可能會被駭客利用。
    - 容器化應用程式：在 Cluster 內運行的應用程式是常見的攻擊目標。

- 內部威脅：一種可能的也包跨來自內部人員的威脅。內部攻擊者可以利用在組織內工作時所給予的漏洞或特權進行非法訪問及操作。
    - 集群管理員 (Administrator)：Kubernetes 集群管理員可以控制運行的容器、Pod，包括在容器化環境中執行任意命令。這部分可以透過 Kubernetes 本身支援的 RBAC 機制，通過限制對敏感功能的訪問，以減少可能的風險。但由於 Kubernetes 本身缺乏雙人完整性控制 (註：好比要開一道門需要兩把不同的鑰匙，這兩把鑰匙在不同人身上)。此外，管理員甚至也可以透過物理性的方法直接訪問系統本身或是虛擬化管理程序 (Hypervisor)，這都可能破壞 Kubernetes 執行環境。
    - 用戶 (User)：容器化應用程式中的訪問用戶可能知道並擁有訪問 Kubernetes Cluster 中的容器化服務的憑證，取得這項憑證後，可能基於軟體本身的漏洞用於進階的攻擊。
    - 雲端服務或基礎設施提供商  (Cloud Service Provider, CSP)：由於 Kubernetes Cluster 可能運行於其他服務提供商，CSP 經常需要具有多層技術和管理控制，以保護系統免受可能的威脅以及攻擊。

## 各對應層面的強化建議摘要

### Kubernetes Pod Security

#### 運行非 root 權限身份的容器 ("Non-root" containers)

預設情況下，由於容器本身屬於隔離執行環境，容器中的應用程式預設將使用 root 身份運行。在 Pod 安全性一節中，討論了以非 Root (Non-root) 用戶身份部署運行 Pod 執行環境的相關可能做法，並且在文件中提及一個 Dockerfile 的範例，透過相關命令在運行應用程式的同時，透過設定 Linux group 和用戶身份，採用非 root 用戶身份執行該進程 (process)。

```dockerfile
FROM ubuntu:latest

#Update and install the make utility
RUN apt update && apt install -y make

#Copy the source from a folder called “code” and build the application with
the make utility
COPY . /code
RUN make /code

#Create a new user (user1) and new group (group1); then switch into that
user’s context
RUN useradd user1 && groupadd group1
USER user1:group1

#Set the default entrypoint for the container
CMD /code/app
```

此外，Kubernetes 本身對於 Pod 部署提供了 `securityContext` 屬性，可用於設定 Pod 運行時採用非 Root 身份運作，例如：

```yaml
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
```

#### 設定僅可讀的檔案系統 (Immutable container file systems)

預設情況下，Pod 本身內的應用具備權限對容器中的檔案系統進行寫入操作，攻擊者將可以利用這項權限進行檔案建立、下載惡意程式碼甚至更改應用程式代碼等操作。在對於本身容器執行環境的檔案系統屬於僅讀取的使用情境，Kubernetes 管理者可以為 Pod 本身設定為僅可讀取，並透過掛載 Volume (emptyDir[^emptyDir]) 將寫入操作限制於用於暫存空間 (可為檔案系統或是記憶體: tmpfs)，並在容器終止後自動清除，以提高安全性。

```yaml
spec:
  containers:
  - command: ["sleep"]
    args: ["999"]
    image: ubuntu:latest
    name: web
    securityContext:
        readOnlyRootFilesystem: true
    volumeMounts:
        - mountPath: /writeable/location/here
          name: volName
    volumes:
        - emptyDir: {}
          name: volName
```

#### 建立安全的容器映像 (Building secure container images)

一種常見為建立安全的容器映像策略，通常是在映像 CI/CD 建置和推送過程中，增加 Image scanning 和弱點掃描的工作，例如：檢查是否使用過期的程式函式庫、依賴套件、設定和配置問題、不當的權限和開放端口 (Port) 設定、可能的弱點及 CVEs 等。然而，在這份文件中也同時分享了一個採用 Kubernetes 原生的功能和 Adminission Webhook 機制在容器部署的同時觸發相關的掃描工作 ，並且提供更為全面和彈性的安全性偵測機制和參考架構，主動阻斷任何非法的映象部署，甚至在 Webhook 設計中阻止不合規的 Pod 部署設定 (例如：部署 Privilege Container)。

![](/assets/images/2023/nsa-kubernetes-hardening-guide/secure-container-image-build-workflow.png)
(圖片來源：Kubernetes Hardening Guidance)

#### 其他

以下是在該章節中中列舉有關 Pod 安全性的其他建議：

- 增強 Pod 安全性：常見的策略為套用 Pod Security Policies (PSPs - 在季芹的 Kubernetes 版本中已經棄用)、Kubernetes 1.23 開始預設採用的 Pod Security Admission 等

- 保護 Pod Service Account Token：針對不需要存取 Pod Service Account Token 的執行環境關閉設定 Service Account Token 的掛載 (automountServiceAccountToken: false)

- 在系統層強化容器執行和虛擬化環境安全：例如啟用 Kernel 本身支持的 seccomp、Hypervisor 本身支持的安全虛擬化技術運行容器執行環境等

### 網路隔離和強化 (Network separation (isolation) and hardening)

Kubernetes 網路安全性是非常重要的一環，透過對於 Kubernetes 中各個網路元件的隔離和強化，可以大幅降低網路攻擊的風險，以下在這個章節中主要提及可採用的措施：

#### 網路隔離

Kuberentes 支持的 `NetworkPolicy` 來設定 Pod 之間的網路存取規則，並且限制網路存取來源和目的地，以減少攻擊風險。要設定 Network Policy 之前，通常需要透過將應用部署在不同的 Kubernetes `Namespaces` 實現進一步的隔離，並且也需要確保使用的 CNI (Container Network Interface) Plugin 對於 `NetworkPolicy` 支援[^network-policies]。

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: example-access-nginx
  namespace: <NAMESPACE_NAME>
spec:
  podSelector:
    matchLabels:
      app: nginx
  ingress:
  - from:
    - podSelector:
      matchLabels:
        access: "true"
```

#### 設定資源使用政策

Kubernetes 支援使用 `LimitRanges`[^limit-ranges] (用於單一 Namespace 中限制個別 Pod、Container 可使用的資源數量)、`ResourceQuotas`[^resource-quotas] (可用於限制在 Namespace 中總體可以使用的 CPU、Memory、儲存資源，甚至是限制物件數量，例如只能運行多少個 Pod) 和 `Process ID (PID)` [^pid-limit] 限制等方法針對特定 Kubernetes Namespace、Node 或是 Pod 達到控制可用資源的目的。


```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: cpu-min-max-demo-lr
spec:
  limits
  - default:
      cpu: 1
    defaultRequest:
      cpu: 0.5
    max:
      cpu: 2
    min:
      cpu 0.5
    type: Container
```

另外一個文件沒提的是，Kubernetes Pod 本身部署也同時支持相關的資源限制設定，例如：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend
spec:
  containers:
  - name: app
    image: images.my-company.example/app:v4
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

#### 控制平面強化 (Control Plane Hardening)

在這一節中主要討論了幾項針對 Kubernetes Master Node 相關的強化討論，包含：

- 啟用 API Server 訪問控制：透過 API Server 的 Role-Based Access Control (RBAC) 機制，可以設定哪些使用者或群組可以訪問 API Server，並且限制訪問權限，以減少不合法的 API Server 請求。

- 網路加密：透過 HTTPS/TLS 或是其他網路加密方式。由於 etcd 屬於整個 Kubernetes Cluster 最關鍵的元件，因此也包含為 etcd 以及 API Server 之間的傳輸啟用加密技術。除了可以增加網路傳輸的安全性，更減少被竊聽或攻擊的風險。

- 避免將 Kbuernetes API Server 暴露於網路上：API Server 預設使用了 6443 (有些使用 443)，應對於這些相關的端口 (Port) 進行強化甚至加上關聯的安全組規則，包含：

    - `2379-2380`: etcd server client API
    - `10250`: kubelet API
    - `10259`: kube-scheduler
    - `10257`: kube-controller-manager
    - `30000-32767`: Ports that may be opened on a Worker Node when using NodePort


- 針對 Secret 物件的加密：預設情況下，Kubernetes Secret 本身屬於未加密的 base64 編碼字串，任何具備 Kubernetes API 操作權限的人均有機會可以獲取到相關的敏感資訊。因此，可以透過三方的加密服務為 Secret 寫入 etcd 時進行加密 (例如：AWS Key Management Service, KMS)、為 API Server 去啟動參數中增加 `--encryption-provider-config` 設定加密提供服務 [^kms-encryption] 等來增加 Kubernetes Secret 的安全性。

#### 保護敏感的雲端服務基礎建設資訊 (Protecting sensitive cloud infrastructure)

許多組織會選擇將 Kubernetes 運行在雲端服務提供商的執行環境中，管理者可以，例如：以 AWS 為例，可以透過設定 EC2 本身的屬性封鎖 EC2 Metadata Service (IMDS) 的存取權限並且阻擋獲取可能的憑證 (EC2 Instance IAM Role)。例如：以下是文件中沒有提及使用 EC2 本身支持的設定或是透過 `NetworkPolicy` 實現。

(AWS CLI)
```bash
aws ec2 modify-instance-metadata-options --instance-id <value> --http-tokens required --http-put-response-hop-limit 1
```

(NetworkPolicy)
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-metadata-access
  namespace: example
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 169.254.169.254/32
```

### 授權和身份驗證 (Authentication and authorization)

授權和身份驗證是保護 Kubernetes 環境的重要一環，在這一章節，指南介紹了一些最佳實踐，包括使用適當的身份驗證方法、限制對 Kubernetes API 的訪問權限和使用適當的角色和權限。但主要圍繞為 Kubernetes 本身的 Role-Based Access Control (RBAC) 設定以保護 Kubernetes 執行環境。例如：設定一個僅對於 Pod 可讀取的 Role 身份。

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: your-namespace-name
  name: pod-reader
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "watch", "list"]
```

要啟用這項設定，kube-apiserver 必須使用必要的參數 (`--authorization-mode=RBAC`) 以支援該方法。


## 總結 Kubernetes Hardening Guide

作為本篇內容的總結，以下是這份文件中對於每個部分的主要建議摘要：

- Kubernetes Pod 安全
    - 運行非 root 權限身份的容器 ("Non-root" containers)
    - 設定僅可讀的檔案系統 (Immutable container file systems) 運行容器
    - 建立及掃描容器映像以找出可能的漏洞或設定錯誤
    - 使用相關技術和功能控制可能的安全性威脅，包括：
        - 防止運行 Privileged Container 容器
        - 降量避免頻繁使用較不安全的功能和選項，例如 hostPID、hostIPC、hostNetwork、allowedHostPath
        - 透過 RunAsUser 屬性避免以 root 用戶運行應用
        - 在系統層可以考慮啟用安全功能（例如： SELinux、AppArmor 和 seccomp)
- 網路隔離和強化
    - 使用防火牆和基於角色的訪問控制（RBAC）限制對控制平面節點的訪問，並考慮在控制平面組件和節點之間使用單獨的網絡
    - 限制對 etcd 的訪問
    - 配置控制平面組件使用通過傳輸層安全性（TLS）憑證進行身份驗證、加密通信，包含將 etcd 加密並使用 TLS 協議通信
    - 考慮設定 NetworkPolicy 以隔離資源，並設定明確的網路安全性策略 (NetworkPolicy)
    - 將所有憑證和敏感信息加密存放在 Kubernetes Secrets 中，而不是在配置文件中。考慮啟用 KMS 等服務加密 Kubernetes Secrets 資源
- 認證和授權
    - 禁用匿名用戶直接訪問和操作 Kubernetes API Server（預設啟用）
    - 啟用 RBAC，並為用戶、管理員、開發人員、Service Account 等建立個別身份的 RBAC 策略。
- 記錄檔和威脅檢測
    - 為 API Server 啟用 Audit log 操作記錄檔（預設為關閉），並為 Kubernetes 事件紀錄以進行查閱和追蹤
    - 為應用和容器設定一致性的日誌收集、監控和警報系統
- 升級和應用程序安全最佳實踐
    - 即時更新 Kubernetes 版本和安全漏洞
    - 定期進行漏洞掃描和渗透测试
    - 從環境中移除和刪除未使用的元件、部署

總的來說，在閱讀完這份 NSA 和 CISA 釋出的這份 Kubernetes Hardening Guide 我更感覺像是在重新複習一次 Kubernetes 本身對於安全性功能的支援，我認為作為一份 Checklist 再好不過且的確是一份非常值得參考的文件。

當然，在很多實際應用中，Kubernetes 的部署和安全性都可能基於組織文化，甚至任何非人為可控制因素，使得無法針對所有的威脅進行一一的強化，但身為 Kubernetes 管理者，通過學習並且逐步實施這些最佳實踐，某種程度上能夠更好保護 Kubernetes 的執行環境，減少面臨的可能安全性風險，同時建立一個持續改進的安全計劃和引導組織文化提升，以應對不斷變化的安全性威脅。

## 參考資源

[^k8s-hardening-guide]: [Kubernetes Hardening Guidance](https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF) (August 2022).
[^nsa-cisa-press]: [NSA, CISA release Kubernetes Hardening Guidance release Kubernetes Hardening Guidance](https://www.nsa.gov/Press-Room/News-Highlights/Article/Article/2716980/nsa-cisa-release-kubernetes-hardening-guidance/)
[^crowdstrike-cryptojacking-k8s-campaign]: [CrowdStrike Discovers First-Ever Dero Cryptojacking Campaign Targeting Kubernetes](https://www.crowdstrike.com/blog/crowdstrike-discovers-first-ever-dero-cryptojacking-campaign-targeting-kubernetes/)
[^emptyDir]: [Kubernetes Documentation - emptyDir](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir)
[^network-policies]: [Kubernetes Documentation - Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
[^limit-ranges]: [Kubernetes Documentation - Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)
[^resource-quotas]: [Kubernetes Documentation - Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
[^pid-limit]: [Kubernetes Documentation - Process ID Limits And Reservations](https://kubernetes.io/docs/concepts/policy/pid-limiting/)
[^kms-encryption]: [Kubernetes Documentation - Using a KMS provider for data encryption](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/#encrypting-your-data-with-the-kms-provider)
