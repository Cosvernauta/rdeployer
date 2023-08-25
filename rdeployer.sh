#!/bin/bash
######################################################################
# Deploy para Jenkins con WebLogic/JBoss/Oracle Services Bus
# Deploy para UrbanCode con WebLogic/JBoss/Oracle Services Bus
# Construido para Jenkins (tested 2.84, 2.138, 2.232.3)
# Construido para UrbanCode (tested 7.1.0.2.1063225)
# JBoss 6.x en adelante (tested 6.4, 7.2)
# Weblogic: 10.x en adelante (tested 10.3, 11g, 12.x)
# OSB/ESB: 11g en adelante (tested 11g, 12c)
#---------------------------------------------------------------------
# Para mas info , revisar ROADMAP
# Jimmy R. Lili jlili.salgado(a)gmail.com
######################################################################
#Set Variables default config
ServerDomainHostname=""
ServerDomainPort=""
https="http://"
[ "${ServerDomainHTTP}" = true ] && https="http://"
[ "${ServerDomainHTTPS}" = true ] && https="https://"
AutoColorOutPut=true #060622-1836
ValidateAppWeblogic=true
vEXIT=0
[ "$1" == "" ] && APDIR="${APHOME}" || APDIR="${APHOME}/$1"
mFORCE=true
TimeOutSSH=30
TimeOutDeploy=60
####

UNDEP=$2
APNAME=`basename ${0%.*}`
U_HOUR="$(date '+%H%M')"
U_DATE="$(date '+%Y%m%d')"
U_TIME="${U_DATE}${U_HOUR}"
U_MES="$(date '+%m')"
>version.txt # Inicializando, para cualquier tipo de error en primera ejecución.

if [ "${PluginLauncher}" == "UrbanCode" ]
then
        if [ -f BNUMBER.prc ]
        then
                BN=$(cat BNUMBER.prc)
                BN=$(expr $BN + 1)
                echo ${BN} > BNUMBER.prc
                WORKSPACE=${WORKDIR}
        else
                echo 1 > BNUMBER.prc
        fi

        BUILD_NUMBER=$(cat BNUMBER.prc)
fi

