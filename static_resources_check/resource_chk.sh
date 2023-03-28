#!/bin/bash

REC_DATE=`date +%Y%m%d`

for ln in `cat /root/static_res_chk/website_list.txt`; do
       curl -sL ${ln} | grep -v runtime | sed -e "s#src=\"\/\/#\n#g" -e "s#\"#\n#g" -e "s#\/\/#\n#g" -e "s#\/>#\n#g" | grep cdn >> /tmp/static_res_${REC_DATE}.txt;
done

uniq /tmp/static_res_${REC_DATE}.txt

for ln in `cat /tmp/static_res_${REC_DATE}.txt`; do
        RET_CODE=`curl -sI ${ln} | head -n1 | awk '{print $2}'`
        sed -i "s#${ln}#${ln} ${RET_CODE}#" /tmp/static_res_${REC_DATE}.txt
done

if [[ -n "`grep -v 200 /tmp/static_res_${REC_DATE}.txt`" ]]; then
	for ln in `cat /root/static_res_chk/alert_email.txt`; do
            echo "Missing resourse: `grep -v 200 /tmp/static_res_${REC_DATE}.txt`" | mailx -v -s "Static resourse report" ${ln};
	    sleep 10;
	done;
fi