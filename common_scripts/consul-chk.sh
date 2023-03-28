#!/bin/bash

#########################################
#### consul service health check script           ####
#### Author: ktcunreal@gmail.com                  ####
#### 2020                                                                      ####
#########################################

# set -xe

# 各环境项目
TEST=("gateway" "cbbs" "cbps" "insurance" "mtms")
QA1=("gateway" "cbbs" "cbps" "infra" "insurance" "mtms")
QA2=("gateway" "cbbs" "cbps" "infra" "mtms" "gold-facade")
DTTEST=("gateway" "cbbs" "cbps" "infra" "mtms" "gold-facade")
SUM=$[ ${#TEST[*]} + ${#QA1[*]} + ${#QA2[*]} + ${#DTTEST[*]} ]

# 邮件头
MSG="SERVICE STATUS MONITOR\n-------------------------------\n\n"

# 日志存放路径
LOG=/var/log/healthchk.log

svcchk() {
    if [[ -z `curl -sL $CONSUL | /usr/local/bin/jq | grep $1` ]]; then
        echo "[`date +%Y.%m.%d%t%H:%M:%S`] <$ENVIRONMENT> Service <$1> seems down.Please check consul for more detail." | tee -a $LOG;
    else
        echo "[`date +%Y.%m.%d%t%H:%M:%S`] <$ENVIRONMENT> Service <$1> is up." | tee -a $LOG;
    fi
}

healthchk() {
    ENVIRONMENT=$1
    CONSUL=$2
    SERVICE=("$@")
    for (( i=2;i<${#SERVICE[*]};i++ ));
    do
        svcchk ${SERVICE[$i]}
    done;
}

# 执行检查
healthchk "title1" "http://127.0.0.1:8500/v1/agent/checks" ${TEST[*]}
healthchk "title2" "http://127.0.0.1:8500/v1/agent/checks" ${QA1[*]}
healthchk "title3" "http://127.0.0.1:8500/v1/agent/checks" ${QA2[*]}
healthchk "title4" "http://127.0.0.1:8500/v1/agent/checks" ${DTTEST[*]}

# 报警邮件
for ln in `seq 1 $SUM`;
do
    GROUP=`tac $LOG | sed -n "$ln"p | grep "down" | awk -F '[<>]' '{print $2}'`
    PROJ=`tac $LOG | sed -n "$ln"p | grep "down" | awk -F '[<>]' '{print $4}'`
    if [[ $PROJ && ! -e /var/log/$GROUP.$PROJ.lock ]]; then
        echo -e "$MSG`tac $LOG | sed -n \"$ln\"p`" | tr -d '\r' | mail -s "Consul 报警信息"  123456@qq.com
        touch /var/log/$GROUP.$PROJ.lock  
    fi
done

# 恢复邮件
for ln in `seq 1 $SUM`;
do
    GROUP=`tac $LOG | sed -n "$ln"p | grep "up" | awk -F '[<>]' '{print $2}'`
    PROJ=`tac $LOG | sed -n "$ln"p | grep "up" | awk -F '[<>]' '{print $4}'`
    if [[ $PROJ && -e /var/log/$GROUP.$PROJ.lock ]]; then
        echo -e "$MSG`tac $LOG | sed -n \"$ln\"p`" | tr -d '\r' | mail -s "Consul 报警恢复"  123456@qq.com
        rm /var/log/$GROUP.$PROJ.lock -f
    fi
done
