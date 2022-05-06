# 初识 Kafka

## 安装与配置

本文将通过 Docker 快速搭建一个可用的 Kafka 集群服务。

### ZooKeeper 安装与配置

ZooKeeper 是安装 Kafka 集群的**必要组件**，Kafka 通过 ZooKeeper 来实施**对元数据信息的管理**，包括集群、broker、主题、分区等内容。

ZooKeeper 是一个开源的分布式协调服务。分布式应用程序可以基于 ZooKeeper 实现诸如**数据发布/订阅**、**负载均衡**、**命名服务**、**分布式协调/通知**、**集群管理**、**Master 选举**、**配置维护**等功能。在 ZooKeeper 中共有 3 个角色： `leader` 、 `follower` 和 `observer` ，同一时刻 ZooKeeper 集群中只会有一个 `leader` ，其他的都是 `follower` 和 `observer`。`observer` 不参与投票，默认情况下 ZooKeeper 中只有 `leader` 和 `follower` 两个角色。更多相关知识可以查阅 ZooKeeper 官方网站来获得。

本文通过 `docker-compose` 命令使用 [Zookeeper 官方镜像](https://hub.docker.com/_/zookeeper) 来搭建一个 ZooKeeper 集群。

集群中一共有三个服务 `zoo1` 、 `zoo2` 和 `zoo3`。

ZooKeeper 的默认配置文件位于容器的 `/conf/zoo.cfg` 位置，可以通过 `docker exec  -it <zookeeper-container-id> bash` 命令进入到 ZooKeeper 容器内部查看文件。其中 Zookeeper 官方镜像默认将**内存数据库快照**和**数据库更新的事务日志**分别配置在 `/data` 和 `/datalog` 目录中。本文并没有将配置文件挂载至本地磁盘中，而是通过 ZooKeeper 官方镜像提供的环境变量对容器进行配置，官方镜像提供的环境变量参考 [文档](https://hub.docker.com/_/zookeeper)。

为了搭建 ZooKeeper 集群需要每个 ZooKeeper 服务相互可见。环境变量 `ZOO_MY_ID` 和 `ZOO_SERVERS` 用于做相关配置。

* `ZOO_MY_ID` 代表服务的编号，在集群中必须是唯一的且应该介于 `1` 至 `255` 之间。
  * 配置完成后将在 `${dataDir}` 目录下创建一个 `myid` 文件并将 `ZOO_MY_ID` 值进行写入；如果 `${dataDir}` 目录已经包含 `myid` 文件则此变量不会产生任何影响。
* `ZOO_SERVERS` 用于指定 Zookeeper 集群的机器列表。
  * 每个服务的条目格式为 `server.<id>=<address>:<port1>:<port2>;[<client port address>:]<client port>`。条目用空格分隔。
    * `<id>` ：服务的编号，保证服务条目编号和 `ZOO_MY_ID` (即 `myid` 文件值)保持一致
    * `<address>` ：服务地址
    * `<port1>` ：服务与集群中的 `leader` 服务交换信息的端口(默认：`2888` )
    * `<port2>` ：集群选举是互相通信的端口(默认：`3888` )
    * `<client port>` ：客户端连接 ZooKeeper 服务的端口
    * ...
  * 如果 `/conf/zoo.cfg` 文件在启动容器被挂载，则此变量不会产生任何影响。

```yml
version: '3.1'

services:
  zoo1:
    image: zookeeper
    restart: always
    hostname: zoo1
    ports:
      - 2181:2181
    volumes:
      - $PWD/docker/zookeeper/1/data:/data
      - $PWD/docker/zookeeper/1/log:/datalog
    environment:
      ZOO_MY_ID: 1
      ZOO_SERVERS: server.1=zoo1:2888:3888;2181 server.2=zoo2:2888:3888;2181 server.3=zoo3:2888:3888;2181

  zoo2:
    image: zookeeper
    restart: always
    hostname: zoo2
    ports:
      - 2182:2181
    volumes:
      - $PWD/docker/zookeeper/2/data:/data
      - $PWD/docker/zookeeper/2/log:/datalog
    environment:
      ZOO_MY_ID: 2
      ZOO_SERVERS: server.1=zoo1:2888:3888;2181 server.2=zoo2:2888:3888;2181 server.3=zoo3:2888:3888;2181

  zoo3:
    image: zookeeper
    restart: always
    hostname: zoo3
    ports:
      - 2183:2181
    volumes:
      - $PWD/docker/zookeeper/3/data:/data
      - $PWD/docker/zookeeper/3/log:/datalog
    environment:
      ZOO_MY_ID: 3
      ZOO_SERVERS: server.1=zoo1:2888:3888;2181 server.2=zoo2:2888:3888;2181 server.3=zoo3:2888:3888;2181
```

注： `docker-compose` 文件中的 `ZOO_SERVERS` 的服务地址都是 `zoo1` 、 `zoo2` 和 `zoo3` ，因为这三个服务都是在同一个 `docker-compose` 项目中，同一项目中的服务可以通过服务名对其他服务进行访问，换句话说 `docker-compose` 中的所有服务位于同一 Docker 网络中。

### Kafka 的安装与配置

本小节将使用 Docker 进行搭建 Kafka 集群，但是遗憾的是 Kafka 目前为止并没有提供官方的 Docker 镜像，但庆幸的是有 [bitnami/kafka](https://hub.docker.com/r/bitnami/kafka/) 镜像。

Kafka 集群的搭建是建立在 ZooKeeper 集群搭建完成的基础上的。所以 `docker-compose` 文件中的每个 Kafka 服务都依赖于( `depends_on` )ZooKeeper 集群中所有容器( `zoo1` 、 `zoo2` 和 `zoo3` )创建完成之后再进行创建。

Kafka 容器的配置文件位于 `/opt/bitnami/kafka/config` 目录下，但是并不推荐对该目录进行挂载，建议通过环境变量对 Kafka 容器进行配置。在默认的 `server.properties` 文件中可以看到 `log.dirs=/bitnami/kafka/data` 配置，说明 Kafka 容器默认将日志数据文件存储在 `/bitnami/kafka/data` 目录下，可以通过对该目录进行挂载实现数据持久化。

对于 Kafka 容器的环境变量参考 [文档](https://hub.docker.com/r/bitnami/kafka/)。本小节将简单对使用到的环境变量进行简单的介绍：

* `KAFKA_BROKER_ID` 是 Kafka 集群中 broker 的编号，每个 broker 的编号在集群中唯一。
  * 对应 `server.properties` 文件中的 `broker.id` 属性。
* `KAFKA_CFG_ZOOKEEPER_CONNECT` 是 Kafka 服务连接 ZooKeeper 服务的地址列表，每个地址使用逗号进行分割。
  * 因为 Kafka 集群和 ZooKeeper 在同一个 Docker 网络中(同一 `docker-compose` 项目中)，所以可以通过服务名直接进行访问。
  * 对应 `server.properties` 文件中的 `zookeeper.connect` 属性。
* `KAFKA_CFG_LISTENERS` 是一个逗号分隔的侦听器列表，Kafka 会绑定到的 `<hostname-or-ip>:<port>` 以进行侦听。
  * `<hostname-or-ip>` 默认值为 `0.0.0.0` ，表示监听所有接口。
  * 如果侦听器名称不是安全协议，还必须设置 `listener.security.protocol.map` 。
  * 对应 `server.properties` 文件中的 `listeners` 属性。
* `KAFKA_ADVERTISED_LISTENERS` 表示要发布到 ZooKeeper 以供客户端连接 broker 的元数据。
  * 客户端运行时，传递给客户端的侦听器地址只是为了获取用于连接集群中 broker 的元信息。侦听器在监听到客户端请求后会将 `KAFKA_CFG_ADVERTISED_LISTENERS` 元数据返回，客户端根据返回的元数据中的侦听器列表与集群中的 broker 建立连接。
  * `KAFKA_CFG_ADVERTISED_LISTENERS` 也是一个逗号分隔的侦听器列表，每个侦听器的格式和 `KAFKA_CFG_ADVERTISED_LISTENERS` 的 `<hostname-or-ip>:<port>` 格式一样。区别是该列表传递回客户端的元数据， `<hostname-or-ip>` 为 `0.0.0.0` 是无效的。
* `KAFKA_LISTENER_SECURITY_PROTOCOL_MAP` 为每个侦听器名称定义要使用的安全协议的键/值对。
  * 对应 `server.properties` 文件中的 `listener.security.protocol.map` 属性。

```yml
version: '3.1'

services:
  zoo1:
    image: zookeeper
    restart: always
    hostname: zoo1
    ports:
      - 2181:2181
    volumes:
      - $PWD/docker/zookeeper/1/data:/data
      - $PWD/docker/zookeeper/1/log:/datalog
    environment:
      ZOO_MY_ID: 1
      ZOO_SERVERS: server.1=zoo1:2888:3888;2181 server.2=zoo2:2888:3888;2181 server.3=zoo3:2888:3888;2181

  zoo2:
    image: zookeeper
    restart: always
    hostname: zoo2
    ports:
      - 2182:2181
    volumes:
      - $PWD/docker/zookeeper/2/data:/data
      - $PWD/docker/zookeeper/2/log:/datalog
    environment:
      ZOO_MY_ID: 2
      ZOO_SERVERS: server.1=zoo1:2888:3888;2181 server.2=zoo2:2888:3888;2181 server.3=zoo3:2888:3888;2181

  zoo3:
    image: zookeeper
    restart: always
    hostname: zoo3
    ports:
      - 2183:2181
    volumes:
      - $PWD/docker/zookeeper/3/data:/data
      - $PWD/docker/zookeeper/3/log:/datalog
    environment:
      ZOO_MY_ID: 3
      ZOO_SERVERS: server.1=zoo1:2888:3888;2181 server.2=zoo2:2888:3888;2181 server.3=zoo3:2888:3888;2181

  kafka1:
    image: bitnami/kafka
    ports:
      - 29092:29092
    volumes:
      - $PWD/docker/kafka/1/data:/bitnami/kafka/data
    environment:
      - KAFKA_BROKER_ID=1
      - KAFKA_CFG_ZOOKEEPER_CONNECT=zoo1:2181,zoo2:2181,zoo3:2181
      - ALLOW_PLAINTEXT_LISTENER=yes
      - KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=INNER:PLAINTEXT,EXTERNAL:PLAINTEXT
      - KAFKA_CFG_LISTENERS=INNER://0.0.0.0:9092,EXTERNAL://0.0.0.0:29092
      - KAFKA_CFG_ADVERTISED_LISTENERS=INNER://kafka1:9092,EXTERNAL://localhost:29092
      - KAFKA_CFG_INTER_BROKER_LISTENER_NAME=INNER
    depends_on:
      - zoo1
      - zoo2
      - zoo3

  kafka2:
    image: bitnami/kafka
    ports:
      - 29093:29092
    volumes:
      - $PWD/docker/kafka/2/data:/bitnami/kafka/data
    environment:
      - KAFKA_BROKER_ID=2
      - KAFKA_CFG_ZOOKEEPER_CONNECT=zoo1:2181,zoo2:2181,zoo3:2181
      - ALLOW_PLAINTEXT_LISTENER=yes
      - KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=INNER:PLAINTEXT,EXTERNAL:PLAINTEXT
      - KAFKA_CFG_LISTENERS=INNER://0.0.0.0:9092,EXTERNAL://0.0.0.0:29092
      - KAFKA_CFG_ADVERTISED_LISTENERS=INNER://kafka2:9092,EXTERNAL://localhost:29093
      - KAFKA_CFG_INTER_BROKER_LISTENER_NAME=INNER
    depends_on:
      - zoo1
      - zoo2
      - zoo3

  kafka3:
    image: bitnami/kafka
    ports:
      - 29094:29092
    volumes:
      - $PWD/docker/kafka/3/data:/bitnami/kafka/data
    environment:
      - KAFKA_BROKER_ID=3
      - KAFKA_CFG_ZOOKEEPER_CONNECT=zoo1:2181,zoo2:2181,zoo3:2181
      - ALLOW_PLAINTEXT_LISTENER=yes
      - KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=INNER:PLAINTEXT,EXTERNAL:PLAINTEXT
      - KAFKA_CFG_LISTENERS=INNER://0.0.0.0:9092,EXTERNAL://0.0.0.0:29092
      - KAFKA_CFG_ADVERTISED_LISTENERS=INNER://kafka3:9092,EXTERNAL://localhost:29094
      - KAFKA_CFG_INTER_BROKER_LISTENER_NAME=INNER
    depends_on:
      - zoo1
      - zoo2
      - zoo3
```

在 Docker 中运行，您需要为 Kafka 配置两个监听器：

1. Docker 网络内的通信。包括 broker 之间的通信，以及在 Docker 中运行的其他组件或第三方客户端或生产者之间的通信。对于这些通信，我们需要使用 Docker 容器的主机名。同一 Docker 网络上的每个 Docker 容器都将使用 Kafka broker 容器的主机名来访问它。
2. 非 Docker 网络流量。客户端运行在 Docker 的宿主机上，客户端通过 `localhost` 连接到从 Docker 容器公开的端口。

以 `kafka2` 服务的 `docker-compose` 片段进行讲解：

* Docker 网络中的客户端使用侦听器 `INNER` 连接，`INNER` 侦听器会监听容器所有网卡接口的 `9092` 端口。Docker 网络中的客户端在访问侦听器时会返回建立连接的元数据`kafka2:9092`，客户端使用 Docker 网络的域名解析与 `kafka2` 的监听器建立连接。
* Docker 网络外部的客户端使用监听器 `EXTERNAL` 连接，`EXTERNAL` 侦听器会监听容器所有网卡接口的 `29092` 端口。当宿主机的客户端访问侦听器时会返回建立连接的元数据 `localhost:29093` ，客户端根据元数据与暴露在宿主机 `29093` 端口的外部网络侦听器建立连接。

有关 Kafka 侦听器的更多信息参考 [Kafka Listeners - Explained](https://rmoff.net/2018/08/02/kafka-listeners-explained/)。
