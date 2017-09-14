#!/bin/bash

config_file='/usr/share/elasticsearch/config/elasticsearch.yml'

# It is assumed that the name of this appOrbit application tier is elasticsearch
tier_name='elasticsearch'
service='elasticsearch'

# Data and logs path
data_path='/var/lib/elasticsearch'

logs_path='/var/log/elasticsearch'

# Find out number of nodes in the cluster
num_cluster_nodes=${ES_NUM_OF_NODES}

# Wait until elasticsearch service is ready
until ping -c 1 ${tier_name}; do echo "Service ${tier_name} not reachable. Sleeping 5 seconds..."; sleep 5; done;

# Minimum number of nodes that must be present before startup/recovery can start
# The cluster will remain inoperable unless there are at least these many nodes
# Setting this to 75 % of total nodes
if [ "${num_cluster_nodes}" -le 2 ]; then
    min_required_nodes=${num_cluster_nodes}
else
    min_required_nodes=$((${num_cluster_nodes} * 75 / 100))
fi

# Wait until minimum required nodes are up
until [ $(getent hosts ${tier_name} | awk '{print $1}' | sort -u | wc -l) -ge ${min_required_nodes} ]
do
    echo "Waiting for ${min_required_nodes} nodes to be up. Sleeping 5 seconds..."
    sleep 5
done

# Rebuild the config file
echo '### Elasticsearch Config File Begins ###' > ${config_file}

# Cluster name
echo "cluster.name: ${ES_CLUSTER_NAME:-apporbit-es-cluster}" >> ${config_file}

# Node name
echo "node.name: ${HOSTNAME}" >> ${config_file}

# network.host will bind the node to this IP address and publish it to other nodes in the cluster
echo "network.host: $(hostname -i)" >> ${config_file}

# Provide data path
echo "path.data: ${data_path}" >> ${config_file}

# Provide logs path
echo "path.logs: ${logs_path}" >> ${config_file}

# Disable security to as X-pack security requires license which is currently out of scope of this application
#commented out by Raj
#echo 'xpack.security.enabled: false' >> ${config_file}

# Find out quorum of nodes to avoid the problem of split brain
# A cluster of just 2 nodes is not recommended as as quorum of 2 nodes is 2 which makes the cluster inoperable
# in case of loss of any node.
quorum=`expr ${num_cluster_nodes} / 2 + 1 `
echo "discovery.zen.minimum_master_nodes: ${quorum}" >> ${config_file}

# Identify other nodes in the cluster and create their list
ip_list=''
for ip in $(getent hosts ${tier_name} | awk '{print $1}' | sort -u | grep -v $(hostname -i)); do ip_list="${ip_list}\"${ip}\", "; done
ip_list=$(echo "[$(echo ${ip_list} | sed s/,$//)]")

# Configure other nodes for unicast
echo "discovery.zen.ping.unicast.hosts: ${ip_list}" >> ${config_file}

# Recovery Settings
# How many nodes should be there in the cluster
echo "gateway.expected_nodes: ${num_cluster_nodes}" >> ${config_file}
# How long to wait for all the nodes
echo "gateway.recover_after_time: 5m" >> ${config_file}
# Minimum number of nodes that must be present before recovery can start
echo "gateway.recover_after_nodes: ${min_required_nodes}" >> ${config_file}

# if bootstrap.memory_lock is enabled, it also requires ulimit to be set with docker run --ulimit memlock=-1:-1
#echo "bootstrap.memory_lock: true" >> ${config_file}

echo '### Elasticsearch Config File Ends ###' >> ${config_file}
cat ${config_file}

# check if elasticsearch is already running
# if running stop elastic search
#if (( $(ps -ef | grep -v grep | grep $service | wc -l) >0 ))
#then
#echo "service $service is running. Will be restarted"
#service elasticsearch stop
#service elasticsearch start
#else
#echo "service $service is NOT running. Will be started"
#service elasticsearch start
#fi
#tail -f dummylogfile

#Delete User=Elasticsearch from Group=Sudo
deluser elasticsearch sudo
su elasticsearch -c /usr/share/elasticsearch/bin/elasticsearch

# call downstream script. Was part of the original elasticsearch container
#/bin/bash /usr/share/elasticsearch/bin/es-docker.sh

