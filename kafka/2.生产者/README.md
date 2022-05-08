# 生产者

## 客户端开发

一个正常的生产逻辑需要具备以下几个步骤：

1. 配置生产者客户端参数
2. 创建相应的生产者实例
3. 构建待发送的消息
4. 发送消息
5. 关闭生产者实例

生产者客户端示例代码如下：

```java
public class ProducerFastStart {
    public static final String brokerList = "localhost:29092,localhost:29093,localhost:29094";
    public static final String topic = "topic-demo";

    public static void main(String[] args) {
        Properties properties = new Properties();
        properties.put("bootstrap.servers", brokerList);
        properties.put("key.serializer", StringSerializer.class.getName());
        properties.put("value.serializer", StringSerializer.class.getName());
        properties.put("client.id", "producer.client.id.demo");
        //配置生产者客户端参数并创建 KafkaProducer 实例
        KafkaProducer<String, String> producer = new KafkaProducer<>(properties);
        //构建所需要发送的消息
        ProducerRecord<String, String> record = new ProducerRecord<>(topic, "Hello, Kafka!");
        producer.send(record);

        //关闭生产者客户端示例
        producer.close();
    }
}
```

接下来我们将按照生产逻辑的各个步骤来一一做相应分析。

### 生产者客户端参数配置

在创建真正的生产者实例前需要配置相应的参数，在 Kafka 生产者客户端 KafkaProducer 中有 3 个参数是**必填**的。

- `bootstrap.servers`：该参数用来指定**生产者客户端连接 Kafka 集群所需的 broker 地址清单**，具体的内容格式为 `host1:port1,host2:port2`，可以设置一个或多个地址，中间以逗号隔开，此参数的默认值为 `""`。注意这里并非需要所有的 broker 地址，因为生产者会从给定的 broker 里查找到其他 broker 的信息。不过建议至少要设置两个以上的 broker 地址信息，当其中任意一个宕机时，生产者仍然可以连接到 Kafka集群上。
- `key.serializer` 和 `value.serializer`：broker 端接收的消息必须以字节数组（`byte[]`）的形式存在。上述代码中生产者使用的 `KafkaProducer<String, String>` 和 `ProducerRecord<String, String>` 中的泛型 `<String, String>` 对应的就是消息中 `key` 和 `value` 的类型，生产者客户端使用这种方式可以让代码具有良好的可读性，不过在发往 broker 之前需要将**消息中对应的 `key` 和 `value` 做相应的序列化操作来转换成字节数组**。`key.serializer` 和 `value.serializer` 这两个参数分别用来指定 `key` 和 `value` 序列化操作的序列化器，这两个参数无默认值且必须填写序列化器的全限定名。

KafkaProducer 中的参数众多，除了上述必填的参数外，代码中还设置了参数`client.id`，这个参数用来设定 KafkaProducer 对应的客户端 id，默认值为`""`。如果客户端不设置，则 KafkaProducer 会自动生成一个非空字符串，内容形式如`producer-1`、`producer-2`，即字符串`producer-`与数字的拼接。

### 创建生产者实例

在配置完参数之后就可以使用它来创建一个生产者实例，示例如下：

```java
KafkaProducer<String, String> producer = new KafkaProducer<>(properties);
```

KafkaProducer 是**线程安全**的，可以在多个线程中共享单个 KafkaProducer 实例，也可以将 KafkaProducer 实例进行池化来供其他线程调用。

### 消息的构建

构建的消息对象 ProducerRecord，它并不是单纯意义上的消息，它包含了多个属性，原本需要发送的与业务相关的消息体只是其中的一个 `value` 属性。`ProducerRecord` 类的定义如下（只截取成员变量）：

```java
public class ProducerRecord<K, V> {
    private final String topic; //主题
    private final Integer partition; //分区号
    private final Headers headers; //消息头部
    private final K key; //键
    private final V value; //值
    private final Long timestamp; //消息的时间戳
    //省略其他成员方法和构造方法
}
```

