#! /bin/bash
# 作用: 用于自动删除ceph集群中osd的配置信息及osd所在物理节点的对应配置
# 执行方式: sh auto_del_ceph_osd.sh ID 
# version 0.1
# to_do: a. 添加osd删除导致数据平衡过程的集群状态监控; b. 该脚本只能在本机运行, 无法在远程主机运行; c. 缺少必要判断

osd_data_path=$(ceph daemon osd.$1 config show | grep osd_data | awk -F '"' '{print $4}' | tr -d '\' 2> /dev/null)
osd_data_dev=$(mount | grep ${osd_data_path} | awk '{print $1}' | tr -d '[0-9]')
osd_journal_path=$(ceph daemon osd.$1 config show | grep "\bosd_journal\b" | awk -F '"' '{print $4}' | tr -d '\' 2> /dev/null)
osd_journal_dev=$(ls -l ${osd_journal_path} | awk '{print $NF}')
[[ -b ${osd_journal_path} ]] && osd_journal_dev_flag=1 || osd_journal_dev_flag=0

echo -e "osd_data_path=${osd_data_path}\nosd_journal_path=${osd_journal_path}\nosd_journal_dev_flag=${osd_journal_dev}\nosd_journal_dev_flag=${osd_journal_dev_flag}\n"

systemctl stop ceph-osd@$1.service
# centos 6使用service ceph stop osd.$1
ceph osd out osd.$1
ceph osd crush remove osd.$1
ceph auth del osd.$1
ceph osd rm osd.$1
echo "Rebalancing osd.$1 data..."

# ceph集群数据平衡状态监测脚本

echo "Cleaning osd.$1 config..."
sed -i "/^\[osd.$1\]/,/^$/d" /etc/ceph/ceph.conf
sed -i "/ceph-$1/d" /etc/fstab
sed -i "/ceph-$1/d" /etc/rc.d/rc.local

echo "Cleaning osd.$1 journal..."
if [[ ${osd_journal_dev_flag} == 1 ]];then
     dd if=/dev/zero of=${osd_journal_dev} bs=20M  &> /dev/null
     [[ $? == 1 ]] && echo "Complete clean osd.$1 journal disk"
     sleep 5
else
     rm -rf ${osd_journal_dev}
     sleep 5
fi

echo "Cleaning osd.$1 data..."
rm -rf /var/lib/ceph/osd/ceph-$1/*
fuser -v -k  /var/lib/ceph/osd/ceph-$1/ &> /dev/null
umount ${osd_data_path}
rm -rf /var/lib/ceph/osd/ceph-$1
ceph-disk zap ${osd_data_dev} &> /dev/null

echo "Complete delete $(hostname) osd.$1 !!!"

