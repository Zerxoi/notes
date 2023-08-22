# K3D

## K3D 换源

K3S 内部使用 containerd 作为容器引擎。containerd 目前没有直接配置镜像加速的功能，但 containerd 中可以修改 `docker.io` 对应的 `endpoint`，所以可以通过修改 `endpoint` 来实现镜像加速下载。

```shell
# 本地创建加速器配置
cat > registries.yaml << EOF
mirrors:
  docker.io:
    endpoint:
    - https://dockerhub.azk8s.cn
    - https://z7uqx9v8.mirror.aliyuncs.com
EOF

# K3D 使用本地加速器配置
k3d cluster create --api-port 6550 -p "8081:80@loadbalancer" --agents 2 --registry-config registries.yaml
```

## K3S Ingress 原理

参考：

1. [Rancher - Service Load Balancer](https://docs.rancher.cn/docs/k3s/networking/_index/#service-load-balancer)
2. [K3s Load Balancer（Rancher LB）](https://blog.51cto.com/u_1472521/5214568)
3. [K3s Features in k3d](https://k3d.io/v5.4.4/usage/k3s/)

原理图

![原理图](imgs/K3S%20Load%20Balancer.drawio.png)

## K3D 安装 Istio

不安装 K3D 自带的 Traefik Ingress。

```shell
k3d cluster create --api-port 6550 -p "9080:80@loadbalancer" -p "9443:443@loadbalancer" --agents 2 --k3s-arg '--disable=traefik@server:0' cluster-istio
```

安装 Istio

```shell
istioctl install --set profile=demo -y
```