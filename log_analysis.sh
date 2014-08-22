#!/bin/bash
##
#
##设置脚本使用字符集
#export LANG=en_US.UTF-8
export LANG=zh_CN.GB2312
export  PATH=/usr/local/bin:$PATH
master_mail=liu@example.com
alert_mail=liu@example.com

####Defined variables
IPADD=`/sbin/ifconfig | grep "inet addr" | head -1 | awk '{print $2}'| awk -F ":" '{print $2}'`

##DATE_time
DATE=`date +%Y%m%d`
DATE_YES=`date -d "1 days ago" +%Y%m%d`
DATE_LOG=`date +%Y%m%d-%H%M`
DATE_YES_LOG=`date -d '1 days ago' +%Y%m%d-%H%M`
UNBAN_DATE=`date -d "15 days ago" +"%Y%m%d"`

##为避免与tmp的切割日志脚本冲突，定义在03:57-04:03检测脚本不执行。
DATE1=357  ###不运行脚本的开始时间;drop日志的分隔时间，357前输出到前一天的日志文件中
DATE2=403  ###不运行脚本的结束时间
RUN_DATE=`date +%k%M`
[ "${RUN_DATE}" -gt "${DATE1}" -a  "${RUN_DATE}" -lt "${DATE2}" ]  && exit 1

##定义发送drop_ip邮件及删除旧文件的时间
MAIL_DATE1=0800
MAIL_DATE2=0809

##PROJECT_name
LOG_PATH=/tmp/
PROJECT=$(find $LOG_PATH -type f -mtime -1 -size  +4k -regex "${LOG_PATH}/access_5?3?[a-z][0-9a-zA-Z-]*\.log" |awk -F'[/|_|.]' '{print $7}')

##project_filter_file
PROJECT_FILTER=/tmp/abc.txt
PROJECT_CONF=/tmp/tmp_log_script.conf
##单个链接访问的倍数比较
REQUEST_TIMES=3
HIGH_TIMES=3.0
LOW_TIMES=0.3
PV_CHECK_NUM=500
PV_CHECK_URI_NUM=300

CUT_LOG_PATH=/tmp/log

##pv log file
PV_PATH=/tmp/pv
MAIL_PATH=/tmp/pvmail
MAIL_LOG=${MAIL_PATH}/pv_mail_${DATE_LOG}.log

##drop_ip log file
DROP_PATH=/tmp/droplog
DROP_LOG=${DROP_PATH}/drop_log_${DATE}.txt
DROP_YES_LOG=${DROP_PATH}/drop_log_${DATE_YES}.txt

UNBAN_PATH=/tmp/unbanlog
UNBAN_LOG=${UNBAN_PATH}/unban_log_${DATE}.txt

[ -d ${CUT_LOG_PATH} ] || mkdir ${CUT_LOG_PATH}
[ -d ${DROP_PATH} ] || mkdir ${DROP_PATH}
[ -d ${UNBAN_PATH} ] || mkdir ${UNBAN_PATH}
[ -d ${PV_PATH} ] || mkdir ${PV_PATH}
[ -d ${MAIL_PATH} ] || mkdir ${MAIL_PATH}

[ -f /etc/black_ip ] || touch /etc/black_ip
[ -x /etc/black_ip ] || chmod +x /etc/black_ip

##删除15天前drop掉的ip.
UNBAN_LINE=`grep -n  "${UNBAN_DATE}"  /etc/black_ip |tail -1 | awk -F':'  '{print $1}'`
if [ ! -z ${UNBAN_LINE} ] 
then    
	sed -n "1,${UNBAN_LINE} p" /etc/black_ip >> ${UNBAN_LOG}
	sed -i "1,${UNBAN_LINE} d" /etc/black_ip 
	/bin/bash /etc/iptables.sh
	#[ -s ${UNBAN_LOG} ]  &&  /bin/mail -s "${IPADD}_${DATE}_unban_ip"  ${master_mail}  <  ${UNBAN_LOG}
fi

quiet_mail_value(){
    if [ ! -s ${PROJECT_CONF} ] ; then
        QUIET_MAIL=0
        echo  "quiet_mail=0" >> ${PROJECT_CONF}
        echo "${PROJECT_CONF} not exist, parameter recover default value.please check."| mail -s "${PROJECT_CONF} parameter recover default setting" ${master_mail}
        return
    else
        eval $(awk  -F'=' '$1 ~ /^quiet_mail$/{print "QUIET_MAIL="$2}' ${PROJECT_CONF})
        if [ -z "${QUIET_MAIL}" ]; then
            QUIET_MAIL=0
            echo  "quiet_mail=0" >> ${PROJECT_CONF}
            echo "${PROJECT_CONF} quiet_mail recover default quiet_mail=0 please check."| mail -s "${PROJECT_CONF} parameter recover default setting" ${master_mail}            
        fi
    fi

    if [ "${QUIET_MAIL}" -ge "1" ] ; then
        QUIET_MAIL=`expr $QUIET_MAIL - 1`
        sed  -i "s/^quiet_mail=.*/quiet_mail=${QUIET_MAIL}/" ${PROJECT_CONF}
    fi
}

