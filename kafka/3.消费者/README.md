# 消费者

## 消费者与消费组

**消费者（Consumer）**负责订阅 Kafka 中的主题（Topic），并且从订阅的主题上拉取消息。

在 Kafka 的消费理念中还有一层**消费组（Consumer Group）**的逻辑概念，一个消费组中可以包含多个消费者，每个消费者都只有一个对应消费组。消费者是实际的应用实例，可以是一个**线程**，也可以是一个**进程**。

主题中的一个分区会分配给每个**消费组**中订阅该**主题**的一个消费者。每个消费者只能消费所分配到的分区中的消息。每一个消费组都会有一个固定的名称，消费者在进行消费前需要指定其所属消费组的名称，这个可以通过消费者客户端参数 `group.id` 来配置，默认值为空字符串。

同一个消费组内的消费者既可以部署在同一台机器上，也可以部署在不同的机器上。

### 分区分配

![消费者与消费组](imgs/%E6%B6%88%E8%B4%B9%E8%80%85%E4%B8%8E%E6%B6%88%E8%B4%B9%E7%BB%84.drawio.png)

一个消费组中的消费者还可以订阅不同的主题，主题的分区分配后的结果如下：

![消费组多订阅](imgs/%E6%B6%88%E8%B4%B9%E7%BB%84%E5%A4%9A%E8%AE%A2%E9%98%85.drawio.png)

当消费组中订阅主题的消费者增加或减少的时候，会导致主题分区的所属权从消费组中订阅主题的一个消费者转移至消费组中的另一个订阅主题的消费者 —— **再均衡**。再均衡为消费组高可用性和伸缩性提供保障，开发者可以增加（或减少）消费者的个数来提高（或降低）整体的消费能力。如果消费者过多，出现了消费者的个数大于分区个数的情况，就会有消费者分配不到任何分区。

![消费组内有过多的消费者](imgs/%E6%B6%88%E8%B4%B9%E7%BB%84%E5%86%85%E6%9C%89%E8%BF%87%E5%A4%9A%E6%B6%88%E8%B4%B9%E8%80%85.jpg)

开发者可以通过消费者客户端参数 `partition.assignment.strategy` 来设置消费者与订阅主题之间的分区分配策略。

### 投递模式

对于消息中间件而言，一般有两种消息投递模式：**点对点（P2P，Point-to-Point）模式**和**发布/订阅（Pub/Sub）模式**。

- **点对点模式**是基于队列的，消息生产者发送消息到队列，消息消费者从队列中接收消息。
- 。**发布订阅模式**定义了如何向一个内容节点发布和订阅消息，这个内容节点称为主题（Topic），主题可以认为是消息传递的中介，消息发布者将消息发布到某个主题，而消息订阅者从主题中订阅消息。主题使得消息的订阅者和发布者互相保持独立，不需要进行接触即可保证消息的传递，发布/订阅模式在消息的**一对多广播**时采用。

Kafka 同时支持两种消息投递模式，而这正是得益于消费者与消费组模型的契合：

- 如果所有的消费者都隶属于同一个消费组，那么所有的消息都会被均衡地投递给每一个消费者，即每条消息只会被一个消费者处理，这就相当于**点对点模式**的应用。
- 如果所有的消费者都隶属于不同的消费组，那么所有的消息都会被广播给所有的消费者，即每条消息会被所有的消费者处理，这就相当于**发布/订阅模式**的应用。

## 客户端开发

一个正常的消费逻辑需要具备以下几个步骤：

1. 配置消费者客户端参数
2. 创建相应的消费者实例。
3. 订阅主题。
4. 拉取消息并消费。
5. 提交消费位移。
6. 关闭消费者实例。

