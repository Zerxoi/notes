# Java

## lambda 外部局部变量 final

lambda表达式外的局部变量会通过lambda表达式的构造器函数将外部变量传递给lambda内部类的变量。

因为Java中都是采用值传递的方式，所以为保证外部局部变量和lambda表达式内部的一致性（基本类型变量值不能够被修改，引用类型变量地址不能够被修改），外部局部变量需要使用final修饰符进行修饰。

在 Java 8 之前，匿名类中如果要访问局部变量的话，那个局部变量必须显式的声明为 final

Java 8 之后，在匿名类或 Lambda 表达式中访问的局部变量，如果不是 final 类型的话，编译器自动加上 final 修饰符，即Java8新特性：effectively final。

## 乐观锁和悲观锁使用场景

当竞争不激烈 (出现并发冲突的概率小)时，乐观锁更有优势，因为悲观锁会锁住代码块或数据，其他线程无法同时访问，影响并发，而且加锁和释放锁都需要消耗额外的资源。
当竞争激烈(出现并发冲突的概率大)时，悲观锁更有优势，因为乐观锁在执行更新时频繁失败，需要不断重试，浪费CPU资源。

## 反射原理

类加载器加载类获取Class对象，获取Class对象的属性，方法并进行操作。

## 注解原理

https://juejin.cn/post/6844904167517995022
https://juejin.cn/post/6844904168491073543

## 迭代器