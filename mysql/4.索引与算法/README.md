# 索引与算法

InnoDB存储引擎支持以下几种常见的索引：

- **B+树索引**
- **全文索引**
- **哈希索引**

MySQL提供了一个`EXPLAIN`命令用于查看SQL语句的执行计划来对SQL语句进行分析, 并输出 SQL 执行的详细信息，以供开发人员针对性优化.

filesort

## B+树索引

### B+树

B+ 树是一种树数据结构，通常用于数据库和操作系统的文件系统中。B+ 树的特点是能够保持数据稳定有序，其插入与修改拥有较稳定的对数时间复杂度。

在B+树中的节点通常被表示为一组有序的元素和子指针。如果此B+树的阶数是`m`，则除了根之外的每个节点都包含最少`⌊m/2⌋`个元素，最多`m-1`个元素，对于任意的结点有最多 `m` 个子指针。对于所有内部节点，子指针的数目总是比元素的数目多一个。所有叶子都在相同的高度上，叶结点本身按关键字大小从小到大链接。

![一棵高度为2的B+树](imgs/%E4%B8%80%E6%A3%B5%E9%AB%98%E5%BA%A6%E4%B8%BA2%E7%9A%84B%2B%E6%A0%91.png)


**B+树的插入操作**

B+树的插入必须保证插入后叶子节点中的记录依然排序，同时需要考虑插入到B+树的三种情况，每种情况都可能会导致不同的插入算法。

![B+树插入的3种情况](imgs/B%2B%E6%A0%91%E6%8F%92%E5%85%A5%E7%9A%843%E7%A7%8D%E6%83%85%E5%86%B5.png)

**B+树的删除操作**

B+树使用填充因子（fill factor）来控制树的删除变化，50%是填充因子可设的最小值。B+树的删除操作同样必须保证删除后叶子节点中的记录依然排序，同插入一样，B+树的删除操作同样需要考虑以下表中的三种情况，与插入不同的是，删除根据填充因子的变化来衡量。

![B+树删除的3种情况](imgs/B%2B%E6%A0%91%E5%88%A0%E9%99%A4%E7%9A%843%E7%A7%8D%E6%83%85%E5%86%B5.png)

### B+树索引类型

数据库中的B+树索引可以分为**聚集索引（clustered inex）**和**辅助索引（secondary index）**，但是不管是聚集还是辅助的索引，其内部都是B+树的，即高度平衡的，叶子节点存放着所有的数据。聚集索引与辅助索引不同的是，叶子节点存放的是否是一整行的信息。

### 聚集索引

InnoDB存储引擎表是**索引组织表**，即表中数据按照主键顺序存放。

而**聚集索引（clustered index）**就是按照每张表的主键构造一棵B+树，同时叶子节点中存放的即为整张表的行记录数据，也将聚集索引的叶子节点称为**数据页**。聚集索引的这个特性决定了索引组织表中数据也是索引的一部分。同B+树数据结构一样，每个数据页都通过一个双向链表来进行链接。

由于实际的数据页只能按照一棵B+树进行排序，因此每张表只能拥有**一个**聚集索引。在多数情况下，查询优化器倾向于采用聚集索引，因为聚集索引能够在B+树索引的叶子节点存上直接找到数据。

聚集索引的数据页上存放的是完整的*每行的记录*，而在非数据页的索引页中存放的仅仅是*键值及指向数据页的偏移量*，而不是一个完整的行记录。

![B+树索引](imgs/B%2B%E6%A0%91%E7%B4%A2%E5%BC%95.png)

**聚集索引的存储并不是物理上连续的，而是逻辑上连续的**。这其中有两点：

1. **页**通过双向链表链接，页按照主键的顺序排序;
2. 每个**页中的记录**也是通过双向链表进行维护的，逻辑上按照主键顺序排序，物理存储上可以不按照主键存储。

由于定义了数据的逻辑顺序，聚集索引能够特别快地访问针对**主键的排序查找和范围查找**。查询优化器能够快速发现某一段范围的数据页需要扫描。

### 辅助索引

对于辅助索引（Secondary Index，也称非聚集索引），叶子节点并不包含行记录的全部数据。叶子节点除了包含**键值**以外，每个叶子节点中的索引行中还包含了一个**书签（bookmark）**。书签用来告诉InnoDB存储引擎哪里可以找到与索引相对应的行数据。由于InnoDB存储引擎表是索引组织表，因此InnoDB存储引擎的辅助索引的书签就是相应行数据的**聚集索引键**。

辅助索引的存在并不影响数据在聚集索引中的组织，因此每张表上可以有**多个辅助索引**。

![辅助索引与聚集索引的关系](imgs/%E8%BE%85%E5%8A%A9%E7%B4%A2%E5%BC%95%E4%B8%8E%E8%81%9A%E9%9B%86%E7%B4%A2%E5%BC%95%E7%9A%84%E5%85%B3%E7%B3%BB.png)

**回表**：当通过辅助索引来寻找数据时，InnoDB存储引擎会遍历辅助索引并通过叶级别的指针获得指向主键索引的主键，然后再通过主键索引来找到一个完整的行记录。

总结：一个表可以有多个非聚集索引，非聚集索引的叶子节点存储当前索引键和书签（聚集索引键），非叶子节点存储当前索引键和页偏移量。

![辅助索引分析](imgs/%E8%BE%85%E5%8A%A9%E7%B4%A2%E5%BC%95%E5%88%86%E6%9E%90.png)

**堆表**

对于其他的一些数据库，如Microsoft SQL Server数据库，其有一种称为**堆表**的表类型，即行数据的存储按照插入的顺序存放。这与MySQL数据库的MyISAM存储引擎有些类似。堆表的特性决定了堆表上的索引都是非聚集的，主键与非主键的区别只是是否唯一且非空（NOT NULL）。因此这时书签是一个行标识符（Row Identifiedr，RID），可以用如“文件号：页号：槽号”的格式来定位实际的行数据。

对于非聚集索引的离散读取，索引组织表上的非聚集索引会比堆表上的聚集索引慢一些（因为需要回表），并且非聚集可能在一张表中存在多个，那么为什么还需要索引组织表？

在一些情况下，使用堆表的确会比索引组织表更快，但是我觉得大部分原因是由于存在**OLAP**的应用，在索引组织表中OLAP查询需要大量的回表查询。表中数据是否需要更新，并且更新是否影响到**物理地址的变更**（因为堆表的书签是行的物理地址）。另一个不能忽视的是对于**排序和范围查找**，索引组织表通过B+树的中间节点就可以找到要查找的所有页，然后进行读取，而堆表的特性决定了这对其是不能实现的。最后，多次**非聚集索引的离散读**效率会很低，但是一般的数据库都通过实现预读（read ahead）技术来避免多次的离散读操作。因此，具体是建堆表还是索引组织表，这取决于应用，不存在哪个更优的问题。

### B+树索引的分裂

**存在的问题**

B+树索引页的分裂并不总是从页的中间记录开始，这样可能会导致页空间的浪费。例如下面的记录：

```
P1: 1、2、3、4、5、6、7、8、9
```

插入是根据自增顺序进行的，若这时插入10这条记录后需要进行页的分裂操作，那么根据B+树的分裂方法，会将记录5作为**分裂点记录（split record）**，分裂后得到下面两个页：

```
P1：1、2、3、4
P2：5、6、7、8、9、10
```

然而由于插入是顺序的，P1这个页中将不会再有记录被插入，从而导致空间的浪费。而P2又会再次进行分裂。

InnoDB存储引擎的Page Header中有以下几个部分用来保存插入的顺序信息：