- `topic` 和 `partition` 字段分别代表消息要发往的**主题**和**分区号**。
- `headers` 字段是**消息的头部**，Kafka 0.11.x 版本才引入这个属性，它大多用来设定一些与应用相关的信息，如无需要也可以不用设置。
- `key` 是用来指定**消息的键**，它不仅是消息的*附加信息*，还可以用来*计算分区号*进而可以让消息发往特定的分区。前面提及消息以主题为单位进行归类，而这个 `key` 可以让消息再进行二次归类，同一个 `key` 的消息会被划分到同一个分区中。有 `key` 的消息还可以支持*日志压缩的功能*。
- `value` 是指**消息体**，一般不为空，如果为空则表示特定的消息——*墓碑消息*。
- `timestamp` 是指消息的时间戳，它有 `CreateTime` 和 `LogAppendTime` 两种类型，前者表示消息创建的时间，后者表示消息追加到日志文件的时间。

### 消息的发送

创建生产者实例和构建消息之后，就可以开始发送消息了。发送消息主要有三种模式：**发后即忘（fire-and-forget）**、**同步（sync）**及**异步（async）**。

#### 发后即忘

生产者客户端示例代码中的发送方式 `producer.send(record);` 就是**发后即忘**，它只管往 Kafka 中发送消息而并**不关心消息是否正确到达**。在大多数情况下，这种发送方式没有什么问题，不过在某些时候（比如发生不可重试异常时）会造成消息的丢失。这种发送方式的**性能最高**，**可靠性也最差**。

#### 同步

KafkaProducer 的 `send()` 方法并非是 `void` 类型，而是 `Future<RecordMetadata>` 类型，`send()` 方法有 2 个重载方法，具体定义如下：

```java
public Future<RecordMetadata> send(ProducerRecord<K, V> record)
public Future<RecordMetadata> send(ProducerRecord<K, V> record, Callback callback)
```

要实现**同步发送方式**，可以利用返回的 `Future` 对象实现，示例如下：

```java
try {
    RecordMetadata metadata = producer.send(record).get();
    System.out.println(metadata.topic() + "-" + metadata.partition() + ":" + metadata.offset());
} catch (ExecutionException | InterruptedException e) {
    e.printStackTrace();
}
```

实际上 `send()` 方法本身就是异步的，`send()` 方法返回的 `Future` 对象可以使调用方稍后获得发送的结果。在执行 send()方法之后直接链式调用了 `get()` 方法来阻塞等待 Kafka 的响应，直到消息发送成功，或者发生异常。如果发生异常，那么就需要捕获异常并交由外层逻辑处理。

从 `Future<RecordMetadata>` 对象中可以获取一个 `RecordMetadata` 对象，在 `RecordMetadata` 对象里包含了消息的一些元数 据信息，比如当前消息的**主题**、**分区号**、**分区中的偏移量（offset）**、**时间戳**等。

`Future` 表示一个任务的生命周期，并提供了相应的方法来判断任务是否已经完成或取消，以及获取任务的结果和取消任务等。既然 `KafkaProducer.send()` 方法的返回值是一个 `Future` 类型的对象，那么完全可以用 Java 语言层面的技巧来丰富应用的实现，比如使用 `Future` 中的 `get(long timeout, TimeUnit unit)` 方法实现**可超时的阻塞**。

同步发送的方式**可靠性高**，要么消息被发送成功，要么发生异常。如果发生异常，则可以
捕获并进行相应的处理，而不会像“发后即忘”的方式直接造成消息的丢失。不过同步发送的
方式的**性能会差很多**，需要阻塞等待一条消息发送完之后才能发送下一条。

#### 异步

对于**异步发送**的方式，一般是在 `send()` 方法里指定一个 `Callback` 的**回调函数**，Kafka 在返回响应时调用该函数来实现异步的发送确认。

**回调函数和`Future`的对比**：有读者或许会有疑问，`send()` 方法的返回值类型就是 `Future`，而 `Future` 本身就可以用作异步的逻辑处理。这样做不是不行，只不过 Future 里的 `get()` 方法在何时调用，以及怎么调用都是需要面对的问题，消息不停地发送，那么诸多消息对应的 `Future` 对象的处理难免会引起代码处理逻辑的混乱。使用 `Callback` 的方式非常简洁明了，Kafka 有响应时就会回调，要么发送成功，要么抛出异常。

异步发送方式的示例如下：

```java
producer.send(record, new Callback() {
    @Override
    public void onCompletion(RecordMetadata metadata, Exception exception) {
        if (exception != null) {
            exception.printStackTrace();
        } else {
            System.out.println(metadata.topic() + "-" + metadata.partition() + ":" + metadata.offset());
        }
    }
});
```

