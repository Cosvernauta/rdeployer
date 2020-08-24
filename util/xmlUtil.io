#!/bin/bash
# Version 1.0 - Revisado: 15042018-1854
# Funciona con rdeployer.sh
RUTA=${1}/consoles.xml
NOD=$2

if [[ ! -f $RUTA ]]; then
    echo "ERROR"
    exit 1
fi

n1=($(grep -oP '(?<=node>)[^<]+' "${RUTA}"))
for i in ${!n1[*]}; do
    #echo "$i" "${n1[$i]}"
    if [[ ${n1[$i]} == ${NOD} ]];then
        #echo "Es igual"
        MSEARCH=$i
    fi
    # instead of echo use the values to send emails, etc
done


n1=($(grep -oP '(?<=login>)[^<]+' "${RUTA}"))
for i in ${!n1[*]}; do
    #echo "$i" "${n1[$i]}"
    if [ $i -eq ${MSEARCH} ]
    then
        #echo "Es igual"
        USR=${n1[$i]}
    fi
done


n1=($(grep -oP '(?<=password>)[^<]+' "${RUTA}"))
for i in ${!n1[*]}; do
  #echo "$i" "${n1[$i]}"
  if [ $i -eq ${MSEARCH} ];then
      #echo "Es igual"
      PASSWD=${n1[$i]}
  fi
done

n1=($(grep -oP '(?<=host>)[^<]+' "${RUTA}"))

for i in ${!n1[*]}; do
  #echo "$i" "${n1[$i]}"
  if [ $i -eq ${MSEARCH} ];then
      #echo "Es igual"
      IP=${n1[$i]}
  fi
done

n1=($(grep -oP '(?<=port>)[^<]+' "${RUTA}"))

for i in ${!n1[*]}; do
  #echo "$i" "${n1[$i]}"
  if [ $i -eq ${MSEARCH} ]; then
      #echo "Es igual"
      PORT=${n1[$i]}
  fi
done

echo "$USR $PASSWD $IP $PORT"