- `PAGE_LAST_INSERT`：最后插入记录的位置
- `PAGE_DIRECTION`：最后插入记录的方向
- `PAGE_N_DIRECTION`：一个方向连续插入记录的数量

通过这些信息，InnoDB存储引擎可以决定是向左还是向右进行分裂，同时决定将分裂点记录为哪一个。若插入是随机的，则取页的中间记录作为分裂点的记录，这和之前介绍的相同。若往同一方向进行插入的记录数量`PAGE_N_DIRECTION`为5，并且目前已经定位（cursor）到的记录（InnoDB存储引擎插入时，首先需要进行定位，定位到的记录为待插入记录的前一条记录）之后还有3条记录，则分裂点的记录为定位到的记录后的第3条记录，否则分裂点记录就是待插入的记录。

来看一个向右分裂的例子，并且定位到的记录`cursor record`之后还有5条记录，大于3。则分裂记录`split record`为`cursor record`后的第3条记录。向右分裂后得到下图。

![向右分裂的一种情况](imgs/%E5%90%91%E5%8F%B3%E5%88%86%E8%A3%82%E7%9A%84%E4%B8%80%E7%A7%8D%E6%83%85%E5%86%B5.png)

![向右分裂后页中记录的情况](imgs/%E5%90%91%E5%8F%B3%E5%88%86%E8%A3%82%E5%90%8E%E9%A1%B5%E4%B8%AD%E8%AE%B0%E5%BD%95%E7%9A%84%E6%83%85%E5%86%B5.png)

如果定位到的记录`cursor record`之后记录数小于3条，通常自增情况下是0条记录。则分裂记录`split record`为新插入的数据。

![向右分裂的另一种情况](imgs/%E5%90%91%E5%8F%B3%E5%88%86%E8%A3%82%E7%9A%84%E5%8F%A6%E4%B8%80%E7%A7%8D%E6%83%85%E5%86%B5.png)

### B+树的索引管理

#### 索引管理

通过 `ALTER TABLE` 和 `CREATE/DROP INDEX` 命令来实现索引的创建和删除。用户可以设置对整个列的数据进行索引，也可以只索引一个列的开头部分数据。

若用户想要查看表中索引的信息，可以使用命令`SHOW INDEX`。接着具体阐述命令`SHOW INDEX`展现结果中每列的含义。

- `Table`：**索引所在的表名**。
- `Non_unique`：**索引是否非唯一**，可以看到primary key是0，因为必须是唯一的。
- `Key_name`：**索引的名字**，用户可以通过这个名字来执行DROP INDEX。
- `Seq_in_index`：**索引中该列的位置**，如果看联合索引中就比较直观了。
- `Column_name`：**索引列的名称**。
- `Collation`：**列以什么方式存储在索引中**。可以是`A`或`NULL`。B+树索引总是`A`，即排序的。如果使用了Heap存储引擎，并且建立了Hash索引，这里就会显示`NULL`了。因为Hash根据Hash桶存放索引数据，而不是对数据进行排序。
- `Cardinality`：非常关键的值，表示**索引中唯一值的数目的估计值**。Cardinality表的行数应尽可能接近1，如果非常小，那么用户需要考虑是否可以删除此索引。
- `Sub_part`：**是否是列的部分被索引**。如果对列的前100个字符建立索引则该字段显示为100。如果索引整个列，则该字段为`NULL`。
- `Packed`：**关键字如何被压缩**。如果没有被压缩，则为`NULL`。
- `Null`：**是否索引的列含有`NULL`值**。
- `Index_type`：**索引的类型**。InnoDB存储引擎只支持B+树索引，所以显示的都是BTREE。
- `Comment`：**注释**。

#### Fast Index Creation

MySQL 5.5版本之前（不包括5.5）存在的一个普遍被人诟病的问题是MySQL数据库对于索引的添加或者删除的这类DDL操作，MySQL数据库的操作过程为：

- 首先创建一张新的临时表，表结构为通过命令`ALTER TABLE`新定义的结构。
- 然后把原表中数据导入到临时表。
- 接着删除原表。
- 最后把临时表重名为原来的表名。

可以发现，若用户对于一张大表进行索引的添加和删除操作，那么这会需要很长的时间。更关键的是，若有大量事务需要访问正在被修改的表，这意味着数据库服务不可用。

InnoDB存储引擎从InnoDB 1.0.x版本开始支持一种称为**Fast Index Creation（快速索引创建）**的索引创建方式——简称FIC。

对于辅助索引的创建，InnoDB存储引擎会对创建索引的表加上一个S锁。在创建的过程中，不需要重建表，因此速度较之前提高很多，并且数据库的可用性也得到了提高。

步骤：

1. 创建新的表结构文件（`.frm`）
2. 对原表加S锁，不允许执行DML，但允许查询；
3. 根据聚集索引的顺序，构造新的索引项，按照顺序插入新索引页；
4. 升级原表上的锁，不允许读写操作，等待当前表的所有只读事务提交；
5. 替换原表结构文件（`.frm`），完成DDL操作。

删除辅助索引操作就更简单了，InnoDB存储引擎只需更新内部视图，并将辅助索引的空间标记为可用，同时删除MySQL数据库内部视图上对该表的索引定义即可。

这里需要特别注意的是，临时表的创建路径是通过参数`tmpdir`进行设置的。用户必须保证`tmpdir`有足够的空间可以存放临时表，否则会导致创建索引失败。

由于FIC在索引的创建的过程中对表加上了S锁，因此在创建的过程中只能对该表进行读操作，若有大量的事务需要对目标表进行写操作，那么数据库的服务同样不可用。

**FIC方式只限定于辅助索引，对于主键的创建和删除同样需要重建一张表**。

#### Online DDL

虽然FIC可以让InnoDB存储引擎避免创建临时表，从而提高索引创建的效率,但索引创建时会阻塞表上的DML操作。MySQL 5.6版本开始支持Online DDL（在线数据定义）操作，其允许辅助索引创建的同时，还允许其他诸如`INSERT`、`UPDATE`、`DELETE`这类DML操作，这极大地提高了MySQL数据库在生产环境中的可用性。

此外，不仅是辅助索引，以下这几类DDL操作都可以通过“在线”的方式进行操作：

- 辅助索引的创建与删除
- 改变自增长值
- 添加或删除外键约束
- 列的重命名

通过新的`ALTER TABLE`语法，用户可以选择索引的创建方式：

```sql
ALTER TABLE tbl_name
| ADD {INDEX|KEY} [index_name]
[index_type] (index_col_name, ...) [index_option] ...
ALGORITHM [=] {DEFAULT|INPLACE|COPY}
LOCK [=] {DEFAULT|NONE|SHARED|EXCLUSIVE}
```

`ALGORITHM`指定了创建或删除索引的算法，`COPY`表示按照MySQL 5.1版本之前的工作模式，即创建临时表的方式。`INPLACE`表示索引创建或删除操作不需要创建临时表，类似FIC。`DEFAULT`表示根据参数`old_alter_table`来判断是通过`INPLACE`还是`COPY`的算法，该参数的默认值为`OFF`，表示采用`INPLACE`的方式。

LOCK部分为索引创建或删除时对表添加锁的情况，可有的选择为：

- **NONE**

    执行索引创建或者删除操作时，对目标表不添加任何的锁，即事务仍然可以进行读写操作，不会收到阻塞。因此这种模式可以获得最大的并发度。

- **SHARE**

    这和之前的FIC类似，执行索引创建或删除操作时，对目标表加上一个S锁。对于并发地读事务，依然可以执行，但是遇到写事务，就会发生等待操作。如果存储引擎不支持SHARE模式，会返回一个错误信息。

