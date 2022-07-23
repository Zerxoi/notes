#!/bin/bash
for host in $NAMENODE_HOST $RESOURCEMANAGER_HOST $SECONDARY_NAMENODE_HOST
do
    echo =============== $host ===============
    ssh $host "$JAVA_HOME/bin/jps"
done
