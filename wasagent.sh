#!/bin/bash

HOST=$1
CONNECTOR="9090"

DATA=$(wget -q -O - http://${HOST}:${CONNECTOR}/wasagent/WASAgent --post-data=$22 2> /dev/null)

[ $? != 0 ] && exit 2
echo ${DATA} | awk -F\| '{ print $2"|"$3  ; exit $1 }'
exit $?
