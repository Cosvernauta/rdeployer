#!/bin/bash
############################################
# Deploy para Jenkins con WebLogic
# Construido para Jenkins (tested 2.84, 2.138)
# Rev.  1.5.10 - 240418-0154
#       1.5.11 - 310518-2005
#	1.5.12 - 190618-0057
#	1.5.14 - 030718-0000
#	1.5.17 - 190818-0957
#	1.5.20 - 110119-0528
#	2.0.0  - 020219-2006
#	2.0.1  - 230319-1528
#	2.0.2  - 220519-1703
#	2.0.3  - 200719-0023
# Jimmy R. cosvernautaux(a)gmail.com
############################################
#Set Variables
[ "$1" == "" ] && APDIR="${APHOME}" || APDIR="${APHOME}/$1"
UNDEP=$2
APNAME=`basename ${0%.*}`
U_HOUR="$(date '+%H%M')"
U_DATE="$(date '+%Y%m%d')"
U_TIME="${U_DATE}${U_HOUR}"
U_MES="$(date '+%m')"
APPLOG=${APNAME}.${BUILD_NUMBER}.log # 230319-1528
VERSION="2.0.3A"
TIMEO=180
export monthnames=(Invalid Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic)
YEAR="$(date '+%Y')"
MES=${monthnames[${U_MES#0}]}
LOGAPHIST="${APNAME}.history"
# Se debe configurar en el job 2 variables: TYPEINST y RFC
#TYPEINST - Parámetro de elección:
#	    Opciones: new | rollback
#RFC - Parámetro de Cadena

fnDeployer()
{
# fnDeployer [0|1]
# 0 = Para desactivar el upload
# 1 = Para activar el upload
> ${APNAME}.log
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
#OPTIONS="$OPTIONS -redeploy" #Este es el principal "redeploy" para hacer update al componente

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
    nohup ${JAVA_HOME}/bin/java -Xms512M -Xmx512M -cp ${WEBLOGIC_HOME}/server/lib/weblogic.jar weblogic.Deployer ${OPTIONS} -undeploy >> ${APPLOG}  2>&1

    [ $? -gt 0 ] && msg "Error en la desinstalación del componente, Se continuará con un redeploy" "ERROR" || msg "Undeploy realizado" "OK"
fi

#Ejecutamos el deploy con las opciones configuradas
msg "Ejecutando deploy, espere un momento..." "INFO"
echo "[ $(date) ]" >> ${APNAME}.log
echo "===== DEPLOY/REDEPLOY APP =====" >> ${APPLOG}
nohup ${JAVA_HOME}/bin/java -Xms512M -Xmx512M -cp ${WEBLOGIC_HOME}/server/lib/weblogic.jar weblogic.Deployer ${OPTIONS} -redeploy >> ${APPLOG}  2>&1

if [ $? -gt 0 ]
then
    fnError 
    msg "Verificar la salida en el archivo ${APPLOG} en workspace para más información" "ERROR"
    [ "${TYPEINST}" == "rollback" ] && exit 1 # 190619 Bug detectado, hacia doble rollback cuando la opcion era rollback y fallaba el war en instalarse, se coloca esta línea para que valide el tipo de instalacion.
    [ "$NPROD" == "0" ] && msg "Aplicando Rollback a la estructura Generada:" "DEBUG"
    [ "$NPROD" == "0" ] && fnEstructuraRB 
    exit 1
else
	msg "Deploy realizado" "OK"
	#Armamos las opciones para stop/start | 110119-0528
	OPTIONS="-remote"
	OPTIONS="$OPTIONS -name ${APNAME}"  # Nombre de la aplicacion
	OPTIONS="$OPTIONS -targets ${SRVNAMES}" # Las instancias donde se va a deployar el componente o donde se encuentra deployado
	OPTIONS="$OPTIONS -adminurl ${T3URL}" # La cadena URL de conexion, usaremos T3
	OPTIONS="$OPTIONS -user ${USER} -password ${PASSWD}" # Usuario y password para poder entrar a la consola

	msg "Apagando el componente:" "INFO" # 110119-0528
	echo "===== STOP APP =====" >> ${APPLOG}
	nohup ${JAVA_HOME}/bin/java -Xms512M -Xmx512M -cp ${WEBLOGIC_HOME}/server/lib/weblogic.jar weblogic.Deployer ${OPTIONS} -stop >> ${APPLOG} 2>&1
	msg "Componente Apagado" "OK"

	msg "Encendiendo el componente:" "INFO" # 110119-0528
	echo "===== START APP =====" >> ${APPLOG}
	nohup ${JAVA_HOME}/bin/java -Xms512M -Xmx512M -cp ${WEBLOGIC_HOME}/server/lib/weblogic.jar weblogic.Deployer ${OPTIONS} -start >> ${APPLOG} 2>&1
	msg "Componente Encendido" "OK"
fi

}

fnError()
{
	for f in $(ls -lad ${APHOME}/data/*.dat|awk '{print $9}')
	do
		source ${f}
		#200719-0023 Variable de workspace, usado desde Jenkins.
		CNT=$(grep "${ERR1}" ${WORKSPACE}/${APPLOG} | grep "${ERR2}" | grep "${ERR3}" |wc -l)
		
		if [ $CNT -gt 0 ]
		then
			msg "$ERR1... $ERR2... $ERR3" "ERROR $(basename $f | awk -F'.' '{print $1}')"
			msg "$SOL" "SOLUCION"
			return 1
		fi
	done
}
fnValida()
{
	msg "Validando que exista componente en la ruta de JK" "INFO"	
	
	if [ ! -f ${RTJK}/${APWAR} ]
	then
		msg "No hay componente war dentro de la ruta de Jenkins, favor de copiar componente" "ERROR"
		exit 1
	else
		msg "Validación exitosa." "OK"
	fi

	if [ "${RFC}" == "" ] && [ $NPROD != 1 ]
	then
		msg "No se coloco el numero de RFC, favor de colocar el RFC cuando se ejecute el job." "ERROR"
        	exit 1
	fi

}


fnFirma() #Funcion para desplegar la firma del componente, obtiene la firma de la ruta Jenkins
{
	usr=$(ssh -q ${IPSRV} "whoami")
	hostn=$(ssh -q ${IPSRV} "hostname")
	echo "========================================================================================="
	if [ $1 -eq 1 ]
	then
	   echo "Firma del componente ${APWAR} de la ruta de Jenkins:" 
	   md5sum ${RTJK}/${APWAR}
	else
	   echo "Firma del componente ${APWAR} en la ruta del servidor ${IPSRV}:"
	   # 110119-0528 Valida si es Linux, en caso contrario usa openssl
	   ssh -q ${IPSRV} "[ "$(uname -s)" = "Linux" ] && md5sum ${RTINST}/${APWAR}* || openssl dgst -md5 ${RTINST}/${APWAR}*"
	fi
        # 271218: Se coloca nuevo metodo de obtener usuario y hostname
        echo "[ $usr | $hostn ]"
	echo "========================================================================================="

}


fnConfig() #Configuraciones rdeployer: {componente}.conf
{
msg "Validando archivo de configuracion" "INFO"

if [ -f ${APDIR}/${APNAME}.conf ]
then
         . ${APDIR}/${APNAME}.conf
         msg "Archivo de Configuracion cargado" "OK"
else
         msg "No se encuentra un archivo de configuracion: ${APDIR}/${APNAME}.conf" "ERROR"
         exit 1
fi

}


fnEstructuraNew()
{
RUTA_COPIA="${RTINST}/${YEAR}/${MES}/${RFC}"
msg "Creando comando para estructura de directorios:" "INFO"
msg "${RTINST}" "DEBUG"
msg "${YEAR}" "DEBUG"
msg "${MES}" "DEBUG"
CMD1="mkdir -p ${RUTA_COPIA}"
ssh -q ${IPSRV} "${CMD1}"

msg "Creando comando para mover instalación que exista:" "INFO"
msg "backup ${RTINST}/${APWAR}.prev" "DEBUG"
CMD1="[ -f ${RTINST}/${APWAR}.prev ] && mv ${RTINST}/${APWAR}.prev ${RTINST}/.bck/${APWAR}.prev.${U_TIME}"
CMD1="$CMD1;[ ! -d ${RTINST}/.bck ] && mkdir ${RTINST}/.bck"
msg "backup ${RTINST}/${APWAR}" "DEBUG"
CMD1="$CMD1;[ -f ${RTINST}/${APWAR} ] && cp -rp ${RTINST}/${APWAR} ${RTINST}/${APWAR}.prev"
CMD1="$CMD1;ls -ltr ${RTINST}/.bck/${APWAR}.prev.${U_TIME}"
CMD1="$CMD1;ls -ltr ${RTINST}/${APWAR}.prev"

msg "Creando comando para punto de montaje como liga suave:" "INFO"
msg "remove ${RTINST}/${APWAR}" "DEBUG"
CMD1="$CMD1;rm -rf ${RTINST}/${APWAR}"
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
APWARBCK=$(ssh -q ${IPSRV} "find ${RTINST}/.bck/ -name '${APWAR}.prev.*'" | head -1)

msg "Creando comando para borrado de componente actual" "INFO"
CMD1="rm -rf ${RTINST}/${APWAR}"

msg "Creando comando para mover prev como componente actual" "INFO"
CMD1="$CMD1;mv ${RTINST}/${APWAR}.prev ${RTINST}/${APWAR}"

if [ $(echo $APWARBCK | wc -l) -gt 0 ]
then
     APWARBCK=$(echo $APWARBCK | tail -1)
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
CONN="$(${APHOME}/util/xmlUtil.io ${APHOME}/conf ${NODE})"

if [ "${CONN}" == "ERROR" ]
then
        msg "No se puede obtener usuario y password en el archivo de configuracion" "ERROR"
        exit 1
else
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
	msg "Número de RFC: ${RFC}" "INFO"
	fnEstructuraNew
	;;
"rollback")
	msg "Número de RFC del que falló: ${RFC}" "INFO"
	RFC=$(ssh -q ${IPSRV} "ls -lad ${RTINST}/${APWAR}.prev" | awk '{print $11}' | awk -F "/" '{print $8}')
	msg "Número de RFC de RollBack: ${RFC}" "INFO"
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
fnGetConsole
[ "$NPROD" == "0" ] && fnTipoEstructuraInstall ${TYPEINST} # Variable TYPEINST que se obtiene directo desde Jenkins
fnDeployer ${NPROD} # Variable NPROD obtenido de Jenkins
fnFirma ${NPROD} # Variable NPROD obtenido de Jenkins