APPLOG=${APNAME}.${BUILD_NUMBER}.log # 230319-1528
APPID=${APNAME}${BUILD_NUMBER} # 070919-1736
#[ "${CICD}" == "Jenkins" ] && APPLOG=${APNAME}.${BUILD_NUMBER}.log # 230319-1528 140921-0836
#[ "${CICD}" == "Jenkins" ] && APPID=${APNAME}${BUILD_NUMBER} || APPID=${APNAME} # 070919-1736 140921-0836
VERSION="4.2.10"
export monthnames=(Invalid Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic)
YEAR="$(date '+%Y')"
MES=${monthnames[${U_MES#0}]}
LOGAPHIST="${APNAME}.history"
NRFC=$(echo ${RFC} | tr -d [:blank:])
# Se debe configurar en el job 2 variables: TYPEINST y RFC
#TYPEINST - Parámetro de elección:
#           Opciones: new | fix | rollback
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
TimeOutDeploy=$( expr "${TimeOutDeploy}" "*" 1000 )

#Armamos las opciones para deployar
CMD="deploy ${RTC}"
ICMD="deployment-info --name=${APWAR}"
SHA1="ls deployment=${APWAR}"
OPTIONS="--connect --timeout=${TimeOutDeploy}"
OPTIONS="$OPTIONS --command-timeout=${TimeOutDeploy}"
OPTIONS="$OPTIONS --controller=${HOSTURL}"
OPTIONS="$OPTIONS --user=${USER}"
OPTIONS="$OPTIONS --password=${PASSWD}"
#OPTIONS="$OPTIONS --command-timeout $TimeOutDeploy"
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
echo "[ $(date) ]" >> ${APPLOG}
echo "===== INFO/REDEPLOY APP =====" >> ${APPLOG}
if  $mFORCE
then
        CMD="$CMD --force"
        echo "Executing mode force in ${RTC}" >> ${APPLOG}
        echo "Timeout configured: ${TimeOutDeploy}" >> ${APPLOG}
        nohup ${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --commands="${SHA1},${ICMD},${CMD},${SHA1}" >> ${APPLOG}  2>&1
else
        echo "Executing mode deploy in ${RTC}" >> ${APPLOG}
        echo "Timeout configured: ${TimeOutDeploy}" >> ${APPLOG}
        CMD="$CMD --server-groups=${SRVNAMES}"
        nohup ${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --command="${CMD}" >> ${APPLOG}  2>&1
fi

if [ $? -gt 0 ]
then
    fnErrorExecute
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
OPTIONS="$OPTIONS -timeout ${TimeOutDeploy}" # 220519-1703 Timeout si no se llega a deployarse.
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
    msg "Opción undeploy seleccionada, realizando desinstalacion del componente:" "INFO"
    #msg "${LOGURL}ws/${APPLOG}" "LOG"
    echo "===== UNDEPLOY APP =====" >> ${APPLOG}
    nohup ${JAVA_HOME}/bin/java -Xms${vMemoryIni} -Xmx${vMemoryMax} -cp ${WEBLOGIC_HOME}/server/lib/weblogic.jar weblogic.Deployer ${OPTIONS} -undeploy >> ${APPLOG}  2>&1

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
#OPTIONS3="-remote"
OPTIONS3="-adminurl ${T3URL}" # La cadena URL de conexion, usaremos T3
OPTIONS3="$OPTIONS3 -user ${USER} -password ${PASSWD}" # Usuario y password para poder entrar a la consola

#Realizamos el check de la aplicación.
#msg "${ValidateAppWeblogic}" "DEBUG"
$ValidateAppWeblogic && fnCheckWL $OPTIONS3 || msg "CheckWL desactivado, se continua instalacion" "INFO"
#fnCheckWL $OPTIONS3
sleep 5
#Detenemos el componente
fnStopWL
sleep 5

#Ejecutamos el deploy con las opciones configuradas
msg "Ejecutando deploy, espere un momento..." "INFO"
echo "[ $(date) ]" >> ${APNAME}.log
echo "===== DEPLOY/REDEPLOY APP =====" >> ${APPLOG}
nohup ${JAVA_HOME}/bin/java -Xms${vMemoryIni} -Xmx${vMemoryMax} -cp ${WEBLOGIC_HOME}/server/lib/weblogic.jar weblogic.Deployer ${OPTIONS} -redeploy >> ${APPLOG}  2>&1

if [ $? -gt 0 ]
then
        fnErrorExecute
        #Levantamos el componente apagado.
        fnStartWL
        exit 1
else
        msg "Deploy realizado." "OK"
        sleep 5
        #WARNG=$(grep "Unable to contact" ${WORKSPACE}/${APPLOG}|wc -l)
        WARNG=$(grep "Unable to contact" ${APPLOG}|wc -l)
        #WARNG=$(grep "Target state: start failed on Server" ${WORKSPACE}/${APPLOG}|wc -l)

        if [ ${WARNG} -gt 0 ]
        then
            msg "Se encontraron que algunas instancias no estaban disponibles, checar salida del log en la url anteriormente mostrada" "WARN"
            WARNINST=$(grep "Unable to contact" ${APPLOG}| awk '{print $5}'|sort|uniq) # 210323-1151
            msg "Instancias con problemas:" "WARN"
            msg "${WARNINST}" "WARN"
            vEXIT=4
        fi
        #[ "$NPROD" == "1" ] && RTINST=$(dirname $(grep "Starting task with path" ${APPLOG} | awk -F":" '{print $4}'))
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

msg "Creando la estructura para deployar:" "INFO"
msg "Nombre de la aplicacion: ${APNAME}" "DEBUG"
msg "Componente: ${APWAR}" "DEBUG"
msg "Target(s): ${SRVNAMES}" "DEBUG"
msg "Consola: ${T3URL}" "DEBUG"
msg "Nodo: ${NODE}" "DEBUG"
msg "Usuario consola: ${USER}" "DEBUG"

if [ -f ${RTJK}/${PROJECTCONF} ]
then
# 231121-1130: Checa archivo XML
  vXML=${RTJK}/${PROJECTCONF}
  msg "XML Config: ${PROJECTCONF}" "DEBUG"
else
  msg "XML No encontrado, se realiza instalación sólo del JAR sin configuración" "WARN"
  vXML="None"
  msg "${vXML}" "DEBUG"
fi

[ "$NPROD" == "1" ] && NRFC=${BUILD_NUMBER}

msg "Ejecutando deploy, espere un momento..." "INFO"
#msg "${LOGURL}ws/${APPLOG}" "LOG"
echo "===== DEPLOY APP ESB CONSOLE =====" >> ${APPLOG}
echo "File: ${OSB_HOME}/osb/tools/configjar/setenv.sh" >> ${APPLOG}
nohup ${ORACLE_HOME}/oracle_common/common/bin/wlst.sh ${APHOME}/util/fnESBmod.py ${T3URL} ${USER} ${PASSWD} ${RTJK}/${APWAR} ${vXML} ${OSBKEY} ${PROJECTNAME} ${NRFC} >> ${APPLOG} 2>&1

if [ $? -gt 0 ]
then
    fnErrorExecute
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


 if [ $(cat ${APPLOG} | grep ${APWAR} | wc -l) -ge 1 ]
 then
        msg "Aplicación existente." "DEBUG"
        mFORCE=true
 else
        msg "La Aplicación no está instalada, se procede instalacion." "DEBUG"
        mFORCE=false
 fi

}


fnCheckWL()  # 111110-1745
{
 if [ "${UNDEP}" != "undeploy" ]
 then
   msg "Validando que exista la Aplicación:" "INFO"
   msg "${APNAME}" "DEBUG"
   echo "===== LIST APP =====" >> ${APPLOG}
# Nueva forma de listar aplicaciones | 131121-1708
   nohup ${JAVA_HOME}/bin/java -Xms${vMemoryIni} -Xmx${vMemoryMax} -cp ${WEBLOGIC_HOME}/server/lib/weblogic.jar weblogic.Deployer ${OPTIONS3} -listapps >> ${APPLOG} 2>&1
   cAppCount=$(grep ${APNAME} ${APPLOG} | wc -l)
   #msg "${APNAME}: ${cAppCount}" "DEBUG"

   if [ ${cAppCount} -ge 1 ]
   then
        msg "Aplicación existente." "OK"
   else
        msg "La Aplicación no está instalada." "WARN"
   fi
 else
   msg "Undeploy activado, se omite Check" "WARN"
 fi
}

fnStartJB() # 300320-1858
{
 msg "Encendiendo el componente:" "INFO" # 110119-0528
 echo "===== START APP =====" >> ${APPLOG}
 if [ ${vTYPJB} == "DOMAIN" ] # Issue: 240922-1347
 then
        echo "Starting in ${vTYPJB} Mode" >> ${APPLOG}
        for Group in ${SRVNAMES/,/ }
        do
          ${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --command="/server-group=${Group}:start-servers" >> ${APPLOG}  2>&1 # 050620-0930
          sleep 10
          #${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --command="/server-group=${Group}:start-servers" >> ${APPLOG}  2>&1
          msg "Componente Encendido - ${Group}." "OK"
        done
 elif [ ${vTYPJB} == "STANDALONE" ]
 then
        nohup ${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --command=":reload" >> ${APPLOG}  2>&1
        msg "Componente reload." "OK"
 else
        msg "revisar tipo de JBoss" "INFO"
 fi

}


fnStartWL()
{
 msg "Encendiendo el componente:" "INFO" # 110119-0528
 if [ "${UNDEP}" != "undeploy" ]
 then
    echo "===== START APP =====" >> ${APPLOG}
    nohup ${JAVA_HOME}/bin/java -Xms${vMemoryIni} -Xmx${vMemoryMax} -cp ${WEBLOGIC_HOME}/server/lib/weblogic.jar weblogic.Deployer ${OPTIONS2} -start >> ${APPLOG} 2>&1
    msg "Componente Encendido." "OK"
 else
    msg "Undeploy activado, se omite Start" "WARN"
 fi

}

fnCheckInstJB()
{
  echo "Host Controller and Servers on JBoss:" >> ${APPLOG}
  for Grp in ${1}
  do
    for HC in $(${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --command="ls host=")
    do
        grpInfo=$(${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --command="/host=${HC}:resolve-expression-on-domain" | grep ${Grp} | awk '{print $1,$5,$7}'| sed 's/{//g'|sed 's/"//g')
        echo "${grpInfo}" | grep .. >> ${APPLOG}
    done
  done


}

fnStopJB() # 300320-1858
{
 msg "Apagando el componente:" "INFO" # 110119-0528
# echo "== LIST ${APPID}  ==" >> ${APPLOG}
# nohup ${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --command="${ICMD}" >> ${APPLOG}  2>&1
 echo "===== STOP APP =====" >> ${APPLOG}
 #msg "${LOGURL}ws/${APPLOG}" "LOG" # 070919-1736
 vTYPJB="$(${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --command="ls"|grep "launch-type"| awk -F"=" '{print $2}')"
 vJBVer="$(${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --command="ls"|grep "product-version"| awk -F"=" '{print $2}')"
 vJBVerRel=$(echo ${vJBVer} | awk -F"." '{print $1"."$2}')
 echo "Execute stop in ${vTYPJB}" >> ${APPLOG}
 echo " Version JBoss: ${vJBVer}" >> ${APPLOG}

 if [ ${vTYPJB} == "DOMAIN" ]
 then
        #echo "Execute stop in ${vTYPJB}" >> ${APPLOG}
        for Group in ${SRVNAMES/,/ }
        do
          echo "Stop Group Server: $Group" >> ${APPLOG}
          fnCheckInstJB ${Group}

          if [ $(echo "${vJBVerRel} >= 7.2" | bc) -eq 1 ] # 120123-2011
          #if [ "${vJBVerRel}" == "7.2" -o "${vJBVerRel}" == "7.4" ]
          then
            nohup ${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --command="/server-group=${Group}:kill-servers" >> ${APPLOG}  2>&1
          else
            nohup ${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --command="/server-group=${Group}:stop-servers" >> ${APPLOG}  2>&1 # 050620-0930
          fi

          if [ $? -gt 0 ] #101019-1211 Valida si se apagó o  no.
          then
            msg "No se pudo detener la aplicación (Group ${Group}), probablemente no existe la aplicación o ya se enuentra abajo, se continua con el deploy" "WARN"
          else
            msg "Componente Apagado - ${Group}." "OK"
          fi

        done

 elif [ "${vTYPJB}" == "STANDALONE" ]
 then
        msg "JBoss standalone, se continua deploy" "INFO"
        #nohup ${JB_HOME}/bin/jboss-cli.sh ${OPTIONS} --command=":stop-servers" >> ${APPLOG}  2>&1
 fi

}



fnStopWL()
{
 msg "Apagando el componente:" "INFO" # 110119-0528
 if [ "${UNDEP}" != "undeploy" ]
 then
   echo "===== STOP APP =====" >> ${APPLOG}
   #msg "${LOGURL}ws/${APPLOG}" "LOG" # 070919-1736
   nohup ${JAVA_HOME}/bin/java -Xms${vMemoryIni} -Xmx${vMemoryMax} -cp ${WEBLOGIC_HOME}/server/lib/weblogic.jar weblogic.Deployer ${OPTIONS2} -stop >> ${APPLOG} 2>&1

   if [ $? -gt 0 ] #101019-1211 Valida si se apagó o  no.
   then
       msg "No se pudo detener la aplicación, probablemente no existe la aplicación o ya se enuentra abajo, se continua con el deploy" "WARN"
   else
        msg "Componente Apagado." "OK"
   fi
else
  msg "Undeploy activado, se omite Stop" "WARN"
fi
}

fnErrorExecute()
{
     fnError
     msg "Verificar la salida en el archivo ${APPLOG} en workspace/workdir para más información:" "ERROR"
     #msg "${LOGURL}ws/${APPLOG}" "LOG" # 070919-1736
     case ${TYPEINST} in

         "rollback")
                 fnEstructuraTemp # 1010221505
                 exit 1 # 190619 Bug detectado, hacia doble rollback cuando la opcion era rollback
                 ;;
         "new"|"fix") #030523-2000
                 [ "$NPROD" == "0" ] && msg "Aplicando Rollback a la estructura Generada:" "DEBUG"
                 [ "$NPROD" == "0" ] && fnEstructuraRB
                 ;;

     esac
}

fnError()
{
        for f in $(ls -lad ${APHOME}/data/*.dat|awk '{print $9}')
        do
                source ${f}
                CNTotal=0
                CNT1=0
                CNT2=0
                CNT3=0
                #200719-0023 Variable de workspace, usado desde Jenkins.
                # Antes: ${WORKSPACE}/${APPLOG}
                [ "${ERR1}" != "" ] && CNT1=$(grep "${ERR1}"  ${APPLOG} | wc -l)
                [ "${ERR2}" != "" ] && CNT2=$(grep "${ERR2}" ${APPLOG} | wc -l)
                [ "${ERR3}" != "" ] && CNT3=$(grep "${ERR3}" ${APPLOG} | wc -l)
                #echo "===== ERROR CATALOG =====" >> ${APPLOG}
                #echo "Error1:${CNT1}   Error2:${CNT2}          Error3:${CNT3}" >> ${APPLOG}
                CNTotal=$((CNT1 + CNT2 + CNT3))

                #if [ $CNT1 -gt 0 ] || [ $CNT2 -gt 0 ] || [ $CNT3 -gt 0 ]
                if [ $CNTotal -gt 0 ]
                then
                        msg "$(basename $f | awk -F'.' '{print $1}') -> $ERR1... $ERR2... $ERR3" "ERROR"
                        msg "$SOL" "SOLUCION"
                        return 1
                fi
        done
}
fnValida()
{
        msg "Validando que exista componente en la ruta repositorio:" "INFO"

        if [ ! -f ${RTJK}/${APWAR} ]
        then
                msg "Ruta: ${RTJK}/${APWAR}" "DEBUG"
                msg "No hay componente war dentro de la ruta de Jenkins, favor de copiar componente" "ERROR"
                exit 1
        else
                msg "Validación exitosa." "OK"
                msg "$(md5sum ${RTJK}/${APWAR})" "DEBUG"
                #md5sum ${RTJK}/${APWAR} |awk '{print $1}' > version.txt # 240922-1347
        fi

        if [ "${NRFC}" == "" ] && [ $NPROD != 1 ]
        then
                msg "No se coloco el numero de RFC, favor de colocar el RFC cuando se ejecute el job." "ERROR"
                exit 1
        fi

}


fnConfig() #Configuraciones rdeployer: {componente}.conf
{
msg "Validando variables de entorno Jenkins:" "INFO"

if [ -z ${WEBLOGIC_HOME} ] && [ -z ${APHOME} ] && [ -z ${JB_HOME} ] && [ -z ${OSB_HOME} ] && [ -z ${NPROD} ] && [ -z ${JAVA_HOME} ]
then
  msg "No esta configurado Plugin rdeployer correctamente en ${PluginLauncher}" "ERROR"
  exit 1
else
  msg "Variables set correctamente." "OK"
fi

msg "Validando archivo de configuracion global:" "INFO"

if [ -f ${APHOME}/conf/rdeployer.conf ]
then
         . ${APHOME}/conf/rdeployer.conf
         msg "Archivo de Configuracion global cargado." "OK"
         [ "${PluginLauncher}" == "UrbanCode" ] && AutoColorOutPut=false
else
         msg "No se encuentra el archivo de configuracion Global: ${APHOME}/conf/rdeployer.conf" "ERROR"
         exit 1
fi

if [ -f ${APHOME}/util/txt2term.io ]
then
        . ${APHOME}/util/txt2term.io
else
        msg "No se encuentra archivo de utilidad: ${APHOME}/util/txt2term.io" "ERROR"
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

#msg "${ServerDomainHostname} | ${ServerDomainPort}" "DEBUG"

if [ "${ServerDomainHostname}" != "" ]
then
        LOGURL="${https}${ServerDomainHostname}:${ServerDomainPort}/job/${JOB_NAME}/"
else
        LOGURL=${JOB_URL}
fi

#. ${APHOME}/util/colors.io
}


fnEstructuraNewESB()
{
vCOMP=$1

if [ "${PROJECTCONF}" == "${vCOMP}" ]
then
        vFirmaXMLRemote=$(ssh -q ${IPSRV} "md5sum ${RTINST}/${vCOMP}" | awk '{print $1}')
        vFirmaXMLLocal=$(md5sum ${RTJK}/${vCOMP} | awk '{print $1}')

        if [ "${vFirmaXMLLocal}" != "${vFirmaXMLRemote}" ]
        then
          fnEstructuraNew ${vCOMP}
        else
          msg "XML sin modificaciones, se omite copiado" "INFO"
        fi
fi
}

fnEstructuraNew()
{
vCOMP=$1
vFirmaActual=$(ssh -q ${IPSRV} "md5sum ${RTINST}/${vCOMP}" | awk '{print $1}') #250423-1837
vFirmaNewComponente=$(md5sum ${RTJK}/${vCOMP} | awk '{print $1}') #250423-1837

if [ "${vFirmaActual}" != "${vFirmaNewComponente}" ]; then #250423-1837
  RUTA_COPIA="${RTINST}/${YEAR}/${MES}/${NRFC}/${TYPEINST}" # 240823-200
  msg "Creando comando para estructura de directorios:" "INFO"
  msg "${RTINST}" "DEBUG"
  msg "${YEAR}" "DEBUG"
  msg "${MES}" "DEBUG"
  [ "${TYPEINST}" == "fix" ] && msg "FIX" "DEBUG" # 030523-2000

  CMD1="mkdir -p ${RUTA_COPIA}"
  ssh -q ${IPSRV} "${CMD1}"
  # 080320-2358 Se actualiza la forma de estructura con mas validaciones.
  msg "Creando comando para mover instalación que exista:" "INFO"
  msg "backup ${RTINST}/${vCOMP}.prev" "DEBUG"
  CMD1="[ ! -d ${RTINST}/.bck ] && mkdir ${RTINST}/.bck"
  CMD1="$CMD1;[ -f ${RTINST}/${vCOMP}.prev ] && mv ${RTINST}/${vCOMP}.prev ${RTINST}/.bck/${vCOMP}.prev.${U_TIME}"
  msg "backup ${RTINST}/${vCOMP}" "DEBUG"
  CMD1="$CMD1;[ -f ${RTINST}/${vCOMP} ] && cp -rp ${RTINST}/${vCOMP} ${RTINST}/${vCOMP}.prev"
  CMD1="$CMD1;[ -d ${RTINST}/.bck ] && ls -ltr ${RTINST}/.bck/${vCOMP}.prev.${U_TIME}"
  CMD1="$CMD1;[ -f ${RTINST}/${vCOMP}.prev ] && ls -ltr ${RTINST}/${vCOMP}.prev"

  msg "Creando comando para punto de montaje como liga suave:" "INFO"
  msg "remove ${RTINST}/${vCOMP}" "DEBUG"
  CMD1="$CMD1;[ -f ${RTINST}/${vCOMP} ] && rm -rf ${RTINST}/${vCOMP}"
  msg "link ${RUTA_COPIA}/${vCOMP} ${RTINST}/${vCOMP}" "DEBUG"
  CMD1="$CMD1;ln -s ${RUTA_COPIA}/${vCOMP} ${RTINST}/${vCOMP}"

  msg "Copiando el componente en el directorio:" "INFO"
  msg "${RTJK}/${vCOMP}" "DEBUG"
  msg "${IPSRV}:${RUTA_COPIA}/." "DEBUG"
  scp -qrp ${RTJK}/${vCOMP} ${IPSRV}:${RUTA_COPIA}/.

  if [ $? -gt 0 ]
  then
        msg "Error al copiar el componente ${vCOMP}" "ERROR"
        exit 1
  fi

  msg "Ejecutando comandos de estructura:" "INFO"
  msg "$CMD1" "DEBUG"
  ssh -q ${IPSRV} "${CMD1}"
  msg "Se termina ejecución" "OK"
else
  msg "Componente tiene misma firma, se omite su copiado" "WARN" #250423-1837
fi #250423-1837

}

fnEstructuraTemp()
{
  CMD1="rm -rf ${RTINST}/${APWAR}"
  CMD1="$CMD1;rm -rf ${RTINST}/${APWAR}.prev"
  CMD1="$CMD1;mv ${RTINST}/r_temp/* ${RTINST}/."
  CMD1="$CMD1;rmdir ${RTINST}/r_temp"
  msg "$CMD1" "DEBUG"
  ssh -q ${IPSRV} "${CMD1}"
}

fnEstructuraRB()
{
msg "Buscando prev en backups para montar como .prev" "INFO"
APWARBCK=$(ssh -q ${IPSRV} "ls -ltr ${RTINST}/.bck/${APWAR}.prev.*| tail -1")

msg "Creando comando para borrado de componente actual" "INFO"
CMD1="[ -d ${RTINST}/r_temp ] && rm -rf ${RTINST}/r_temp"
CMD1="$CMD1;mkdir ${RTINST}/r_temp"
CMD1="$CMD1;mv ${RTINST}/${APWAR} ${RTINST}/r_temp/."
CMD1="$CMD1;cp -rp ${RTINST}/${APWAR}.prev ${RTINST}/r_temp/."

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

fnRBCopyESB() # 081221-0524
{

msg "Copiando componentes para deploy Rollback de ESB:" "INFO"
scp -qrpo ConnectTimeout=${TimeOutSSH} ${IPSRV}:${RTINST}/${APWAR} ${RTJK}/.

if [ -f ${RTJK}/${PROJECTCONF} ]
then
# 231121-1130: Checa archivo XML
 vXML=${RTJK}/${PROJECTCONF}
 msg "XML Config: ${PROJECTCONF}" "DEBUG"
else
 msg "XML No encontrado, se realiza instalación sólo del JAR sin configuración" "WARN"
 vXML="None"
 msg "${vXML}" "DEBUG"
fi

if [ $? -gt 0 ]
then
        msg "No se puede extraer componente para Rollback" "ERROR"
        exit 1
else
        scp -qrpo ConnectTimeout=${TimeOutSSH} ${IPSRV}:${RTINST}/${PROJECTCONF} ${RTJK}/.

        if [ $? -gt 0 ] && [ ${vXML} != "None" ]
        then
          msg "No se puede extraer componente para Rollback" "ERROR"
          exit 1
        else
         msg "No se puede extraer xml, se continua con componente WAR" "WARN"
        fi
fi

msg "Componentes validados." "OK"

}
fnValidateFile()
{
  FileVal=$1

  if [ ! -f ${FileVal} ]; then
  msg "No existe Archivo ${FileVal}, favor de validar" "ERROR"
  else
        msg "${FileVal} seems right!" "DEBUG"
  fi

}

fnGetConsole()
{
#Vamos a obtener el usuario, password, ip y puerto de la consola bajo archivo XML
#CONN="$(${APHOME}/util/xmlUtil.io ${APHOME}/conf ${NODE})"
xUTIL=xmlUtil3  #260520-1157
fnValidateFile ${APHOME}/util/${xUTIL}.io
xVerUTIL=$( ${APHOME}/util/${xUTIL}.io --version) #090523-1642
msg "Versión XML Util: ${xVerUTIL}" "INFO" #260520-1157, 090523-1642
CONN="$(${APHOME}/util/${xUTIL}.io ${APHOME}/conf ${NODE} $1)"

case "${CONN}" in

        "ERR1")
                msg "XML sintaxis incorrecta" "ERROR"
                exit 1
                ;;
        "ERR2")
                msg "Archivo XML no encontrado" "ERROR"
                exit 1
                ;;
        "ERR3")
                msg "Datos de usuario y password no encontrados para NODO ${NODE}" "ERROR"
                exit 1
                ;;
esac

msg "Datos de consola encontrados." "OK"
USER=$(echo $CONN | awk '{print $1}')
PASSWD=$(echo $CONN | awk '{print $2}')
IPSRV=$(echo $CONN | awk '{print $3}')
PORT=$(echo $CONN | awk '{print $4}')

export USER
export PASSWD
export IPSRV
export PORT

[ "${PluginLauncher}" == "Jenkins" ] && msg "${LOGURL}ws/${APPLOG}" "LOG" # 070622-1653
}


fnTipoEstructuraInstall()
{
msg "Tipo de Instalación: ${TYPEINST}" "INFO"

case $1 in
"new"|"fix") #030523-2000
        msg "Número de RFC: ${NRFC}" "INFO"
        fnEstructuraNew ${APWAR}
        if [ -f ${RTJK}/${PROJECTCONF} ]; then
          [ "${DODEPLOY}" == "esb" ] && fnEstructuraNewESB ${PROJECTCONF}
        else
          [ "${DODEPLOY}" == "esb" ] && msg "XML No encontrado, se ignora archivo. Probable instalación sin XML" "WARN"
        fi

        ;;

"rollback")
        msg "Número de RFC del que falló: ${NRFC}" "INFO"
        NRFC=$(ssh -q ${IPSRV} "ls -lad ${RTINST}/${APWAR}.prev" | awk '{print $11}' | awk -F "/" '{print $8}')
        msg "Número de RFC de RollBack: ${NRFC}" "INFO"
        fnEstructuraRB ${APWAR}
        [ "${DODEPLOY}" == "esb" ] && fnEstructuraRB ${PROJECTCONF}
        [ "${DODEPLOY}" == "esb" ] && fnRBCopyESB
        ;;
esac

}

fnPluginInfo() {

case $1 in
        "weblogic")
        echo "===== PLUGIN VERSION =====" >> ${APPLOG}
        if [ -f ${WEBLOGIC_HOME}/server/lib/weblogic.jar ]; then
          ${JAVA_HOME}/bin/java -Xms${vMemoryIni} -Xmx${vMemoryMax} -cp ${WEBLOGIC_HOME}/server/lib/weblogic.jar weblogic.Deployer -version >> ${APPLOG}
        else
          msg "Plugin no encontrado en la ruta ${WEBLOGIC_HOME}" "ERROR"
          exit 1
        fi

        if [ $? -gt 0 ]
        then
                msg "no se puede cargar plugin, favor de validar salida del log y revisar si existen los binarios" "ERROR"
                exit 1
        fi
                        ;;

        "jboss") # 210323-1151
        echo "===== PLUGIN VERSION =====" >> ${APPLOG}

        if [ -f ${JB_HOME}/bin/jboss-cli.sh ]; then
                msg "JBoss CLI Detected" >> ${APPLOG}
        else
                msg "No se encuentra el archivo plugin para Jboss en ${JB_HOME}" "ERROR"
                exit 1
        fi
                        ;;

        "esb")
        if [ -f ${OSB_HOME}/osb/tools/configjar/setenv.sh ]
        then
                echo "===== PLUGIN VERSION =====" >> ${APPLOG}
                source ${OSB_HOME}/osb/tools/configjar/setenv.sh >> ${APPLOG}
                if [ $? -gt 0 ]
                then
                  msg "No se puede aplicar set de variables necesarias para ESB, favor de revisar salida de log" "ERROR"
                  exit 1
                else
                        #msg "Configuracion cargada para esb" "OK"
                        ${JAVA_HOME}/bin/java weblogic.version|head -2|tail -1 >> ${APPLOG}
                fi
        else
                msg "No existe el archivo para cargar configuracion de esb, favor de validar" "ERROR"
                exit 1
        fi
                        ;;

esac
}

fnNPROD()
{
        [ $1 -eq 1 ] && RTINST=$(dirname $(grep "Starting task with path" ${APPLOG} | awk -F":" '{print $4}'))
}

msg()
{
case $2 in
        "ERROR")
                U_HOUR="$(date '+%H%M%S')"
                if [ "${AutoColorOutPut}" = true ]
                then
                        printf "\e[31m[$U_HOUR] [$2]\e[0m $1\e[0m\n"
                else
                        printf "[$U_HOUR] [$2] $1\n"
                fi
                ;;
        "WARN")
                U_HOUR="$(date '+%H%M%S')"
                if [ "${AutoColorOutPut}" = true ]
                then
                        printf "\e[33m[$U_HOUR] [$2]\e[0m $1\e[0m\n"
                else
                        printf "[$U_HOUR] [$2] $1\n"
                fi
                ;;
        "OK")
                U_HOUR="$(date '+%H%M%S')"
                if [ "${AutoColorOutPut}" = true ]
                then
                        printf "\e[32m[$U_HOUR] [$2]\e[0m $1\e[0m\n"
                else
                        printf "[$U_HOUR] [$2] $1\n"
                fi
                ;;
        "DEBUG")
                U_HOUR="$(date '+%H%M%S')"
                if [ "${AutoColorOutPut}" = true ]
                then
                        printf "\e[35m[$U_HOUR] [$2]\e[0m $1\e[0m\n"
                else
                        printf "[$U_HOUR] [$2] $1\n"
                fi
                ;;
        "BANNER")
                U_HOUR="$(date '+%H%M%S')"
                if [ "${AutoColorOutPut}" = true ]
                then
                        printf "\e[30;48;5;82m[$1]\e[0m\n"
                else
                        printf "[$U_HOUR] [$2] $1\n"
                fi
                ;;

        *)
                U_HOUR="$(date '+%H%M%S')"
                printf "[$U_HOUR] [$2] $1\n"
                ;;
esac
}

# MAIN #
msg "rdeployer para ${PluginLauncher}, cocinando instalaciones desde 2018" "BANNER"
[ "${PluginLauncher}" == "UrbanCode" ] && AutoColorOutPut=false


if [ "${AutoColorOutPut}" = true ]
then
        msg "Versión de rdeployer: \e[1m$VERSION\e[0m" "INFO"
else
        msg "Versión de rdeployer: $VERSION" "INFO"
fi

fnConfig
fnValida

msg "Plugin Launcher: ${PluginLauncher}" "INFO"
case $DODEPLOY in
 "weblogic")
        fnPluginInfo weblogic
        msg "Plugin cargado: Weblogic_Deployer" "INFO"
        fnGetConsole Weblogic
        [ "$NPROD" == "0" ] && fnTipoEstructuraInstall ${TYPEINST} # 120521-0111
        fnDeployerWL ${NPROD} # Variable NPROD obtenido de Jenkins
        fnFirma ${NPROD} ${APWAR} # Variable NPROD obtenido de Jenkins
        ;;
 "jboss")
        fnPluginInfo jboss # 210323-1151
        msg "Plugin cargado: JBoss_CLI" "INFO"
        fnGetConsole JBoss
        [ "$NPROD" == "0" ] && fnTipoEstructuraInstall ${TYPEINST} # 120521-0111
        fnDeployerJB ${NPROD}
        fnFirma ${NPROD} ${APWAR} # Variable NPROD obtenido de Jenkins
        ;;
 "esb")
        fnPluginInfo esb
        msg "Plugin cargado: Oracle_Services_Bus" "INFO"
        fnGetConsole ESB
        [ "$NPROD" == "0" ] && fnTipoEstructuraInstall ${TYPEINST} # 120521-0111
        fnDeployESB ${NPROD}
        fnFirma ${NPROD} "${PROJECTCONF} ${APWAR}" # Variable NPROD obtenido de Jenkins
        ;;
 *)
        msg "Archivo CONF no tiene propiedad DODEPLOY, favor de configurar: DODEPLOY=[weblogic|jboss|esb]" "ERROR"
        ;;
esac

exit ${vEXIT}