`onCompletion()` 方法的**两个参数是互斥的**，消息发送成功时，`metadata` 不为 `null` 而 `exception` 为 `null`；消息发送异常时，`metadata` 为 `null` 而 `exception` 不为 `null`。

```java
producer.send(record1, callback1);
producer.send(record2, callback2);
```

对于同一个分区而言，如果消息 `record1` 于 `record2` 之前先发送（参考上面的示例代码），那么 KafkaProducer 就可以保证对应的 `callback1` 在 `callback2` 之前调用，也就是说，**回调函数的调用也可以保证分区有序**。

#### 发送异常

KafkaProducer 中一般会发生两种类型的异常：**可重试的异常**和**不可重试的异常**。

常见的**可重试异常**有：`NetworkException`、`LeaderNotAvailableException`、`UnknownTopicOrPartitionException`、`NotEnoughReplicasException`、`NotCoordinatorException` 等。比如 `NetworkException` 表示网络异常，这个有可能是由于网络瞬时故障而导致的异常，可以通过重试解决；又比如 `LeaderNotAvailableException` 表示分区的 leader 副本不可用，这个异常通常发生在 leader 副本下线而新的 leader 副本选举完成之前，重试之后可以重新恢复。

对于可重试的异常，如果配置了 `retries` 参数，那么只要在规定的重试次数内自行恢复了，就不会抛出异常。`retries` 参数的默认值为 `0`。如果重试了 `retries` 次之后还没有恢复，那么仍会抛出异常，进而发
送的外层逻辑就要处理这些异常了。

**不可重试的异常**，比如 `RecordTooLargeException` 异常，暗示了所发送的消息太大，KafkaProducer 对此不会进行任何重试，直接抛出异常。

### 关闭生产者实例

`close()` 方法会阻塞等待之前所有的发送请求完成后再关闭 KafkaProducer。与此同时，KafkaProducer 还提供了一个带超时时间的 `close()` 方法，具体定义如下：

```java
public void close(long timeout, TimeUnit timeUnit)
```

如果调用了带超时时间 `timeout` 的 `close()` 方法，那么只会在等待 `timeout` 时间内来完成所有尚未完成的请求处理，然后强行退出。在实际应用中，一般使用的都是无参的 `close()` 方法。

## 序列化

生产者需要用**序列化器（Serializer）**把对象转换成字节数组才能通过网络发送给 Kafka。而在对侧，消费者需要用**反序列化器（Deserializer）**把从 Kafka 中收到的字节数组转换成相应的对象。

![序列化](imgs/%E5%BA%8F%E5%88%97%E5%8C%96.drawio.png)

在生产者客户端代码中，为了方便，消息的 `key` 和 `value` 都使用了字符串，对应程序中的序列化器也使用了客户端自带的 `org.apache.kafka.common.serialization.StringSerializer`，除了用于 `String` 类型的序列化器，还有 `ByteArray`、`ByteBuffer`、`Bytes`、`Double`、`Integer`、`Long` 这几种类型，它们都实现了 `org.apache.kafka.common.serialization.Serializer` 接口，此接口有 3 个方法：

```java
public void configure(Map<String, ?> configs, boolean isKey)
public byte[] serialize(String topic, T data)
public void close()
```

`configure()`方法用来配置当前类，`serialize()`方法用来执行序列化操作。而 `close()`方法用来关闭当前的序列化器，一般情况下 `close()`是一个空方法，如果实现了此方法，则必须确保此方法的幂等性，因为这个方法很可能会被 KafkaProducer 调用多次。

生产者使用的序列化器和消费者使用的反序列化器是需要一一对应的。

## 生产者拦截器

生产者拦截器既可以用来**在消息发送前做一些准备工作**，比如*按照某个规则过滤不符合要求的消息*、*修改消息的内容*等，也可以用来在**发送回调逻辑前做一些定制化的需求**，比如*统计类工作*。

生产者拦截器的使用也很方便，主要是自定义实现 `org.apache.kafka.clients.producer.ProducerInterceptor` 接口。ProducerInterceptor 接口中包含 3 个方法：

```java
public ProducerRecord<K, V> onSend(ProducerRecord<K, V> record);
public void onAcknowledgement(RecordMetadata metadata, Exception exception);
public void close();
```

