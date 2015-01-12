##because /etc/init.d/tomcat scripts define CATALINA_PID can not effect catalina.sh
##so redefind CATALINA_PID variable
CATALINA_PID=${CATALINA_HOME}/var/catalina.pid

##set jmx
JAVA_OPTS=$JAVA_OPTS" -Dcom.sun.management.jmxremote.port=6789"
JAVA_OPTS=$JAVA_OPTS" -Dcom.sun.management.jmxremote.host=127.0.0.1"
JAVA_OPTS=$JAVA_OPTS" -Dcom.sun.management.jmxremote.ssl=false"
JAVA_OPTS=$JAVA_OPTS" -Dcom.sun.management.jmxremote.authenticate=true"
JAVA_OPTS=$JAVA_OPTS" -Dcom.sun.management.jmxremote.access.file=$CATALINA_HOME/conf/jmxremote.access"
JAVA_OPTS=$JAVA_OPTS" -Dcom.sun.management.jmxremote.password.file=$CATALINA_HOME/conf/jmxremote.passwd"

