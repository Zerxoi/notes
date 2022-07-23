#!/bin/bash

if [ $# -lt 1 ]
then
    echo "No Args Input..."
    exit ; 
fi

case $1 in
"start")
    echo " =================== 启动 hadoop 集群 ==================="
    echo " --------------- 启动 hdfs ---------------"
    ssh $NAMENODE_HOST "$HADOOP_HOME/sbin/start-dfs.sh" 
    echo " --------------- 启动 yarn ---------------"
    ssh $RESOURCEMANAGER_HOST "$HADOOP_HOME/sbin/start-yarn.sh"
    echo " --------------- 启动 historyserver ---------------"
    ssh $NAMENODE_HOST "$HADOOP_HOME/bin/mapred --daemon start historyserver"
;;
"stop")
    echo " =================== 关闭 hadoop 集群 ==================="
    echo " --------------- 关闭 historyserver ---------------"
    ssh $NAMENODE_HOST "$HADOOP_HOME/bin/mapred --daemon stop historyserver"
    echo " --------------- 关闭 yarn ---------------"
    ssh $RESOURCEMANAGER_HOST "$HADOOP_HOME/sbin/stop-yarn.sh" 
    echo " --------------- 关闭 hdfs ---------------"
    ssh $NAMENODE_HOST "$HADOOP_HOME/sbin/stop-dfs.sh"
;;
*)
   echo "Input Args Error..."
;;
esac