---
layout: post
title:  "Strengthening Kubernetes Security: Kubernetes Hardening Guidance released by NSA and CISA"
author: eason
categories: [Kubernetes, Security]
image: assets/images/2023/nsa-kubernetes-hardening-guide/cover.png
---

As a containerized scheduling platform, Kubernetes has become an essential part of the infrastructure in many enterprises and production environments. However, due to its complexity, Kubernetes' execution environment also faces many security challenges and potential issues. The United States National Security Agency (NSA) and Cybersecurity and Infrastructure Security Agency (CISA) released a network security report called Kubernetes Hardening Guidance in 2022 [^nsa-cisa-press] (full document [^k8s-hardening-guide]). As a guide to strengthen Kubernetes, the guide not only aims to provide relevant strengthening policies for the NSA, CISA, and key infrastructure for running Kubernetes clusters for federal and public agencies in the United States, but also details the security threats hidden in the Kubernetes environment and provides relevant configuration guidelines to minimize its security risks. For Kubernetes administrators, this guide is a very useful reference resource.

## Purpose of Providing Kubernetes Hardening Guidance

The purpose of this guide is to provide the best security practices when using Kubernetes to reduce its risks. In this document, various topics are mentioned, from authentication, authorization, network security, to monitoring policies, and useful tools and techniques are provided to strengthen the security measures of Kubernetes clusters.

## What does this guide say?

After reading this document, it can be noticed that the overview section of the document directly mentions the core security issues around which the entire document revolves. The following dozens of pages describe in detail how to set up and protect the Kubernetes environment and related security issues. In this content, not only from the perspective of the cluster system administrator, but also from the perspective of the system developer, relevant configuration recommendations are proposed to avoid common configuration errors, and relevant practices, mitigation, and strengthening measures are covered, mainly including:

- Scan containers and pods to find vulnerabilities or configuration errors
- Run containers and pods with minimum permissions
- Use network isolation policies (Network Policy) to control the scope of threats
- Use firewalls to restrict unnecessary network connections and use encryption to protect confidentiality
- Use sound authentication and authorization mechanisms to limit user and administrator access and limit the scope of possible attacks
- Log and review activity logs (Audit Log) to detect potential malicious activity in a timely manner
- Regularly review all Kubernetes configurations, use vulnerability scanning tools to ensure that risks are properly handled, and plan upgrades regularly

## Main Content of Kubernetes Hardening Guidance

This guide is mainly divided into three parts: authorization and authentication, network security, and monitoring

### Authorization and Authentication

Authorization and authentication are the first step in protecting the Kubernetes environment. In this section, the guide introduces some best practices, including using appropriate authentication methods, restricting access to the Kubernetes API, and using appropriate roles and permissions. The common configuration policy is Kubernetes' own Role-Based Access Control (RBAC).

Access to the Kubernetes environment should be protected through multi-factor authentication (MFA). In addition, the configuration of permissions should follow the principle of least privilege to minimize the attack surface. At the same time, the importance of using appropriate roles and permissions (Role-Based Access Control) to limit access to the Kubernetes API is emphasized.

### Network Security

In this section, the guide introduces some best practices, including using network isolation, restricting access to the Kubernetes network, and using encrypted communication.

In this document, several recommendations are mentioned to use appropriate network policies and restrict communication between pods. The document also covers relevant recommendations for using encrypted communication to protect sensitive data.

### Monitoring and Threat Detection

Monitoring is critical to protecting the Kubernetes environment. In this section, the guide introduces some best practices, including using appropriate monitoring tools, paying attention to important events and alerts, and establishing response plans.

The guide recommends using appropriate monitoring tools to monitor the status and behavior of the Kubernetes environment. At the same time, the necessity of establishing response plans to respond to security incidents in the environment is emphasized. The guide provides some example events to help enterprises better understand which events may pose risks to their environment.

## Threat Model of Kubernetes Clusters

As the business and computing load that Kubernetes can carry increase, more and more applications and network services are running on Kubernetes as a containerized scheduling foundation platform. In this case, this also means that the content running in the Kubernetes cluster may contain many critical information of enterprises and organizations, making Kubernetes a high-value target for attackers to steal data or computing power. For example: In addition to being a possible target for DDoS attacks, a common attack method is to deploy malware for bitcoin or cryptocurrency mining. CrowdStrike also released a common attack method this year, pointing out that mining attackers disguise mining programs as Pause Containers to make it difficult for administrators to detect [^crowdstrike-cryptojacking-k8s-campaign].

