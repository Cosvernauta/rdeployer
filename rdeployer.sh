#!/bin/bash
######################################################################
# Deploy para Jenkins con WebLogic/JBoss/Oracle Services Bus
# Construido para Jenkins (tested 2.84, 2.138)
# JBoss 6.x en adelante (tested 6.4, 7.2)
# Weblogic: 10.x en adelante (tested 10.3, 11g, 12.x)
# OSB/ESB: 11g en adelante (tested 11g, 12c)
#---------------------------------------------------------------------
# Para mas info , revisar ROADMAP
# Jimmy R. Lili jlili.salgado(a)gmail.com
######################################################################
#Set Variables
vEXIT=0
[ "$1" == "" ] && APDIR="${APHOME}" || APDIR="${APHOME}/$1"
UNDEP=$2
APNAME=`basename ${0%.*}`
U_HOUR="$(date '+%H%M')"
U_DATE="$(date '+%Y%m%d')"
U_TIME="${U_DATE}${U_HOUR}"
U_MES="$(date '+%m')"
APPLOG=${APNAME}.${BUILD_NUMBER}.log # 230319-1528
APPID=${APNAME}${BUILD_NUMBER} # 070919-1736
#[ "${CICD}" == "Jenkins" ] && APPLOG=${APNAME}.${BUILD_NUMBER}.log # 230319-1528 140921-0836
#[ "${CICD}" == "Jenkins" ] && APPID=${APNAME}${BUILD_NUMBER} || APPID=${APNAME} # 070919-1736 140921-0836
VERSION="3.1.3"
export monthnames=(Invalid Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic)
YEAR="$(date '+%Y')"
MES=${monthnames[${U_MES#0}]}
LOGAPHIST="${APNAME}.history"
NRFC=$(echo ${RFC} | tr -d [:blank:])
# Se debe configurar en el job 2 variables: TYPEINST y RFC
#TYPEINST - Parámetro de elección:
#	    Opciones: new | rollback
#RFC - Parámetro de Cadena
export ORACLE_HOME=${OSB_HOME}
export MW_HOME=${ORACLE_HOME}
export WL_HOME=${ORACLE_HOME}/wlserver


fnDeployerJB() # 300320-1858
{
touch ${APNAME}.log
#Armamos el command CLI de conexión a la consola
HOSTURL="${IPSRV}:${PORT}"
RTC=${RTJK}/${APWAR}

#Armamos las opciones para deployar
CMD="deploy ${RTC}"
CMD="$CMD --force"
ICMD="deployment-info --name=${APWAR}"
SHA1="ls deployment=${APWAR}"
OPTIONS="--connect"
OPTIONS="$OPTIONS --controller=${HOSTURL}"
OPTIONS="$OPTIONS --user=${USER}"
OPTIONS="$OPTIONS --password=${PASSWD}"
#OPTIONS="$OPTIONS --command-timeout $TIMEO" 
#OPTIONS="$OPTIONS --commands='${SHA1},${ICMD},${CMD},${SHA1}'"

msg "Creando la estructura para deployar:" "INFO"
msg "Nombre de la aplicacion: ${APNAME}" "DEBUG"
msg "Componente: ${APWAR}" "DEBUG"
msg "Target(s): ${SRVNAMES}" "DEBUG"
msg "Consola: ${HOSTURL}" "DEBUG"
msg "Nodo: ${NODE}" "DEBUG"
msg "Usuario consola: ${USER}" "DEBUG"

#Realizamos el check de la aplicación.
fnCheckJB $OPTIONS $ICMD
sleep 5
#310520-1510
#Detenemos el componente.
fnStopJB
sleep 5

msg "Ejecutando deploy, espere un momento..." "INFO"
echo "[ $(date) ]" >> ${APNAME}.log
echo "===== INFO/REDEPLOY APP =====" >> ${APPLOG}
nohup ${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --commands="${SHA1},${ICMD},${CMD},${SHA1}" >> ${APPLOG}  2>&1

if [ $? -gt 0 ]
then
    fnError
    msg "Verificar la salida en el archivo ${APPLOG} en workspace para más información:" "ERROR"
    msg "${JOB_URL}ws/${APPLOG}" "LOG" # 070919-1736
    [ "${TYPEINST}" == "rollback" ] && exit 1 # 190619 Bug detectado, hacia doble rollback cuando la opcion era rollback y fallaba el war en instalarse, se coloca esta línea para que valide el tipo de instalacion.
    [ "$NPROD" == "0" ] && msg "Aplicando Rollback a la estructura Generada:" "DEBUG"
    [ "$NPROD" == "0" ] && fnEstructuraRB
    #Levantamos el componente apagado.
    fnStartJB
    exit 1
else
        msg "Deploy realizado." "OK"
        sleep 5
	#Detenemos el componente.
	#fnStopJB
	#sleep 5
        #Levantamos el componente.
        fnStartJB
fi

}

fnDeployerWL()
{
# fnDeployerWL [0|1]
# 0 = Para desactivar el upload
# 1 = Para activar el upload
touch ${APNAME}.log
#Armamos el t3 de conexión a la consola
T3URL="t3://"
T3URL="$T3URL${IPSRV}:"
T3URL="$T3URL${PORT}"

#Armamos las opciones para deployar
OPTIONS="-debug -remote -verbose"

if [ $1 -eq 1 ]
then
     OPTIONS="$OPTIONS -upload" # Aplicable para los no produtivos, para que siempre lo suba al AdminServer
     RTC=${RTJK}/${APWAR}
else
     RTC=${RTINST}/${APWAR}
fi

OPTIONS="$OPTIONS -name ${APNAME}"  # Nombre de la aplicacion
OPTIONS="$OPTIONS -source ${RTC}" #Ruta del componente a instalar, debe estar localmente
OPTIONS="$OPTIONS -targets ${SRVNAMES}" # Las instancias donde se va a deployar el componente o donde se encuentra deployado
OPTIONS="$OPTIONS -adminurl ${T3URL}" # La cadena URL de conexion, usaremos T3
OPTIONS="$OPTIONS -timeout ${TIMEO}" # 220519-1703 Timeout si no se llega a deployarse.
OPTIONS="$OPTIONS -user ${USER} -password ${PASSWD}" # Usuario y password para poder entrar a la consola

msg "Creando la estructura para deployar:" "INFO"

msg "Nombre de la aplicacion: ${APNAME}" "DEBUG"
msg "Componente: ${APWAR}" "DEBUG"
msg "Target(s): ${SRVNAMES}" "DEBUG"
msg "Consola: ${T3URL}" "DEBUG"
msg "Nodo: ${NODE}" "DEBUG"
msg "Usuario consola: ${USER}" "DEBUG"

if [ "${UNDEP}" == "undeploy" ]
then
    msg "Opción undeploy seleccionada, forzando a modo undeploy:" "INFO"
    echo "===== UNDEPLOY APP =====" >> ${APPLOG}
    nohup ${JAVA_HOME}/bin/java -Xms${vMEMORYINI} -Xmx${vMEMORYMAX} -cp ${WEBLOGIC_HOME}/server/lib/weblogic.jar weblogic.Deployer ${OPTIONS} -undeploy >> ${APPLOG}  2>&1

    [ $? -gt 0 ] && msg "Error en la desinstalación del componente, Se continuará con un redeploy" "ERROR" || msg "Undeploy realizado" "OK"
fi

#Armamos las opciones para stop/start | 110119-0528
OPTIONS2="-debug -remote -verbose"
OPTIONS2="$OPTIONS2 -name ${APNAME}"  # Nombre de la aplicacion
OPTIONS2="$OPTIONS2 -targets ${SRVNAMES}" # Las instancias donde se va a deployar el componente o donde se encuentra deployado
OPTIONS2="$OPTIONS2 -adminurl ${T3URL}" # La cadena URL de conexion, usaremos T3
#OPTIONS2="$OPTIONS2 -id ${APPID}" # 070919-1736
OPTIONS2="$OPTIONS2 -user ${USER} -password ${PASSWD}" # Usuario y password para poder entrar a la consola

#Armamos las opciones para Check | 111110-1745
OPTIONS3="-remote"
OPTIONS3="$OPTIONS3 -adminurl ${T3URL}" # La cadena URL de conexion, usaremos T3
OPTIONS3="$OPTIONS3 -user ${USER} -password ${PASSWD}" # Usuario y password para poder entrar a la consola

#Realizamos el check de la aplicación.
fnCheckWL $OPTIONS3
sleep 5
#Detenemos el componente
fnStopWL
sleep 5

#Ejecutamos el deploy con las opciones configuradas
msg "Ejecutando deploy, espere un momento..." "INFO"
echo "[ $(date) ]" >> ${APNAME}.log
echo "===== DEPLOY/REDEPLOY APP =====" >> ${APPLOG}
nohup ${JAVA_HOME}/bin/java -Xms${vMEMORYINI} -Xmx${vMEMORYMAX} -cp ${WEBLOGIC_HOME}/server/lib/weblogic.jar weblogic.Deployer ${OPTIONS} -redeploy >> ${APPLOG}  2>&1

if [ $? -gt 0 ]
then
    fnError 
    msg "Verificar la salida en el archivo ${APPLOG} en workspace para más información:" "ERROR"
    msg "${JOB_URL}ws/${APPLOG}" "LOG" # 070919-1736 
    [ "${TYPEINST}" == "rollback" ] && exit 1 # 190619 Bug detectado, hacia doble rollback cuando la opcion era rollback y fallaba el war en instalarse, se coloca esta línea para que valide el tipo de instalacion.
    [ "$NPROD" == "0" ] && msg "Aplicando Rollback a la estructura Generada:" "DEBUG"
    [ "$NPROD" == "0" ] && fnEstructuraRB 
    #Levantamos el componente apagado.
    fnStartWL
    exit 1
else
	msg "Deploy realizado." "OK"
	sleep 5
	#WARNG=$(grep "Unable to contact" ${WORKSPACE}/${APPLOG}|wc -l)
	WARNG=$(grep "Target state: start failed on Server" ${WORKSPACE}/${APPLOG}|wc -l)

	if [ ${WARNG} -gt 0 ]
	then
	    msg "Se encontraron que algunas instancias no estaban disponibles, checar ${JOB_URL}ws/${APPLOG}" "WARN"
	    vEXIT=4
	fi
	
	#Levantamos el componente.
	fnStartWL
fi

}

fnDeployESB()
{
#Parametros: t3 user    password        component.jar   CustomizationFile       osb     default
touch ${APNAME}.log
#Armamos el t3 de conexión a la consola
T3URL="t3://"
T3URL="$T3URL${IPSRV}:"
T3URL="$T3URL${PORT}"


if [ -f ${OSB_HOME}/osb/tools/configjar/setenv.sh ]
then
	source ${OSB_HOME}/osb/tools/configjar/setenv.sh >> ${APPLOG}
	if [ $? -gt 0 ]
	then
		msg "No se puede aplicar set de variables necesarias para ESB, favor de revisar salida de log" "ERROR"
		exit 1
	else
		msg "Configuracion cargada para esb" "OK"
	fi
else
	msg "No existe el archivo para cargar configuracion de esb, favor de validar" "ERROR"
	exit 1
fi

msg "Ejecutando deploy, espere un momento..." "INFO"
msg "${JOB_URL}ws/${APPLOG}" "LOG"
echo "===== DEPLOY APP ESB CONSOLE =====" >> ${APPLOG}
nohup ${ORACLE_HOME}/oracle_common/common/bin/wlst.sh ${APHOME}/util/fnESBmod.py ${T3URL} ${USER} ${PASSWD} ${RTJK}/${APWAR} ${RTJK}/${PROJECTCONF} ${OSBKEY} ${PROJECTNAME} >> ${APPLOG} 2>&1

if [ $? -gt 0 ]
then
    fnError
    msg "Verificar la salida en el archivo ${APPLOG} en workspace para más información:" "ERROR"
    msg "${JOB_URL}ws/${APPLOG}" "LOG" # 070919-1736
    [ "${TYPEINST}" == "rollback" ] && exit 1 # 190619 Bug detectado, hacia doble rollback cuando la opcion era rollback y fallaba el war en instalarse, se coloca esta línea para que valide el tipo de instalacion.
    [ "$NPROD" == "0" ] && msg "Aplicando Rollback a la estructura Generada:" "DEBUG"
    [ "$NPROD" == "0" ] && fnEstructuraRB
    exit 1
else
        msg "Deploy realizado." "OK"
        sleep 5
fi

}


fnCheckJB()  # 300320-1858
{
 msg "Validando que exista la Aplicación:" "INFO"
 msg "${APNAME}" "DEBUG"
 echo "===== LIST APP =====" >> ${APPLOG}
 nohup ${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --command="ls deployment=" >> ${APPLOG}  2>&1


 if [ $(cat ${APPLOG} | grep ${APNAME} | wc -l) -gt 1 ]
 then
        msg "Aplicación existente." "DEBUG"
 else
        msg "La Aplicación no está instalada." "DEBUG"
 fi

}


fnCheckWL()  # 111110-1745
{
 msg "Validando que exista la Aplicación:" "INFO"
 msg "${APNAME}" "DEBUG"
 echo "===== LIST APP =====" >> ${APPLOG}
 nohup ${JAVA_HOME}/bin/java -Xms${vMEMORYINI} -Xmx${vMEMORYMAX} -cp ${WEBLOGIC_HOME}/server/lib/weblogic.jar weblogic.Deployer ${OPTIONS3} -listtask >> ${APPLOG} 2>&1

 #if [ $(${JAVA_HOME}/bin/java -Xms512M -Xmx512M -cp ${WEBLOGIC_HOME}/server/lib/weblogic.jar weblogic.Deployer ${OPTIONS3} -list  | grep ${APNAME} | wc -l) -eq 1 ]
 if [ $(cat ${APPLOG} | grep ${APNAME} | wc -l) -gt 1 ]
 then
	msg "Aplicación existente." "DEBUG"
 else
	msg "La Aplicación no está instalada." "DEBUG"
 fi
 
}

fnStartJB() # 300320-1858
{
 msg "Encendiendo el componente:" "INFO" # 110119-0528
 echo "===== START APP =====" >> ${APPLOG}
 if [ ${vTYPJB} == "DOMAIN" ]
 then
	for Group in $(echo ${SRVNAMES//,/ })
	do
 	  nohup ${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --command="/server-group=${Group}:start-servers" >> ${APPLOG}  2>&1 # 050620-0930
 	  msg "Componente Encendido - ${Group}." "OK"
	done
 elif [ ${vTYPJB} == "STANDALONE" ]
 then
	nohup ${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --command=":reload" >> ${APPLOG}  2>&1
	msg "Componente reload." "OK"
 fi

}


fnStartWL()
{
 msg "Encendiendo el componente:" "INFO" # 110119-0528
 echo "===== START APP =====" >> ${APPLOG}
 #nohup ${JAVA_HOME}/bin/java -Xms${vMEMORYINI} -Xmx${vMEMORYMAX} -cp ${WEBLOGIC_HOME}/server/lib/weblogic.jar weblogic.Deployer ${OPTIONS} -start -adminmode >> ${APPLOG} 2>&1
 nohup ${JAVA_HOME}/bin/java -Xms${vMEMORYINI} -Xmx${vMEMORYMAX} -cp ${WEBLOGIC_HOME}/server/lib/weblogic.jar weblogic.Deployer ${OPTIONS2} -start >> ${APPLOG} 2>&1
 msg "Componente Encendido." "OK"
}

fnStopJB() # 300320-1858
{
 msg "Apagando el componente:" "INFO" # 110119-0528
 echo "== LIST ${APPID}  ==" >> ${APPLOG}
 nohup ${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --command="${ICMD}" >> ${APPLOG}  2>&1
 echo "===== STOP APP =====" >> ${APPLOG}
 msg "${JOB_URL}ws/${APPLOG}" "LOG" # 070919-1736
 vTYPJB=$(${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --command="ls"|grep "launch-type"| awk -F"=" '{print $2}')
 #echo ${vTYPJB} >> ${APPLOG}


 if [ ${vTYPJB} == "DOMAIN" ]
 then
	echo "Execute stop in ${vTYPJB}" >> ${APPLOG}
	for Group in $(echo ${SRVNAMES//,/ })
	do
	  echo "Stop Group Server: $Group" >> ${APPLOG}
 	  nohup ${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --command="/server-group=${Group}:stop-servers" >> ${APPLOG}  2>&1 # 050620-0930
   	  if [ $? -gt 0 ] #101019-1211 Valida si se apagó o  no.
	  then
    	    msg "No se pudo detener la aplicación (Group ${Group}), probablemente no existe la aplicación o ya se enuentra abajo, se continua con el deploy" "WARN"
	  else
            msg "Componente Apagado - ${Group}." "OK"
	  fi

        done

 elif [ ${vTYPJB} == "STANDALONE" ]
 then
	msg "JBoss standalone, se continua deploy" "INFO"
	#nohup ${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --command=":stop-servers" >> ${APPLOG}  2>&1 
 fi

}



fnStopWL()
{
 msg "Apagando el componente:" "INFO" # 110119-0528
 echo "===== STOP APP =====" >> ${APPLOG}
 msg "${JOB_URL}ws/${APPLOG}" "LOG" # 070919-1736
 nohup ${JAVA_HOME}/bin/java -Xms${vMEMORYINI} -Xmx${vMEMORYMAX} -cp ${WEBLOGIC_HOME}/server/lib/weblogic.jar weblogic.Deployer ${OPTIONS2} -stop >> ${APPLOG} 2>&1
 #echo "== LIST ${APPID}  ==" >> ${APPLOG}
 #nohup ${JAVA_HOME}/bin/java -Xms${vMEMORYINI} -Xmx${vMEMORYMAX} -cp ${WEBLOGIC_HOME}/server/lib/weblogic.jar weblogic.Deployer -adminurl ${T3URL} -user ${USER} -password ${PASSWD} -id ${APPID} -listtask >> ${APPLOG} 2>&1


if [ $? -gt 0 ] #101019-1211 Valida si se apagó o  no.
then
    msg "No se pudo detener la aplicación, probablemente no existe la aplicación o ya se enuentra abajo, se continua con el deploy" "WARN"
else
 	msg "Componente Apagado." "OK"
fi
}

fnError()
{
	for f in $(ls -lad ${APHOME}/data/*.dat|awk '{print $9}')
	do
		source ${f}
		#200719-0023 Variable de workspace, usado desde Jenkins.
		CNT1=$(grep "${ERR1}" ${WORKSPACE}/${APPLOG} | wc -l)
		CNT2=$(grep "${ERR2}" ${WORKSPACE}/${APPLOG} | wc -l)
		CNT3=$(grep "${ERR3}" ${WORKSPACE}/${APPLOG} | wc -l)
		echo "===== ERROR CATALOG =====" >> ${APPLOG}
		echo "Error1:${CNT1}	Error2:${CNT2}		Error3:${CNT3}" >> ${APPLOG}
		CNTotal=$((CNT1 + CNT2 + CNT3))

		#if [ $CNT1 -gt 0 ] || [ $CNT2 -gt 0 ] || [ $CNT3 -gt 0 ]
		if [ $CNTotal -gt 0 ]
		then
			msg "$ERR1... $ERR2... $ERR3" "ERROR $(basename $f | awk -F'.' '{print $1}')"
			msg "$SOL" "SOLUCION"
			return 1
		fi
	done
}
fnValida()
{
	msg "Validando que exista componente en la ruta de JK:" "INFO"	
	
	if [ ! -f ${RTJK}/${APWAR} ]
	then
		msg "Ruta: ${RTJK}/${APWAR}" "DEBUG"
		msg "No hay componente war dentro de la ruta de Jenkins, favor de copiar componente" "ERROR"
		exit 1
	else
		msg "Validación exitosa." "OK"
		msg "$(md5sum ${RTJK}/${APWAR})" "MD5"
	fi

	if [ "${NRFC}" == "" ] && [ $NPROD != 1 ]
	then
		msg "No se coloco el numero de RFC, favor de colocar el RFC cuando se ejecute el job." "ERROR"
        	exit 1
	fi

}


fnFirma() #Funcion para desplegar la firma del componente, obtiene la firma de la ruta Jenkins
{
	vApp=$2
	msg "Conectando a servidor para obtener firma(s) a través de terminal virtual:" "INFO"
	#echo "==================================================================================================================="
        echo "+-----------------+"
        echo "| T X T 2 T E R M |"
        echo "+-----------------+-----------------------------------------------------------------------------------------------------------------+"
	echo "| Terminal	Sessions	View	Tools	Settings	Help                              $(date)      |"
	echo "+-----------------------------------------------------------------------------------------------------------------------------------+ "
	echo -e "\n"

	for vC in $(echo ${vApp})
	do

	if [ $1 -eq 1 ]
	then
	   vCOMP=${RTJK}/${vC}
	   USRSO=$(whoami)
	   #echo "Firma del componente ${APWAR} de la ruta de Jenkins:" 
	   #echo "========================================================================================="
	   #echo "[ $USRSO | $HOSTNAME ] $ md5sum ${vCOMP};ls -lad ${vCOMP}"
	   echo "[ $USRSO | $HOSTNAME ] ${RTINST}"
	   echo "$USRSO} $ md5sum ${vCOMP};ls -lad ${vCOMP}"
	   md5sum ${vCOMP}
	   ls -lad ${vCOMP}
	   echo "[ $USRSO | $HOSTNAME ] ${RTINST}"
	   echo "$USRSO $ date"
	   date
	   echo "[ $USRSO | $HOSTNAME ] ${RTINST}"
	   echo "$USRSO $"
	else
	   vCOMP=${RTINST}/${vC}
	   USRSO=$(ssh -q $IPSRV "whoami")
	   hostn=$(ssh -q ${IPSRV} "hostname")
	   #echo "Firma del componente ${APWAR} en la ruta del servidor ${IPSRV}:"
	   # 110119-0528 Valida si es Linux, en caso contrario usa openssl
	   echo "[ ${IPSRV} | ${hostn} ] ${RTINST}"
	   ssh -q ${IPSRV} "[ "$(uname -s)" = "Linux" ] && echo '${USRSO} $ md5sum ${vCOMP}*;ls -lad ${vCOMP}*' || echo 'openssl dgst -md5 ${vCOMP}*'"
	   ssh -q ${IPSRV} "[ "$(uname -s)" = "Linux" ] && md5sum ${RTINST}/${APWAR}* || openssl dgst -md5 ${vCOMP}*"
	   ssh -q ${IPSRV} "ls -lad ${vCOMP}*"
	   echo "[ ${IPSRV} | ${hostn} ] ${RTINST}"
	   echo "${USRSO} $ date"
	   ssh -q ${IPSRV} "date"
           # 271218: Se coloca nuevo metodo de obtener usuario y hostname
           #echo "[ $usr | $hostn ]"
	   echo "[ ${IPSRV} | ${hostn} ] ${RTINST}"
	   echo "${USRSO} $  "
	fi
	done
	
 	echo "${USRSO} $ █"	
	echo -e "\n"
	echo "+-----------------------------------------------------------------------------------------------------------------------------------+"
	echo "| <F1>Menú	| <F2>Copy Prompt Terminal	| <F3>Paste Prompt Terminal	| <BloqMay>=Inactive	     		            |"
	#echo "|                                                                                                                              |"
	echo "+-----------------------------------------------------------------------------------------------------------------------------------+"
	#echo "================================================================================================================================"

}


fnConfig() #Configuraciones rdeployer: {componente}.conf
{
msg "Validando archivo de configuracion global:" "INFO"

if [ -f ${APHOME}/conf/rdeployer.conf ]
then
         . ${APHOME}/conf/rdeployer.conf
         msg "Archivo de Configuracion global cargado." "OK"
else
         msg "No se encuentra el archivo de configuracion Global: ${APHOME}/conf/rdeployer.conf" "ERROR"
         exit 1
fi

msg "Validando archivo de configuracion:" "INFO"

if [ -f ${APDIR}/${APNAME}.conf ]
then
         . ${APDIR}/${APNAME}.conf
         msg "Archivo de Configuracion aplicativo cargado." "OK"
else
         msg "No se encuentra un archivo de configuracion: ${APDIR}/${APNAME}.conf" "ERROR"
         exit 1
fi

}


fnEstructuraNew()
{
RUTA_COPIA="${RTINST}/${YEAR}/${MES}/${NRFC}"
msg "Creando comando para estructura de directorios:" "INFO"
msg "${RTINST}" "DEBUG"
msg "${YEAR}" "DEBUG"
msg "${MES}" "DEBUG"
CMD1="mkdir -p ${RUTA_COPIA}"
ssh -q ${IPSRV} "${CMD1}"
# 080320-2358 Se actualiza la forma de estructura con mas validaciones.
msg "Creando comando para mover instalación que exista:" "INFO"
msg "backup ${RTINST}/${APWAR}.prev" "DEBUG"
CMD1="[ ! -d ${RTINST}/.bck ] && mkdir ${RTINST}/.bck"
CMD1="$CMD1;[ -f ${RTINST}/${APWAR}.prev ] && mv ${RTINST}/${APWAR}.prev ${RTINST}/.bck/${APWAR}.prev.${U_TIME}"
msg "backup ${RTINST}/${APWAR}" "DEBUG"
CMD1="$CMD1;[ -f ${RTINST}/${APWAR} ] && cp -rp ${RTINST}/${APWAR} ${RTINST}/${APWAR}.prev"
CMD1="$CMD1;[ -d ${RTINST}/.bck ] && ls -ltr ${RTINST}/.bck/${APWAR}.prev.${U_TIME}"
CMD1="$CMD1;[ -f ${RTINST}/${APWAR}.prev ] && ls -ltr ${RTINST}/${APWAR}.prev"

msg "Creando comando para punto de montaje como liga suave:" "INFO"
msg "remove ${RTINST}/${APWAR}" "DEBUG"
CMD1="$CMD1;[ -f ${RTINST}/${APWAR} ] && rm -rf ${RTINST}/${APWAR}"
msg "link ${RUTA_COPIA}/${APWAR} ${RTINST}/${APWAR}" "DEBUG"
CMD1="$CMD1;ln -s ${RUTA_COPIA}/${APWAR} ${RTINST}/${APWAR}"

msg "Copiando el componente war en el directorio:" "INFO"
msg "${RTJK}/${APWAR}" "DEBUG"
msg "${IPSRV}:${RUTA_COPIA}/." "DEBUG"
scp -qrp ${RTJK}/${APWAR} ${IPSRV}:${RUTA_COPIA}/.

if [ $? -gt 0 ]
then
	msg "Error al copiar el componente WAR ${APWAR}" "ERROR"
	exit 1
fi

msg "Ejecutando comandos de estructura:" "INFO"
msg "$CMD1" "DEBUG"
ssh -q ${IPSRV} "${CMD1}"

}

fnEstructuraRB()
{
msg "Buscando prev en backups para montar como .prev" "INFO"
#APWARBCK=$(ssh -q ${IPSRV} "find ${RTINST}/.bck/ -name '${APWAR}.prev.*'" | head -1)
APWARBCK=$(ssh -q ${IPSRV} "ls -ltr ${RTINST}/.bck/${APWAR}.prev.*| tail -1")

msg "Creando comando para borrado de componente actual" "INFO"
CMD1="rm -rf ${RTINST}/${APWAR}"

msg "Creando comando para mover prev como componente actual" "INFO"
CMD1="$CMD1;mv ${RTINST}/${APWAR}.prev ${RTINST}/${APWAR}"

if [ $(echo $APWARBCK | wc -l) -gt 0 ]
then
     APWARBCK=$(echo $APWARBCK | awk '{print $9}')
     msg "Creando comando para mover backup de prev como componente previo" "INFO"
     CMD1="$CMD1;mv ${APWARBCK} ${RTINST}/${APWAR}.prev"
else
     msg "No existe un prev en backup para ser montado como .prev, se omite la creación de comando" "WARN"
fi

msg "Ejecutando comandos de estructura:" "INFO"
msg "$CMD1" "DEBUG"
ssh -q ${IPSRV} "${CMD1}"
}


fnGetConsole()
{
#Vamos a obtener el usuario, password, ip y puerto de la consola bajo archivo XML
#CONN="$(${APHOME}/util/xmlUtil.io ${APHOME}/conf ${NODE})"
xUTIL=xmlUtil2  #260520-1157
msg "Versión XML Util: ${xUTIL}" "INFO" #260520-1157
CONN="$(${APHOME}/util/${xUTIL}.io ${APHOME}/conf ${NODE} $1)"

if [ "${CONN}" == "ERROR" ]
then
        msg "No se puede obtener usuario y password en el archivo de configuracion" "ERROR"
        exit 1
else
	msg "Datos de consola encontrados." "OK"
        USER=$(echo $CONN | awk '{print $1}')
        PASSWD=$(echo $CONN | awk '{print $2}')
        IPSRV=$(echo $CONN | awk '{print $3}')
        PORT=$(echo $CONN | awk '{print $4}')
fi

export USER
export PASSWD
export IPSRV
export PORT
}


fnTipoEstructuraInstall()
{
msg "Tipo de Instalación: ${TYPEINST}" "INFO"

case $1 in
"new")
	msg "Número de RFC: ${NRFC}" "INFO"
	fnEstructuraNew
	;;
"rollback")
	msg "Número de RFC del que falló: ${NRFC}" "INFO"
	NRFC=$(ssh -q ${IPSRV} "ls -lad ${RTINST}/${APWAR}.prev" | awk '{print $11}' | awk -F "/" '{print $8}')
	msg "Número de RFC de RollBack: ${NRFC}" "INFO"
	fnEstructuraRB
	;;
esac

}


msg()
{
	U_HOUR="$(date '+%H%M%S')"
	printf "[$U_HOUR] [$2] $1\n"
}


# MAIN #
msg "Versión de rdeployer: $VERSION" "INFO"
fnConfig 
fnValida

case $DODEPLOY in
 "weblogic")
	msg "Plugin cargado: Weblogic_Deployer" "INFO"
	fnGetConsole Weblogic
	[ "$NPROD" == "0" ] && fnTipoEstructuraInstall ${TYPEINST} # 120521-0111
	fnDeployerWL ${NPROD} # Variable NPROD obtenido de Jenkins
	fnFirma ${NPROD} ${APWAR} # Variable NPROD obtenido de Jenkins
	;;
 "jboss")
	msg "Plugin cargado: JBoss_CLI" "INFO"
	fnGetConsole JBoss
	[ "$NPROD" == "0" ] && fnTipoEstructuraInstall ${TYPEINST} # 120521-0111
	fnDeployerJB ${NPROD}
	fnFirma ${NPROD} ${APWAR} # Variable NPROD obtenido de Jenkins
	;;
 "esb")
	msg "Plugin cargado: Oracle_Services_Bus" "INFO"
	fnGetConsole ESB
	[ "$NPROD" == "0" ] && fnTipoEstructuraInstall ${TYPEINST} # 120521-0111
	fnDeployESB ${NPROD}
	fnFirma ${NPROD} "${APWAR} ${PROJECTCONF}" # Variable NPROD obtenido de Jenkins
	;;
 *)
	msg "Archivo CONF no tiene propiedad DODEPLOY, favor de configurar: DODEPLOY=[weblogic|jboss|esb]" "ERROR"
	;;
esac

exit ${vEXIT}
