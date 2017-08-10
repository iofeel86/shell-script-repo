#! /bin/bash
# version 0.1

# define init para
# JOURNAL_PARTION_UUID用于指定journal分区在 /dev/disk/by-partuuid/ 下的uuid
journal_partion_uuid=$(uuidgen)
#echo "/dev/disk/by-partuuid/${journal_partion_uuid}" > /tmp/ceph_new_osd_journal_uuid
OSD_JOURNAL_DEV_TYPECODE="45b0969e-9b03-4f30-b4c6-b4b80ceff106"
OSD_DATA_DEV_TYPECODE="4fbd7e29-9d25-41b8-afd0-062c0ceff05d"

function get_osd_journal_size() {
     local def_journal=`grep "^osd_journal_size\b" /etc/ceph/ceph.conf  | awk '{print $NF}'`
     echo ${def_journal:-5120}
}
journal_size=$(get_osd_journal_size)

function get_osd_journal_part_num() {
     local src_journal_dev_part_num=$(sgdisk -p $1 | awk 'END{print $1}' | grep -o "[0-9]*")
     local dst_journal_dev_part_num=$(echo 1 ${src_journal_dev_part_num:-0} | awk '{print $1+$2}')
     echo ${dst_journal_dev_part_num}
}

case $# in
1)
# osd的journal和data同一设备: journal分区为1, data分区为2
     osd_journal_device=$1
     osd_data_device=$1
     journal_part_num=1
     osd_part_num=2
     sgdisk --set-alignment=2048  --new=1::+${journal_size}M --mbrtogpt --change-name=1:"ceph journal" --partition-guid=1:${journal_partion_uuid} --typecode=1:${OSD_JOURNAL_DEV_TYPECODE} -- ${osd_journal_device} &> /dev/null && echo "${osd_journal_device} JOURNAL PART OK!!!"
     sgdisk --set-alignment=2048 --new=${osd_part_num}:: --change-name=${osd_part_num}:"ceph data" --typecode=${osd_part_num}:${OSD_DATA_DEV_TYPECODE} --mbrtogpt -- ${osd_data_device} &> /dev/null && echo "${osd_data_device} DATA PART OK!!!"
     ;;
2)
# osd的journal和data不同设备
     osd_journal_device=$2
     osd_data_device=$1
     journal_part_num=$(get_osd_journal_part_num ${osd_journal_device})
     osd_part_num=1
     sgdisk --set-alignment=2048  --new=${journal_part_num}::+${journal_size}M --mbrtogpt --change-name=${journal_part_num}:"ceph journal" --partition-guid=${journal_part_num}:${journal_partion_uuid} --typecode=${journal_part_num}:${OSD_JOURNAL_DEV_TYPECODE} -- ${osd_journal_device} &> /dev/null && echo "${osd_journal_device} JOURNAL PART OK!!!"
     sgdisk --set-alignment=2048 --new=${osd_part_num}:: --change-name=${osd_part_num}:"ceph data" --typecode=${osd_part_num}:${OSD_DATA_DEV_TYPECODE} --mbrtogpt -- ${osd_data_device} &> /dev/null && echo "${osd_data_device} DATA PART OK!!!"
     ;;
*)
     echo "Para is error"
     ;;
esac
echo ":${osd_data_device}${osd_part_num}:/dev/disk/by-partuuid/${journal_partion_uuid}" >> /tmp/ceph-osd_journal_map_list
