#!/bin/bash

export HADOOP_USERNAME=zouxin
export NAMENODE_HOST=hadoop-1
export RESOURCEMANAGER_HOST=hadoop-2
export SECONDARY_NAMENODE_HOST=hadoop-3
export JAVA_HOME=/home/$HADOOP_USERNAME/jdk8
export HADOOP_HOME=/home/$HADOOP_USERNAME/hadoop3

# Password-free login
ssh-copy-id $HADOOP_USERNAME@$NAMENODE_HOST

# Set environment variables
if [ `ssh $HADOOP_USERNAME@$NAMENODE_HOST grep -c JAVA_HOME .profile` -eq 0 ]
then
    ssh $HADOOP_USERNAME@$NAMENODE_HOST "cd ~ && \
        echo 'export JAVA_HOME=$JAVA_HOME' >> .profile && \
        echo 'export HADOOP_HOME=$HADOOP_HOME' >> .profile && \
        echo 'export PATH=\$PATH:\$JAVA_HOME/bin:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin' >> .profile && \
        source .profile"
fi


if [ ! -f jdk8.tar.gz ]
then
    curl -o jdk8.tar.gz https://repo.huaweicloud.com/java/jdk/8u202-b08/jdk-8u202-linux-x64.tar.gz
fi
if ssh $HADOOP_USERNAME@$NAMENODE_HOST test -d jdk8;
then
    echo "JDK8 is already installed!"
else
    scp jdk8.tar.gz $HADOOP_USERNAME@$NAMENODE_HOST:~
    ssh $HADOOP_USERNAME@$NAMENODE_HOST "cd ~ && mkdir -p jdk8 && tar zxvf jdk8.tar.gz -C ./jdk8 --strip-components 1 && rm jdk8.tar.gz"
fi

if [ ! -f hadoop3.tar.gz ]
then
    curl -o hadoop3.tar.gz https://mirrors.aliyun.com/apache/hadoop/common/hadoop-3.3.3/hadoop-3.3.3.tar.gz
fi
if ssh $HADOOP_USERNAME@$NAMENODE_HOST test -d hadoop3;
then
    echo "Hadoop3 is already installed!"
else
    scp hadoop3.tar.gz $HADOOP_USERNAME@$NAMENODE_HOST:~
    ssh $HADOOP_USERNAME@$NAMENODE_HOST "cd ~ && mkdir -p hadoop3 && tar zxvf hadoop3.tar.gz -C ./hadoop3 --strip-components 1 && rm hadoop3.tar.gz"
fi

mkdir -p tmp/conf
for file in core-site.xml hdfs-site.xml mapred-site.xml yarn-site.xml workers hadoop-env.sh
do
    envsubst < conf/$file > tmp/conf/$file
done

mkdir -p tmp/shell
for file in hadoopall.sh jpsall.sh scpall.sh
do
    envsubst '$NAMENODE_HOST $RESOURCEMANAGER_HOST $SECONDARY_NAMENODE_HOST' < shell/$file > tmp/shell/$file
done
scp tmp/conf/* $HADOOP_USERNAME@$NAMENODE_HOST:$HADOOP_HOME/etc/hadoop
scp tmp/shell/* $HADOOP_USERNAME@$NAMENODE_HOST:~
ssh $HADOOP_USERNAME@$NAMENODE_HOST "cd ~ && chmod +x *.sh"
rm -r tmp