- **EXCLUSIVE**

    在`EXCLUSIVE`模式下，执行索引创建或删除操作时，对目标表加上一个X锁。读写事务都不能进行，因此会阻塞所有的线程，这和COPY方式运行得到的状态类似，但是不需要像COPY方式那样创建一张临时表。

- **DEFAULT**

    `DEFAULT`模式首先会判断当前操作是否可以使用`NONE`模式，若不能，则判断是否可以使用`SHARE`模式，最后判断是否可以使用`EXCLUSIVE`模式。也就是说`DEFAULT`会通过判断事务的最大并发性来判断执行DDL的模式。

InnoDB存储引擎实现Online DDL的原理是在执行创建或者删除操作的同时，将`INSERT`、`UPDATE`、`DELETE`这类DML操作日志写入到一个缓存中。待完成索引创建后再将重做应用到表上，以此达到数据的一致性。这个缓存的大小由参数`innodb_online_alter_log_max_size`控制，默认的大小为128MB。若用户更新的表比较大，并且在创建过程中伴有大量的写事务，如遇到`innodb_online_alter_log_max_size`的空间不能存放日志时，用户可以调大参数`innodb_online_alter_log_max_size`，以此获得更大的日志缓存空间。

此外，还可以设置`ALTER TABLE`的模式为`SHARE`，这样在执行过程中不会有写事务发生，因此不需要进行DML日志的记录。

需要特别注意的是，由于Online DDL在创建索引完成后再通过重做日志达到数据库的最终一致性，这意味着在索引创建过程中，**SQL优化器不会选择正在创建中的索引**。

## Cardinality

Cardinality值表示索引中不重复记录数量的预估值，可以通过`SHOW INDEX`结果中的列Cardinality来观察。Cardinality仅仅只是一个预估值，而不是一个准确值，基本上用户也不可能得到一个准确的值。在实际应用中，`Cardinality / n_rows_in_table`应尽可能地接近1。如果非常小，那么用户需要考虑是否还有必要创建这个索引。故在访问高选择性属性的字段并从表中取出很少一部分数据时，对这个字段添加B+树索引是非常有必要的。

### Cardinality统计

因为MySQL数据库中有各种不同的存储引擎，而每种存储引擎对于B+树索引的实现又各不相同，所以对Cardinality的统计是放在**存储引擎层**进行的。

在InnoDB存储引擎中，Cardinality统计信息的更新发生在两个操作中：`INSERT`和`UPDATE`。不可能在每次发生`INSERT`和`UPDATE`时就去更新Cardinality信息（**统计频率**），这样会增加数据库系统的负荷，同时对于**大表**的统计（**统计数量**），时间上也不允许数据库这样去操作。

因此，针对**统计频率**的问题，InnoDB存储引擎内部对更新Cardinality信息的策略为：

- 表中1/16的数据已发生过变化。
- `stat_modified_counter＞2 000 000 000`。

第一种策略为自从上次统计Cardinality信息后，表中1/16的数据已经发生过变化，这时需要更新Cardinality信息。第二种情况考虑的是，如果对表中某一行数据频繁地进行更新操作，这时表中的数据实际并没有增加，实际发生变化的还是这一行数据，则第一种更新策略就无法适用这这种情况。故在InnoDB存储引擎内部有一个计数器`stat_modified_counter`，用来表示发生变化的次数，当`stat_modified_counter`大于`2 000 000 000`时，则同样需要更新Cardinality信息。

针对**统计数量**的问题，InnoDB存储引擎使用采样的方法来统计Cardinality信息。默认InnoDB存储引擎对8个**叶子节点（Leaf　Page）**进行采用，通过参数`innodb_stats_sample_pages`来进行设置。采样的过程如下：

- 取得B+树索引中叶子节点的数量，记为`A`。
- 随机取得B+树索引中的8个叶子节点。统计每个页不同记录的个数，即为`P1`，`P2`，…，`P8`。
- 根据采样信息给出Cardinality的预估值：`Cardinality =（P1 + P2 + … + P8）* A / 8`。

通过上述的说明可以发现，在InnoDB存储引擎中，Cardinality值是通过对8个叶子节点预估而得的，不是一个实际精确的值。再者，每次对Cardinality值的统计，都是通过随机取8个叶子节点得到的，这同时又暗示了另一个Cardinality现象，即每次得到的Cardinality值可能是不同的。如果表足够小，表的叶子节点数小于或者等于8个。这时即使随机采样，也总是会采取到这些页，因此每次得到的Cardinality值是相同的。

在InnoDB 1.2版本之前，可以通过参数`innodb_stats_sample_pages`用来设置统计Cardinality时每次采样页的数量，默认值为8。参数`innodb_stats_method`用来判断如何对待索引中出现的NULL值记录。该参数默认值为nulls_equal，表示将NULL值记录视为相等的记录。其有效值还有`nulls_unequal`，`nulls_ignored`，分别表示将NULL值记录视为不同的记录和忽略NULL值记录。

InnoDB1.2版本提供了更多的参数对Cardinality统计进行设置:

![InnoDB 1.2新增参数](imgs/InnoDB%201.2%E6%96%B0%E5%A2%9E%E5%8F%82%E6%95%B0.png)

当执行SQL语句`ANALYZE TABLE`、`SHOW TABLE STATUS`、`SHOW INDEX`以及访问`INFORMATION_SCHEMA`架构下的表`TABLES`和`STATISTICS`时会导致InnoDB存储引擎去重新计算索引的Cardinality值。若表中的数据量非常大，并且表中存在多个辅助索引时，执行上述这些操作可能会非常慢。虽然用户可能并不希望去更新Cardinality值。

## B+树索引的使用

### 不同应用中B+树索引的使用

在OLTP应用中，查询操作只从数据库中取得一小部分数据，一般可能都在10条记录以下，甚至在很多时候只取1条记录，如根据主键值来取得用户信息，根据订单号取得订单的详细信息，这都是典型OLTP应用的查询语句。在这种情况下，**B+树索引建立后，对该索引的使用应该只是通过该索引取得表中少部分的数据（Cardinality值高）**。这时建立B+树索引才是有意义的，否则即使建立了，优化器也可能选择不使用索引。

对于OLAP应用，情况可能就稍显复杂了。不过概括来说，在OLAP应用中，都需要访问表中大量的数据，根据这些数据来产生查询的结果，这些查询多是面向分析的查询，目的是为决策者提供支持。如这个月每个用户的消费情况，销售额同比、环比增长的情况。因此在OLAP中索引的添加根据的应该是宏观的信息，而不是微观，因为最终要得到的结果是提供给决策者的。例如不需要在OLAP中对姓名字段进行索引，因为很少需要对单个用户进行查询。**但是对于OLAP中的复杂查询，要涉及多张表之间的联接操作，因此索引的添加依然是有意义的**。但是，如果联接操作使用的是Hash Join，那么索引可能又变得不是非常重要了，所以这需要DBA或开发人员认真并仔细地研究自己的应用。不过在OLAP应用中，通常会需要对时间字段进行索引，这是因为大多数统计需要根据时间维度来进行数据的筛选。