###配置是否发送pv相关邮件的控制参数
quiet_mail_value

for TOMCAT in ${PROJECT} ;do

    LOG_FILE=/tmp/logs/access_${TOMCAT}.log
        
    CUT_LOG_FILE=${CUT_LOG_PATH}/hour_${TOMCAT}_${DATE_LOG}.log
    TMP_LOG=${CUT_LOG_PATH}/.hour_${TOMCAT}_${DATE_LOG}.tmp

    STRUTSLOG=/tmp/strutslog/${TOMCAT}-${DATE}-struts.txt

    PV_LOG=${PV_PATH}/pv_${TOMCAT}_${DATE_LOG}.log
    PV_YES_LOG=${PV_PATH}/pv_${TOMCAT}_${DATE_YES_LOG}.log
    PV_TMP_LOG=${PV_PATH}/.pv_${TOMCAT}_${DATE_LOG}.tmp
    PV_MAIL_LOG=${MAIL_PATH}/pv_${TOMCAT}_${DATE_LOG}.log


    ##静态server不执行检测.
    echo "${TOMCAT}"  | grep -q "\-static" &&  continue 

    LINE_NUM=${CUT_LOG_PATH}/${TOMCAT}_line.tmp_v2

    ### Cut_nginx_log #####################################
    [ ! -e ${LOG_FILE} ] && continue

    [ ! -s ${LINE_NUM} ] && wc -l ${LOG_FILE} | awk '{print $1}' > ${LINE_NUM}  && continue
    [ -s ${LINE_NUM} ] && BEGIN=`cat ${LINE_NUM}`

 	[ -s ${LOG_FILE} ] && wc -l ${LOG_FILE} | awk '{print $1}' > ${LINE_NUM}
    END=`cat ${LINE_NUM}` 

    if [ ${BEGIN} -lt ${END} ]; then
        [ -s ${LOG_FILE} ] &&  sed -n "${BEGIN},${END}"p ${LOG_FILE} > ${CUT_LOG_FILE}
    elif [ ${BEGIN} -gt ${END} ]; then
        echo "1" > ${LINE_NUM} 
    else
        continue
    fi

    ### PV analyze ####################################################
    [ -s ${CUT_LOG_FILE} ] || continue
    PV_SUM=`wc -l  ${CUT_LOG_FILE} |awk '{print $1}'`
    echo "${TOMCAT}:${PV_SUM}" > ${PV_LOG}
    awk -F'"|?' '{R[$3]++}END{for (i in R) print R[i]"-"i}' ${CUT_LOG_FILE} |sort -nr >> ${PV_LOG}
        
    ###日志pv量统计
    PV_YES_SUM=1
    if [ -s ${PV_YES_LOG} ];then
        eval $(awk  -v A=${TOMCAT} -F':' '($1 == A){print "PV_YES_SUM="$2}' ${PV_YES_LOG} )
    else
        touch ${PV_YES_LOG}
    fi
    [ -z "${PV_YES_SUM}" ] && PV_YES_SUM=1
    pv_times=`echo "${PV_SUM} ${PV_YES_SUM}" |awk '{printf "%.1f\n",$1/$2}'`
	awk -v URI_NUM=${PV_CHECK_URI_NUM} -F'-' '($2 !="" && NR==FNR ){a[$2]=$1}($2 !="" && NR>FNR) && ($1 > URI_NUM || a[$2]>URI_NUM ) {if($2 in a){printf ("%s\t%-40s\t%-5s\t%-40s\tratio:%-.1f\n", $1,$2,a[$2],$2,$1/a[$2])} else{printf ("%s\t%-40s\tratio:%-5s\n",$1,$2,$1)}}' ${PV_YES_LOG} ${PV_LOG} > ${PV_TMP_LOG}
    awk -v TIMES=${REQUEST_TIMES} -v LOW_TIMES=${LOW_TIMES} -F':' '($NF > TIMES || $NF < LOW_TIMES ){print}' ${PV_TMP_LOG} > ${PV_MAIL_LOG}
    rm -f  ${PV_TMP_LOG}

    ###检测是否发送pv量相关邮件
    if [ "${QUIET_MAIL}" -ne "0" ];then
        rm -rf  ${PV_MAIL_LOG}
    else
        if [ "${PV_SUM}" -gt "${PV_YES_SUM}" ]; then   
            if [ "${PV_SUM}" -gt "${PV_CHECK_NUM}" ]; then
                if [[ "${pv_times}" > "${HIGH_TIMES}" ]]; then
                echo >> ${MAIL_LOG}
                echo "###########################" >> ${MAIL_LOG}
                echo "${TOMCAT} pv total: ${PV_SUM}" >> ${MAIL_LOG}
                echo "${DATE_LOG}: ${TOMCAT} pv: ${PV_SUM}, More than ${HIGH_TIMES} times of yesterday pv: ${PV_YES_SUM}." >> ${MAIL_LOG}
                    if [ -s "${PV_MAIL_LOG}" ]; then 
                        echo "today_num----request_uri--------yesterday_num----request_uri----ratio:" >> ${MAIL_LOG}
                        cat ${PV_MAIL_LOG}  >> ${MAIL_LOG}
                    fi
                else
                    if [ -s "${PV_MAIL_LOG}" ]; then 
                        echo >> ${MAIL_LOG}
                        echo "###########################" >> ${MAIL_LOG}
                        echo "${TOMCAT} pv total: ${PV_SUM}" >> ${MAIL_LOG}
                        echo "today_num----request_uri--------yesterday_num----request_uri----ratio:" >> ${MAIL_LOG}
                        cat ${PV_MAIL_LOG}  >> ${MAIL_LOG}
                    fi
                fi
            fi
        else
            if [ "${PV_YES_SUM}" -gt "${PV_CHECK_NUM}" ] && [[ "${pv_times}" < "${LOW_TIMES}" ]]; then
                echo >> ${MAIL_LOG}
                echo "###########################" >> ${MAIL_LOG}
                echo "${TOMCAT} pv total: ${PV_SUM}" >> ${MAIL_LOG}
                echo "${DATE_LOG}: ${TOMCAT} pv: ${PV_SUM}, Less than ${LOW_TIMES} times of yesterday pv: ${PV_YES_SUM}." >> ${MAIL_LOG}
                    if [ -s "${PV_MAIL_LOG}" ]; then
                        echo "today_num----request_uri--------yesterday_num----request_uri----ratio:" >> ${MAIL_LOG}
                        cat ${PV_MAIL_LOG}  >> ${MAIL_LOG}
                    fi
            fi
        fi
        [ -f ${PV_MAIL_LOG} ] && rm -f ${PV_MAIL_LOG}
    fi			
	
    ### strutlog check ####################################
    awk -F'"' '($1 !~ /118.242.160.50|118.242.2.240/ &&  $NF !~ /struts\.token\.name=token/ ){print $0}'  ${CUT_LOG_FILE} > ${TMP_LOG}
    
    if [ ! -s ${TMP_LOG} ]; then
        rm -f ${TMP_LOG}
        continue
    fi

    LINE=`wc -l ${TMP_LOG} | awk '{print $1}'`
       
    if [ ${LINE} -gt 20 ] && [ ! -f /tmp/strutslog/${TOMCAT}_tmp_v2.sendmail ] && [ ${TOMCAT}x != statusx ]; then
        echo "${TOMCAT} resolve to ${IPADD}." | /bin/mail  -s "${TOMCAT}_resolve_to_${IPADD}" ${alert_mail}
    fi
    [ ${LINE} -gt 20 ] &&  touch /tmp/strutslog/${TOMCAT}_tmp_v2.sendmail

    if [ ${LINE} -gt 10 ]; then  
        awk -F'"' '$3$NF~/struts|redirect|classLoader/{print $0}' ${TMP_LOG} > ${STRUTSLOG}
        if [ ! -s ${STRUTSLOG} ] ; then
            rm -f ${STRUTSLOG}
        else
            /bin/mail -s "struts_${IPADD}_${TOMCAT}" ${alert_mail} <  ${STRUTSLOG}
        fi
    fi
    
    ### 53wan 不执行loganalyze部分.
    if [ "${TOMCAT}"  == "53wan" ];then
        [ -f ${TMP_LOG} ] && rm -f ${TMP_LOG}
        continue
    fi

    ### Loganalyze ########################################
    IGNORE_IP=`tail -1  ${PROJECT_FILTER}`
    CONDITION1=`grep "##all" ${PROJECT_FILTER} -A1 | grep -v "##all" `
    CONDITION2=`grep "##${TOMCAT}-exclude" ${PROJECT_FILTER} -A1 | grep -v "##${TOMCAT}-exclude" `

    DROP_IP_FILE=${CUT_LOG_PATH}/drop_ip_${TOMCAT}_${DATE_LOG}.log

    [ -z ${CONDITION2} ]
    STATUS=$?
    if [ ${STATUS}x = 0x ]; then
       awk -F '"' '{print $1,$3,$NF}' ${TMP_LOG} |grep "${CONDITION1}" | awk '{IP[$1]++}END{for(i in IP) print IP[i]" "i}' | grep -v "${IGNORE_IP}" |awk  '$1>2{print $2}' >${DROP_IP_FILE}
    else
       awk -F '"' '{print $1,$3,$NF}' ${TMP_LOG} | grep "${CONDITION1}" | grep -v "${CONDITION2}" |awk '{IP[$1]++}END{for(i in IP) print IP[i]" "i}' | grep -v "${IGNORE_IP}"| awk '$1>2{print $2}' > ${DROP_IP_FILE}
    fi

    if [ -s ${DROP_IP_FILE} ]; then
        for IP in `cat ${DROP_IP_FILE}`; do
            if [ ${STATUS} = 0 ]; then
                FILTER_STRING=`grep ${IP} ${TMP_LOG} | grep -o "${CONDITION1}" | awk '{S[$1]++}END{for (i in S) print i}'| awk '{{printf"%s,",$0}}'`
            else 
                FILTER_STRING=`grep ${IP} ${TMP_LOG} | grep -o "${CONDITION1}" | grep -v "${CONDITION2}" | awk '{S[$1]++}END{for (i in S) print i}' | awk '{{printf"%s,",$0}}'`
            fi
                              
            [ -x /usr/local/bin/nali ] &&  IP_AREA=`/usr/local/bin/nali ${IP} 2>/dev/null`
            [ -z "${IP_AREA}" ] && IP_AREA=${IP}
            grep -q  "/sbin/iptables -A INPUT -s ${IP} -j DROP" /etc/black_ip
            if [ $? -ne 0 ]; then
                echo "/sbin/iptables -A INPUT -s ${IP} -j DROP  ##${DATE}.">>/etc/black_ip
                if [ "${RUN_DATE}" -lt "${DATE1}" ];then
                	echo "${DATE_LOG},  ${IP_AREA}  visited  ${TOMCAT}  ${FILTER_STRING}  dropped." >> ${DROP_YES_LOG}
                else
                        echo "${DATE_LOG},  ${IP_AREA}  visited  ${TOMCAT}  ${FILTER_STRING}  dropped." >> ${DROP_LOG}
                fi
            else
                if [ "${RUN_DATE}" -lt "${DATE1}" ];then
                       echo "${DATE_LOG},  ${IP_AREA}  visited  ${TOMCAT}  critical, has dropped in /etc/black_ip." >> ${DROP_YES_LOG}
                else
                        echo "${DATE_LOG},  ${IP_AREA}  visited  ${TOMCAT}  critical, has dropped in /etc/black_ip." >> ${DROP_LOG}
                fi
            fi
        done

        ### delete iptables #################
        LINES=`wc -l /etc/black_ip | awk '{print $1}'`
        if [ ${LINES} -gt 100 ]; then
            LINES2=`expr $(( ${LINES} - 100 ))`
            sed -i "1,${LINES2} d" /etc/black_ip
        fi
        /bin/bash /etc/iptables.sh
    fi
    rm -f ${DROP_IP_FILE} ${TMP_LOG}
