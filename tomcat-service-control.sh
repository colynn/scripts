#!/bin/bash
# chkconfig: - 86 14
# Startup script for Tomcat Servlet Engine
#
# description: script to launch Tomcat on boot
#
#mailto: colynn.liu

CATALINA_USER=root
CATALINA_HOME=/usr/local/tomcat7
CATALINA_BIN="${CATALINA_HOME}/bin"
CATALINA_CMD="${CATALINA_BIN}/catalina.sh"
#JAVA_HOME=""
CATALINA_PID=${CATALINA_HOME}/var/catalina.pid


RETVAL=0
prog=tomcat7


case "$1" in
    start)
        if [ -f "$CATALINA_PID" ]; then
            echo "$CATALINA_PID already exists; process is already running or crashed" 1>&2
        else
            echo "Starting Tomcat..."
            su - $CATALINA_USER -c "${CATALINA_CMD} start"
   	    RETVAL=$?
            if [ $RETVAL -eq 0 ] ; then
		echo $(ps -ef |grep "$CATALINA_HOME " |grep -v "grep $CATALINA_HOME " |grep "/java" |awk '{print $2}' ) > $CATALINA_PID
	    	echo "$CATALINA_HOME tomcat start is ok."
	     fi  
        fi
        ;;
    status)
        if [ ! -f "$CATALINA_PID" ]; then
            echo "$CATALINA_PID does not exist; process does not exist or has gone rogue"
        else
            echo "pid file exists: ${CATALINA_PID}"
            PID=$(cat $CATALINA_PID)
            echo "should be running with pid ${PID}"
            if [ -x "/proc/${PID}" ]; then
                echo "process exists in process list at /proc/${PID}"
            else
                echo "process does not exist in process list (could not find it at /proc/${PID}; did it die without nuking its own pid file?"
            fi
        fi
        ;;
    stop)
        if [ ! -f "$CATALINA_PID" ]; then
            echo "$CATALINA_PID does not exist; process does not exist or has gone rogue" 1>&2
        else
            PID=$(cat $CATALINA_PID)
            echo "Stopping..."
            su - $CATALINA_USER -c "kill  -9 ${PID}"
            while [ -x "/proc/${PID}" ]; do
                echo "Waiting for Tomcat to shut down..."
                sleep 2
            done
	    rm $CATALINA_PID
            echo "Tomcat stopped"
        fi
        ;;
    *)
        echo $"Usage: $0 {start|stop|status}"
        ;;
esac