各种联接操作的执行流程参考文章 [Mysql中的Join详解](https://blog.51cto.com/u_15080014/3723243)，如果想要对Hash Join进行深入了解参考文章 [MySQL 8.0之hash join](https://cloud.tencent.com/developer/article/1684046)。

### 联合索引

联合索引是指对表上的多个列进行索引。联合索引的创建方法与单个索引创建的方法一样，不同之处仅在于有多个索引列。例如，以下代码创建了一张t表，并且索引`idx_a_b`是联合索引，联合的列为`(a, b)`。

```sql
CREATE TABLE t(
    a INT NOT NULL,
    b INT,
    KEY idx_a(a),
    KEY idx_a_b(a,b)
)ENGINE=INNODB;

insert into t select 1,1;
insert into t select 1,2;
insert into t select 2,1;
insert into t select 2,4;
insert into t select 3,1;
insert into t select 3,2;
```

从本质上来说，联合索引也是一棵B+树，不同的是联合索引的键值的数量不是1，而是大于等于2。接着来讨论两个整型列组成的联合索引，假定两个键值的名称分别为a、b。

![多个键值的B+树](imgs/%E5%A4%9A%E4%B8%AA%E9%94%AE%E5%80%BC%E7%9A%84B%2B%E6%A0%91.png)

其实和之前讨论的单个键值的B+树并没有什么不同，键值都是排序的，通过叶子节点可以逻辑上顺序地读出所有数据，就上面的例子来说，即（1，1）、（1，2）、（2，1）、（2，4）、（3，1）、（3，2）。数据按（a，b）的顺序进行了存放。

因此，对于查询`SELECT*FROM TABLE WHERE a=xxx and b=xxx`，显然是可以使用`（a，b）`这个联合索引的。对于单个的a列查询`SELECT*FROM TABLE WHERE a=xxx`，也可以使用这个`（a，b）`索引。但对于b列的查询`SELECT*FROM TABLE WHERE b=xxx`，则不可以使用这棵B+树索引。可以发现叶子节点上的b值为1、2、1、4、1、2，显然不是排序的，因此对于b列的查询使用不到`（a，b）`的索引。

联合索引的第二个好处是已经对第二个键值进行了排序处理。通过`explain select * from t where a = 1 order by b;`得到如下结果：

```
# id	select_type	table	partitions	type	possible_keys	key	key_len	ref	rows	filtered	Extra
1	SIMPLE	t		ref	idx_a,idx_a_b	idx_a_b	4	const	2	100.00	Using index
```

对于上述的SQL语句既可以使用`idx_a`索引，也可以使用`idx_a_b`索引。但是优化器使用了`idx_a_b`索引，因为这个联合索引中b字段已经排好序了。根据该联合索引取出数据，无须再对`b`做一次额外的排序操作。如果通过`explain select * from t force index(idx_a) where a = 1 order by b;`强制使用`idx_a`索引，执行计划下表所示。

```
# id	select_type	table	partitions	type	possible_keys	key	key_len	ref	rows	filtered	Extra
1	SIMPLE	t		ref	idx_a	idx_a	4	const	2	100.00	Using filesort
```

在Extra选项中可以看到`Using filesort`，即需要额外的一次排序操作才能完成查询。


正如前面所介绍的那样，联合索引`（a，b）`其实是根据列a、b进行排序，因此下列语句可以直接使用联合索引得到结果：

```sql
SELECT...FROM TABLE WHERE a=xxx ORDER BY b
```


然而对于联合索引`（a，b，c）`来说，下列语句同样可以直接通过联合索引得到结果：

```sql
SELECT...FROM TABLE WHERE a=xxx ORDER BY b
SELECT...FROM TABLE WHERE a=xxx AND b=xxx ORDER BY c
```
但是对于下面的语句，联合索引不能直接得到结果，其还需要执行一次filesort排序操作，因为索引`（a，c）`并未排序：

```sql
SELECT...FROM TABLE WHERE a=xxx ORDER BY c
```

### 覆盖索引（列覆盖+统计问题）

InnoDB存储引擎支持**覆盖索引（covering index，或称索引覆盖）**，即*从辅助索引中就可以得到查询的记录，而不需要查询聚集索引中的记录*。使用覆盖索引的一个好处是辅助索引**不包含整行记录的所有信息，故其大小要远小于聚集索引，因此可以减少大量的IO操作**。

对于InnoDB存储引擎的辅助索引而言，由于其包含了主键信息，因此其叶子节点存放的数据为`（primary key1，primary key2，…，key1，key2，…）`。例如，下列语句都可仅使用一次辅助联合索引来完成查询：

```sql
SELECT key2 FROM table WHERE key1=xxx；
SELECT primary key2,key2 FROM table WHERE key1=xxx；
SELECT primary key1,key2 FROM table WHERE key1=xxx；
SELECT primary key1,primary key2，key2 FROM table WHERE key1=xxx；
```

**覆盖索引的另一个好处是对某些统计问题而言的，InnoDB存储引擎并不会选择通过查询聚集索引来进行统计**。还是对于上一小节创建的表`t`，要进行如下的查询：

```sql
EXPLAIN SELECT COUNT(*) FROM t;
```

由于t表上还有辅助索引，而辅助索引远小于聚集索引，选择辅助索引可以减少IO操作，故优化器的选择为`idx_a`。可以看到，`possible_keys`列为`NULL`，但是实际执行时优化器却选择了`idx_a`索引，而列`Extra`列的`Using index`就是代表了优化器进行了覆盖索引操作。

```
# id	select_type	table	partitions	type	possible_keys	key	key_len	ref	rows	filtered	Extra
1	SIMPLE	t		index		idx_a	4		6	100.00	Using index
```

### 优化器选择不使用索引的情况（不能覆盖索引+大量数据）

在某些情况下，当执行`EXPLAIN`命令进行SQL语句的分析时，会发现优化器并没有选择索引去查找数据，而是通过扫描聚集索引，也就是直接进行全表的扫描来得到数据。这种情况多发生于**范围查找**、**JOIN链接操作**等情况下。

```sql
SELECT*FROM orderdetails
WHERE orderid＞10000 and orderid＜102000;
```

上述这句SQL语句查找订单号大于10000的订单详情，通过命令`SHOW INDEX FROM orderdetails`，若表的索引如下图所示。

![表orderdetails的索引详情](imgs/%E8%A1%A8orderdetails%E7%9A%84%E7%B4%A2%E5%BC%95%E8%AF%A6%E6%83%85.png)

可以看到表`orderdetails`有`（OrderID，ProductID）`的联合主键，此外还有对于列OrderID的单个索引。上述这句SQL显然是可以通过扫描OrderID上的索引进行数据的查找。然而通过EXPLAIN命令，用户会发现优化器并没有按照`OrderID`上的索引来查找数据。

![上述范围查询的SQL执行计划](imgs/%E4%B8%8A%E8%BF%B0%E8%8C%83%E5%9B%B4%E6%9F%A5%E8%AF%A2%E7%9A%84SQL%E6%89%A7%E8%A1%8C%E8%AE%A1%E5%88%92.png)

在`possible_keys`一列可以看到查询可以使用`PRIMARY`、`OrderID`、`OrdersOrder_Details`三个索引，但是在最后的索引使用中，优化器选择了`PRIMARY聚集索引`，也就是`表扫描（table scan）`，而非`OrderID辅助索引扫描（index scan）`。

原因在于用户要选取的数据是整行信息，而`OrderID`索引不能覆盖到我们要查询的信息，因此在对`OrderID`索引查询到指定数据后，还需要一次书签访问来查找整行数据的信息。虽然`OrderID`索引中数据是顺序存放的，但是再一次进行书签查找的数据则是无序的，因此变为了磁盘上的离散读操作。如果要求访问的数据量很小，则优化器还是会选择辅助索引，但是当访问的数据占整个表中数据的蛮大一部分时（一般是20%左右），优化器会选择通过聚集索引来查找数据。因为之前已经提到过，顺序读要远远快于离散读。

因此对于不能进行索引覆盖的情况，优化器选择辅助索引的情况是，通过辅助索引查找的数据是少量的。

### 索引提示

MySQL数据库支持索引提示（INDEX HINT），**显式地告诉优化器使用哪个索引**。个人总结以下两种情况可能需要用到INDEX HINT：

- **MySQL数据库的优化器错误地选择了某个索引，导致SQL语句运行的很慢**。这种情况在最新的MySQL数据库版本中非常非常的少见。优化器在绝大部分情况下工作得都非常有效和正确。这时有经验的DBA或开发人员可以强制优化器使用某个索引，以此来提高SQL运行的速度。
- **某SQL语句可以选择的索引非常多，这时优化器选择执行计划时间的开销可能会大于SQL语句本身**。例如，优化器分析Range查询本身就是比较耗时的操作。这时DBA或开发人员分析最优的索引选择，通过Index Hint来强制使优化器不进行各个执行路径的成本分析，直接选择指定的索引来完成查询。

在MySQL数据库中Index Hint的语法如下：

```sql
tbl_name [[AS] alias] [index_hint_list]

index_hint_list:
    index_hint [index_hint] ...

index_hint:
    USE {INDEX|KEY}
      [FOR {JOIN|ORDER BY|GROUP BY}] ([index_list])
  | {IGNORE|FORCE} {INDEX|KEY}
      [FOR {JOIN|ORDER BY|GROUP BY}] (index_list)

index_list:
    index_name [, index_name] ...
```

- `USE INDEX`只是告诉优化器可以选择该索引，实际上优化器还是会再根据自己的判断进行选择。
- `FORCE INDEX`用于强制使用某个索引来完成查询。


### Multi-Range Read优化

MySQL5.6版本开始支持Multi-Range Read（MRR）优化。**Multi-Range Read优化的目的就是为了减少磁盘的随机访问，并且将随机访问转化为较为顺序的数据访问**，这对于IO-bound类型的SQL查询语句可带来性能极大的提升。Multi-Range Read优化可适用于`range`，`ref`，`eq_ref`类型的查询。查询类型参考文章 [Mysql Explain之type详解](https://juejin.cn/post/6844904149864169486)。

对于InnoDB和MyISAM存储引擎的范围查询和JOIN查询操作，MRR的工作方式如下：

1. 将查询得到的辅助索引键值存放于一个缓存中，这时缓存中的数据是根据辅助索引键值排序的。
2. 将缓存中的键值根据RowID(主键)进行排序。
3. 根据RowID（主键）的排序顺序来访问实际的数据文件。

若InnoDB存储引擎或者MyISAM存储引擎的缓冲池不是足够大，即不能存放下一张表中的所有数据，此时频繁的离散读操作还会导致缓存中的页被替换出缓冲池，然后又不断地被读入缓冲池。若是按照主键顺序进行访问，则可以将此重复行为降为最低。

**Multi-Range Read还可以将某些范围查询拆分为键值对，以此来进行批量的数据查询**。这样做的好处是可以在拆分过程中，**直接过滤一些不符合查询条件的数据**，例如：

```sql
SELECT * FROM t
    WHERE key_part1 ＞= 1000 AND key_part1 ＜ 2000
    AND key_part2=10000;
```

表t有`（key_part1，key_part2）`的联合索引，因此索引根据`key_part1`，`key_part2`的位置关系进行排序。若没有Multi-Read Range，此时查询类型为Range，SQL优化器会先将`key_part1`大于1000且小于2000的数据都取出，即使`key_part2`不等于1000。待取出行数据后再根据`key_part2`的条件进行过滤。这会导致无用数据被取出。如果有大量的数据且其`key_part2`不等于1000，则启用Mulit-Range Read优化会使性能有巨大的提升。

倘若启用了Multi-Range Read优化，优化器会先将查询条件进行拆分，然后再进行数据查询。就上述查询语句而言，优化器会将查询条件拆分为`（1000，1000）`，`（1001，1000）`，`（1002，1000）`，…，`（1999，1000）`，最后再根据这些拆分出的条件进行数据的查询。

因此，MRR优化有以下几个好处：

1. MRR使数据访问变得较为顺序。在查询辅助索引时，首先根据得到的查询结果，按照主键进行排序，并按照主键排序的顺序进行书签查找。(从MRR的工作方式就能看出来)
2. 减少缓冲池中页被替换的次数。（缓冲池中的页是按照主键顺序排序的，所以不会被频繁读取和换出）
3. 批量处理对键值的查询操作。(对查询条件进行拆分，直接过滤掉不符合的数据)

#### MRR参数

是否启用Multi-Range Read优化可以通过参数optimizer_switch中的标记（flag）来控制。

当`mrr`标记为`on`时，表示启用Multi-Range Read优化。`mrr_cost_based`标记表示是否通过`cost based`的方式来选择是否启用mrr。若将`mrr`设为`on`，`mrr_cost_based`设为`off`，则总是启用Multi-Range Read优化。

```sql
--- 总是开启MRR
SET @@optimizer_switch = 'mrr=on,mrr_cost_based=off';
--- 根据mrr_cost_based判断是否开启MRR
SET @@optimizer_switch = 'mrr=on,mrr_cost_based=off';
--- 关闭MRR
SET @@optimizer_switch = 'mrr=off';
```

参数`read_rnd_buffer_size`用来控制键值（Row ID）的缓冲区大小，当大于该值时，则执行器对已经缓存的数据根据RowID进行排序，并通过RowID来取得行数据。该值默认为256K。

### Index Condition Pushdown(ICP) 优化

参考文章：

1. [MySQL机制介绍之ICP](https://omg-by.github.io/2020/05/28/new/MySQL/MySQL%E6%9C%BA%E5%88%B6%E4%BB%8B%E7%BB%8D%E4%B9%8BICP/)
2. [一起学习Mysql索引三（ICP,索引条件下推）](https://zhuanlan.zhihu.com/p/73035620)

#### 原理

通过二级索引查询数据时，存储引擎会通过**最左前缀规则**找到匹配的聚集索引主键，主键回表查询获取完整的行记录信息，如果列字段查询条件出现**无法使用最左前缀规则匹配**或者**查询列没有被二级索引覆盖**等情况，还需要在数据传递至MySQL Server层时再去为这些数据行进行`WHERE`的条件的过滤。

![using where](imgs/using%20where.png)

和Multi-Range Read一样，Index Condition Pushdown同样是MySQL 5.6开始支持的一种根据索引进行查询的优化方式。

之前的MySQL数据库版本不支持Index Condition Pushdown，当进行索引查询时，首先根据索引来查找记录，然后再根据`WHERE`条件来过滤记录。

在支持Index Condition Pushdown后，存储引擎同样还会在二级索引中通过**最左前缀规则**找到匹配的聚集索引主键，但是对于**不能使用最左前缀规则但是覆盖二级索引的字段**，MySQL数据库将这类字段的过滤被**下推（pushdown）**至存储引擎层的二级索引的查询过程中来进行过滤。之后的过程和未使用ICP优化一样，获取过滤后的行记录的聚集索引主键，根据主键回表查询聚集索引获取完整的行记录，最后再在Server层对二级索引中未覆盖到的查询列进行`WHERE`条件的过滤。而由于在引擎层就能够过滤掉大量的数据，这样无疑能够减少了对基表和MySQL Server的访问次数，从而提升了性能。

![using index condition](imgs/using%20index%20condition.png)

#### ICP 参数

是否启用Index Condition Pushdown优化可以通过参数`optimizer_switch`中的`index_condition_pushdown`标记（flag）来控制。

```sql
--- 关闭 ICP
SET optimizer_switch = 'index_condition_pushdown=off';
--- 开启 ICP
SET optimizer_switch = 'index_condition_pushdown=on'; 
```

当优化器选择Index Condition Pushdown优化时，可在执行计划的列`Extra`看到`Using index condition`提示。

#### ICP的使用限制

ICP虽然挺好用的，但是并不是所有的SQL都能够通过ICP得到性能提升。因为如果`WHERE`条件的字段不在索引列中,还是要读取整表的记录到Server层做`WHERE`过滤。

这里列出几点ICP的相关限制：

- 当SQL需要全表访问时，ICP的优化策略可用于`range`、`ref`、`eq_ref`、`ref_or_null` 类型的访问数据方法 。
- 支持InnoDB和MyISAM表。
- ICP只能用于二级索引，不能用于主索引。
- 并非全部`WHERE`条件都可以用ICP筛选。如果`WHERE`条件的字段不在索引列中，还是要读取整表的记录到Server层做WHERE过滤。
- ICP的加速效果取决于在存储引擎内通过ICP筛选掉的数据的比例。
- 5.6 版本的不支持分表的ICP 功能，5.7 版本的开始支持。
- 当SQL使用覆盖索引时，不支持ICP优化方法。


## 哈希索引

### InnoDB存储引擎中的哈希算法

InnoDB存储引擎使用哈希算法来对字典进行查找，其冲突机制采用**链接法**，哈希函数采用**除法散列**方式。

**链接法**会把散列到同一槽中的所有元素都放在一个链表中。对于缓冲池页的哈希表来说，在缓冲池中的Page页都有一个chain指针，它指向相同哈希函数值的页。

在哈希函数的**除法散列法**会通过取关键字`k`除以`m`的余数，将关键字`k`映射到`m`个槽的某一个去，即哈希函数为：`hash(k) = k % m`。而对于除法散列，m的取值为略大于2倍的缓冲池页数量的质数。例如：当前参数`innodb_buffer_pool_size`的大小为10M，则共有`640`个`16KB`的页。对于缓冲池页内存的哈希表来说，需要分配`640×2=1280`个槽，但是由于`1280`不是质数，需要取比`1280`略大的一个质数，应该是`1399`，所以在启动时会分配`1399`个槽的哈希表，用来哈希查询所在缓冲池中的页。

InnoDB存储引擎的缓冲池对于会根据页的关键字对也进行查找。InnoDB存储引擎的表空间都有一个`space_id`，用户所要查询的应该是某个表空间的某个连续16KB的页，即偏移量`offset`，页的关键字`K = space_id＜＜20+space_id+offset`。

### 自适应哈希索引

InnoDB存储引擎会监控对表上各索引页的查询。如果观察到建立哈希索引可以带来速度提升，则建立哈希索引，称之为自适应哈希索引（Adaptive Hash Index，AHI）。AHI是通过缓冲池的B+树页构造而来，因此建立的速度很快，而且不需要对整张表构建哈希索引。InnoDB存储引擎会自动根据访问的频率和模式来自动地为某些热点页建立哈希索引，因此并不能人为干预。

通过命令`SHOW ENGINE INNODB STATUS`可以看到当前自适应哈希索引的使用状况。

需要注意的是，哈希索引只能用来搜索等值的查询，而对于其他查找类型，如范围查找，是不能使用哈希索引的。

可以通过参数`innodb_adaptive_hash_index`来禁用或启动此特性，默认为开启。

## 全文检索

### 概述

**全文检索（Full-Text Search，FTS）**是将存储于数据库中的整本书或整篇文章中的任意内容信息查找出来的技术。它可以根据需要获得全文中有关章、节、段、句、词等信息，也可以进行各种统计和分析。

B+树索引对字段前缀匹配查找有较好的支持，例如：

```sql
--- 匹配 hello 开头的内容
select * from blog where content like = 'hello%'；
```

但是对于全文检索，B+树只能采用索引扫描的方式得到结果。

```sql
--- 匹配包含 hello 的内容
select * from blog where content like = '%hello%'；
```

从InnoDB 1.2.x版本开始，InnoDB存储引擎开始支持全文检索，其支持MyISAM存储引擎的全部功能，并且还支持其他的一些特性。

### 倒排索引

全文检索通常使用**倒排索引（inverted index）**来实现。倒排索引同B+树索引一样，也是一种索引结构。它在**辅助表（auxiliary table）**中存储了单词与单词自身在一个或多个文档中所在位置之间的映射。这通常利用**关联数组**实现，其拥有两种表现形式：

- **inverted file index**：其表现形式为`{单词，单词所在文档的ID}`
- **full inverted index**：其表现形式为`{单词，(单词所在文档的ID，在具体文档中的位置)}`

表`t`存储的内容如下表所示，`DocumentId`表示进行全文检索文档的Id，`Text`表示存储的内容，用户需要对存储的这些文档内容进行全文检索。

![全文检索表t](imgs/%E5%85%A8%E6%96%87%E6%A3%80%E7%B4%A2%E8%A1%A8t.png)

对于**inverted file index**的关联数组，其存储内容如下：

![inverted file index的关联数组](imgs/inverted%20file%20index%E7%9A%84%E5%85%B3%E8%81%94%E6%95%B0%E7%BB%84.png)

对于inverted file index，其仅存取文档Id，而**full inverted index**存储的是对(pair)，即`(DocumentId，Position)`，因此其存储的倒排索引如表下所示。相比之下，full inverted index占用更多的空间，但是能更好地定位数据，并扩充一些其他的搜索特性。

![full invertedindex的关联数组](imgs/full%20inverted%20index%E7%9A%84%E5%85%B3%E8%81%94%E6%95%B0%E7%BB%84.png)

### InnoDB全文检索

InnoDB存储引擎从1.2.x版本开始支持全文检索的技术，其采用**full inverted index**的方式。在InnoDB存储引擎中，将`(DocumentId，Position)`视为一个`ilist`。因此在全文检索的表中，有两个列，一个是`word`字段，另一个是`ilist`字段，并且在`word`字段上有设有索引。此外，由于InnoDB存储引擎在`ilist`字段中存放了`Position`信息，故可以进行**临近搜索（Proximity Search）**，而MyISAM存储引擎不支持该特性。

#### 倒排索引表/辅助表

倒排索引需要将word存放到一张表中，这个表称为**Auxiliary Table（辅助表）**。在InnoDB存储引擎中，为了提高全文检索的并行性能，共有**6张**Auxiliary Table，**目前每张表根据word的Latin编码进行分区**。Auxiliary Table是持久的表，存放于磁盘上。

InnoDB存储引擎允许用户查看指定倒排索引的Auxiliary Table中分词的信息，可以通过设置参数`innodb_ft_aux_table`来观察倒排索引的Auxiliary Table。在上述设置完成后，就可以通过查询`information_schema`架构下的表`INNODB_FT_INDEX_TABLE`得到倒排索引表的信息。

```sql
--- 查看test架构下表fts_a的Auxiliary Table
SET GLOBAL innodb_ft_aux_table='test/fts_a';
--- 查看Auxiliary Table辅助表的信息
SELECT * FROM information_schema.INNODB_FT_INDEX_TABLE;
```

#### FTS Document ID（全文检索文档ID）

在InnoDB存储引擎中，为了支持全文检索，必须有一个列与分词`word`进行映射，在InnoDB中这个列被命名为`FTS_DOC_ID`，其类型必须是`BIGINT UNSIGNED NOT NULL`，并且InnoDB存储引擎自动会在该列上加入一个名为`FTS_DOC_ID_INDEX`的`Unique Index`。由于列名为FTS_DOC_ID的列具有特殊意义，因此创建时必须注意相应的类型，否则MySQL数据库会抛出错误。

#### 全文检索索引缓存（FTS Index Cache）

在InnoDB存储引擎的全文索引中，还有另外一个重要的概念**FTS Index Cache（全文检索索引缓存）**，其*用来提高全文检索的性能*。FTS Index Cache位于**内存**中，是一个**红黑树**结构，根据`（word，ilist）`进行排序。

FTS Index Cache 在功能上和Insert Buffer类似，FTS Index Cache 和 Insert Buffer 的关系：

1. Insert Buffer 和 FTS Index Cache 都是将离散的数据插入操作转换为数据的批量插入操作；
2. Insert Buffer 提高非唯一非聚集索引表的插入性能；FTS Index Cache 提高倒排索引表的插入性能；
3. Insert Buffer 持久化对象；FTS Index Cache 内存对象
4. Insert Buffer B+树存储结构；FTS Index Cache 红黑树结构。

参数`innodb_ft_cache_size`用来控制FTS Index Cache的大小，默认值为`32M`。当该缓存满时，会将其中的`(word，ilist)`分词信息同步到磁盘的Auxiliary Table中。增大该参数可以提高全文检索的性能，但是在宕机时，未同步到磁盘中的索引信息可能需要更长的时间进行恢复。

#### InnoDB 倒排索引工作方式

- **数据插入**：数据插入的事务提交时，插入数据已经更新了对应的表，但是对全文索引的更新可能在分词操作后还在FTS `Index Cache`中，`Auxiliary Table`可能还没有更新。InnoDB存储引擎会批量对`Auxiliary Table`进行更新，而不是每次插入后更新一次`Auxiliary Table`。当对全文检索进行查询时，`Auxiliary Table`首先会将在`FTS Index Cache`中对应的word字段合并到`Auxiliary Table`中，然后再进行查询。
- **数据库关闭**：当数据库关闭时，在`FTS Index Cache`中的数据库会同步到磁盘上的`Auxiliary Table`中。
- **数据库宕机**：如果当数据库发生宕机时，一些`FTS Index Cache`中的数据库可能未被同步到磁盘上。那么下次重启数据库时，当用户对表进行全文检索（查询或者插入操作）时，InnoDB存储引擎会自动读取未完成的文档，然后进行分词操作，再将分词的结果放入到`FTS Index Cache`中。
- **数据删除**：对于删除操作，其在事务提交时，不删除磁盘Auxiliary Table中的记录，而只是删除FTS Cache Index中的记录。对于Auxiliary Table中被删除的记录，InnoDB存储引擎会记录其FTS Document ID，并将其保存在DELETED auxiliary table中。

    - 在设置参数`innodb_ft_aux_table`后，用户同样可以访问`information_schema`架构下的表`INNODB_FT_DELETED`来观察删除的FTS Document ID。
    - 由于文档的DML操作实际并不删除索引中的数据，相反还会在对应的`INNODB_FT_DELETED`表中插入记录，因此随着应用程序的允许，索引会变得非常大，即使索引中的有些数据已经被删除，查询也不会选择这类记录。为此，InnoDB存储引擎提供了`OPTIMIZE TABLE`命令来允许用户手工地将已经删除的记录从索引中彻底删除。因为`OPTIMIZE TABLE`还会进行一些其他的操作，如Cardinality的重新统计，若用户希望仅对倒排索引进行操作，那么可以通过参数`innodb_optimize_fulltext_only`进行设置。
    - 若被删除的文档非常多，那么`OPTIMIZE TABLE`操作可能需要占用非常多的时间，这会影响应用程序的并发性，并极大地降低用户的响应时间。用户可以通过参数`innodb_ft_num_word_optimize`来限制每次实际删除的分词数量。该参数的默认值为`2000`。

#### 全文检索创建

```sql
CREATE TABLE articles (
    FTS_DOC_ID BIGINT UNSIGNED AUTO_INCREMENT NOT NULL PRIMARY KEY,
    title VARCHAR(200),
    body TEXT,
    -- 将 tile 和 body 两个字段建立倒排索引
    FULLTEXT (title,body)
) ENGINE=InnoDB;

INSERT INTO articles (title,body) VALUES
    ('MySQL Tutorial','DBMS stands for DataBase ...'),
    ('How To Use MySQL Well','After you went through a ...'),
    ('Optimizing MySQL','In this tutorial, we show ...'),
    ('1001 MySQL Tricks','1. Never run mysqld as root. 2. ...'),
    ('MySQL vs. YourSQL','In the following database comparison ...'),
    ('MySQL Security','When configured properly, MySQL ...');
```

上述代码创建了表`articles`，对`title`和`body`字段进行全文检索，因此创建一个类型为`FULLTEXT`的索引。同时手动创建了一个`FTS_DOC_ID`列作为文档ID。

通过设置参数`innodb_ft_aux_table`来查看分词对应的信息：

```sql
-- 查看倒排索引表
SET GLOBAL innodb_ft_aux_table='employees/articles';
SELECT * FROM information_schema.INNODB_FT_INDEX_TABLE;
```

但实际上，现在查看倒排索引表还看不到数据，因为现在数据只被插入到了 FTS Index Cache 中，要想查看到倒排索引表可以通过全文检索或者`OPTIMIZE TABLE`命令进行更新。之后便能看到倒排索引的数据了。

```sql
-- 倒排索引表为空，可以通过手动全文检索或者使用OPTIMIZE TABLE命令进行更新(但是好像倒排索引表仍然为空)
SELECT * FROM articles
    WHERE MATCH (title,body)
    AGAINST ('database' IN NATURAL LANGUAGE MODE);
-- 使用OPTIMIZE TABLE命令彻底删除全文检索文档ID
OPTIMIZE TABLE employees.articles;
-- 再次访问倒排索引表发现数据存在
SELECT * FROM information_schema.INNODB_FT_INDEX_TABLE;
```

可以看到每个`word`都对应了一个`DOC_ID`和`POSITION`。此外，还记录了`FIRST_DOC_ID`、`LAST_DOC_ID`以及`DOC_COUNT`，分别代表了该`word`第一次出现的文档ID，最后一次出现的文档ID，以及该`word`在多少个文档中存在。

还需要注意的是，因为本文在`title`和`body`两个列上建立全文检索，在多个列上建立倒排索引实际上是对`title`和`body`两个字段进行拼接，对拼接后的值进行全文检索。这个可以通过查看`information_schema.INNODB_FT_INDEX_TABLE`轻易看出。

```sql
--- 删除文档编号为7的记录
DELETE FROM employees.articles WHERE FTS_DOC_ID=5;
--- 编号为7的记录在倒排索引表中并没有被删除
SELECT * FROM information_schema.INNODB_FT_INDEX_TABLE;
--- 文档编号7插入到INNODB_FT_DELETED表中
SELECT * FROM information_schema.INNODB_FT_DELETED;
--- 设置OPTIMIZE TABLE命令只用来对倒排索引进行操作
SET GLOBAL innodb_optimize_fulltext_only=1;
--- 使用OPTIMIZE TABLE命令彻底删除全文检索文档ID
OPTIMIZE TABLE employees.articles;
--- 彻底删除的文档会被记录在INNODB_FT_BEING_DELETED表中
SELECT * FROM information_schema.INNODB_FT_BEING_DELETED;
```

#### stopword 列表

**stopword列表（stopword list）**表示该列表中的`word`不需要对其进行索引分词操作。

InnoDB存储引擎有一张默认的stopword列表，其在`information_schema`架构下，表名为`INNODB_FT_DEFAULT_STOPWORD`，默认共有36个stopword。

```sql
SELECT * FROM information_schema.INNODB_FT_DEFAULT_STOPWORD;
```

此外用户也可以通过参数`innodb_ft_server_stopword_table`来自定义stopword列表。

```sql
--- 创建新的stopword表
CREATE TABLE user_stopword(
    value VARCHAR(30)
)ENGINE=INNODB;

--- 设置新建表为stopword表
SET GLOBAL innodb_ft_server_stopword_table="test/user_stopword";
```

#### 多个全文检索索引

在MySQL8.0似乎可以在一个表上建立多个全文检索索引，例如：

```sql
CREATE TABLE articles2 (
    FTS_DOC_ID BIGINT UNSIGNED AUTO_INCREMENT NOT NULL PRIMARY KEY,
    title VARCHAR(200),
    body TEXT,
    -- 将 tile 和 body 两个字段建立倒排索引
    FULLTEXT idx_fts_tile(title),
    FULLTEXT idx_fts_body(body)
) ENGINE=InnoDB;
```

上表分别为`title`和`body`分别建立了一个全文检索的倒排索引，说明一个表上是可以创建多个全文检索索引的。在插入数据之后对使用`OPTIMIZE TABLE`更新倒排索引后查看`information_schema.INNODB_FT_INDEX_TABLE`表发现倒排索引中包含`title`和`body`两列的分词，但是根据倒排索引表的`POSIION`列可知倒排索引并不是将`title`和`body`拼接在一起后再建立的。

但是这样就会存在一些问题，如果我要对title中的mysql进行全文检索的话，在倒排索引表`information_schema.INNODB_FT_INDEX_TABLE`中我能够得到`title`和`body`列中包含mysql的文档ID（主键），但是并不知道哪些文档是title列中包含mysql的。因此就会在文档ID回表查询返回行数据后，还需要Server层对查询到的列再进行一次过滤。


> **以下内容均为我的猜想：**
>
> 西卡西，这样效率会不会太低了？
> 
> 我的猜想是，MySQL底层会在分别为`title`和`body`建立一个倒排索引表，各自表存放各自的分词，而不是都放在`information_schema.INNODB_FT_INDEX_TABLE`表中的。如果对`title`进行全文检索的话，就查询`title`的倒排索引表，返回满足条件的文档ID，在根据文档ID回表即可。而为什么`information_schema.INNODB_FT_INDEX_TABLE`表会将两个倒排索引放在一起，我的猜测其实这个表就类似一个视图的概念，只是一个逻辑表，它将所有的倒排索引分词和文档信息展示在一起。

#### 限制

当前InnoDB存储引擎的全文检索还存在以下的限制：

- ~每张表只能有**一个**全文检索的索引。（但是在MySQL 8.0中是可以创建多个全文索引的）~
- 由多列组合而成的全文检索的索引列必须使用相同的字符集与排序规则。
- 不支持没有**单词界定符（delimiter）**的语言，如中文、日语、韩语等。

### 全文检索

MySQL数据库支持全文检索（Full-Text Search）的查询，其语法为：

```sql
MATCH (col1,col2,...) AGAINST (expr [search_modifier])
search_modifier:
  {
       IN NATURAL LANGUAGE MODE
     | IN NATURAL LANGUAGE MODE WITH QUERY EXPANSION
     | IN BOOLEAN MODE
     | WITH QUERY EXPANSION
  }
```

MySQL数据库通过`MATCH()…AGAINST()`语法支持全文检索的查询，`MATCH`指定了需要被查询的列，`AGAINST`指定了使用何种方法去进行查询。

全文检索函数`MATH()`返回全文检索的**相关性值**。相关性值是非负浮点数。零相关性意味着没有相似性。相关性是根据**行（文档）中的单词数**、**行中唯一单词的数量**、**集合中的单词总数**以及**包含特定单词的行数**来计算的。

全文搜索分为三种类型：
- Natural Language
- Boolean
- Query Expansion

#### Natrual Language

全文检索通过MATCH函数进行查询，默认采用Natural Language模式，其表示查询带有指定word的文档。

对于上一小节中创建的表`articles`，查询`title`或`body`字段中带有`mysql`的文档，若不使用全文索引技术，则允许使用下述SQL语句，但是这种查询不能很好的利用B+树索引，B+树只能利用索引扫描的方法对字段进行遍历后得到结果。

```sql
SELECT * FROM articles WHERE title LIKE '%database%' OR body LIKE'%database%';
```

使用`EXPLAIN`执行查看SQL语句的执行计划:

```
# id	select_type	table	partitions	type	possible_keys	key	key_len	ref	rows	filtered	Extra
1	SIMPLE	articles		ALL					6	16.67	Using where
```

可以看出查询类型为ALL，说明B+树会通过全表查找的方式判断记录中的`title`或`body`字段是否包含`database`。

若采用全文检索技术，可以用下面的SQL语句进行查询：

```sql
SELECT * FROM articles WHERE MATCH(title, body) AGAINST('database' IN NATURAL LANGUAGE MODE);
--- NATURAL LANGUAGE是默认的全文检索模式，可以简写如下形式
SELECT * FROM articles WHERE MATCH(title, body) AGAINST('database');
```

观察上述SQL语句的执行计划：

```sql
# id	select_type	table	partitions	type	possible_keys	key	key_len	ref	rows	filtered	Extra
1	SIMPLE	articles		fulltext	idx_fts	idx_fts	0	const	1	100.00	Using where; Ft_hints: sorted
```

可以看到，在`type`这列显示了`fulltext`，即表示使用全文检索的倒排索引，而`key`这列显示了`idx_fts`，表示索引的名字，说明使用全文检索。除此之外再Extra列中包含`Ft_hints: sorted`标志，表示返回的行就会自动按照相关性最高的顺序排列。如果查询SQL中显式指定`ORDER BY`，则需要根据排序字段对列进行排序，Extra列中的标志会变为`Ft_hints: no_ranking; Using filesort`，表示不根据相关性排序而根据显式指定字段排序。例如：

```sql
SELECT * FROM articles WHERE MATCH(title, body) AGAINST('database') ORDER BY title;
```

#### Boolean

MySQL数据库允许使用IN BOOLEAN MODE修饰符来进行全文检索。当使用该修饰符时，查询字符串的前后字符会有特殊的含义。

Boolean全文检索支持以下几种操作符：

- `+`表示该word必须存在。
- `-`表示该word必须被排除。
- `(no operator)`表示该word是可选的，但是如果出现，其相关性会更高
- `@distance`表示查询的多个单词之间的距离是否在`distance`之内，`distance`的单位是字节。这种全文检索的查询也称为**Proximity Search**。如`MATCH（body）AGAINST ('"Pease pot"@30'IN BOOLEAN MODE)`表示字符串Pease和pot之间的距离需在30字节内。
- `＞`表示出现该单词时增加相关性。
- `＜`表示出现该单词时降低相关性。
- `~`表示允许出现该单词，但是出现时相关性为负（全文检索查询允许负相关性）。
- `*`表示以该单词开头的单词。
- `"`表示短语。

更多信息参考：[Boolean Full-Text Searches](https://dev.mysql.com/doc/refman/8.0/en/fulltext-boolean.html)

#### Query Expansion

MySQL数据库还支持全文检索的扩展查询。这种查询通常在查询的关键词太短，用户需要implied knowledge（隐含知识）时进行。例如，对于单词`database`的查询，用户可能希望查询的不仅仅是包含`database`的文档，可能还指那些包含MySQL、Oracle、DB2、RDBMS的单词。而这时可以使用Query Expansion模式来开启全文检索的隐含知识。

通过在查询短语中添加`WITH QUERY EXPANSION`或`IN NATURAL LANGUAGE MODE WITH QUERY EXPANSION`可以开启**blind query expansion**（又称为**automatic relevance feedback**）。该查询分为两个阶段。

- 第一阶段：根据搜索的单词进行全文索引查询。
- 第二阶段：根据第一阶段产生的分词再进行一次全文检索的查询。

更多信息参考：[Full-Text Searches with Query Expansion](https://dev.mysql.com/doc/refman/8.0/en/fulltext-query-expansion.html)