KafkaProducer *在将消息序列化和计算分区之前*会调用生产者拦截器的 `onSend()` 方法来**对消息进行相应的定制化操作**。一般来说最好不要修改消息 ProducerRecord 的 `topic`、`key` 和 `partition` 等信息，如果要修改，则需确保对其有准确的判断，否则会与预想的效果出现偏差。比如修改 `key` 不仅会影响分区的计算，同样会影响broker端日志压缩（Log Compaction）的功能。

KafkaProducer 会在*消息被应答（Acknowledgement）之前*或*消息发送失败时*调用生产者拦截器的  `onAcknowledgement()` 方法，*优先于用户设定的 Callback 之前执行*。这个方法运行在Producer 的 I/O 线程中，所以这个方法中实现的代码逻辑越简单越好，否则会影响消息的发送速度。

`close()` 方法主要用于**在关闭拦截器时执行一些资源的清理工作**。

在这 3 个方法中抛出的异常都会被捕获并记录到日志中，但并不会再向上传递。

`ProducerInterceptor` 接口还有一个父接口 `org.apache.kafka.common.Configurable`，这个接口中只有一个方法：

```java
void configure(Map<String, ?> configs);
```

`Configurable` 接口中的 `configure()` 方法主要用来获取配置信息及初始化数据。

KafkaProducer通过 `interceptor.classes` 参数来指定拦截器，此参数的默认值为 `""`。KafkaProducer中不仅可以指定一个拦截器，还可以指定多个拦截器以形成拦截链（各个拦截器之间使用逗号隔开）。拦截链中的 `onSend()` 和 `onAcknowledgement()` 方法会按照 `interceptor.classes` 参数配置的拦截器的顺序执行。

在拦截链中，如果某个拦截器执行失败，操作并不会终止而是执行下一个拦截器，那么下一个拦截器会接着从上一个执行成功的拦截器继续执行。

## 分区器

消息在通过 `send()` 方法发往broker的过程中，有可能需要经过**拦截器（Interceptor）**、**序列化器（Serializer）**和**分区器（Partitioner）**的一系列作用之后才能被真正地发往 broker。拦截器一般不是必需的，而序列化器是必需的。

消息经过序列化之后就需要确定它发往的分区，如果消息 `ProducerRecord` 中指定了 `partition` 字段，那么就不需要分区器的作用，因为 `partition` 代表的就是所要发往的分区号。如果消息 `ProducerRecord` 中没有指定 `partition` 字段，那么就需要依赖分区器，根据key这个字段来计算 `partition` 的值。**分区器的作用就是为消息分配分区**。

afka中提供的默认分区器是 `org.apache.kafka.clients.producer.internals.DefaultPartitioner`，它实现了 `org.apache.kafka.clients.producer.Partitioner` 接口，这个接口中定义了2个方法，具体如下所示。

```java
public int partition(String topic, Object key, byte[] keyBytes, Object value, byte[] valueBytes, Cluster cluster);
public void close();
```

- `partition()` 方法用来**计算分区号**，返回值为 `int` 类型。`partition()` 方法中的参数分别表示*主题*、*键*、*序列化后的键*、*值*、*序列化后的值*，以及*集群的元数据信息*，通过这些信息可以实现功能丰富的分区器。
- `close()`方法在关闭分区器的时候用来**回收一些资源**。

`Partitioner` 接口和上一节的生产者拦截器 `ProducerInterceptor` 接口一样，它也有一个同样的父接口 `Configurable`。

在默认分区器 `DefaultPartitioner` 的实现中，`close()` 是空方法，而在 `partition()` 方法中定义了主要的分区分配逻辑。如果 `key` 不为 `null`，那么默认的分区器会对 `key` 进行哈希（采用 `MurmurHash2` 算法，具备高运算性能及低碰撞率），最终根据得到的哈希值来计算分区号，拥有相同 `key` 的消息会被写入同一个分区。如果 `key` 为 `null`，那么消息将会以轮询的方式发往主题内的各个**可用分区**。

> 注意：如果 `key` 不为 `null`，那么计算得到的分区号会是所有分区中的任意一个；如果 `key` 为 `null`，那么计算得到的分区号仅为可用分区中的任意一个，注意两者之间的差别。

除了使用 Kafka 提供的默认分区器进行分区分配，还可以使用自定义的分区器，只需同
`DefaultPartitioner` 一样实现 `Partitioner` 接口即可。

## 原理分析

### 整体架构

