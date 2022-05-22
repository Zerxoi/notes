# 初识 Kafka

Kafka 起初是由 LinkedIn 公司采用 Scala 语言开发的一个*多分区**、*多副本*且基于 ZooKeeper 协调的**分布式消息系统**，现已被捐献给 Apache 基金会。

目前 Kafka 已经定位为一个**分布式流式处理平台**，它以*高吞吐*、*可持久化*、*可水平扩展*、*支持流数据处理*等多种特性而被广泛使用。

Kafka 之所以受到越来越多的青睐，与它所“扮演”的三大角色是分不开的：

- **消息系统**：Kafka 和**传统的消息系统**（也称作**消息中间件**）都具备系统*解耦*、*冗余存储*、*流量削峰*、*缓冲*、*异步通信*、*扩展性*、*可恢复性*等功能。与此同时，Kafka 还提供了大多数消息系统难以实现的*消息顺序性保障*及*回溯消费*的功能。
- **存储系统**：Kafka 把消息持久化到磁盘，相比于其他基于内存存储的系统而言，有效地降低了数据丢失的风险。也正是得益于 Kafka 的**消息持久化功能**和**多副本机制**，我们可以把 Kafka 作为长期的数据存储系统来使用，只需要把对应的数据保留策略设置为“永久”或启用主题的日志压缩功能即可。
- **流式处理平台**：Kafka 不仅为每个流行的流式处理框架提供了可靠的**数据来源**，还提供了一个完整的**流式处理类库**，比如窗口、连接、变换和聚合等各类操作。

## 基本概念

- ZooKeeper：负责 Kafka 集群元数据的管理、控制器的选举等操作的；
- Producer：生产者，也就是发送消息的一方。生产者负责创建消息，然后将其投递 Kafka 中；
- Consumer：消费者，也就是接收消息的一方。消费者连接到Kafka 上并接收消息，进而进行相应的业务逻辑处理。
  - **容灾能力**：Consumer 使用拉（Pull）模式从服务端拉取消息，并且保存消费的具体位置，当消费者宕机后恢复上线时可以根据之前保存的消费位置重新拉取需要的消息进行消费，这样就不会造成消息丢失。
