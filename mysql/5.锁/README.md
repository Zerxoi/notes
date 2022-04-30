# 锁

## 概念

锁机制用于管理对共享资源的并发访问。数据库系统使用锁是为了支持对共享资源进行并发访问，提供数据的完整性和一致性。

InnoDB存储引擎会在行级别上对**表数据**上锁，也会在**数据库内部**其他多个地方使用锁，从而允许对多种不同资源提供并发访问。例如，操作缓冲池中的LRU列表，删除、添加、移动LRU列表中的元素，为了保证一致性，必须有锁的介入。

## lock 与 latch

在数据库中，lock与latch都可以被称为“锁”。

**latch**一般称为闩锁（轻量级的锁），因为其要求锁定的时间必须非常短。若持续的时间长，则应用的性能会非常差。在InnoDB存储引擎中，latch又可以分为`mutex`（互斥量）和`rwlock`（读写锁）。latch的对象是*线程*，其目的是用来保证并发线程操作*内存*中临界资源的正确性，并且通常*没有死锁检测的机制*。

**lock**的对象是*事务*，用来锁定的是*数据库中的对象*，如表、页、行。并且一般lock的对象仅在事务`commit`或`rollback`后进行释放（不同事务隔离级别释放的时间可能不同）。此外，`lock`同大多数数据库中一样，是*有死锁机制*的。

![lock与latch的比较](imgs/lock%E4%B8%8Elatch%E7%9A%84%E6%AF%94%E8%BE%83.png)

对于InnoDB存储引擎中的latch，可以通过命令`SHOW ENGINE INNODB MUTEX`来进行查看。

## InnoDB存储引擎中的锁

### 锁的类型

#### 行级锁

InnoDB存储引擎实现了如下两种标准的**行级锁**：

- **共享锁（S Lock）**，允许事务读一行数据。
- **排他锁（X Lock）**，允许事务删除或更新一行数据。

![共享锁和排他锁的兼容性](imgs/%E5%85%B1%E4%BA%AB%E9%94%81%E5%92%8C%E6%8E%92%E4%BB%96%E9%94%81%E7%9A%84%E5%85%BC%E5%AE%B9%E6%80%A7.png)

可以发现X锁与任何的锁都不兼容，而S锁仅和S锁兼容。需要特别注意的是，S和X锁都是行锁，兼容是指对同一记录（row）锁的兼容性情况。

#### 意向锁

InnoDB存储引擎支持**多粒度（granular）锁定**，这种锁定允许事务在行级上的锁和表级上的锁同时存在。为了支持在不同粒度上进行加锁操作，InnoDB存储引擎支持一种额外的锁方式，称之为**意向锁（Intention Lock）**。意向锁是将锁定的对象分为多个层次，意向锁意味着事务希望在更细粒度（fine granularity）上进行加锁。

若将上锁的对象看成一棵树，那么对最下层的对象上锁，也就是对最细粒度的对象进行上锁，那么首先需要对粗粒度的对象上锁。例如下图，如果需要对页上的**记录r**进行上X锁，那么分别需要对*数据库A*、*表*、*页*上意向锁IX，最后对**记录r**上X锁。若其中任何一个部分导致等待，那么该操作需要等待粗粒度锁的完成。

![层次结构](imgs/%E5%B1%82%E6%AC%A1%E7%BB%93%E6%9E%84.png)

InnoDB存储引擎支持意向锁设计比较简练，其意向锁即为**表级别**的锁，而并没有页级别的意向锁。设计目的主要是为了在一个事务中揭示下一行将被请求的锁类型。其支持两种意向锁：

- **意向共享锁（IS Lock）**，事务想要获得一张表中某几行的共享锁
- **意向排他锁（IX Lock）**，事务想要获得一张表中某几行的排他锁

由于InnoDB存储引擎支持的是行级别的锁，因此意向锁其实不会阻塞除全表扫以外的任何请求。故表级意向锁与行级锁的兼容性如下表所示。