![生产者客户端的整体架构](imgs/%E7%94%9F%E4%BA%A7%E8%80%85%E5%AE%A2%E6%88%B7%E7%AB%AF%E7%9A%84%E6%95%B4%E4%BD%93%E6%9E%B6%E6%9E%84.jpg)

整个生产者客户端由两个线程协调运行，这两个线程分别为**主线程**和**Sender 线程**。

- **主线程**中由KafkaProducer 创建消息，然后通过可能的*拦截器*、*序列化器*和*分区器*的作用之后缓存到*消息累加器（RecordAccumulator，也称为消息收集器）*中。
- **Sender 线程**负责从RecordAccumulator 中获取消息并将其发送到Kafka 中。

---

**RecordAccumulator** 主要用来*缓存消息以便Sender 线程可以批量发送，进而减少网络传输的资源消耗以提升性能*。RecordAccumulator 缓存的大小可以通过生产者客户端参数 `buffer.memory` 配置，默认值为 `33554432B`，即 `32MB`。如果生产者发送消息的速度超过发送到服务器的速度，则会导致生产者空间不足(更准确的说是 RecordAccumulator 满了)，这个时候KafkaProducer 的 `send()` 方法调用要么被阻塞。如果阻塞时间超过参数 `max.block.ms` 配置的超时时间（默认值 `60000`，即60秒），就会抛出异常。

主线程中发送过来的消息都会被追加到 RecordAccumulator 的某个双端队列（Deque）中，**在RecordAccumulator 的内部为每个分区都维护了一个双端队列**， 队列中的内容就是 `ProducerBatch`，即 `Deque<ProducerBatch>`。消息写入缓存时，追加到双端队列的尾部；Sender读取消息时，从双端队列的头部读取。注意 `ProducerBatch` 不是 `ProducerRecord`，`ProducerBatch`中可以包含一至多个 `ProducerRecord`。通俗地说，`ProducerRecord` 是生产者中创建的消息，而 `ProducerBatch` 是指一个消息批次，`ProducerRecord` 会被包含在 `ProducerBatch` 中，这样可以使字节的使用更加紧凑。与此同时，将较小的 `ProducerRecord` 拼凑成一个较大的 `ProducerBatch`，也可以减少网络请求的次数以提升整体的吞吐量。如果生产者客户端需要向很多分区发送消息， 则可以将 `buffer.memory` 参数适当调大以增加整体的吞吐量。

消息在网络上都是以字节（Byte）的形式传输的，在发送之前需要创建一块内存区域来保存对应的消息。在Kafka 生产者客户端中，通过 `java.io.ByteBuffer` 实现消息内存的创建和释放。不过频繁的创建和释放是比较耗费资源的，在RecordAccumulator 的内部还有一个**BufferPool**，它主要用来*实现ByteBuffer 的复用，以实现缓存的高效利用*。不过 **BufferPool 只针对特定大小的 ByteBuffer 进行管理**，而其他大小的 ByteBuffer 不会缓存进BufferPool 中，这个特定的大小由 `batch.size` 参数来指定，默认值为 `16384B`，即 `16KB`。我们可以适当地调大 `batch.size` 参数以便多缓存一些消息。

ProducerBatch 的大小和 `batch.size` 参数也有着密切的关系。当一条消息（`ProducerRecord`）流入RecordAccumulator 时，会先寻找与消息分区所对应的双端队列（如果没有则新建），再从这个双端队列的尾部获取一个 `ProducerBatch`（如果没有则新建），查看 `ProducerBatch` 中是否还可以写入这个 `ProducerRecord`， 如果可以则写入， 如果不可以则需要创建一个新的 `ProducerBatch`。在新建`ProducerBatch` 时评估这条消息的大小是否超过 `batch.size` 参数的大小，如果不超过，那么就以`batch.size` 参数的大小来创建 `ProducerBatch`，这样在使用完这段内存区域之后，可以通过`BufferPool` 的管理来进行复用；如果超过，那么就以评估的大小来创建 `ProducerBatch`，这段内存区域不会被复用。

---

Sender 从 RecordAccumulator 中获取缓存的消息之后，会进一步将原本 `<分区, Deque<ProducerBatch>>` 的保存形式转变成 `<Node, List<ProducerBatch>>` 的形式，其中 `Node` 表示**Kafka集群的broker 节点**。对于**网络连接**来说，生产者客户端是与*具体的broker 节点*建立的连接，也就是向具体的broker 节点发送消息，而并不关心消息属于哪一个分区；而对于**KafkaProducer的应用逻辑**而言，我们只关注向哪个*分区*中发送哪些消息，所以在这里需要做一个应用**逻辑层面**到**网络I/O 层面**的转换。

