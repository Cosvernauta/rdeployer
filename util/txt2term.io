#!/bin/bash
fnFirma() #Funcion para desplegar la firma del componente, obtiene la firma de la ruta Jenkins
{
        vApp=$2
        msg "Conectando a servidor para obtener firma(s) a través de terminal virtual:" "INFO"
        #echo "==================================================================================================================="
        if [ "${AutoColorOutPut}" = true ]
	then
		BarinColor="\e[37;44m"
        	BarnoColor="\e[0m"
	else
		BarinColor=""
		BarnoColor=""
	fi

        printf "+-----------------+\n"
        printf "| T X T 2 T E R M |"
        #printf "+-----------------+-----------------------------------------------------------------------------------------------------------------+\n"
        printf "$BarinColor\n| Terminal   Sessions        View    Tools   Settings        Help \t\t\t\t\t\t\t$BarnoColor\n"
        #printf "+-----------------------------------------------------------------------------------------------------------------------------------+\n"
        echo  " "

        for vC in $(echo ${vApp})
        do

        if [ $1 -eq 1 ]
        then
           vCOMP=${RTJK}/${vC}
           USRSO=$(whoami)
           echo "[ $USRSO | $HOSTNAME ] ${RTINST}"
           echo "${USRSO} $ md5sum ${vCOMP};ls -lad ${vCOMP}"
           md5sum ${vCOMP} | tee v.tmp # 240922-1347
	   cat v.tmp | head -1 > version.txt
	   rm -rf v.tmp
           [ "${AutoColorOutPut}" = true ] && ls -lad ${vCOMP} | awk '{print "\033[32m"$0"\033[0m"}' || ls -lad ${vCOMP} | awk '{print $0}'
           #echo "[ $USRSO | $HOSTNAME ] ${RTINST}"
           #echo "$USRSO $ date"
           #date
           #echo "[ $USRSO | $HOSTNAME ] ${RTINST}"
           #echo "$USRSO $"
        else
           vCOMP=${RTINST}/${vC}
           USRSO=$(ssh -q $IPSRV "whoami")
           hostn=$(ssh -q ${IPSRV} "hostname")
           #echo "Firma del componente ${APWAR} en la ruta del servidor ${IPSRV}:"
           # 110119-0528 Valida si es Linux, en caso contrario usa openssl
           echo "[ ${IPSRV} | ${hostn} ] ${RTINST}"
           ssh -q ${IPSRV} "[ "$(uname -s)" = "Linux" ] && echo '${USRSO} $ md5sum ${vCOMP}*;ls -lad ${vCOMP}*' || echo 'openssl dgst -md5 ${vCOMP}*'"
           ssh -q ${IPSRV} "[ "$(uname -s)" = "Linux" ] && md5sum ${vCOMP}* || openssl dgst -md5 ${vCOMP}*" | tee v.tmp # 240922-1347
	   cat v.tmp | head -1 > version.txt
	   rm -rf v.tmp
           [ "${AutoColorOutPut}" = true ] && ssh -q ${IPSRV} "ls -lad ${vCOMP}*" | awk '{print "\033[32m"$0"\033[0m"}' || ssh -q ${IPSRV} "ls -lad ${vCOMP}*" | awk '{print $0}'
        fi
        done

        if [ $1 -eq 1 ]
        then
          echo "[ $USRSO | $HOSTNAME ] ${RTINST}"
          echo "$USRSO $ date"
          date
          echo "[ $USRSO | $HOSTNAME ] ${RTINST}"
        else
          echo "[ ${IPSRV} | ${hostn} ] ${RTINST}"
          echo "${USRSO} $ date"
          ssh -q ${IPSRV} "date"
          echo "[ ${IPSRV} | ${hostn} ] ${RTINST}"
        fi

        echo "${USRSO} $ █"
        echo " "
#        printf "+-----------------------------------------------------------------------------------------------------------------------------------+\n"
        printf "$BarinColor\n| <F1>Menú   | <F2>Copy Prompt Terminal      | <F3>Paste Prompt Terminal     | <BloqMay>=Inactive \t\t\t$BarnoColor\n"
#        printf "+-----------------------------------------------------------------------------------------------------------------------------------+\n"
}