In this document, a threat modeling is specifically listed for existing Kubernetes clusters, and some of the most likely threats that may be encountered are:

- Supply Chain: Upstream and third-party software supply chain attack vectors are diverse and difficult to mitigate. This includes product components, services, personnel, and even risks that may include third-party software and suppliers used to build and manage Kubernetes clusters, affecting multiple levels:
    - Container/application level: Because any application and container can be run and scheduled in Kubernetes, a part of security threats depend heavily on third-party security, developer trustworthiness, and software defenses. A malicious container or application deployed in Kubernetes can pose a security threat.
    - Container runtime: In order to run containers, the container runtime required by the container must be present on each worker node, and downloaded from the storage location of the image. The container runtime plays a critical role in the life cycle of containers, including monitoring system resources and isolating system resources available to containers. Vulnerabilities in the container runtime and related virtualization technologies may cause this isolation to fail and even allow attackers to obtain higher privileges on the system.
    - Infrastructure: The underlying hardware and firmware on which Kubernetes runs are still dependent on the basic system. Any vulnerabilities in the system layer or Kubernetes master node may provide a foothold for malicious attacks.
- Malicious attackers: Malicious attackers often exploit vulnerabilities or steal credentials from social engineering. Kubernetes exposes several APIs in its architecture, which allows attackers to further exploit these APIs for malicious operations, including:
    - Control Plane: Kubernetes master node has many components, and if the API Server is not properly configured for permission management, attackers may access the Kubernetes cluster arbitrarily for related malicious operations.
    - Worker Node: In addition to running the container engine, the worker node typically also runs important services such as kubelet and kube-proxy. If these services themselves have vulnerabilities, they may be exploited by hackers.
    - Containerized applications: Applications running in the cluster are a common target for attacks.
- Internal threats: One possible threat also includes threats from internal personnel. Internal attackers can use vulnerabilities or privileges given when working in the organization for nefarious purposes.
  - Cluster Administrator: Kubernetes cluster administrators can control running containers, pods, and even execute arbitrary commands in a containerized environment. This can be mitigated by limiting access to sensitive functionalities through Kubernetes' built-in RBAC mechanism. However, Kubernetes lacks dual integrity controls (i.e., two different keys required to open a door, with each key held by different people). Additionally, administrators can physically access the system or virtualization management programs (hypervisor), which can compromise the Kubernetes runtime environment.
  - User: Access users in containerized applications may know and possess credentials to access containerized services in the Kubernetes cluster. Once obtained, these credentials can be used for advanced attacks based on vulnerabilities in the software itself.
  - Cloud Service Provider (CSP): Since Kubernetes clusters may run on other service providers, CSPs often need to have multi-layered technical and management controls to protect the system from potential threats and attacks.

## Enhancement for Each Dimensions

### Kubernetes Pod Security

#### Running "Non-root" Containers

By default, applications running in containers use the root user identity. However, it is possible to deploy and run Pods as non-root users. In the Pod Security section, an example Dockerfile is provided that demonstrates how to use Linux groups and user identities to run the process as a non-root user.

```
FROM ubuntu:latest

# Update and install the make utility
RUN apt update && apt install -y make

# Copy the source from a folder called “code” and build the application with the make utility
COPY . /code
RUN make /code

# Create a new user (user1) and new group (group1); then switch into that user’s context
RUN useradd user1 && groupadd group1
USER user1:group1

# Set the default entrypoint for the container
CMD /code/app

```

In addition, Kubernetes provides the `securityContext` attribute for setting non-root user identities during Pod deployment:

```
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000

```

#### Immutable Container File Systems

By default, applications running inside Pods have permission to write to the container file system. This permission can be exploited by attackers to create files, download malicious code, or modify application code. To enhance security, Kubernetes administrators can set the container file system as read-only and use a Volume (emptyDir[^emptyDir]) for write operations for temporary storage (either a file system or tmpfs memory) that is automatically cleared after the container terminates.

