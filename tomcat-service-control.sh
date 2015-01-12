#!/bin/bash
# chkconfig: - 86 14
# Startup script for Tomcat Servlet Engine
#
# description: script to launch Tomcat on boot
#
#mailto: colynn.liu

CATALINA_USER=tomcat
CATALINA_HOME=/opt/tomcat1
CATALINA_BIN="${CATALINA_HOME}/bin"
CATALINA_CMD="${CATALINA_BIN}/catalina.sh"
CATALINA_PID="${CATALINA_HOME}/var/catalina.pid"
CATALINA_OUT=${CATALINA_HOME}/logs/catalina.out

##jmx
#jmx seting will read ${CATALINA_HOME}/bin/setenv.sh

#define status variable
RETVAL=0

start() {
	if [ -f "$CATALINA_PID" ]; then
        echo "$CATALINA_PID already exists; process is already running or crashed" 1>&2
        else
        echo "Starting Tomcat..."
        su - $CATALINA_USER -c "${CATALINA_CMD} start"
        RETVAL=$?
          if [ $RETVAL -eq 0 ] ; then
             echo "$CATALINA_HOME tomcat start is ok."
	     echo "${CATALINA_OUT} log get more infomation."
          fi
        fi
}

stop(){
        if [ ! -f "$CATALINA_PID" ]; then
                echo "$CATALINA_PID does not exist; process does not exist or has gone rogue" 1>&2
        else
        	PID=$(cat $CATALINA_PID)
        echo "Stopping..."
        su - $CATALINA_USER -c "${CATALINA_CMD} stop"
        while [ -x "/proc/${PID}" ]; do
                echo "waiting for Shutdown..."
                sleep 1
        done
        echo "$CATALINA_HOME tomcat stopped is ok."
        fi
}

stop-force(){
        if [ ! -f "$CATALINA_PID" ]; then
                echo "$CATALINA_PID does not exist; process does not exist or has gone rogue" 1>&2
        else
        	PID=$(cat $CATALINA_PID)
        echo "Stopping..."
        su - $CATALINA_USER -c "${CATALINA_CMD} stop -force"
        while [ -x "/proc/${PID}" ]; do
                echo "waiting for Shutdown..."
                sleep 1
        done
        echo "$CATALINA_HOME tomcat stopped is ok."
        fi
}

case "$1" in
   start)
	start
	;;
   status)
	if [ ! -f "$CATALINA_PID" ]; then
		echo "$CATALINA_PID does not exist; process does not exist or has gone rogue"
	else
		echo "pid file exists: ${CATALINA_PID}"
	PID=$(cat $CATALINA_PID)
	echo "${CATALINA_HOME} should be running with pid ${PID}"
	   if [ -x "/proc/${PID}" ]; then
		echo "process exists in process list at /proc/${PID}"
	   else
		echo "process does not exist in process list (could not find it at /proc/${PID}; did it die without nuking its own pid file?"
	   fi
	fi
	;;
    stop)
	stop
	;;
    stop-force)
	stop-force
	;;
    restart)
	stop
 	sleep 1
	start
	;;
    *)
        echo $"Usage: $0 {start|stop|stop-force|restart|status}"
	;;
esac

