#! /bin/bash 
# 脚本名称: ceph_cluster_pool_adjust_pg.sh
# 脚本用途: 在ceph集群进行扩容操作后, 并且需要对pg和pgp进行调整的情况下, 用于实现将pg_num和pgp_num调整至目标值
# 执行方式: sh ceph_cluster_pool_adjust_pg.sh rbd 16 2 ;其中: $1=rbd用于指定本次调整pgp的对应的存储池pool的名称; $2=16用于指定本次对pg调整的目标值为16; #3=2用于指定每次增加pg或pgp的步进值为2
# 执行位置: ceph-mon节点或ceph-osd节点
# 执行条件: 执行脚本节点与当前ceph集群可以正常通信
# 日期: 2017-08-17
# 版本: v0.4
# 维护人员: Pavel
# TO_DO: a. 已对脚本在测试环境进行测试, 未产生问题


DATE_DAY=$(date +%F)
[ -d /var/log/ops/ceph ] || mkdir -p /var/log/ops/ceph
ADJUST_PGNUM_LOG="/var/log/ops/ceph/${DATE_DAY}-auto_adjust_ceph_pgnum.log"

dest_pg_num=$2
#adjust_pg_unit=$3

check_ceph_cluster_states() {
    local cluster_pg_num=$(ceph pg dump pgs_brief 2> /dev/null | grep "^[0-9]*\." | wc -l)
    local cluster_pg_in_active_clean=$(ceph pg dump pgs_brief 2> /dev/null | grep "\bactive+clean\b" | wc -l)
    if [ ${cluster_pg_num} == ${cluster_pg_in_active_clean} ];then
        echo "$(date +%F_%H:%M:%S) ceph cluster is in health states, will to auto adjust pgp_num\n" >> ${ADJUST_PGNUM_LOG}
        return 0
    else
        echo "$(date +%F_%H:%M:%S) ceph cluster is not in health states, will not to auto adjust pgp_num\n" >> ${ADJUST_PGNUM_LOG}
        return 1
    fi
}

judege_pg_num_diff_dest_pg_num() {
    local pool_pg_num=$(ceph osd pool get $1 pg_num | awk '{print $2}')
    local pool_pgp_num=$(ceph osd pool get $1 pgp_num | awk '{print $2}')
    if [[ ${pool_pg_num} -eq ${dest_pg_num} ]];then
		if [[ ${pool_pg_num} -gt ${pool_pgp_num} ]];then
			judge_ceph_pool_pg_and_pgp_num $1 $2
		else
			echo  -e "Adjust $1 pg_num work complete!"
			exit 0
		fi
    elif [[ ${pool_pg_num} -gt ${dest_pg_num} ]];then
        echo -e "Pool $1 pg_num > ${dest_pg_num}"
        exit 4
    else
        judge_ceph_pool_pg_and_pgp_num $1 $2
    fi
}



judge_ceph_pool_pg_and_pgp_num() {
    local pg_num=$(ceph osd pool get $1 pg_num | awk '{print $2}')
    local pgp_num=$(ceph osd pool get $1 pgp_num | awk '{print $2}')
    
    if [[ ${pg_num} -lt ${pgp_num} ]]; then
            echo "POOL $1 is error"
    elif [[ ${pg_num} -eq ${pgp_num} ]]; then
            adjust_ceph_pool_pg_and_pgp_num $1 pg $2
    else [[ ${pg_num} -gt ${pgp_num} ]]
            adjust_ceph_pool_pg_and_pgp_num $1 pgp $2
    fi
}

adjust_ceph_pool_pg_and_pgp_num() {
    local adjust_flag=$2
    local src_num=$(ceph osd pool get $1 $2_num | awk '{print $2}')
    if [ ${adjust_flag} == pg ];then
        local dest_num=${dest_pg_num}
    elif [ ${adjust_flag} == pgp ];then
        local dest_num=$(ceph osd pool get $1 pg_num | awk '{print $2}')
    else
        echo -e "adjust_ceph_pool_pg_and_pgp_num function not hava a correct parameter"
        exit 5
    fi

    local adjust_unit=$(judege_adjust_unit ${src_num} ${dest_num} $3)
    local actual_dest_num=$(echo ${adjust_unit} ${src_num} | awk '{print $1+$2}')
    echo -e "\nADJUST POOL $1 ${adjust_flag}_num ${src_num} ==> ${actual_dest_num}"
    ceph osd pool set $1 ${adjust_flag}_num ${actual_dest_num}
    echo -e "=========="
}


judege_adjust_unit() {
        local judge_flag=$(echo $1 $2 $3 | awk '{print int(($2-$1)/$3)}')
        if [ "${judge_flag}" -lt 1 ]; then
            local pgp_unit=$(echo $1 $2 | awk '{print $2-$1}')
        else
            local pgp_unit=$3
        fi
        echo ${pgp_unit}
}

local_script_usage() {
	echo -e "Usage: $0 \$1 \$2 \$3"
	echo -e '	$1 => POOL_NAME is the pool to adjust pg_num'
	echo -e '	$2 => DEST_PG_NUM is the pg_num to be'
	echo -e '	$3 => ADJUST_PG_UNIT is the size to adjust pg_num or pgp_num in each time'
}

if [[ $1 == "?" || $1 == "-h" || $1 == "--help" || $1 == "help" ]];then
	local_script_usage
	exit 2
fi

if [[ $# -ne 3 ]];then
	local_script_usage
else
	while true;do
	    check_ceph_cluster_states
	    if [ $? = 0 ]; then
		judege_pg_num_diff_dest_pg_num $1 $3
	    else
		echo "ceph cluster is not health"
		#return 7
	    fi
	    sleep 5
	done
fi