- Broker：服务代理节点。负责将收到的消息存储到磁盘中；
  - Topic：主题是一个**逻辑上的概念**，Kafka 中的消息以主题为单位进行归类，生产者负责将消息发送到特定的主题（发送到Kafka 集群中的每一条消息都要指定一个主题），而消费者负责订阅主题并进行消费。
  - Partition：分区可以看作对消息的二次归类，也是一个逻辑上的概念
    - 主题可以细分为多个分区，一个分区只属于单个主题，很多时候也会把分区称为**主题分区（Topic-Partition）**。
    - 分区实现了对主题的**可伸缩性**和**水平拓展的功能**，解决了主题单文件I/O的性能瓶颈
    - **跨broker**：Kafka中的分区可以分布在不同的服务器（broker）上，也就是说，一个主题可以横跨多个 broker，以此来提供比单个 broker 更强大的性能。
    - offset：消息在被追加到分区日志文件的时候都会分配一个特定的**偏移量（offset）**。
      - offset 是消息在分区中的唯一标识，Kafka 通过它来保证消息在分区内的顺序性，不过offset 并不跨越分区，也就是说，Kafka 保证的是**分区有序**而不是主题有序。
      - 分类：
        - LSO（Log Start Offset）：LSO标识当前日志文件中第一条消息的 offset
        - LEO（Log End Offset ）：LEO 标识当前日志文件中下一条待写入消息的 offset
        - HW（High Watermark）：HW，俗称高水位，它标识了一个特定的消息偏移量（offset），消费者只能拉取到这个 offset 之前的消息。
          - **min(LEO)**：分区 ISR 集合中的每个副本都会维护自身的 LEO，而 ISR 集合中最小的 LEO即为分区的 HW，对消费者而言只能消费 HW 之前的消息。
    - Replica：Kafka 为分区引入了多副本（Replica）机制，通过增加副本数量可以提升**容灾能力**。同一分区的不同副本中保存的是相同的消息（在同一时刻，副本之间并非完全一样），副本之间是“一主多从”的关系，分区的每个副本可以将其看作一个**可追加的日志（Log）文件**
      - 副本角色
        - **leader 副本**
          - **负责处理读写请求**
          - **负责维护和跟踪 ISR 集合**：leader 副本负责维护和跟踪 ISR 集合中所有 follower 副本的滞后状态，当 follower 副本落后太多或失效时，leader 副本会把它从 ISR 集合中剔除。如果 OSR 集合中有 follower 副本“追上”了 leader 副本，那么 leader 副本会把它从 OSR 集合转移至 ISR 集合。
        - **follower 副本**只负责与 leader 副本的消息同步
      - 副本同步状态集合
        - **AR**：分区中的所有副本统称为 AR（Assigned Replicas）
        - **ISR**：所有与 leader 副本保持一定程度同步的副本（包括 leader 副本在内）组成 ISR（In-Sync Replicas），ISR 集合是 AR 集合中的个子集。
        - **OSR**：与 leader 副本同步滞后过多的副本（不包括 leader 副本）组成 OSR（Out-of-Sync Replicas）
      - **同步滞后性**：消息会先发送到 leader 副本，然后 follower 副本才能从 leader 副本中拉取消息进行同步，同步期间内 follower 副本相对于 leader 副本而言会有一定程度的滞后。
      - **容灾能力**：副本处于不同的 broker 中，当 leader 副本出现故障时，从 follower 副本中重新选举新的 leader 副本对外提供服务。Kafka 通过多副本机制实现了故障的自动转移，当 Kafka 集群中某个 broker 失效时仍然能保证服务可用。
        - 默认情况下，当 leader 副本发生故障时，**只有在 ISR 集合中的副本才有资格被选举为新的 leader**，而在 OSR 集合中的副本则没有任何机会（不过这个原则也可以通过修改相应的参数配置来改变）。

### 主题与分区

在 Kafka 中还有两个特别重要的概念——**主题（Topic）**与**分区（Partition）**。

Kafka 中的消息以主题为单位进行归类，生产者负责将消息发送到特定的主题（发送到Kafka 集群中的每一条消息都要指定一个主题），而消费者负责订阅主题并进行消费。

主题是一个逻辑上的概念，它还可以细分为多个分区，一个分区只属于单个主题，很多时候也会把分区称为**主题分区（Topic-Partition）**。同一主题下的不同分区包含的消息是不同的，分区在存储层面可以看作一个**可追加的日志（Log）文件**，消息在被追加到分区日志文件的时候都会分配一个特定的**偏移量（offset）**。offset 是消息在分区中的唯一标识，Kafka 通过它来保证消息在分区内的顺序性，不过offset 并不跨越分区，也就是说，Kafka 保证的是分区有序而不是主题有序。

## 安装与配置

本文将通过 Docker 快速搭建一个可用的 Kafka 集群服务。

### ZooKeeper 安装与配置

ZooKeeper 是安装 Kafka 集群的**必要组件**，Kafka 通过 ZooKeeper 来实施**对元数据信息的管理**，包括集群、broker、主题、分区等内容。

ZooKeeper 是一个开源的分布式协调服务。分布式应用程序可以基于 ZooKeeper 实现诸如**数据发布/订阅**、**负载均衡**、**命名服务**、**分布式协调/通知**、**集群管理**、**Master 选举**、**配置维护**等功能。在 ZooKeeper 中共有 3 个角色： `leader` 、 `follower` 和 `observer` ，同一时刻 ZooKeeper 集群中只会有一个 `leader` ，其他的都是 `follower` 和 `observer`。`observer` 不参与投票，默认情况下 ZooKeeper 中只有 `leader` 和 `follower` 两个角色。更多相关知识可以查阅 ZooKeeper 官方网站来获得。

