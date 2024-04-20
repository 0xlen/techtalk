---
layout: post
title:  "深入研究 Kubernetes Garbage Collection：容器映像清除機制"
author: eason
categories: [Kubernetes]
image: assets/images/2024/deep-dive-into-kubernetes-garbage-collector-imagefs/cover.jpg
lang: tw
canonical_url: https://easontechtalk.com/tw/deep-dive-into-kubernetes-garbage-collector-imagefs/
---

kubelet 如何觸發垃圾收集機制 (Garbage Collection)？在本文中，我們將深入探討 Kubernetes Garbage Collection，並且理解 kubelet 如何實現映像清除機制。此外，我們也將探討如何正確地監控 imageFS 的使用情況。

當 kubelet 檢測到 imageFs（存儲容器映像的檔案系統）的可用空間低於預定閾值時，它會觸發 Garbage Collection，即開始清理不再需要的容器映像以釋放空間。這一閾值可以通過 kubelet 的配置選項 `--image-gc-high-threshold` (`imageGCHighThresholdPercent`) 設定，預設值為 85%，這意味著當 imageFs 的可用空間低於總空間的 85% 時，kubelet 將開始進行映像清理工作，並且可能在日誌中注意到類似以下的提示：

```bash
kubelet[2298]: I0226 11:59:17.153440    2298 image_gc_manager.go:310] "Disk usage on image filesystem is over the high threshold, trying to free bytes down to the low threshold" usage=93 highThreshold=85 amountToFree=69382155468 lowThreshold=80

kubelet[2298]: I0226 12:04:17.157231    2298 image_gc_manager.go:310] "Disk usage on image filesystem is over the high threshold, trying to free bytes down to the low threshold" usage=97 highThreshold=85 amountToFree=88325110988 lowThreshold=80
```

## kubelet 如何計算容器映像空間並且觸發 Garbage Collection

要了解 kubelet 其中對於容器映像管理的 Garbage Collection 的機制，就得先分析 kubelet 實際是如何分析磁碟空間，並且根據對應設定參數設定觸發清除工作。

以 Kubernetes 1.29 核心程式碼為例 [^k8s-1-29-image-gc-manager]。在該片段中，定義了 `usagePercent` 計算方法，並且提供了一個判斷式檢查是否超過 `im.policy.HighThresholdPercent` 的數值。從這個片段中，可以推敲這裡的邏輯與上述的參數設定觸發映像清理行為相關：

```go
  // Get disk usage on disk holding images.
  fsStats, _, err := im.statsProvider.ImageFsStats(ctx)
  if err != nil {
    return err
  }

	var capacity, available int64
	if fsStats.CapacityBytes != nil {
		capacity = int64(*fsStats.CapacityBytes)
	}
	if fsStats.AvailableBytes != nil {
		available = int64(*fsStats.AvailableBytes)
	}

  ...

  // If over the max threshold, free enough to place us at the lower threshold.
  usagePercent := 100 - int(available*100/capacity)
  if usagePercent >= im.policy.HighThresholdPercent {
    amountToFree := capacity*int64(100-im.policy.LowThresholdPercent)/100 - available
    klog.InfoS("Disk usage on image filesystem is over the high threshold, trying to free bytes down to the low threshold", "usage", usagePercent, "highThreshold", im.policy.HighThresholdPercent, "amountToFree", amountToFree, "lowThreshold", im.policy.LowThresholdPercent)
    freed, err := im.freeSpace(ctx, amountToFree, freeTime, images)
    if err != nil {
      return err
    }

    if freed < amountToFree {
      err := fmt.Errorf("Failed to garbage collect required amount of images. Attempted to free %d bytes, but only found %d bytes eligible to free.", amountToFree, freed)
      im.recorder.Eventf(im.nodeRef, v1.EventTypeWarning, events.FreeDiskSpaceFailed, err.Error())
      return err
    }
  }
```

值得一提的是，變數 `capacity` 以及 `available` 從字面上來看分別代表了總以及剩餘可用空間，實作上實際引用了 `statsProvider.ImageFsStats` 其中的 `CapacityBytes` 以及 `AvailableBytes` 數值。

如果進一步分析核心程式碼，可以發現 `statsProvider` 可以根據實作上的定義存在獲取映像對應的儲存空間數據有些微不同 (Image Filesystem，以下簡稱 imageFS)。ImageFS 在 kubelet 核心程式碼中存在兩者不同的實作方式，一種為使用 CRI 獲取，另一種則為使用 cadvisor，因此，在核心程式碼目錄中可以注意到存在 `cri_stats_provider.go` [^k8s-1-29-cri-stats-provider] 以及 `cadvisor_stats_provider.go` [^k8s-1-29-cadvisor-stats-provider] 兩者不同的實作。