![InnoDB存储引擎中锁的兼容性](imgs/InnoDB%E5%AD%98%E5%82%A8%E5%BC%95%E6%93%8E%E4%B8%AD%E9%94%81%E7%9A%84%E5%85%BC%E5%AE%B9%E6%80%A7.png)

**演示**

简单创建一个表`test`,插入一些简单的数据。

```sql
CREATE TABLE `test` (
  `id` int NOT NULL AUTO_INCREMENT,
  `num` int NOT NULL,
  `str` varchar(128) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `test` (`num`, `str`) VALUES ('1', 'foo'), ('1', 'bar'), ('2', 'foobar'), ('3', 'hello world');
```

如果我们直接对`test`表记录进行如下修改，实际上会在在`test`表上添加一个IX意向锁，因为现在`test`表上没有其他锁，所以兼容；之后再在id等于4的列上添加X锁，同样锁兼容，因此修改成功。

```sql
UPDATE `test` SET `num` = '4' WHERE (`id` = '4');
```

但是如果在修改之前先为`test`表添加一个S锁，之后在进行修改。

```sql
-- 为test表添加S锁
LOCK TABLE test READ;
-- 无法修改
UPDATE `test` SET `num` = '4' WHERE (`id` = '4');
```

执行上述SQL会发现无法对记录进行修改，因为在对id为4的记录添加X所之前，会先对`test`表添加IX意向锁。但是在`test`表添加意向锁之前，`test`表上有S锁，因为S锁与IX意向锁不锁兼容，所以无法修改，要等到`test`表S锁解锁后才能够修改。

```sql
-- 表解锁
UNLOCK tables;
-- 修改成功
UPDATE `test` SET `num` = '4' WHERE (`id` = '4');
```

### 锁的信息

> 注：要求MySQL版本大于8.0

`SHOW ENGINE INNODB STATUS`命令来查看当前锁请求的信息：

```
...
------------
TRANSACTIONS
------------
Trx id counter 23026
Purge done for trx's n:o < 23024 undo n:o < 0 state: running but idle
History list length 0
LIST OF TRANSACTIONS FOR EACH SESSION:
---TRANSACTION 421962756665288, not started
0 lock struct(s), heap size 1128, 0 row lock(s)
---TRANSACTION 421962756664480, not started
0 lock struct(s), heap size 1128, 0 row lock(s)
---TRANSACTION 421962756663672, not started
0 lock struct(s), heap size 1128, 0 row lock(s)
---TRANSACTION 421962756662056, not started
0 lock struct(s), heap size 1128, 0 row lock(s)
---TRANSACTION 421962756661248, not started
0 lock struct(s), heap size 1128, 0 row lock(s)
---TRANSACTION 421962756660440, not started
0 lock struct(s), heap size 1128, 0 row lock(s)
---TRANSACTION 421962756659632, not started
0 lock struct(s), heap size 1128, 0 row lock(s)
---TRANSACTION 421962756658824, not started
0 lock struct(s), heap size 1128, 0 row lock(s)
...
```

**事务信息**被存储在`information_schema`架构下的`INNODB_TRX`表中。`INNODB_TRX`表由8个字段组成。

![表INNODB_TRX的结构说明](imgs/%E8%A1%A8INNODB_TRX%E7%9A%84%E7%BB%93%E6%9E%84%E8%AF%B4%E6%98%8E.png)

InnoDB的**锁信息**被存储在`performance_schema`架构下的`data_locks`表中，该表有如下字段组成。

![data_locks的结构](imgs/data_locks%E7%9A%84%E7%BB%93%E6%9E%84.png)

在通过表`data_locks`查看了每张表上锁的情况后，用户就可以来判断由此引发的等待情况了。当事务较小时，用户就可以人为地、直观地进行判断了。但是当事务量非常大，其中锁和等待也时常发生，这个时候就不这么容易判断。但是通过`performance_schema`架构下的`data_lock_waits`表，可以很直观地反映当前事务的等待。表`data_lock_waits`由4个字段组成。

![data_lock_waits的结构](imgs/data_lock_waits%E7%9A%84%E7%BB%93%E6%9E%84.png)