本文通过 `docker-compose` 命令使用 [Zookeeper 官方镜像](https://hub.docker.com/_/zookeeper) 来搭建一个 ZooKeeper 集群。

集群中一共有三个服务 `zoo1` 、 `zoo2` 和 `zoo3`。

ZooKeeper 的默认配置文件位于容器的 `/conf/zoo.cfg` 位置，可以通过 `docker exec  -it <zookeeper-container-id> bash` 命令进入到 ZooKeeper 容器内部查看文件。其中 Zookeeper 官方镜像默认将**内存数据库快照**和**数据库更新的事务日志**分别配置在 `/data` 和 `/datalog` 目录中。本文并没有将配置文件挂载至本地磁盘中，而是通过 ZooKeeper 官方镜像提供的环境变量对容器进行配置，官方镜像提供的环境变量参考 [文档](https://hub.docker.com/_/zookeeper)。

为了搭建 ZooKeeper 集群需要每个 ZooKeeper 服务相互可见。环境变量 `ZOO_MY_ID` 和 `ZOO_SERVERS` 用于做相关配置。

- `ZOO_MY_ID` 代表服务的编号，在集群中必须是唯一的且应该介于 `1` 至 `255` 之间。
  - 配置完成后将在 `${dataDir}` 目录下创建一个 `myid` 文件并将 `ZOO_MY_ID` 值进行写入；如果 `${dataDir}` 目录已经包含 `myid` 文件则此变量不会产生任何影响。
- `ZOO_SERVERS` 用于指定 Zookeeper 集群的机器列表。
  - 每个服务的条目格式为 `server.<id>=<address>:<port1>:<port2>;[<client port address>:]<client port>`。条目用空格分隔。
    - `<id>` ：服务的编号，保证服务条目编号和 `ZOO_MY_ID` (即 `myid` 文件值)保持一致
    - `<address>` ：服务地址
    - `<port1>` ：服务与集群中的 `leader` 服务交换信息的端口(默认：`2888` )
    - `<port2>` ：集群选举是互相通信的端口(默认：`3888` )
    - `<client port>` ：客户端连接 ZooKeeper 服务的端口
    - ...
  - 如果 `/conf/zoo.cfg` 文件在启动容器被挂载，则此变量不会产生任何影响。

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

- `KAFKA_BROKER_ID` 是 Kafka 集群中 broker 的编号，每个 broker 的编号在集群中唯一。
  - 对应 `server.properties` 文件中的 `broker.id` 属性。
- `KAFKA_CFG_ZOOKEEPER_CONNECT` 是 Kafka 服务连接 ZooKeeper 服务的地址列表，每个地址使用逗号进行分割。
  - 因为 Kafka 集群和 ZooKeeper 在同一个 Docker 网络中(同一 `docker-compose` 项目中)，所以可以通过服务名直接进行访问。
  - 对应 `server.properties` 文件中的 `zookeeper.connect` 属性。
- `KAFKA_CFG_LISTENERS` 是一个逗号分隔的侦听器列表，Kafka 会绑定到的 `<hostname-or-ip>:<port>` 以进行侦听。
  - `<hostname-or-ip>` 默认值为 `0.0.0.0` ，表示监听所有接口。
  - 如果侦听器名称不是安全协议，还必须设置 `listener.security.protocol.map` 。
  - 对应 `server.properties` 文件中的 `listeners` 属性。
- `KAFKA_ADVERTISED_LISTENERS` 表示要发布到 ZooKeeper 以供客户端连接 broker 的元数据。
  - 客户端运行时，传递给客户端的侦听器地址只是为了获取用于连接集群中 broker 的元信息。侦听器在监听到客户端请求后会将 `KAFKA_CFG_ADVERTISED_LISTENERS` 元数据返回，客户端根据返回的元数据中的侦听器列表与集群中的 broker 建立连接。
  - `KAFKA_CFG_ADVERTISED_LISTENERS` 也是一个逗号分隔的侦听器列表，每个侦听器的格式和 `KAFKA_CFG_ADVERTISED_LISTENERS` 的 `<hostname-or-ip>:<port>` 格式一样。区别是该列表传递回客户端的元数据， `<hostname-or-ip>` 为 `0.0.0.0` 是无效的。
- `KAFKA_LISTENER_SECURITY_PROTOCOL_MAP` 为每个侦听器名称定义要使用的安全协议的键/值对。
  - 对应 `server.properties` 文件中的 `listener.security.protocol.map` 属性。

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
      - KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE=false
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
      - KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE=false
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
      - KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE=false
    depends_on:
      - zoo1
      - zoo2
      - zoo3
```

在 Docker 中运行，您需要为 Kafka 配置两个监听器：

1. Docker 网络内的通信。包括 broker 之间的通信，以及在 Docker 中运行的其他组件或第三方客户端或生产者之间的通信。对于这些通信，我们需要使用 Docker 容器的主机名。同一 Docker 网络上的每个 Docker 容器都将使用 Kafka broker 容器的主机名来访问它。
2. 非 Docker 网络流量。客户端运行在 Docker 的宿主机上，客户端通过 `localhost` 连接到从 Docker 容器公开的端口。

以 `kafka2` 服务的 `docker-compose` 片段进行讲解：

- Docker 网络中的客户端使用侦听器 `INNER` 连接，`INNER` 侦听器会监听容器所有网卡接口的 `9092` 端口。Docker 网络中的客户端在访问侦听器时会返回建立连接的元数据`kafka2:9092`，客户端使用 Docker 网络的域名解析与 `kafka2` 的监听器建立连接。
- Docker 网络外部的客户端使用监听器 `EXTERNAL` 连接，`EXTERNAL` 侦听器会监听容器所有网卡接口的 `29092` 端口。当宿主机的客户端访问侦听器时会返回建立连接的元数据 `localhost:29093` ，客户端根据元数据与暴露在宿主机 `29093` 端口的外部网络侦听器建立连接。

有关 Kafka 侦听器的更多信息参考 [Kafka Listeners - Explained](https://rmoff.net/2018/08/02/kafka-listeners-explained/)。

`KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE` 用于设置服务端参数 `auto.create.topics.enable`，该参数用于控制当生产者向一个尚未创建的主题发送消息时，是否会自动创建一个该主题。

### 生产与消费

Kafka提供了许多使用的脚本工具，存放在 `$KAFKA_HOME` 的 `bin` 目录下（对应容器中的 `/opt/bitnami/kafka/bin` 目录）。

其中与主题有关的就是 `kafka-topics.sh` 脚本，下面将演示如果通过该脚本 `--create` 选项创建一个分区数为 `4`、副本因子为 `2` 的主题 `topic-create`。

```sh
kafka-topics.sh --bootstrap-server kafka1:9092  --create --topic topic-create --partitions 4 --replication-factor 2
```

还可以通过 `--describe` 选项查看主题 `topic-create` 的详细信息。

```sh
kafka-topics.sh --bootstrap-server kafka1:9092 --describe --topic topic-create
```

通过 `kafka-console-consumer.sh` 脚本来消费消息。

```sh
kafka-console-consumer.sh --bootstrap-server kafka1:9092 --topic topic-create
```

通过 `kafka-console-producer.sh` 脚本来发送消息。

```sh
$ kafka-console-producer.sh --bootstrap-server kafka1:9092 --topic topic-create
> Hello, Kafka!
```

在发送 `Hello, Kafka!` 字符串后，消费者会接收到该字符串。

在使用完主题 `topic-create` 后通过 `kafka-topics.sh` 脚本的 `--delete` 选项完成主题的删除操作。

```sh
kafka-topics.sh --bootstrap-server kafka1:9092  --delete --topic topic-create
```