```java
public class KafkaConsumerAnalysis {
    public static final String brokerList = "localhost:29092,localhost:29093,localhost:29094";
    public static final String topic = "topic-demo";
    public static final String groupId = "group.demo";
    public static final AtomicBoolean isRunning = new AtomicBoolean(true);

    public static void main(String[] args) {
        // 1. 配置消费者客户端参数
        Properties properties = new Properties();
        properties.put("key.deserializer", StringDeserializer.class.getName());
        properties.put("value.deserializer", StringDeserializer.class.getName());
        properties.put("bootstrap.servers", brokerList);
        properties.put("group.id", groupId);
        properties.put("client.id", "consumer.client.id.demo");

        // 2. 创建消费者客户端实例
        try (KafkaConsumer<String, String> consumer = new KafkaConsumer<>(properties)) { // 6. try with resources 关闭消费者实例
            // 3. 订阅主题
            consumer.subscribe(Collections.singletonList(topic));
            while (isRunning.get()) {
                ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(1000)); // 5. 提交消费位移（自动提交）
                // 4. 拉取消息并提交位移
                for (ConsumerRecord<String, String> record : records) {
                    System.out.println(record);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

### 参数配置和消费者实例创建

在 Kafka 消费者客户端 KafkaConsumer 中有 4 个参数是必填的。

- `bootstrap.servers`：该参数的释义和生产者客户端 KafkaProducer 中的相同，用来指定连接 Kafka 集群所需的 broker 地址清单，具体内容形式为 `host1:port1,host2:post`，可以设置一个或多个地址，中间用逗号隔开，此参数的默认值为`""`。
- `group.id`：消费者隶属的消费组的名称，默认值为`""`。如果设置为空，则会报出异常：`InvalidGroupIdException`。一般而言，这个参数需要设置成具有一定的业务意义的名称。
- `key.deserializer` 和 `value.deserializer`：与生产者客户端 KafkaProducer 中的 `key.serializer` 和 `value.serializer` 参数对应。消费者从 broker 端获取的消息格式都是字节数组（`byte[]`）类型，所以需要执行相应的反序列化操作才能还原成原有的对象格式。这两个参数分别用来指定消息中 `key` 和 `value` 所需反序列化操作的反序列化器，这两个参数无默认值。

除此之外，代码中还设置了一个参数 `client.id`，这个参数用来设定 KafkaConsumer 对应的客户端 id，默认值也为 `""`。如果客户端不设置，则 KafkaConsumer 会自动生成一个非空字符串，内容形式如`consumer-1`、`consumer-2`，即字符串 `consumer-` 与数字的拼接。

KafkaConsumer 中的参数众多，开发人员可以根据业务应用的实际需求来修改这些参数的默认值，以达到灵活调配的目的。

在配置完参数之后，就可以使用参数配置来创建一个消费者实例：

```java
KafkaConsumer<String, String> consumer = new KafkaConsumer<>(properties)
```

### 订阅主题与分区

Kafka 的消费者在消费之前会被分配一个分区，消费者消费分区中的数据。Kafka 提供了 2 种区分分配的策略，分别是 **主题订阅 `subscribe()` 来根据分区分配策略自动分区** 和 **分区指定 `assign()` 来手动指定消费区分**。

---

#### subscribe

消费者客户端可以通过 `subscribe()` 方法来订阅一个或多个主题。`subscribe()` 的几个重载方法如下：

```java
public void subscribe(Collection<String> topics, ConsumerRebalanceListener listener)
public void subscribe(Collection<String> topics)
public void subscribe(Pattern pattern, ConsumerRebalanceListener listener)
public void subscribe(Pattern pattern)
```

消费者客户端可以通过 **`Collection<String>`订阅** 和 **正则表达式订阅** 两种方式来订阅一个或者多个主题。在订阅之后，Kafka 会将订阅主题的分区根据分区分配策略自动分配给消费者客户端。

此外，如果消费者采用的是**正则表达式订阅**的方式，如果在订阅之后有人又创建了新的主题，并且主题的名字与正则表达式相匹配，新主题的分区有可能会被分配到消费者客户端，那么这个消费者就可以消费到新添加的主题中的消息。

`subscribe()` 的重载方法中有一个 `ConsumerRebalanceListener` 参数类型是用来设置相应的再均衡监听器的，该监听器会在**再均衡发生的前后**进行回调。

---

#### assign

消费者客户端还提供了用于直接订阅某些主题的特定分区的 `assign()`。方法的定义如下：

```java
public void assign(Collection<TopicPartition> partitions)
```

这个方法只接受一个参数 `partitions`，用来指定需要订阅的分区集合。`TopicPartition` 类只有 2 个属性：`topic` 和 `partition`，分别代表分区所属的主题和自身的分区编号，这个类可以和我们通常所说的主题—分区的概念映射起来。

但是在指定消费分区之前，开发者可能并不知道主题的分区信息，消费者客户端种提供了 `partitionsFor()` 方法可以用来查询特定主题的元信息。在 `partitionsFor()` 方法的协助下可以通过 `assign()` 方法来实现对特定分区的订阅功能。

```java
public List<PartitionInfo> partitionsFor(String topic)
```

返回的 `PartitionInfo` 类型即为主题的分区元数据信息，此类的主要结构如下：

```java
public class PartitionInfo {
    private final String topic; // 主题名称
    private final int partition; // 分区编号
    private final Node leader; // leader 副本节点
    private final Node[] replicas; // 分区的 AR 集合
    private final Node[] inSyncReplicas; // 分区的 ISR 集合
    private final Node[] offlineReplicas; // 分区的 OST 集合
    //这里省略了构造函数、属性提取、toString 等方法
}
```

---

#### 取消订阅

在消费者客户端种可以使用 `unsubscribe()` 方法来取消全部主题的订阅。如果将 `subscribe(Collection)` 或 `assign(Collection)` 中的集合参数设置为空集合，那么作用等同于 `unsubscribe()` 方法，下面示例中的三行代码的效果相同：

```java
consumer.unsubscribe();
consumer.subscribe(new ArrayList<String>());
consumer.assign(new ArrayList<TopicPartition>());
```

如果没有订阅任何主题或分区，那么再继续执行消费程序的时候会报出 `IllegalStateException`
异常。

---

#### 订阅主体与分区总结

集合订阅的方式 `subscribe(Collection)`、正则表达式订阅的方式 `subscribe(Pattern)` 和指定分区的订阅方式 `assign(Collection)` 分表代表了三 种不同的订阅状态： `AUTO_TOPICS`、`AUTO_PATTERN` 和 `USER_ASSIGNED`（如果没有订阅，那么订阅状态为 `NONE`）。然而这三种状态是互斥的，在一个消费者中只能使用其中的一种，否则会报出 `IllegalStateException` 异常。

通过 `subscribe()` 方法订阅主题**具有消费者自动再均衡的功能**，在多个消费者的情况下可以根据分区分配策略来自动分配各个消费者与分区的关系。当消费组内的消费者增加或减少时，分区分配关系会自动调整，以实现消费负载均衡及故障自动转移。

而通过 `assign()` 方法订阅分区时，是**不具备消费者自动均衡的功能的**，其实这一点从 assign()方法的参数中就可以看出端倪，两种类型的 `subscribe()` 都有 `ConsumerRebalanceListener` 类型参数的方法，而 `assign()`方法却没有。

### 反序列化

之前我们讲解了 KafkaProducer 对应的序列化器，那么与此对应的 KafkaConsumer 就会有反序列化器。生产者需要用**序列化器（Serializer）**把对象转换成字节数组才能通过网络发送给 Kafka。而在对侧，消费者需要用**反序列化器（Deserializer）**把从 Kafka 中收到的字节数组转换成相应的对象。

![序列化](imgs/%E5%BA%8F%E5%88%97%E5%8C%96.drawio.png)

Kafka 提供了多种类型的反序列化器，这些序列化器都实现了 Deserializer 接口， KafkaProducer 中提及的 Serializer 接口一样，Deserializer 接口也有三个方法。

- `public void configure(Map<String, ?> configs, boolean isKey)`：用来配置当前类。
- `public T deserialize(String topic, byte[] data)`：用来执行反序列化。如果 `data` 为 `null`，那么处理的时候直接返回 `null` 而不是抛出一个异常。
- `public void close()`：用来关闭当前序列化器。

在实际应用中，在 Kafka 提供的序列化器和反序列化器满足不了应用需求的前提下，推荐使用 Avro、JSON、Thrift、ProtoBuf 或 Protostuff 等通用的序列化工具来包装，以求尽可能实现得更加通用且前后兼容。使用通用的序列化工具也需要实现 `Serializer` 和 `Deserializer` 接口，因为 Kafka 客户端的序列化和反序列化入口必须是这两个类型。

### 消息消费

Kafka 中的消费是基于**拉模式**的。消息的消费一般有两种模式：推模式和拉模式。推模式是服务端主动将消息推送给消费者，而拉模式是消费者主动向服务端发起请求来拉取消息。

#### poll

Kafka 中的消息消费是一个不断轮询的过程，消费者所要做的就是重复地调用 `poll()` 方法，而 `poll()` 方法返回的是所订阅的主题（分区）上的一组消息。

对于 `poll()` 方法而言，如果某些分区中没有可供消费的消息，那么此分区对应的消息拉取的结果就为空；如果订阅的所有分区中都没有可供消费的消息，那么 `poll()` 方法返回为空的消息集合。

`poll()` 方法的具体定义如下：

```java
public ConsumerRecords<K, V> poll(final Duration timeout)
@Deprecated
public ConsumerRecords<K, V> poll(final long timeout)
```

注意到 `poll()` 方法里还有一个超时时间参数 `timeout`，用来控制 `poll()` 方法的阻塞时间，在消费者的缓冲区里没有可用数据时会发生阻塞。

**`timeout` 的设置**取决于应用程序对响应速度的要求，比如需要在多长时间内将控制权移交给执行轮询的应用线程。可以直接将 `timeout` 设置为 `0`，这样 `poll()` 方法会立刻返回，而不管是否已经拉取到了消息。如果应用线程唯一的工作就是从 Kafka 中拉取并消费消息，则可以将这个参数设置为最大值 `Long.MAX_VALUE`。

到目前为止，可以简单地认为 `poll()` 方法只是拉取一下消息而已，但就其内部逻辑而言并不简单，它涉及消费位移、消费者协调器、组协调器、消费者的选举、分区分配的分发、再均衡的逻辑、心跳等内容，在后面的章节中会循序渐进地介绍这些内容。

---

#### 消费者消息记录

`poll()` 方法的返回值类型是 `ConsumerRecords`，它用来表示一次拉取操作所获得的**消息集**，内部包含了若干 `ConsumerRecord` **消息**。

在 `ConsumerRecords` 类中还提供了几个方法来方便开发人员对消息集进行处理：`count()` 方法用来计算出消息集中的消息个数，返回类型是 `int`；`isEmpty()` 方法用来判断消息集是否为空，返回类型是 `boolean`；`empty()` 方法用来获取一个空的消息集，返回类型是 `ConsumerRecord<K，V>`。

消费者消费到的消息集 `ConsumerRecord` 中每条消息的类型为 `ConsumerRecord`，这个和生产者发送的消息类型 `ProducerRecord` 相对应，不过 `ConsumerRecord` 中的内容更加丰富，具体的结构参考如下代码：

```java
public class ConsumerRecord<K, V> {
    private final String topic;     // 主题名称
    private final int partition;    // 分区编号
    private final long offset;      // 示消息在所属分区的偏移量
    private final long timestamp;   // 时间戳
    private final TimestampType timestampType;  // 时间戳类型
    private final int serializedKeySize;    // key 经过序列化后的大小
    private final int serializedValueSize;  // value 经过序列化后的大小
    private final Headers headers;  // 消息的头部内容
    private final K key;            // 消息的键
    private final V value;          // 消息的值
    private volatile Long checksum; // CRC32 的校验值
    //省略若干方法
}
```

---

#### 消费数据

`ConsumerRecords` 实现了一个 `Iterable` 接口，开发者可以通过使用迭代器的方式来循环遍历消息集内部的消息。

```java
ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(1000));
for (ConsumerRecord<String, String> record : records) {
    // Consume records
}
```

除此之外，`ConsumerRecords` 类提供了一个 `records()` 方法来获取消息集中指定**分区**或者**主题**中的消息，因此开发者可以按照分区和主题维度来进行消费。

```java
public List<ConsumerRecord<K, V>> records(TopicPartition partition)
public Iterable<ConsumerRecord<K, V>> records(String topic)
```

`ConsumerRecords.partitions()` 方法用来获取消息集中所有分区。按照**分区维度**进行消费的代码逻辑：

```java
ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(1000));
for (TopicPartition tp : records.partitions()) {
    for (ConsumerRecord<String, String> record : records.records(tp)) {
        // Consume partition records
    }
}
```

`ConsumerRecords` 类中并没提供与 `partitions()` 类似的 `topics()` 方法来查看拉取的消息集中所包含的主题列表，如果要按照**主题维度**来进行消费，需要先从消费者的分区信息中获取来获取主题名。

```java
ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(1000));
Set<String> topics = records.partitions().stream().map((TopicPartition::topic)).collect(Collectors.toSet());
for (String topic : topics) {
    for (ConsumerRecord<String, String> record : records.records(topic)) {
        // Consume topic records
    }
}
```

### 位移提交

对于 Kafka 中的分区而言，它的每条消息都有唯一的 `offset`，用来表示消息在分区中对应的位置。对于消费者而言，它也有一个 `offset` 的概念，消费者使用 `offset` 来表示消费到分区中某个消息所在的位置。笔者对 `offset` 做了一些区分：对于消息在分区中的位置，我们将 `offset` 称为**偏移量**；对于消费者消费到的位置，将 `offset` 称为**位移**，有时候也会更明确地称之为**消费位移**。

如果消费者客户端在分区上某次 `poll()` 操作拉取了偏移量为 `[x+2, x+6]` 区间的消息，那么**下次拉取消息开始的位置**就是 `x+7`，如下图所示。消费者在每次拉取消息消费之后，继续从**下次拉取消息开始的位置**拉取消息，在不出现异常的情况下是能够保证分区上的消息能够正确消费。

KafkaConsumer 类提供了 `public long position(TopicPartition partition)` 方法来获取客户端在分区上下次拉取消息开始的位置。需要注意的是，下次拉取消息开始的位置这是当前客户端维护的一个状态，其他客户端不能也不需要获取该状态。

![消息消费](imgs/%E6%B6%88%E8%B4%B9%E4%BD%8D%E7%A7%BB.drawio.png)

如果消费者客户端在处理偏移量为 `x+4` 的消息时，**消费者客户端发生宕机**或者**分区再均衡**导致该分区分配给了其他的消费者客户端，但是其他客户端并不知道上一个客户端的消费位移，就有可能导致**消息丢失**或者**重复消费**的问题。为了解决该问题就记录上一次消费时的消费位移进行持久化的保存，在新消费者客户端（Java版本）中，**消费位移存储在 Kafka 内部的主题 `__consumer_offsets` 中**。这里把将消费位移存储起来（持久化）的动作称为**提交**，消费者在消费完消息之后需要执行消费位移的提交。**提交的位移应该是下一个要消费的消息的偏移量**，例如，在偏移量为 `x+4` 消息处理完成后提交位移，提交的位移应该是 `x+5`。

KafkaConsumer 类提供了 `public OffsetAndMetadata committed(TopicPartition partition)` 方法来获取客户端在分区上提交的位移。

Kafka 中提供了 3 中位移提交方式，分别是自动提交、同步提交和异步提交。同时同步提交和异步提交属于手动提交方式，能够为开发者提供更加灵活的消费位移的管理控制。

- 自动提交
- 手动提交
  - 同步提交
  - 异步提交

---

#### 自动提交

在 Kafka 中默认的消费位移的提交方式是自动提交。

消费者客户端参数 `enable.auto.commit` 控制是否开启自动提交，默认值为 `true`。自动提交不是每消费一条消息就提交一次，而是定期提交，这个定期的周期时间由客户端参数 `auto.commit.interval.ms` 配置，默认值为 `5000`，即 5 秒，此参数生效的前提是 `enable.auto.commit` 参数为 `true`。

自动位移提交的动作是在 `poll()` 方法的逻辑里完成的，在每次真正向服务端发起拉取请求之前会检查可以进行位移提交（提交时间间隔是否超过 `auto.commit.interval.ms`），如果可以则将拉取到的每个分区中 `最大的消息位移 + 1` （提交值是下一个要消费的消息位移）进行提交。

在 Kafka 消费的编程逻辑中位移提交是一大难点，自动提交消费位移的方式非常**简便**，它
免去了复杂的位移提交逻辑，让编码更**简洁**。但随之而来的是**重复消费**和**消息丢失**的问题。

---

假设刚刚提交完一次消费位移，然后拉取一批消息进行消费，在下一次自动提交消费位移之前，消费者**宕机**（或者**再均衡**）了，那么又得从上一次位移提交的地方重新开始消费，这样便发生了**重复消费**的现象。我们可以通过*减小位移提交的时间间隔*来减小重复消息的窗口大小，但这样并不能避免重复消费的发送，而且也会使位移提交更加频繁。

---

![自动位移提交中消息丢失的情况](imgs/%E8%87%AA%E5%8A%A8%E4%BD%8D%E7%A7%BB%E6%8F%90%E4%BA%A4%E4%B8%AD%E6%B6%88%E6%81%AF%E4%B8%A2%E5%A4%B1%E7%9A%84%E6%83%85%E5%86%B5.jpg)

拉取线程 A 不断地拉取消息并存入本地缓存，比如在 `BlockingQueue` 中，另一个处理线程 B 从缓存中读取消息并进行相应的逻辑处理。假设目前进行到了第 `y+1` 次拉取，以及第 `m` 次位移提交的时候，也就是 `x+6` 之前的位移已经确认提交了，处理线程 B 却还正在消费 `x+3` 的消息。此时如果处理线程 B 发生了异常，待其恢复之后会从第 `m` 此位移提交处，也就是 `x+6` 的位置开始拉取消息，那么 `x+3` 至 `x+6` 之间的消息就没有得到相应的处理，这样便发生**消息丢失**的现象。

#### 手动提交

自动位移提交的方式在正常情况下不会发生消息丢失或重复消费的现象，但是在编程的世界里异常无可避免，与此同时，自动位移提交也无法做到精确的位移管理。在 Kafka 中还提供了**手动位移提交**的方式，这样可以使得开发人员对消费位移的管理控制更加**灵活**。很多时候并不是说拉取到消息就算消费完成，而是需要将消息写入数据库、写入本地缓存，或者是更加复杂的业务处理。在这些场景下，所有的业务处理完成才能认为消息被成功消费，手动的提交方式可以让开发人员根据程序的逻辑在合适的地方进行位移提交。

开启手动提交功能的前提是消费者客户端参数 `enable.auto.commit` 配置为 `false`。

---

##### 同步提交

手动提交的同步提交对应于 KafkaConsumer 中的 `commitSync()` 方法。`commitSync()` 有两种重载方法：

```java
public void commitSync()
public void commitSync(final Map<TopicPartition, OffsetAndMetadata> offsets)
```

---

无参的 `commitSync()` 方法会根据 `poll()` 方法拉取后的每个分区下一次拉去的消费的位置（即 `position()` 方法的返回值）进行提交，只要没有发生不可恢复的错误（Unrecoverable Error），它就会阻塞消费者线程直至位移提交完成。对于可恢复的错误消费者会重试提交，如果仍然出错则抛出异常；对于不可恢复的错误，比如 `CommitFailedException`、`WakeupException`、`InterruptException`、`AuthenticationException`、`AuthorizationException` 等，会直接抛出异常，消费者程序可以将其捕获并做针对性的处理。

对于采用 `commitSync()` 的无参方法而言，它提交消费位移的频率和拉取批次消息（`poll()`方法）、处理批次消息的频率是一样的。

---

如果想寻求**更细粒度**的、**更精准**的提交，那么就需要使用 `commitSync()` 的另一个含参方法。该方法提供了一个 `offsets` 参数，用来提交指定分区的位移。

**每消费一条消息就提交一次位移**:

```java
while (isRunning.get()) {
    ConsumerRecords<String, String> records = consumer.poll(1000);
    for (ConsumerRecord<String, String> record : records) {
        //do some logical processing.
        long offset = record.offset();
        TopicPartition partition = new TopicPartition(record.topic(), record.partition());
        consumer.commitSync(Collections.singletonMap(partition, new OffsetAndMetadata(offset + 1)));
    }
}
```

在实际应用中，很少会有这种每消费一条消息就提交一次消费位移的必要场景。`commitSync()` 方法本身是同步执行的，会耗费一定的性能，而示例中的这种提交方式会将**性能拉到一个相当低的点**。更多时候是**按分区粒度同步提交消费位移**:

```java
while (isRunning.get()) {
    ConsumerRecords<String, String> records = consumer.poll(1000);
    for (TopicPartition partition : records.partitions()) {
        List<ConsumerRecord<String, String>> partitionRecords = records.records(partition);
        for (ConsumerRecord<String, String> record : partitionRecords) {
            //do some logical processing.
        }
        long lastConsumedOffset = partitionRecords.get(partitionRecords.size() - 1).offset();
        consumer.commitSync(Collections.singletonMap(partition, new OffsetAndMetadata(lastConsumedOffset + 1)));
    }
}
```

##### 异步提交

与 `commitSync()` 方法相反，异步提交的方式（`commitAsync()`）在执行的时候**消费者线程不会被阻塞**，可能在提交消费位移的结果还未返回之前就开始了新一次的拉取操作。异步提交可以使消费者的性能得到一定的增强。`commitAsync()` 方法有三个不同的重载方法，具体定义如下：

```java
public void commitAsync()
public void commitAsync(OffsetCommitCallback callback)
public void commitAsync(final Map<TopicPartition, OffsetAndMetadata> offsets, OffsetCommitCallback callback)
```

第一个无参的方法和第三个方法中的 `offsets` 对照 `commitSync()` 方法即可。关键的是这里的第二个方法和第三个方法中的 `callback` 参数，它提供了一个异步提交的回调方法，**当位移提交完成后会回调 `OffsetCommitCallback` 中的 `onComplete()` 方法**。

**Q**：如果某一次异步提交的消费位移为 `x`，但是提交失败了，然后下一次又异步提交了消费位移为 `x+y`，这次成功了。如果这里引入了**重试机制**，前一次的异步提交的消费位移在重试的时候提交成功了，那么此时的消费位移又变为了 `x`。如果此时发生**异常**（或者**再均衡**），那么恢复之后的消费者（或者新的消费者）就会从 `x` 处开始消费消息，这样就发生了重复消费的问题。

**A**：为此我们可以设置一个递增的序号来维护异步提交的顺序，每次位移提交之后就增加序号相对应的值。在遇到位移提交失败需要重试的时候，可以检查所提交的位移和序号的值的大小，如果前者小于后者，则说明有更大的位移已经提交了，不需要再进行本次重试（注意这里只是消费位移的提交，数据已经消费完毕）；如果两者相同，则说明可以进行重试提交。除非程序编码错误，否则不会出现前者大于后者的情况。

#### 位移提交总结

如果位移提交失败的情况经常发生，那么说明系统肯定出现了故障，在一般情况下，位移提交失败的情况很少发生，不重试也没有关系，后面的提交也会有成功的。重试会增加代码逻辑的复杂度，不重试会增加重复消费的概率。

如果**消费者异常退出**，那么这个重复消费的问题就很难避免，因为这种情况下无法及时提交消费位移；如果**消费者正常退出或发生再均衡的情况**，那么可以在退出或再均衡执行之前使用同步提交的方式做最后的把关。

以下代码是正常退出时使用同步提交来做**把关**。

```java
try {
    while (isRunning.get()) {
        //poll records and do some logical processing.
        consumer.commitAsync();
    }
} finally {
    try {
        consumer.commitSync();
    }finally {
        consumer.close();
    }
}
```

### 控制或关闭消费

#### 分区消费开关

KafkaConsumer 中使用 `pause()` 和 `resume()` 方法来分别实现暂停某些分区在拉取操作时返回数据给客户端和恢复某些分区向客户端返回数据的操作。这两个方法的具体定义如下：

```java
public void pause(Collection<TopicPartition> partitions)
public void resume(Collection<TopicPartition> partitions)
```

KafkaConsumer 还提供了一个无参的 `paused()` 方法来返回被暂停的分区集合，此方法的具体定义如下：

```java
public Set<TopicPartition> paused()
```

---

#### 消费者客户端开关

之前的示例展示的都是使用一个 `while` 循环来包裹住 `poll()` 方法及相应的消费逻辑，如何优雅地退出这个循环也很有考究。

1. 使用 `AtomicBoolean` 类型的变量 `isRunning`，通过 `while(isRunning.get())` 的方式，这样可以通过在其他地方设定 `isRunning.set(false)` 来退出 `while` 循环。
2. 调用 KafkaConsumer 的 `wakeup()` 方法，`wakeup()` 方法是 KafkaConsumer 中唯一可以从其他线程里安全调用的方法法（KafkaConsumer 是非线程安全的），调用 `wakeup()` 方法后可以退出 `poll()` 的逻辑，并抛出 `WakeupException` 的异常，我们也不需要处理 `WakeupException` 的异常，它只是一种跳出循环的方式。

跳出循环以后一定要显式地执行关闭动作以释放运行过程中占用的各种系统资源，包括**内存资源**、**Socket 连接**等。KafkaConsumer 提供了 `close()` 方法来实现关闭，`close()`方法有三种重载方法，分别如下：

```java
public void close()
public void close(Duration timeout)
@Deprecated
public void close(long timeout, TimeUnit timeUnit)
```

第二种方法是通过 `timeout` 参数来设定关闭方法的最长执行时间，有些内部的关闭逻辑会耗费一定的时间，比如设置了自动提交消费位移，这里还会做一次位移提交的动作；而第一种方法没有 `timeout` 参数，这并不意味着会无限制地等待，它内部设定了最长等待时间（30秒）；第三种方法已被标记为`@Deprecated`，可以不考虑。

一个相对完整的消费程序的逻辑可以参考下面的伪代码：

```java
consumer.subscribe(Arrays.asList(topic));
try {
    while (running.get()) {
        //consumer.poll(***)
        //process the record.
        //commit offset.
    }
} catch (WakeupException e) {
    // ingore the error
} catch (Exception e){
    // do some logic process.
} finally {
    // maybe commit offset.
    consumer.close();
}
```

当关闭这个消费逻辑的时候，可以调用 `consumer.wakeup()`，也可以调用 `isRunning.set(false)`。

### 指定消费位移

#### 自动指定消费位移

Kafka 将每个主题下的每个分区中每个消费组的消费位移保存在 `__consumer_offsets` 主题中，也就是说每多一个 `<TopicPatition, group.id>` 主题分区和消费组的组合就需要保存与其对应的消费位移。

试想一下，**当一个新的消费组建立的时候**，它根本没有可以查找的消费位移。或者**消费组内的一个新消费者订阅了一个新的主题**，它也没有可以查找的消费位移。**当 `__consumer_offsets` 主题中有关这个消费组的位移信息过期而被删除后**，它也没有可以查找的消费位移。

在 Kafka 中每当消费者**查找不到所记录的消费位移**或者**位移越界**时，就会根据消费者客户端参数 `auto.offset.reset` 的配置来决定从何处开始进行消费，这个参数的默认值为 `latest`，表示从分区末尾开始消费消息。如果将 `auto.offset.reset` 参数配置为 `earliest`，那么消费者会从起始处。如果将 `auto.offset.reset` 参数配置为 `none`，意味着出现查到不到消费位移的时候，既不从最新的消息位置处开始消费，也不从最早的消息位置处开始消费，此时会报出 `NoOffsetForPartitionException` 异常。如果配置的不是`latest`、`earliest` 和 `none`，则会报出 `ConfigException` 异常。

---

#### `seek()` 手动指定消费位移

有些时候，我们需要一种**更细粒度的掌控**，可以让我们从**特定的位移处开始拉取消息**，而 KafkaConsumer 中的 `seek()` 方法正好提供了这个功能，让我们得以追前消费或回溯消费。`seek()` 方法的具体定义如下：

```java
public void seek(TopicPartition partition, long offset)
```

`seek()` 方法中的参数 `partition` 表示分区，而 `offset` 参数用来指定从分区的哪个位置开始消费。`seek()` 方法只能重置消费者分配到的分区的消费位置，而分区的分配是在 `poll()` 方法的调用过程中实现的。也就是说，**在执行 `seek()` 方法之前需要先执行一次 `poll()` 方法，等到分配到分区之后才可以重置消费位置**。

```java
KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
consumer.subscribe(Arrays.asList(topic));
consumer.poll(Duration.ofMillis(10000)); // ①
Set<TopicPartition> assignment = consumer.assignment(); // ②
for (TopicPartition tp : assignment) {
    consumer.seek(tp, 10); // ③
}
while (true) {
    ConsumerRecords<String, String> records =
    consumer.poll(Duration.ofMillis(1000));
    //consume the record.
}
```

上面示例中第③行设置了每个分区的消费位置为 `10`。第②行中的 `assignment()` 方法是用来获取消费者所分配到的分区信息的，这个方法的具体定义如下：

```java
public Set<TopicPartition> assignment()
```

如果对未分配到的分区执行 `seek()` 方法，那么会报出 `IllegalStateException` 的异常。

---

#### 手动指定从开头或者末尾开始消费

如果消费组内的消费者在启动的时候能够找到消费位移，除非发生位移越界，否则 `auto.offset.reset` 参数并不会奏效，此时如果想指定从开头或末尾开始消费，就需要 `seek()` 方法的帮助了，下列代码用来指定从分区末尾开始消费。

```java
KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
consumer.subscribe(Arrays.asList(topic));
Set<TopicPartition> assignment = new HashSet<>();
while (assignment.size() == 0) {
    consumer.poll(Duration.ofMillis(100));
    assignment = consumer.assignment();
}
Map<TopicPartition, Long> offsets = consumer.endOffsets(assignment); // ①
for (TopicPartition tp : assignment) {
    consumer.seek(tp, offsets.get(tp)); // ②
}
```

第①行的 `endOffsets()` 方法用来获取指定分区的末尾的消息位置(将要写入最新消息的位置)。

`beginningOffsets()`方法中的参数内容和含义都与 `endOffsets()` 方法中的一样，配合这两个方法我们就可以从分区的开头或末尾开始消费。其实 KafkaConsumer 中直接提供了 `seekToBeginning()` 方法和 `seekToEnd()` 方法来实现这两个功能，这两个方法的具体定义如下：

```java
public void seekToBeginning(Collection<TopicPartition> partitions)
public void seekToEnd(Collection<TopicPartition> partitions)
```

---

#### 手动指定从某时间戳之后的消息开始消费

有时候我们并不知道特定的消费位置，却知道一个相关的时间点，比如我们想要消费昨天8 点之后的消息，这个需求更符合正常的思维逻辑。此时我们无法直接使用 `seek()` 方法来追溯到相应的位置。KafkaConsumer 同样考虑到了这种情况，它提供了一个 `offsetsForTimes()` 方法，通过 `timestamp` 来查询与此对应的分区位置。

```java
public Map<TopicPartition, OffsetAndTimestamp> offsetsForTimes(Map<TopicPartition, Long> timestampsToSearch)
public Map<TopicPartition, OffsetAndTimestamp> offsetsForTimes(Map<TopicPartition, Long> timestampsToSearch, Duration timeout)
```

`offsetsForTimes()`方法的参数 `timestampsToSearch` 是一个 `Map` 类型，`key` 为待查询的分
区，而 `value` 为待查询的时间戳，该方法会返回时间戳大于等于待查询时间的第一条消息对应
的位置和时间戳，对应于 `OffsetAndTimestamp` 中的 `offset` 和 `timestamp` 字段。

---

#### 位移越界

![auto.offset.reset 配置](imgs/auto.offset.reset%20%E9%85%8D%E7%BD%AE.jpg)

前面说过位移越界也会触发 `auto.offset.reset` 参数的执行，位移越界是指知道消费位置却无法在实际的分区中查找到，比如想要从上图中的位置 10 处拉取消息时就会发生位移越界。注意拉取图中位置 9 处的消息时并未越界，这个位置代表特定的含义（LEO）。我们通过 `seek()` 方法来演示发生位移越界时的情形：

```java
KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
consumer.subscribe(Arrays.asList(topic));
Set<TopicPartition> assignment = new HashSet<>();
while (assignment.size() == 0) {
    consumer.poll(Duration.ofMillis(100));
    assignment = consumer.assignment();
}
Map<TopicPartition, Long> offsets = consumer.endOffsets(assignment); // ①
for (TopicPartition tp : assignment) {
    consumer.seek(tp, offsets.get(tp) + 1); // ②
}
```

---

#### 消费位移保存在DB中

Kafka 中的消费位移是存储在一个内部主题 `__consumer_offsets` 中的，而本节的 `seek()` 方法可以突破这一限制：消费位移可保存在任意的存储介质中，例如数据库、文件系统等。以数据库为例，我们将消费位移保存在其中的一个表中，在下次消费的时候可以读取存储在数据表中的消费位移并通过 seek()方法指向这个具体的位置，伪代码如下所示。

```java
consumer.subscribe(Arrays.asList(topic));
// 省略 poll()方法及 assignment 的逻辑
for(TopicPartition tp: assignment){
    long offset = getOffsetFromDB(tp); // 从 DB 中读取消费位移
    consumer.seek(tp, offset);
}
while(true){
    ConsumerRecords<String, String> records =
    consumer.poll(Duration.ofMillis(1000));
    for (TopicPartition partition : records.partitions()) {
        List<ConsumerRecord<String, String>> partitionRecords =
        records.records(partition);
        for (ConsumerRecord<String, String> record : partitionRecords) {
            // process the record.
        }
        long lastConsumedOffset = partitionRecords.get(partitionRecords.size() - 1).offset();
        // 将消费位移存储在 DB 中
        storeOffsetToDB(partition, lastConsumedOffset+1);
    }
}
```

`seek()` 方法为我们提供了从特定位置读取消息的能力，我们可以通过这个方法来向前跳过若干消息，也可以通过这个方法来向后回溯若干消息，这样为消息的消费提供了很大的灵活性。`seek()` 方法也为我们提供了将消费位移保存在外部存储介质中的能力，还可以配合再均衡监听器来提供更加精准的消费能力。

### 再均衡

**再均衡**是指分区的所属权从一个消费者转移到另一消费者的行为，它为消费组具备高可用性和伸缩性提供保障，使我们可以既方便又安全地删除消费组内的消费者或往消费组内添加消费者。

不过在再均衡发生期间，消费组内的消费者是无法读取消息的。也就是说，**在再均衡发生期间的这一小段时间内，消费组会变得不可用**。另外，当一个分区被重新分配给另一个消费者时，**消费者当前的状态也会丢失**。比如消费者消费完某个分区中的一部分消息时还没有来得及提交消费位移就发生了再均衡操作，之后这个分区又被分配给了消费组内的另一个消费者，原来被消费完的那部分消息又被重新消费一遍，也就是发生了重复消费。一般情况下，应尽量**避免不必要的再均衡的发生**。

在讲述 `subscribe()` 方法时提及再均衡监听器 `ConsumerRebalanceListener`，在 `subscribe(Collection<String> topics, ConsumerRebalanceListener listener)` 和 `subscribe(Pattern pattern, ConsumerRebalanceListener listener)` 方法中都有它的身影。再均衡监听器用来设定发生再均衡动作前后的一些准备或收尾的动作。`ConsumerRebalanceListener` 是一个接口，包含 2 个方法，具体的释义如下：

```java
void onPartitionsRevoked(Collection<TopicPartition> partitions)
```

这个方法会在再均衡开始之前和消费者停止读取消息之后被调用。可以通过这个回调方法来处理消费位移的提交，以此来避免一些不必要的重复消费现象的发生。参数 `partitions` 表示再均衡前所分配到的分区。

```java
void onPartitionsAssigned(Collection<TopicPartition> partitions)
```

这个方法会在重新分配分区之后和消费者开始读取消费之前被调用。参数 `partitions` 表示再均衡后所分配到的分区。

---

#### 再均衡前同步提交避免重复消费

下面我们通过一个例子来演示 `ConsumerRebalanceListener` 的用法，具体内容如下所示：

```java
Map<TopicPartition, OffsetAndMetadata> currentOffsets = new HashMap<>();
consumer.subscribe(Arrays.asList(topic), new ConsumerRebalanceListener() {
    @Override
    public void onPartitionsRevoked(Collection<TopicPartition> partitions) {
        consumer.commitSync(currentOffsets);
        currentOffsets.clear();
    }
    @Override
    public void onPartitionsAssigned(Collection<TopicPartition> partitions) {
        // do nothing.
    }
});
try {
    while (isRunning.get()) {
        ConsumerRecords<String, String> records =
        consumer.poll(Duration.ofMillis(100));
        for (ConsumerRecord<String, String> record : records) {
            //process the record.
            currentOffsets.put(
            new TopicPartition(record.topic(), record.partition()),
            new OffsetAndMetadata(record.offset() + 1));
        }
        consumer.commitAsync(currentOffsets, null);
    }
} finally {
    consumer.close();
}
```

上述代码将消费位移暂存到一个局部变量 `currentOffsets` 中，这样在正常消费的时候可以通过 `commitAsync()` 方法来异步提交消费位移，在发生再均衡动作之前可以通过再均衡监听器的 `onPartitionsRevoked()` 回调执行 `commitSync()` 方法同步提交消费位移，以尽量避免一些不必要的重复消费。

#### 再均衡配合外部存储

再均衡监听器还可以配合外部存储使用。我们可以将消费位移保存在数据库中，这里可以通过再均衡监听器查找分配到的分区的消费位移，并且配合 `seek()` 方法来进一步优化代码逻辑：

```java
consumer.subscribe(Arrays.asList(topic), new ConsumerRebalanceListener() {
    @Override
    public void onPartitionsRevoked(Collection<TopicPartition> partitions) {
        // store offset in DB （storeOffsetToDB）
    }
    @Override
    public void onPartitionsAssigned(Collection<TopicPartition> partitions) {
        for(TopicPartition tp: partitions){
            consumer.seek(tp, getOffsetFromDB(tp)); // 从 DB 中读取消费位移
        }
    }
});
```

### 消费者拦截器

消费者拦截器主要**在消费到消息**或**在提交消费位移**时进行一些定制化的操作。

与生产者拦截器对应的，消费者拦截器需要自定义实现 `org.apache.kafka.clients.consumer.ConsumerInterceptor` 接口。`ConsumerInterceptor` 接口包含 3 个方法：

```java
public ConsumerRecords<K, V> onConsume(ConsumerRecords<K, V> records)；
public void onCommit(Map<TopicPartition, OffsetAndMetadata> offsets)；
public void close()。
```

KafkaConsumer 会在 `poll()` 方法返回之前调用拦截器的 `onConsume()` 方法来对消息进行相应的定制化操作，比如修改返回的消息内容、按照某种规则过滤消息（可能会减少 `poll()` 方法返回的消息的个数）。如果 `onConsume()` 方法中抛出异常，那么会被捕获并记录到日志中，但是异常不会再向上传递。

KafkaConsumer 会在提交完消费位移之后调用拦截器的 `onCommit()` 方法，可以使用这个方法来记录跟踪所提交的位移信息，比如当消费者使用 `commitSync` 的无参方法时，我们不知道提交的消费位移的具体细节，而使用拦截器的 `onCommit()` 方法却可以做到这一点。

`close()` 方法和 `ConsumerInterceptor` 的父接口中的 `configure()` 方法与生产者的 `ProducerInterceptor` 接口中的用途一样，这里就不赘述了。

在 KafkaConsumer 中通过 interceptor.classes 参数来配置指定拦截器，此参数的默认值为 `""`。

**注意**：在使用带参数的位移提交（需要手动指定消费位移时）的方式时，有可能提交了错误的位移信息。因为在一次消息拉取的批次中，可能含有最大偏移量的消息会被消费者拦截器过滤。

在消费者中也有拦截链的概念，和生产者的拦截链一样，也是按照 `interceptor.classes` 参数配置的拦截器的顺序来一一执行的（配置的时候，各个拦截器之间使用逗号隔开）。同样也要提防**副作用**的发生。如果在拦截链中某个拦截器执行失败，那么下一个拦截器会接着从上一个执行成功的拦截器继续执行。

### 多线程实现

#### 非线程安全

KafkaProducer 是线程安全的，然而 KafkaConsumer 却是非线程安全的。KafkaConsumer 中
定义了一个 `acquire()` 方法，用来检测当前是否只有一个线程在操作，若有其他线程正在操作则
会抛出 `ConcurrentModifcationException` 异常。

KafkaConsumer 中的每个公用方法在执行所要执行的动作之前都会调用这个 `acquire()` 方法，
只有 `wakeup()` 方法是个例外。`acquire()` 方法的具体定义如下：

```java
private final AtomicLong currentThread = new AtomicLong(NO_CURRENT_THREAD); // KafkaConsumer 中的成员变量，表示当前占有的线程ID
private void acquire() {
    long threadId = Thread.currentThread().getId();
    if (threadId != currentThread.get() && !currentThread.compareAndSet(NO_CURRENT_THREAD, threadId))
        throw new ConcurrentModificationException("KafkaConsumer is not safe for multi-threaded access");
    refcount.incrementAndGet(); // 重入计数器自增
}
```

`acquire()` 方法和我们通常所说的锁（synchronized、Lock 等）不同，它不会造成阻塞等待，我们可以将其看作一个轻量级锁，它仅通过线程操作计数标记的方式来检测线程是否发生了并发操作，以此保证只有一个线程在操作。`acquire()` 方法和 `release()` 方法成对出现，表示相应的加锁和解锁操作。`release()` 方法也很简单，具体定义如下：

```java
private void release() {
    if (refcount.decrementAndGet() == 0) // 重入计数器自减
        currentThread.set(NO_CURRENT_THREAD);
}
```

`acquire()` 方法和 `release()` 方法都是私有方法，因此在实际应用中不需要我们显式地调用，但了解其内部的机理之后可以促使我们正确、有效地编写相应的程序逻辑。

#### 多线程消费

KafkaConsumer非线程安全并不意味着在消费消息的时候只能以单线程的方式执行。如果生产者发送消息的速度大于消息者处理消息的速度，那么就会有越来越多的消息得不到及时的消费，造成了一定的延迟。除此之外，由于Kafka中消息保留机制的作用，有些消息有可能在被消费之前就被清理了，从而造成消息的丢失。通过多线程的方式就是为了提高整体的消费能力。

##### 线程封闭

多线程的实现有多种，第一种也是最常见的方式：**线程封闭**，即为每个线程实例化一个KafkaConsumer对象。

一个线程对应一个 KafkaConsumer 实例，可以称之为**消费线程**。**一个消费线程可以消费一个或多个分区中的消息**，所有的消费线程都隶属于同一个消费组，这种实现方式的并发度受限于分区的实际个数。当消费线程的个数大于分区数时，就有部分消费线程一直处于空闲的状态。

![线程封闭](imgs/%E7%BA%BF%E7%A8%8B%E5%B0%81%E9%97%AD.png)

```java
public class FirstMultiConsumerThreadDemo {
    public static final String brokerList = "localhost:29092,localhost:29093,localhost:29094";
    public static final String topic = "topic-demo";
    public static final String groupId = "group.demo";