這項機制在 Kubernetes 1.23 版本支持了這項 `PodAndContainerStatsFromCRI` 測試功能 (Feature Gate [^feature-gate])，允許 kubelet 透過 CRI 介面與 Container runtime 互動獲取容器相關的指標和數據，但預設都是關閉 [^kubelet-metric-data]，並且使用 cadvisor 作為主要的收集來源。

![](/assets/images/2024/deep-dive-into-kubernetes-garbage-collector-imagefs/cover.jpg)

但不論使用哪種方式收集，根據 kubelet 提供的對應數據統計，其統計結果皆可以使用 kubelet 本身提供的 API 獲得這項資訊，例如：

```bash
$ kubectl get --raw /api/v1/nodes/ip-172-31-21-234.eu-west-1.compute.internal/proxy/stats/summary | jq '.node.runtime.imageFs'
{
  "time": "2024-03-11T10:59:56Z",
  "availableBytes": 17310752768,
  "capacityBytes": 21462233088,
  "usedBytes": 1291296768,
  "inodesFree": 10375082,
  "inodes": 10484720,
  "inodesUsed": 44497
}
```

在使用 containerd 作為容器執行的通用環境下 (例如：Amazon EKS)，其預設將使用 `/var/lib/containerd` 作為主要的 imageFS 位置：

```bash
$ head /etc/containerd/config.toml
version = 2
root = "/var/lib/containerd"
state = "/run/containerd"
```

(如果想瞭解更多有關 imageFS 的位置，Kubernetes Blog 近期有一篇文章在描述不同 Container runtime 對應的 imageFS 磁碟儲存空間耗盡問題，並且建議分離檔案系統位置 [^k8s-blog-separate-imagefs]，在此不贅述)

如果是 CRI，可以嘗試使用 CRI 命令列工具了解 Container Runtime 所使用的 imageFS 掛載位置：

```bash
$ sudo crictl imagefsinfo
{
  "status": {
    "imageFilesystems": [
      {
        "timestamp": "1710154476577999227",
        "fsId": {
          "mountpoint": "/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs"
        },
        "usedBytes": {
          "value": "1291296768"
        },
        "inodesUsed": {
          "value": "44497"
        }
      }
    ],
    "containerFilesystems": []
  }
}
```

因此，我們可以得知 kubelet 會擷取 imageFS 中的 capacity, available 等數值 (不論是 CRI 或是 cadvisor)，上述設定中也可以得知我環境中 imageFS 對應的儲存位置為 `/var/lib/containerd` (containerd)。這部分意味著容器映像的空間將可能與系統的掛載位置共用，例如，以下是我的系統空間輸出，可以根據以下資料嘗試計算取得的數值與 `df` 得到的數值是否匹配：

```bash
$ df
Filesystem     1K-blocks    Used Available Use% Mounted on
devtmpfs         1962632       0   1962632   0% /dev
tmpfs            1971680       0   1971680   0% /dev/shm
tmpfs            1971680    1696   1969984   1% /run
tmpfs            1971680       0   1971680   0% /sys/fs/cgroup
/dev/nvme0n1p1  20959212 4054180  16905032  20% /
shm                65536       0     65536   0% /run/containerd/io.containerd.grpc.v1.cri/sandboxes/6d62590341a08f4066c168f2d00118ac5aade67ceb2797c0d88f97cbe825e302/shm
shm                65536       0     65536   0% /run/containerd/io.containerd.grpc.v1.cri/sandboxes/6f3f7200edfeb3129b765652da98f14009597d26bfcc7973232984ea431e67a7/shm
shm                65536       0     65536   0% /run/containerd/io.containerd.grpc.v1.cri/sandboxes/7c9b3b1b9853dcdccdcc18e99ca89caeac236150df67881dd054651339038efc/shm
shm                65536       0     65536   0% /run/containerd/io.containerd.grpc.v1.cri/sandboxes/38935dde2e2d40d73d039befc1283e165284269f7bb11002fd3937c274998fb5/shm
shm                65536       0     65536   0% /run/containerd/io.containerd.grpc.v1.cri/sandboxes/6fb8c888e2fa36a1ac909909dad4d4f5d520f48eb42731353f176f6e9dd76f03/shm
tmpfs             394336       0    394336   0% /run/user/1000
```

- `/var/lib/containerd` 並未分離不同的檔案系統因此共享 `/` 的對應空間
- 根目錄位置的 `Available` 數值爲 `16905032 KiB`，該數值與上述 kubelet 獲取的 `imageFs.availableBytes`的數值相同 (`17310752768`)。由於 kubelet 獲取的單位是 `Byte`，轉換為 `KiB` 後為 `17310752768 (imageFs.availableBytes) / 1024 = 16905032 KiB` (約 17 G)
- 掛載點 `/` 的總空間大小為 `1K-block`數值 (`20959212 KiB`)，等同於轉換後的 `21462233088 (imageFs.capacityBytes) / 1024 = 20959212 KiB` 數值 (約 20 G)