done

[ -s ${MAIL_LOG} ] && /bin/mail  -s "${IPADD}_${DATE_LOG} pv unusual visited"  ${alert_mail}  < ${MAIL_LOG}

if [ "${RUN_DATE}" -ge "${MAIL_DATE1}" -a  "${RUN_DATE}" -le "${MAIL_DATE2}" ];then
	[ -s ${DROP_YES_LOG} ] && /bin/mail -s "${IPADD}_${DATE_YES}_drop_ip" ${alert_mail} < ${DROP_YES_LOG}
	
	###Delete the log for a long time###
	find ${CUT_LOG_PATH} -type f -cmin +720 -name "hour_*.log" -exec rm -f {} \;
	find ${PV_PATH} -type f -mtime +3 -name "*.log" -exec rm -f {} \;
	## pvmail log file.
	find ${MAIL_PATH} -type f -mtime +30 -name "*.log" -exec rm -f {} \;
	## drop ip log file.
	find ${DROP_PATH} -type f -mtime +30 -name "*.txt" -exec rm -f {} \;
	## unban_ip log file
	find ${UNBAN_PATH} -type f -mtime +30 -name "*.txt" -exec rm -f {} \;
	## struts.log file save 1 month
	find /tmp/strutslog/ -type f -mtime +30 -name "*.txt" -exec rm -f {} \;
fi

## nginx paring  lock file. save 1 day
find /tmp/strutslog/ -type f -mtime +1 -name "*.sendmail" -exec rm -f {} \;