在转换成 `<Node, List<ProducerBatch>>` 的形式之后，Sender 还会进一步封装成 `<Node, Request>` 的形式，这样就可以将 `Request` 请求发往各个 Node 了，这里的 Request 是指 Kafka 的各种协议请求，对于消息发送而言就是指具体的 `ProduceRequest`。

请求在从 Sender 线程发往 Kafka 之前还会保存到 `InFlightRequests` 中，`InFlightRequests` 保存对象的具体形式为 `Map<NodeId, Deque<Request>>`，它的主要作用是**缓存了已经发出去但还没有收到响应的请求**（`NodeId` 是一个 `String` 类型，表示节点的 id 编号）。与此同时，`InFlightRequests` 还提供了许多管理类的方法，并且通过配置参数还可以限制每个连接（也就是客户端与Node 之间的连接）最多缓存的请求数。这个配置参数为 `max.in.flight.requests.per. connection`，默认值为 `5`，即每个连接最多只能缓存 5 个未响应的请求，超过该数值之后就不能再向这个连接发送更多的请求了，除非有缓存的请求收到了响应（Response）。通过比较 `Deque<Request>` 的 `size` 与这个参数的大小来判断对应的 Node 中是否已经堆积了很多未响应的消息，如果真是如此，那么说明这个 Node 节点负载较大或网络连接有问题，再继续向其发送请求会增大请求超时的可能。

### 元数据的更新

`InFlightRequests` 还可以获得 `leastLoadedNode`，即**所有 Node 中负载最小的那一个**。这里的负载最小是通过每个 `Node` 在 `InFlightRequests` 中还未确认的请求决定的，*未确认的请求越多则认为负载越大*。选择 `leastLoadedNode` 发送请求可以使它能够尽快发出，*避免因网络拥塞等异常*而影响整体的进度。`leastLoadedNode` 的概念可以用于多个应用场合，比如**元数据请求**、**消费者组播协议的交互**。

对于一条消息 `ProducerRecord`，生产者只知道消息的主题名称，`key` 和 `value` 等信息，对于其他一些必要的信息却一无所知。`KafkaProducer` 要将此消息追加到指定主题的某个分区所对应的 leader 副本之前，首先需要知道*主题的分区数量*，然后经过计算得出（或者直接指定）目标分区，之后KafkaProducer 需要知道*目标分区的 leader 副本所在的 broker 节点的地址、端口等信息*才能建立连接，最终才能将消息发送到Kafka，在这一过程中所需要的信息都属于**元数据信息**。

在创建生产者客户端时指定的 `bootstrap.servers` 参数只需要配置部分 broker 节点的地址即可，不需要配置所有 broker 节点的地址，因为**客户端可以自己发现其他 broker 节点的地址**，这一过程也属于元数据相关的更新操作。与此同时，分区数量及 leader 副本的分布都会动态地变化，**客户端也需要动态地捕捉这些变化**。

**元数据是指 Kafka 集群的元数据**，这些元数据具体记录了*集群中有哪些主题*，这些*主题有哪些分区*，*每个分区的leader 副本分配在哪个节点上*，*follower 副本分配在哪些节点上*，*哪些副本在AR、ISR 等集合中*，*集群中有哪些节点*，*控制器节点又是哪一个*等信息。

*当客户端中没有需要使用的元数据信息时*或者*超过 `metadata.max.age.ms` 时间没有更新元数据*都会引起**元数据的更新操作**。客户端参数 `metadata.max.age.ms` 的默认值为 `300000`，即 `5` 分钟。元数据的更新操作是在客户端内部进行的，对客户端的外部使用者不可见。当需要更新元数据时，会先挑选出 `leastLoadedNode`，然后向这个 `Node` 发送 `MetadataRequest` 请求来获取具体的元数据信息。这个更新操作是由 Sender 线程发起的，在创建完 `MetadataRequest` 之后同样会存入`InFlightRequests`，之后的步骤就和发送消息时的类似。元数据虽然由 Sender 线程负责更新，但是主线程也需要读取这些信息，这里的数据同步通过 `synchronized` 和 `final` 关键字来保障。

