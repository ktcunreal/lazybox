#!/bin/bash

MAIL_TITLE="AUTOMATIC TEST RESULT NOTIFICATION"
TEST_CASE=$1
TEST_STATUS=$2

if [[ -z "${TEST_CASE}" ]] || [[ -z "${TEST_STATUS}" ]]; then
	echo "Missing webhook parameter.">/tmp/mail.log;
	exit 1;
fi
	
for ln in `cat /root/webhook/config/mail_list.txt`; do 
	echo "An automatic test has triggered.
	Test subject is <${TEST_CASE}>
	${TEST_STATUS}" | mailx -v -s "${MAIL_TITLE}" ${ln};
	sleep 10;
done