    public static void main(String[] args) {
        Properties properties = new Properties();
        properties.put("key.deserializer", StringDeserializer.class.getName());
        properties.put("value.deserializer", StringDeserializer.class.getName());
        properties.put("bootstrap.servers", brokerList);
        properties.put("group.id", groupId);

        int consumerThreadNum = 4;
        for (int i = 0; i < consumerThreadNum; i++) {
            new KafkaConsumerThread(properties, topic).start();
        }
    }

    public static class KafkaConsumerThread extends Thread {
        private final KafkaConsumer<String, String> kafkaConsumer;

        public KafkaConsumerThread(Properties props, String topic) {
            this.kafkaConsumer = new KafkaConsumer<>(props);
            this.kafkaConsumer.subscribe(List.of(topic));
        }

        @Override
        public void run() {
            try {
                while (true) {
                    ConsumerRecords<String, String> records = kafkaConsumer.poll(Duration.ofMillis(100));
                    for (ConsumerRecord<String, String> record : records) {
                        // 消费消息模块 ①
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            } finally {
                kafkaConsumer.close();
            }
        }
    }
}
```

内部类 `KafkaConsumerThread` 代表消费线程，其内部包裹着一个独立的 KafkaConsumer 实例。通过外部类的 `main()` 方法来启动多个消费线程，消费线程的数量由 `consumerThreadNum` 变量指定。一般一个主题的分区数事先可以知晓，可以将 `consumerThreadNum` 设置成不大于分区数的值，如果不知道主题的分区数，那么也可以通过 KafkaConsumer 类的 `partitionsFor()` 方法来间接获取，进而再设置合理的 `consumerThreadNum` 值。

上面这种多线程的实现方式和开启多个消费进程的方式没有本质上的区别，它的优点是每个线程可以按顺序消费各个分区中的消息。缺点也很明显，**每个消费线程都要维护一个独立的 TCP 连接**，如果分区数和 consumerThreadNum 的值都很大，那么会造成不小的系统开销。

在上述代码的消费消息模块 ① 中，如果这里对消息的处理非常迅速，那么 `poll()` 拉取的频次也会更高，进而整体消费的性能也会提升；相反，如果在这里对消息的处理缓慢，比如进行一个事务性操作，或者等待一个 RPC 的同步响应，那么 `poll()` 拉取的频次也会随之下降，进而造成整体消费性能的下降。一般而言，`poll()` 拉取消息的速度是相当快的，而整体消费的瓶颈也正是在处理消息这一块，如果我们通过一定的方式来改进这一部分，那么我们就能带动整体消费性能的提升。

---

##### 分区消费多线程（不推荐）

第一种方式中一个分区只能由一个消费线程进行消费，与此对应的第二种方式是多个消费线程同时消费同一个分区，这个通过 `assign()`、`seek()` 等方法实现，这样可以**打破原有的消费线程的个数不能超过分区数的限制**，进一步提高了消费的能力。不过这种实现方式对于**位移提交和顺序控制的处理就会变得非常复杂**，实际应用中使用得极少，笔者也并不推荐。一般而言，**分区是消费线程的最小划分单位**。

---

##### 消息处理模块多线程

在第一个种方式的基础上，将处理消息模块 ① 改成多线程的实现方式，如下图所示：

![消息处理模块多线程](imgs/%E6%B6%88%E6%81%AF%E5%A4%84%E7%90%86%E6%A8%A1%E5%9D%97%E5%A4%9A%E7%BA%BF%E7%A8%8B.png)

```java
public class ThirdMultiConsumerThreadDemo {
    public static final String brokerList = "localhost:29092,localhost:29093,localhost:29094";
    public static final String topic = "topic-demo";
    public static final String groupId = "group.demo";