## 重要的生产者参数

- `acks` 参数用来指定**分区中必须要有多少个副本收到这条消息，之后生产者才会认为这条消息是成功写入的**。`acks` 是生产者客户端中一个非常重要的参数，它涉及消息的可靠性和吞吐量之间的权衡。`acks` 参数有 3 种类型的值（都是字符串类型）。
  - `acks = 1`。默认值即为 `1`。生产者发送消息之后，只要**分区的 leader 副本成功写入消息**，那么它就会收到来自服务端的成功响应。
    - 如果消息**无法写入 leader 副本**，比如在leader 副本崩溃、重新选举新的 leader 副本的过程中，那么生产者就会收到一个错误的响应（可重试异常），为了避免消息丢失，生产者可以选择重发消息。
    - 如果消息写入 leader 副本并返回成功响应给生产者，且在被**其他 follower 副本拉取之前 leader 副本崩溃**，那么此时消息还是会丢失，因为新选举的 leader 副本中并没有这条对应的消息。
    - 因此 `acks` 设置为 `1` 是**消息可靠性和吞吐量之间的折中方案**。
  - `acks = 0`。生产者发送消息之后**不需要等待任何服务端的响应**。
    - 如果在消息从发送到写入 Kafka 的过程中出现某些异常，导致 Kafka 并没有收到这条消息，那么生产者也无从得知，消息也就丢失了。
    - 在其他配置环境相同的情况下，acks 设置为 `0` 可以达到**最大的吞吐量**。
  - `acks = -1` 或 `acks = all`。生产者在消息发送之后，需要**等待 ISR 中的所有副本都成功写入消息**之后才能够收到来自服务端的成功响应。
    - 在其他配置环境相同的情况下，`acks` 设置为 `-1`（`all`）可以达到**最强的可靠性**。
    - 但这并不意味着消息就一定可靠，因为 ISR 中可能只有 leader 副本，这样就退化成了 `acks = 1` 的情况。
    - 要获得更高的消息可靠性需要配合 `min.insync.replicas` 等参数的联动。
- `max.request.size` 参数用来**限制生产者客户端能发送的消息的最大值**，默认值为 `1048576B`，即 `1MB`。一般情况下，这个默认值就可以满足大多数的应用场景了。
  - 不建议盲目地增大这个参数的配置值，尤其是在对 Kafka 整体脉络没有足够把控的时候。因为这个参数还涉及一些其他参数的联动，比如 broker 端的 `message.max.bytes` 参数，如果配置错误可能会引起一些不必要的异常。
- `retries` 参数用来配置**生产者重试的次数**，默认值为 `0`，即在发生异常的时候不进行任何重试动作。
  - 对于**可重试异常**，比如网络抖动、leader 副本的选举等，这种异常往往是可以自行恢复的，生产者可以通过配置 `retries` 大于 `0` 的值，以此通过内部重试来恢复而不是一味地将异常抛给生产者的应用程序。如果重试达到设定的次数，那么生产者就会放弃重试并返回异常。
  - 不过并不是所有的异常都是可以通过重试来解决的（**不可重试异常**），比如消息太大，超过 `max.request.size` 参数配置的值时，这种方式就不可行了。
  - Kafka 可以保证同一个分区中的**消息是有序的**。如果生产者按照一定的顺序发送消息，那么这些消息也会顺序地写入分区，进而消费者也可以按照同样的顺序消费它们。对于某些应用来说，顺序性非常重要，比如 MySQL 的 binlog 传输，如果出现错误就会造成非常严重的后果。如果将 `acks` 参数配置为非零值，并且 `max.in.flight.requests.per.connection` 参数配置为大于 `1` 的值，那么就会出现错序的现象：如果第一批次消息写入失败，而第二批次消息写入成功，那么生产者会重试发送第一批次的消息，此时如果第一批次的消息写入成功，那么这两个批次的消息就出现了错序。一般而言，在需要保证消息顺序的场合建议把参数 `max.in.flight.requests.per.connection` 配置为 `1`，而不是把 `acks` 配置为 `0`，不过这样也会影响整体的吞吐。
- `retry.backoff.ms` 参数用来**设定两次重试之间的时间间隔**，避免无效的频繁重试。
  - 在配置 `retries` 和 `retry.backoff.ms` 之前，最好先估算一下可能的异常恢复时间，这样可以设定总的重试时间大于这个异常恢复时间，以此来避免生产者过早地放弃重试。
