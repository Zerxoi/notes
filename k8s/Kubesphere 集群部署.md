# Kubesphere 集群部署

## 虚拟机快速部署

软件准备：

- [Vagrant](https://www.vagrantup.com/)
- [VMware WorkStation Pro](https://www.vmware.com/products/workstation-pro/workstation-pro-evaluation.html)

使用 Vagrant 快速创建多个虚拟机的集群环境，虽然 Vagrant 为 VirtualBox 提供了开箱即用的支持，但是个人在使用过程中的体验并不是很好，所以最终使用 VMware WorkStation Pro 来部署集群环境。

为了能够对 VMware WorkStation Pro 的支持，需要提前安装 VMware WorkStation 的 Provider 程序。安装过程参见[此处](https://www.vagrantup.com/docs/providers/vmware/installation)。

编写 Vagrantfile 用于快速创建 3 个 centos/7 镜像的服务器集群。

```
# Vagrantfile
Vagrant.configure("2") do |config|
    (1..3).each do |i|
        config.vm.define "k8s-node#{i}" do |node|
            node.vm.box = "centos/7"
            node.vm.hostname="k8s-node#{i}"
            # 设置虚拟机IP地址
            # node.vm.network "private_network", ip: "192.168.182.#{99+i}", netmask: "255.255.255.0"
        end
    end
end
```

Tips：
1. 如果想使用 VMware 其他 Linux 发行版本的镜像可以参见[此处](https://app.vagrantup.com/boxes/search?provider=vmware)。建议使用 centos/7，个人使用过 ubuntu 坑有点多遂放弃
2. 先关闭IP地址设置，之后手动更改一下我更放心。

在 Vagrantfile 文件所在目录下执行 `vagrant up` 开始创建虚拟机。

将3个虚拟机的网络设置为NAT。（默认就是NAT网络模式）

如果没有NAT网络需要在VMware中新建一个NAT网络。

我创建的NAT网络的网段为 `192.168.182.0`，宿主机的IP地址为 `192.168.182.1`（可以通过该IP在虚拟机访问宿主机），网关为 `192.168.182.2`（用于访问外部网络）。

虚拟机的账号/密码为：`vagrant/vagrant` 和 `root/vagrant`。

使用 `ip addr` 查看时候和NAT网络处于同一网段。

|服务器名|服务器IP|
|-------|--------|
|k8s-node1|192.168.182.152|
|k8s-node2|192.168.182.153|
|k8s-node3|192.168.182.154|

将

```
192.168.182.152  k8s-node1
192.168.182.153  k8s-node2
192.168.182.154  k8s-node3
```

设置静态IP地址：

```
$ sudo vim /etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE="eth0"
BOOTPROTO="static" # 静态IP
ONBOOT="yes" # 开机启动脚本
TYPE="Ethernet"
IPADDR=192.168.182.154 # ip 地址（node1：152，node2:153,node3:154)
GATEWAY=192.168.182.2 # NAT网络网关
NETMASK=255.255.255.0 # NAT网络掩码
DNS1=192.168.182.2 # DNS服务器（如果不知道可以直接填网关地址）
# 重启网络服务
$ sudo systemctl restart network
```

添加到宿主机的 `C:\Windows\System32\drivers\etc\hosts` 文件中用于域名解析。

接下来对网络进行检查：

1. `ping baidu.com` 检查是否能访问外网
    - 如果提示无法解析域名的问题，同时又是在校园网的情况可以试试连接手机热点尝试一下
    - 如果手机热点呢个够正常访问，则说明是DNS的问题，修改 `/etc/resolv.conf` 中的DNS服务器为NAT网关或者校园网DNS服务器
2. `ping 192.168.182.1` 检查是否能ping通宿主机
    - 如果 ping 不通，可以在Windows Security中关闭防火墙后重试
    - 如果能访问则说明没问题，重新开启防火墙即可，因为虚拟机基本不需要对宿主机的访问操作
3. 在宿主机中 `ping 虚拟机IP` 检查是否能够正常访问虚拟机
    - 如果 ping 不通可以关闭虚拟机防火墙后重试（应该不会发生的吧，目前还没遇到该问题）

理论上 centos/7 镜像不会出现上述问题，至少我暂时没遇见；如果使用 ubuntu 镜像的话就可能会有以上这些问题了。网络检查没有问题后即可进入下一步来准备搭建K8S集群的环境了。

## 环境准备

软件准备：Xshell，MobaXterm（最好是能够同时向多个Tab发送指令的终端软件，不然会增加工作量且容易出错）

下面的命令会涉及3个虚拟同时操作的指令，因此如果是多个虚拟机同时操作的指令我会在 $ 前标注 `(multi)`，如果实在k8s-node1节点操作则是 `(node1)`。

使用Xshell之前需要开启每个 centos 虚拟机的ssh的密码认证功能。修改 `/etc/ssh/sshd_config` 文件中的 `PasswordAuthentication no` 改为 `PasswordAuthentication yes`。修改后执行 `sudo systemctl restart sshd` 重启ssh服务。

接下来通过Xshell同时连接3个虚拟机。

再将一下内容添加到 `/etc/hosts` 文件的末尾。

```
192.168.182.152  k8s-node1
192.168.182.153  k8s-node2
192.168.182.154  k8s-node3
```

运行 

```
(multi)$ ping k8s-node1
```

看看每个虚拟机是否能正常ping通。

拿到Linux系统的第一件事我不知道你们都要干什么，反正我必要要update和upgrade一下的。那么在update和upgrade之前就需要进行换源。本文通过换源操作都是根据阿里云镜像站的文档执行的。

centos7 换源参考[此处](https://developer.aliyun.com/mirror/centos)。因为每个虚拟机都需要换源，所以要在多Tab同时执行。

```
(multi)$ sudo mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
(multi)$ sudo curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
(multi)$ sudo yum -y update
(multi)$ sudo yum -y upgrade
```

关闭防火墙

```
(multi)$ sudo systemctl stop firewalld
(multi)$ sudo systemctl disable firewalld
```

关闭 selinux

```
(multi)$ sudo sed -i 's/enforcing/disabled/' /etc/selinux/config
(multi)$ sudo setenforce 0
```

关闭 swap

```
(multi)$ sudo swapoff -a # 临时关闭
(multi)$ sudo sed -ri 's/.*swap.*/# &/' /etc/fstab # 永久关闭
(multi)$ sudo free -g # 验证 swap 必须为 0；
```

将桥接的 IPv4 流量传递到 iptables 的链：

```
(multi)$ su # 以root身份登录
(multi)$ cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
(multi)$ sysctl --system
```

接下来需要安装 docker，添加 docker 源b并安装docker命令参考[此处](https://developer.aliyun.com/mirror/docker-ce)。

```
# step 1: 安装必要的一些系统工具
(multi)$ sudo yum install -y yum-utils device-mapper-persistent-data lvm2
# Step 2: 添加软件源信息
(multi)$  sudo yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
# Step 3
(multi)$ sudo sed -i 's+download.docker.com+mirrors.aliyun.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo
# Step 4: 更新并安装Docker-CE
(multi)$ sudo yum makecache fast
(multi)$ sudo yum -y install docker-ce
# Step 4: 开启Docker服务
(multi)$ sudo systemctl enable docker
```

docker 镜像加速参考[此处](https://cr.console.aliyun.com/cn-hangzhou/instances/mirrors)。

```
(multi)$ sudo mkdir -p /etc/docker
(multi)$ sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://z7uqx9v8.mirror.aliyuncs.com"]
}
EOF
(multi)$ sudo systemctl daemon-reload
(multi)$ sudo systemctl restart docker
```

kubeadm初始化时默认采用cgroupfs作为驱动，推荐使用systemd

```
(multi)$ vim /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors": ["https://z7uqx9v8.mirror.aliyuncs.com"]
}
(multi)$ sudo systemctl daemon-reload
(multi)$ sudo systemctl restart docker
```

添加 k8s 源并安装k8s工具，参考[此处](https://developer.aliyun.com/mirror/kubernetes)。

```
(multi)$ cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
(multi)$ yum install -y --nogpgcheck kubelet-1.21.11 kubeadm-1.21.11 kubectl-1.21.11 # 安装k8s-1.21最新版本，因为kubesphere支持的最新稳定版本为1.21
(multi)$ systemctl enable kubelet && systemctl start kubelet
```

至此，环境准备工作结束。接下来是集群部署环节。

## 集群搭建

集群部署需要每个虚拟机节点大于CPU核心数大于等于2，RAM大于等于1700MB。如果有条件的话建议直接跳到4核心，4GB。需要首先先关闭虚拟机调整CPU和内存情况，再开机进行部署。

使用 kubeadmn 部署集群，参考[此处](https://kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)。


主节点部署
```
(node1)$ su # root 用户权限
# apiserver-advertise-address 为master节点地址，本文中为k8s-node1
# service-cidr和pod-network-cidr分别是service和pod的网段
(node1)$ kubeadm init --apiserver-advertise-address=192.168.182.152 --image-repository registry.cn-hangzhou.aliyuncs.com/google_containers  --service-cidr=10.96.0.0/16 --pod-network-cidr=10.244.0.0/16
```

在主节点部署完毕后根据提示在不同用户下运行

```
(node1)$ mkdir -p $HOME/.kube
(node1)$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
(node1)$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```


为集群部署pod网络，可选网络见[此处](https://kubernetes.io/docs/concepts/cluster-administration/addons/)。
安装flannel网络参考[此处](https://github.com/flannel-io/flannel#deploying-flannel-manually)。

```
(node1)$ kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

安装后通过 `kubectl get pod -A` 查看时候安装完成

完成后复制其他节点加入集群的命令，在其他节点以root身份运行

```
(node2, node3)$ kubeadm join 192.168.182.152:6443 --token gdsshk.xfxldb8fkbjzpl38 --discovery-token-ca-cert-hash sha256:70606c72afbbb1d1f34fa3835657d6ac55e5b1642ee0dfbfe9457cee8b0bf407
```

等待一会后调用 `kubectl get nodes` 查看个节点状态

```
NAME        STATUS   ROLES                  AGE     VERSION
k8s-node1   Ready    control-plane,master   11m     v1.21.11
k8s-node2   Ready    <none>                 3m56s   v1.21.11
k8s-node3   Ready    <none>                 3m38s   v1.21.11
```

如果所有节点都是Ready状态则代表集群搭建完成。

## NFS

在部署Kubesphere之前还需要安装并设置默认StorageClass。本文将安装NFS的StorageClass。

安装之前首先要搭建NFS集群。本文将master节点作为NFS服务器。

node1服务器需要执行 `sudo yum -y install rpcbind nfs-utils`，其中` nfs-utils`为nfs服务，`rpcbind`为连接nfs服务所需，而 node2和node3只需要 `sudo yum install rpcbind`，用于连接nfs服务即可。（其实centos/7已经安装好了）

在服务器上创建挂载目录

```
(node1)$ sudo mkdir /nfs
(node1)$ sudo chown nobody:nobody -R /nfs
(node1)$ sudo chmod 777 -R /nfs
```

配置nfs服务，在 `/etc/exports` 中加入

```
/nfs *(rw,sync,no_subtree_check,no_root_squash)
```
调用 `sudo exportfs -arv` 立即生效。

开机启动nfs服务

```
sudo systemctl enable nfs 
sudo systemctl start nfs
```

测试nfs

```
(node2)$ mkdir nfs-test
(node2)$ mount -t nfs k8s-node1:/nfs nfs-test
(node2)$ echo "123" > nfs-test/abc
(node1)$ cat /nfs/abc # 输出123则表示成功
(node2)$ rm nfs-test/abc
(node2)$ umount nfs-test
(node2)$ rm -rf nfs-test
```

如果测试成功，接下来需要安装和配置k8s的StorageClass，参考[kubernetes-sigs/nfs-subdir-external-provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)和[Kubernetes使用NFS作为存储](https://zahui.fan/posts/179eb842/)。

我们只需要对`nfs-subdir-external-provisioner/deploy/`中的`class.yaml`、`deployment.yaml`和`rabc.yaml`注意修改并应用。

首先需要创建一个 storage-class 命名空间。

```yaml
# class.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-client
  annotations:
    storageclass.kubernetes.io/is-default-class: "true" # 将 nfs-client 设置为默认 StorageClass
provisioner: zerxoi/nfs # 需要和 Deployment 的环境变量 PROVISIONER_NAME 相同
parameters:
  archiveOnDelete: "false"
```

```yaml
# deployment.yaml
# 创建一个命名空间 storage-class
apiVersion: v1
kind: Namespace
metadata:
  name: storage-class
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  labels:
    app: nfs-client-provisioner
  # 名称空间为 storage-class, 要和 rbac 的名称空间保持一致
  namespace: storage-class
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          # 将镜像换为国内镜像
          image: registry.cn-hangzhou.aliyuncs.com/iuxt/nfs-subdir-external-provisioner:v4.0.2
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              # 和 StorageClass 的 provisioner 一致
              value: zerxoi/nfs
            - name: NFS_SERVER
              # nfs 服务器地址
              value: k8s-node1
            - name: NFS_PATH
              # nfs 服务路径
              value: /nfs
      volumes:
        - name: nfs-client-root
          nfs:
            # nfs 服务器地址
            server: k8s-node1
            # nfs 服务路径
            path: /nfs
```

```yaml
# rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
    # 名称空间为 storage-class, 要和 deployment 的名称空间保持一致
  namespace: storage-class
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    # 名称空间为 storage-class, 要和 deployment 的名称空间保持一致
    namespace: storage-class
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
    # 名称空间为 storage-class, 要和 deployment 的名称空间保持一致
  namespace: storage-class
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
    # 名称空间为 storage-class, 要和 deployment 的名称空间保持一致
  namespace: storage-class
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    # 名称空间为 storage-class, 要和 deployment 的名称空间保持一致
    namespace: storage-class
roleRef:
  kind: Role
  name: leader-locking-nfs-client-provisioner
  apiGroup: rbac.authorization.k8s.io
```

在部署好之后，执行 kubectl get sc 查看创建的 StorageClass，如果存则执行 `kubectl apply -f test-claim.yaml` 进行测试。

```yaml
# test-claim.yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: test-claim
spec:
  storageClassName: nfs-client
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Mi
```

执行后，调用 `kubectl get pvc` 查看创建的持久卷请求情况，如果状态为 Bound 说明创建成功。再调用 `kubectl delete pvc test-claim` 删除即可。

## Kubesphere 安装

如果执行完上述步骤已经满足了[Kubesphere的安装要求](https://kubesphere.io/zh/docs/installing-on-kubernetes/introduction/prerequisites/)了，接下来就是[在K8s上安装Kubesphere](https://kubesphere.io/zh/docs/quick-start/minimal-kubesphere-on-k8s/)。

直接执行命令：

```
(node1)$ kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.2.1/kubesphere-installer.yaml
(node1)$ kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.2.1/cluster-configuration.yaml
```

Tips: 

如果有代理的话可以使用以下命令设置代理（需要注意的是，如果宿主机有防火墙的话，需要关掉）

```sh
export http_proxy=http://198.168.182.1:7890
export https_proxy=http://198.168.182.1:7890
```

执行一下命令查看安装日志：

```
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-install -o jsonpath='{.items[0].metadata.name}') -f
```

安装接收后通过 `kubectl get all -A` 查看所有资源是否部署完成，完成后即可访问 `http://k8s-node1:30880`。登陆账号/密码为 `admin` 和 `P@88w0rd`。

在部署成功之后，可以根据需要[启用可插拔的组件](https://kubesphere.io/zh/docs/pluggable-components/)，例如[DevOps功能](https://kubesphere.io/zh/docs/pluggable-components/devops/)。

Tips: DevOps 对内存的要求会稍微高一点，似乎达到了 4G，如果出现问题很有可能是因为分配的内存不足导致的。

建议按照一下顺序学习 Kubesphere：
- [创建企业空间、项目、用户和平台角色](https://kubesphere.io/zh/docs/quick-start/create-workspace-and-project/) 
- [创建并部署 WordPress](https://kubesphere.io/zh/docs/quick-start/wordpress-deployment/)
- [将 SonarQube 集成到流水线](https://kubesphere.io/zh/docs/devops-user-guide/how-to-integrate/sonarqube/) 
- [使用 Jenkinsfile 创建流水线](https://kubesphere.io/zh/docs/devops-user-guide/how-to-use/create-a-pipeline-using-jenkinsfile/)
- [凭证管理](https://kubesphere.io/zh/docs/devops-user-guide/how-to-use/credential-management/)
- [构建和部署 Maven 项目](https://kubesphere.io/zh/docs/devops-user-guide/examples/a-maven-project/)