在知道 kubelet 是如何獲取 imageFS 可用空間和相關數值後，根據 kubelet 核心程式碼的實作，我們可以知道在上述執行環境中，計算使用空間是否超出 `--image-gc-high-threshold` 定義的閥值 (預設為 85%) 則可以根據以下結果得知：

```bash
# usagePercent := 100 - int(available*100/capacity)
# 約等於 20%
usagePercent = 100 - (17310752768 * 100 / 21462233088)
```

由於我的環境中 imageFS 與 `/` 空間共享，因此該數值與 `df` 提供的百分比近似而可以作為參考值。

因此，在我的例子中這樣的狀態並不足以觸發  Garbage Collection 並且清除部分的容器映像。更一步則可能根據 Hard Eviction Threshold 的參數 `--eviction-hard` (驅逐條件) 觸發 Pod 驅逐操作將部分的 Pod 停止並且移除，例如 `imagefs.available<15%` [^node-pressure-eviction]。

### 如何監控 imageFS 的用量

在了解 kubelet 的運作機制和計算方法後，我們可以透過實作一個簡單的 Shell Script 來獲取每個節點的 imageFS 儲存空間和使用率概況，例如：

```bash
nodes=$(kubectl get no -o=jsonpath='{.items[*].metadata.name}')

for node in $nodes; do
    imageFS=$(kubectl get --raw "/api/v1/nodes/$node/proxy/stats/summary"  | jq .node.runtime.imageFs)
    available=$(echo $imageFS | jq '.availableBytes')
    capacity=$(echo $imageFS | jq '.capacityBytes')

    usagePercent=$((100 - $available * 100 / $capacity))

    echo "Node: $node, Available: $(($available / 1024 / 1024)) MiB, Capacity: $(($capacity / 1024 / 1024)) MiB, Usage: $usagePercent%"
done
```

然而，在 imageFS 與主要掛載位置共用的通用情況下，要監控使用空間是否緊張而進一步觸發 Garbage Collection，除了上述簡單的實作，也可以透過常見的監控完成，例如上述的 `df` 所見的使用量百分比數據即可作為一項參考，亦或者是監控系統中有引入常見的 Prometheus Node Exporter 的提供了檔案系統相關的功能 (例如可以定義 `--collector.filesystem.mount-points-exclude` 決定哪些掛載點要排除監控) 能夠具體將檔案系統的數據進一步轉數值化，以進行近一步的監控。

## 總結

本文深入探討了 Kubernetes 的垃圾收集機制 (Garbage Collection) 以及如何監控 imageFS 的使用情況。在了解 Kubernetes 的 Garbage Collection 以及如何監控 imageFS 的使用情況後，可以對於 Kubernetes 環境的監控和資源使用有更全面的認識。妥善的資源管理能確保系統的穩定與效能，避免因為資源耗盡而導致的非預期服務中斷。

## 參考資料

[^k8s-1-29-image-gc-manager]: [Kubernetes v1.29.0 - image_gc_manager.go](https://github.com/kubernetes/kubernetes/blob/v1.29.0/pkg/kubelet/images/image_gc_manager.go#L319-L360)
[^k8s-1-29-cri-stats-provider]: [Kubernetes v1.29.0 - cri_stats_provider.go](https://github.com/kubernetes/kubernetes/blob/v1.29.0/pkg/kubelet/stats/cri_stats_provider.go#L387-L425)
[^k8s-1-29-cadvisor-stats-provider]: [Kubernetes v1.29.0 - cadvisor_stats_provider.go](https://github.com/kubernetes/kubernetes/blob/3f7a50f38688eb332e2a1b013678c6435d539ae6/pkg/kubelet/stats/cadvisor_stats_provider.go#L241-L322)
[^feature-gate]: [Kubernetes Feature Gates](https://kubernetes.io/docs/reference/command-line-tools-reference/feature-gates/#feature-gates-for-alpha-or-beta-features)
[^kubelet-metric-data]: [Kubelet Node Metric](https://kubernetes.io/docs/reference/instrumentation/node-metrics/#:~:text=The%20kubelet%20gathers%20metric%20statistics,via%20the%20Kubernetes%20API%20server)
[^k8s-blog-separate-imagefs]: [Image Filesystem: Configuring Kubernetes to store containers on a separate filesystem](https://kubernetes.io/blog/2024/01/23/kubernetes-separate-image-filesystem/)
[^node-pressure-eviction]: [Node-pressure Eviction Hard eviction thresholds](https://kubernetes.io/docs/concepts/scheduling-eviction/node-pressure-eviction/#hard-eviction-thresholds)