- `compression.type` 参数用来指定**消息的压缩方式**，默认值为 `none`，即默认情况下，消息不会被压缩。该参数还可以配置为`gzip`、`snappy`和`lz4`。
  - 对消息进行压缩可以极大地**减少网络传输量**、降低网络 I/O，从而提高整体的性能。消息压缩是一种使用时间换空间的优化方式，**如果对时延有一定的要求，则不推荐对消息进行压缩**。
- `connections.max.idle.ms` 参数用来指定在**多久之后关闭限制的连接**(Sender 线程中的与 Node 的连接)，默认值是 `540000`（ms），即 `9` 分钟。
- `linger.ms` 参数用来指定**生产者发送 ProducerBatch 之前等待更多消息（ProducerRecord）加入ProducerBatch 的时间**，默认值为 `0`。
  - 生产者客户端会在 `ProducerBatch` 被填满或等待时间超过`linger.ms` 值时发送出去。增大这个参数的值会**增加消息的延迟**，但是同时能**提升一定的吞吐量**。
- `receive.buffer.bytes` 参数用来设置 **Socket 接收消息缓冲区（SO_RECBUF）的大小**，默认值为 `32768`（B），即 `32KB`。
  - 如果设置为`-1`，则使用操作系统的默认值。如果 Producer 与 Kafka 处于不同的机房，则可以适地调大这个参数值。
- `send.buffer.bytes` 参数用来设置 **Socket 发送消息缓冲区（SO_SNDBUF）的大小**，默认值为 `131072`（B），即 `128KB`。
  - 与 `receive.buffer.bytes` 参数一样，如果设置为 `-1`，则使用操作系统的默认值。
- `request.timeout.ms` 参数用来配置 **Producer 等待请求响应的最长时间**，默认值为 `30000`（ms）。请求超时之后可以选择进行重试（`retries` 参数）。
  - 注意这个参数需要比 broker 端参数 `replica.lag.time.max.ms` 的值要大，这样可以减少因客户端重试而引起的消息重复的概率。
- `bootstrap.servers` 参数指定**连接 Kafka 集群所需的 broker 地址清单**。默认值为 `""`。
- `key.serializer` 参数指定消**息中 `key` 对应的序列化类**，需要实现 `org.apache.kafka.common.serialization.Serializer` 接口。默认值为 `""`。
- `value.serializer` 参数指定**消息中 `value` 对应的序列化类**，需要实现 `org.apache.kafka.common.serialization.Serializer` 接口。默认值为 `""`。
- `buffer.memory` 参数用于指定生产者客户端中缓存消息的缓冲区（RecordAccumulator）的大小，默认值为 `33554432` (B)，即 32 MB。
- `batch.size` 参数用于指定 **ProducerBatch 可以复用内存区域的大小**。默认值为 `16384` (B)，即 `16` KB。
- `client.id` 参数用来设定 **KafkaProducer 对应的客户端 ID**。默认值为 `""`。
- `max.block.ms` 参数用来控制 **KafkaProducer 中 `send()` 方法和 `partitionsFor()` 方法的阻塞时间**。当生产者的发送缓冲区已满，或者没有可用的元数据时，这些方法就会阻塞。默认值为 `60000` (ms)，即 60 s。
- `partitioner.class` 参数用来指定分区器，需要实现 `org.apache.kafka.clients.producer.Partitioner` 接口。默认值为 `org.apache.kafka.clients.producer.internals.DefaultPartitioner`。
- `enable.idempotence` 参数用于控制是否**开启幂等性功能**。默认值为 `false`
- `interceptor.classes` 参数用来**设定生产者拦截器**，需要实现 `org.apache.kafka.clients.producer. ProducerInterceptor` 接口。默认值为 `""`。
- `max.in.flight.requests.per.connection` 参数用于**限制每个连接（也就是客户端与 Node 之间的连接）最多缓存的请求数**。默认值为 `5`。
- `metadata.max.age.ms` 参数用于指定**元数据更新时间间隔**。如果在这个时间内元数据没有更新的话会被强制更新。默认值为 `300000` ms， 即 5 分钟。
- `transactional.id` 参数用于设置**事务 id**，事务 id 必须唯一。默认值为 `null`。
