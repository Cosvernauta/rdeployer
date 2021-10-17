#!/bin/bash
# xmlUtil2.io
# perl-XML-XPath
# Version 2.0 - Revisado: 28022020-0052
RTCON=${1}/consoles.xml
NOD="$2"
TYPE=$3

xmlwf ${RTCON}
xmlFind=$(echo '//Consoles/'${TYPE}'/Console-target/node[text()=''"'${NOD}'"]')
xmlFindUser=$(echo '//Consoles/'${TYPE}'/Console-target[node/text()=''"'${NOD}'"]/login')
xmlFindPwd=$(echo '//Consoles/'${TYPE}'/Console-target[node/text()=''"'${NOD}'"]/password')
xmlFindIP=$(echo '//Consoles/'${TYPE}'/Console-target[node/text()=''"'${NOD}'"]/host')
xmlFindPort=$(echo '//Consoles/'${TYPE}'/Console-target[node/text()=''"'${NOD}'"]/port')

if [ ! -f $RUTA ]
then
    echo "ERROR"
    exit 1
fi

MSEARCH=$(xpath ${RTCON} ${xmlFind})

if [ "$(echo $MSEARCH | grep .. | wc -l)" == 1 ]
then
    vTMP=$(xpath ${RTCON} ${xmlFindUser})    
    USR=$(echo $vTMP | awk -F">" '{print $2}'| awk -F"<" '{print $1}')
    vTMP=$(xpath ${RTCON} ${xmlFindPwd})
    PASSWD=$(echo $vTMP | awk -F">" '{print $2}'| awk -F"<" '{print $1}')
    vTMP=$(xpath ${RTCON} ${xmlFindIP})
    IP=$(echo $vTMP | awk -F">" '{print $2}'| awk -F"<" '{print $1}')
    vTMP=$(xpath ${RTCON} ${xmlFindPort})
    PORT=$(echo $vTMP | awk -F">" '{print $2}'| awk -F"<" '{print $1}')
else
    echo "ERROR"
    exit 1

fi

echo "$USR $PASSWD $IP $PORT"