```
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

#### Building Secure Container Images

One common practice for building secure container images is to include image scanning and vulnerability scanning during the CI/CD build and push process. This includes checking for outdated libraries, dependencies, configuration issues, improper permissions, open ports, potential vulnerabilities, and CVEs. Additionally, Kubernetes provides native features and Admission Webhook mechanisms for triggering scans during container deployment. This provides a more comprehensive and flexible security detection mechanism that actively blocks any illegal image deployment and prevents non-compliant Pod deployment settings (such as deploying Privilege Containers) in the Webhook configuration.

![](/assets/images/2023/nsa-kubernetes-hardening-guide/secure-container-image-build-workflow.png)
(Image source: Kubernetes Hardening Guidance)

#### Other

The following are other suggestions related to Pod security in this chapter:

- Enhancing Pod Security: Common strategies include applying Pod Security Policies (PSPs - deprecated in later Kubernetes versions) and using Pod Security Admission, which is enabled by default in Kubernetes 1.23.
- Protecting Pod Service Account Tokens: For execution environments that do not require access to Pod Service Account Tokens, disable the automounting of Service Account Tokens (automountServiceAccountToken: false).
- Enhancing Container Execution and Virtualization Security at the System Level: For example, enabling seccomp, which is supported by the Kernel, and running container execution environments with hypervisor-supported security virtualization technologies.

### Network Separation (Isolation) and Hardening

Network security is an important part of Kubernetes security. By isolating and hardening various network components in Kubernetes, the risk of network attacks can be significantly reduced. The following measures can be taken:

#### Network Isolation

Kubernetes supports `NetworkPolicy` to set network access rules between Pods and restrict network access sources and destinations to reduce attack risks. Before setting up Network Policy, it is usually necessary to isolate applications in different Kubernetes `Namespaces` and ensure that the CNI (Container Network Interface) Plugin used supports `NetworkPolicy`[^network-policies].

```
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

#### Resource Usage Policy Settings

Kubernetes supports the use of `LimitRanges`[^limit-ranges] (to limit the number of resources that individual Pods or Containers can use in a single Namespace), `ResourceQuotas`[^resource-quotas] (to limit the amount of CPU, memory, and storage resources that can be used in a Namespace), and `Process ID (PID)` [^pid-limit] limits to control available resources for specific Kubernetes Namespaces, Nodes, or Pods.

```
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

Resource limit settings can also be applied to the Kubernetes Pod deployment itself:

```
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

#### Control Plane Hardening

This section discusses several enhancements for Kubernetes Master Node security, including:

- Enabling API Server Access Control: Role-Based Access Control (RBAC) can be used to set which users or groups can access the API Server and limit access.
- Network Encryption: Encryption can be enabled using HTTPS/TLS or other network encryption mechanisms. Since etcd is the most critical component of the entire Kubernetes Cluster, encryption can also be used for communication between etcd and the API Server. This not only increases network transmission security but also reduces the risk of eavesdropping or attack.
- Avoid exposing the Kubernetes API Server to the network: API Server uses 6443 (or sometimes 443) by default, and these ports should be strengthened and associated with security group rules, including:

    - `2379-2380`: etcd server client API
    - `10250`: kubelet API
    - `10259`: kube-scheduler
    - `10257`: kube-controller-manager
    - `30000-32767`: Ports that may be opened on a Worker Node when using NodePort

- Encrypting Secret Objects: By default, Kubernetes Secrets are unencrypted base64-encoded strings, and anyone with Kubernetes API access can obtain sensitive information. Therefore, encryption can be used to encrypt Secrets when writing to etcd using third-party encryption services (such as AWS Key Management Service, KMS) or by adding the `--encryption-provider-config` parameter to the API Server startup to configure encryption providers [^kms-encryption].

#### Protecting Sensitive Cloud Infrastructure

Many organizations choose to run Kubernetes in cloud service provider environments. For example, in AWS, administrators can block EC2 Metadata Service (IMDS) access and prevent access to possible credentials (EC2 Instance IAM Role) by setting EC2 properties. The following example shows how to use EC2's built-in settings or `NetworkPolicy` to achieve this.

(AWS CLI)

```
aws ec2 modify-instance-metadata-options --instance-id <value> --http-tokens required --http-put-response-hop-limit 1
```

(NetworkPolicy)

```
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

### Authentication and Authorization

Authentication and authorization are important aspects of Kubernetes security. This chapter provides some best practices, including using appropriate authentication methods, restricting access to the Kubernetes API, and using appropriate roles and permissions. These practices are centered around setting up Role-Based Access Control (RBAC) to protect the Kubernetes environment. Setting up RBAC rules may include:

- Defining roles and permissions for Kubernetes users, groups, and service accounts
- Binding roles to users, groups, and service accounts
- Creating custom roles with specific permissions and constraints
- Limiting namespace access to specific users or groups

However, the focus is mainly on setting up Role-Based Access Control (RBAC) for Kubernetes itself to protect the Kubernetes execution environment. For example, setting up a Role identity that only has read access to Pods:

```
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