    public static void main(String[] args) {
        Properties properties = new Properties();
        properties.put("key.deserializer", StringDeserializer.class.getName());
        properties.put("value.deserializer", StringDeserializer.class.getName());
        properties.put("bootstrap.servers", brokerList);
        properties.put("group.id", groupId);

        KafkaConsumerThread consumerThread = new KafkaConsumerThread(properties, topic, Runtime.getRuntime().availableProcessors());
        consumerThread.start();
    }

    public static class KafkaConsumerThread extends Thread {
        private final KafkaConsumer<String, String> kafkaConsumer;
        private final ExecutorService executorService;

        public KafkaConsumerThread(Properties props, String topic, int threadNumber) {
            kafkaConsumer = new KafkaConsumer<>(props);
            kafkaConsumer.subscribe(Collections.singletonList(topic));
            executorService = new ThreadPoolExecutor(threadNumber, threadNumber, 0L, TimeUnit.MILLISECONDS, new ArrayBlockingQueue<>(1000), new ThreadPoolExecutor.CallerRunsPolicy());
        }

        @Override
        public void run() {
            try {
                while (true) {
                    ConsumerRecords<String, String> records = kafkaConsumer.poll(Duration.ofMillis(100));
                    if (!records.isEmpty()) {
                        executorService.submit(new RecordsHandler(records));
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            } finally {
                kafkaConsumer.close();
            }
        }
    }

    public static class RecordsHandler extends Thread {
        private final ConsumerRecords<String, String> records;

        public RecordsHandler(ConsumerRecords<String, String> records) {
            this.records = records;
        }

        @Override
        public void run() {
            // 处理消息
        }
    }
}
```

代码中的 `RecordHandler` 类是用来处理消息的，而 `KafkaConsumerThread` 类对应的是一个消费线程，里面通过线程池的方式来调用 `RecordHandler` 处理一批批的消息。注意 `KafkaConsumerThread` 类中 `ThreadPoolExecutor` 里的最后一个参数设置的是 `CallerRunsPolicy()`，这样可以防止线程池的总体消费能力跟不上 `poll()` 拉取的能力，从而导致异常现象的发生。第三种实现方式还可以横向扩展，通过开启多个 `KafkaConsumerThread` 实例来进一步提升整体的消费能力。

第三种实现方式相比第一种实现方式而言，除了横向扩展的能力，还可以减少 TCP 连接对系统资源的消耗，不过缺点就是对于消息的顺序处理就比较困难了。上述代码默认开启了 `enable.auto.commit` 参数开启了自动提交功能。这样旨在说明在具体实现的时候并没有考虑位移提交的情况。

###### 第三种方式的位移提交

对于第一种实现方式而言，如果要做具体的位移提交，直接在 KafkaConsumerThread 中的 `run()` 方法里实现即可。而对于第三种实现方式，这里引入一个共享变量 `offsets` 来参与提交，如下图所示：

![带有具体位移提交的第三种实现方式](imgs/%E5%B8%A6%E4%BD%8D%E7%A7%BB%E6%8F%90%E4%BA%A4%E7%9A%84%E7%AC%AC%E4%B8%89%E7%A7%8D%E5%AE%9E%E7%8E%B0%E6%96%B9%E5%BC%8F.png)

```java
public class ThirdMultiConsumerThreadDemo {
    public static final String brokerList = "localhost:29092,localhost:29093,localhost:29094";
    public static final String topic = "topic-demo";
    public static final String groupId = "group.demo";

