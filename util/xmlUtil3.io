#!/bin/bash
# xmlUtil3.io
# xmllint - libxml2-utils
# Version 3.0   - Revisado: 280622-1832
# Version 3.1	- Revisado: 120423-1844
RTCON=${1}/consoles.xml
NOD="$2"
TYPE=$3
vchkXML=""
vchkXML="$(xmlwf ${RTCON})"

if [ "${vchkXML}" != "" ];then
	echo "ERR1"
	exit 1
fi

xmlFind="string(//Consoles/${TYPE}/Console-target/node[text()=\"${NOD}\"])"
xmlFindUser='string(//Consoles/'${TYPE}'/Console-target[node/text()=''"'${NOD}'"]/login)'
xmlFindPwd='string(//Consoles/'${TYPE}'/Console-target[node/text()=''"'${NOD}'"]/password)'
xmlFindIP='string(//Consoles/'${TYPE}'/Console-target[node/text()=''"'${NOD}'"]/host)'
xmlFindPort='string(//Consoles/'${TYPE}'/Console-target[node/text()=''"'${NOD}'"]/port)'

if [ ! -f $RUTA ]
then
    echo "ERR2"
    exit 1
fi

MSEARCH=$(xmllint --xpath ${xmlFind} ${RTCON})

if [ "$(echo $MSEARCH|grep ..|wc -l)" != 0 ]
then
    USR=$(xmllint --xpath ${xmlFindUser} ${RTCON})
    PASSWD=$(xmllint --xpath ${xmlFindPwd} ${RTCON})
    IP=$(xmllint --xpath ${xmlFindIP} ${RTCON})
    PORT=$(xmllint --xpath ${xmlFindPort} ${RTCON})
else
    echo "ERR3"
    exit 1

fi

if [ "${USR}" != "" ];then
  echo "$USR $PASSWD $IP $PORT"
else
  echo "ERR4"
fi