To enable this setting, the kube-apiserver must use the necessary parameter (`--authorization-mode=RBAC`) to support this method.

## Summary

In summary, the Kubernetes Hardening Guidance released by the NSA and CISA provides a comprehensive guide for Kubernetes administrators to minimize the security risks of the Kubernetes environment. The guide covers various aspects of Kubernetes security, including authentication and authorization, network security, and monitoring. By following the best practices and recommendations in this guide, Kubernetes administrators can strengthen the security measures of their Kubernetes clusters and better protect against potential security threats.

As a summary of the content, the following are the key recommendations for each section in this document:

**Kubernetes Pod Security**

- Run containers with non-root privilege
- Configure immutable container file systems
- Create and scan container images for potential vulnerabilities or misconfigurations
- Use relevant technologies and features to control potential security threats, including:
    - Prevent running privileged container containers
    - Avoid using less secure features and options such as hostPID, hostIPC, hostNetwork, allowedHostPath
    - Avoid running applications as root user by using RunAsUser attribute
    - Consider enabling security features at the system level (e.g. SELinux, AppArmor, and seccomp)

**Network Isolation and Hardening**

- Use firewalls and role-based access control (RBAC) to restrict access to control plane nodes and consider using separate network between control plane components and nodes
- Limit access to etcd
- Configure control plane components to use transport layer security (TLS) certificates for authentication and encrypted communication, including encrypting etcd and using TLS protocol for communication
- Consider configuring NetworkPolicy to isolate resources and set explicit network security policies (NetworkPolicy)
- Store all certificates and sensitive information encrypted in Kubernetes Secrets rather than in configuration files. Consider enabling services such as KMS to encrypt Kubernetes Secrets resources.

**Authentication and Authorization**

- Disable anonymous user access to and operation on Kubernetes API Server (enabled by default)
- Enable RBAC and create individual RBAC policies for users, administrators, developers, and Service Accounts.

**Logging and Threat Detection**

- Enable audit log operation record for API Server (turned off by default) and Kubernetes event logs for lookup and tracking
- Configure consistent log collection, monitoring, and alerting systems for applications and containers

**Upgrade and Application Security Best Practices**

- Update Kubernetes version and security vulnerabilities in real time
- Conduct vulnerability scans and penetration tests regularly
- Remove and delete unused components and deployments from the environment

## Conclusion

Overall, after reading this Kubernetes Hardening Guide released by NSA and CISA, I feel like I am reviewing the support of Kubernetes itself for security features. I think as a checklist, it is definitely a very useful reference document.

Of course, in many practical applications, Kubernetes deployment and security may be based on organizational culture or even any uncontrollable factors, making it impossible to strengthen all threats one by one. However, as a Kubernetes administrator, by learning and gradually implementing these best practices, you can better protect the Kubernetes runtime environment, reduce potential security risks, and establish a continuous improvement security plan and guide organizational culture enhancement to deal with constantly changing security threats.

## References

[^k8s-hardening-guide]: [Kubernetes Hardening Guidance](https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF) (August 2022).
[^nsa-cisa-press]: [NSA, CISA release Kubernetes Hardening Guidance release Kubernetes Hardening Guidance](https://www.nsa.gov/Press-Room/News-Highlights/Article/Article/2716980/nsa-cisa-release-kubernetes-hardening-guidance/)
[^crowdstrike-cryptojacking-k8s-campaign]: [CrowdStrike Discovers First-Ever Dero Cryptojacking Campaign Targeting Kubernetes](https://www.crowdstrike.com/blog/crowdstrike-discovers-first-ever-dero-cryptojacking-campaign-targeting-kubernetes/)
[^emptyDir]: [Kubernetes Documentation - emptyDir](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir)
[^network-policies]: [Kubernetes Documentation - Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
[^limit-ranges]: [Kubernetes Documentation - Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)
[^resource-quotas]: [Kubernetes Documentation - Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
[^pid-limit]: [Kubernetes Documentation - Process ID Limits And Reservations](https://kubernetes.io/docs/concepts/policy/pid-limiting/)
[^kms-encryption]: [Kubernetes Documentation - Using a KMS provider for data encryption](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/#encrypting-your-data-with-the-kms-provider)