    public static void main(String[] args) {
        Properties properties = new Properties();
        properties.put("key.deserializer", StringDeserializer.class.getName());
        properties.put("value.deserializer", StringDeserializer.class.getName());
        properties.put("bootstrap.servers", brokerList);
        properties.put("group.id", groupId);
        properties.put("enable.auto.commit", false);

        KafkaConsumerThread consumerThread = new KafkaConsumerThread(properties, topic, Runtime.getRuntime().availableProcessors());
        consumerThread.start();
    }

    public static class KafkaConsumerThread extends Thread {
        private final KafkaConsumer<String, String> kafkaConsumer;
        private final ExecutorService executorService;
        private final Map<TopicPartition, OffsetAndMetadata> offsets = new HashMap<>();

        public KafkaConsumerThread(Properties props, String topic, int threadNumber) {
            kafkaConsumer = new KafkaConsumer<>(props);
            kafkaConsumer.subscribe(Collections.singletonList(topic));
            executorService = new ThreadPoolExecutor(threadNumber, threadNumber, 0L, TimeUnit.MILLISECONDS, new ArrayBlockingQueue<>(1000), new ThreadPoolExecutor.CallerRunsPolicy());
        }

        @Override
        public void run() {
            try {
                while (true) {
                    ConsumerRecords<String, String> records = kafkaConsumer.poll(Duration.ofMillis(100));
                    if (!records.isEmpty()) {
                        executorService.submit(new RecordsHandler(records, offsets));
                    }
                    synchronized (offsets) {
                        if (!offsets.isEmpty()) {
                            kafkaConsumer.commitSync(offsets);
                            offsets.clear();
                        }
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            } finally {
                kafkaConsumer.close();
            }
        }
    }

    public static class RecordsHandler extends Thread {
        private final ConsumerRecords<String, String> records;
        private final Map<TopicPartition, OffsetAndMetadata> offsets;

        public RecordsHandler(ConsumerRecords<String, String> records, Map<TopicPartition, OffsetAndMetadata> offsets) {
            this.records = records;
            this.offsets = offsets;
        }

        @Override
        public void run() {
            for (TopicPartition tp : records.partitions()) {
                List<ConsumerRecord<String, String>> tpRecords = records.records(tp);
                //处理 tpRecords.
                long lastConsumedOffset = tpRecords.get(tpRecords.size() - 1).offset();
                synchronized (offsets) {
                    if (!offsets.containsKey(tp)) {
                        offsets.put(tp, new OffsetAndMetadata(lastConsumedOffset + 1));
                    } else {
                        long position = offsets.get(tp).offset();
                        if (position < lastConsumedOffset + 1) {
                            offsets.put(tp, new OffsetAndMetadata(lastConsumedOffset + 1));
                        }
                    }
                }
            }
        }
    }
}
```

每一个处理消息的 `RecordHandler` 类在处理完消息之后都将对应的消费位移保存到共享变量 `offsets` 中，`KafkaConsumerThread` 在每一次 `poll()` 方法之后都读取 `offsets` 中的内容并对其进行位移提交。注意在实现的过程中对 `offsets` 读写需要加锁处理，防止出现并发问题。并且在写入 `offsets` 的时候需要注意位移覆盖的问题，针对这个问题，可以将 `RecordHandler` 类中的 `run()` 方法实现改为上述代码中的内容。

同时，在向线程池提交消费任务后，使用 `commitSync()` 方法提交消费位移 `offsets`。

---

读者可以细想一下这样实现是否万无一失？其实这种位移提交的方式会有数据丢失的风险。对于同一个分区中的消息，假设一个处理线程 RecordHandler1 正在处理 offset 为 0～99 的消息，而另一个处理线程 RecordHandler2 已经处理完了 offset 为 100～199 的消息并进行了位移提交，此时如果 RecordHandler1 发生异常，则之后的消费只能从 200 开始而无法再次消费 0～99的消息，从而造成了消息丢失的现象。这里虽然针对位移覆盖做了一定的处理，但还没有解决异常情况下的位移覆盖问题。对此就要引入更加复杂的处理机制，这里再提供一种解决思路，参考下图，总体结构上是基于滑动窗口实现的。对于第三种实现方式而言，它所呈现的结构是通过消费者拉取分批次的消息，然后提交给多线程进行处理，而这里的滑动窗口式的实现方式是将拉取到的消息暂存起来，多个消费线程可以拉取暂存的消息，这个用于暂存消息的缓存大小即为滑动窗口的大小，总体上而言没有太多的变化，不同的是对于消费位移的把控。

![滑动窗口式多线程消费实现方式](imgs/%E6%BB%91%E5%8A%A8%E7%AA%97%E5%8F%A3%E5%BC%8F%E5%A4%9A%E7%BA%BF%E7%A8%8B%E6%B6%88%E8%B4%B9%E5%AE%9E%E7%8E%B0%E6%96%B9%E5%BC%8F.jpg)

如上图所示，每一个方格代表一个批次的消息，一个滑动窗口包含若干方格，`startOffset` 标注的是当前滑动窗口的起始位置，endOffset 标注的是末尾位置。每当 `startOffset` 指向的方格中的消息被消费完成，就可以提交这部分的位移，与此同时，窗口向前滑动一格，删除原来 `startOffset` 所指方格中对应的消息，并且拉取新的消息进入窗口。滑动窗口的大小固定，所对应的用来暂存消息的缓存大小也就固定了，这部分内存开销可控。方格大小和滑动窗口的大小同时决定了消费线程的并发数：一个方格对应一个消费线程，对于窗口大小固定的情况，方格越小并行度越高；对于方格大小固定的情况，窗口越大并行度越高。不过，若窗口设置得过大，不仅会增大内存的开销，而且在发生异常（比如 Crash）的情况下也会引起大量的重复消费，同时还考虑线程切换的开销，建议根据实际情况设置一个合理的值，不管是对于方格还是窗口而言，过大或过小都不合适。

如果一个方格内的消息无法被标记为消费完成，那么就会造成 `startOffset` 的悬停。为了使窗口能够继续向前滑动，那么就需要设定一个阈值，当 `startOffset` 悬停一定的时间后就对这部分消息进行本地重试消费，如果重试失败就转入重试队列，如果还不奏效就转入死信队列。真实应用中无法消费的情况极少，一般是由业务代码的处理逻辑引起的，比如消息中的内容格式与业务处理的内容格式不符，无法对这条消息进行决断，这种情况可以通过优化代码逻辑或采取丢弃策略来避免。如果需要消息高度可靠，也可以将无法进行业务逻辑的消息（这类消息可以称为死信）存入磁盘、数据库或 Kafka，然后继续消费下一条消息以保证整体消费进度合理推进，之后可以通过一个额外的处理任务来分析死信进而找出异常的原因。
