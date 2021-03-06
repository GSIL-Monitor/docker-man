#!/bin/bash

# 配置文件变量替换函数(参数1: 参数的定义 参数2: 替换参数的值)
function replace_parameter()
{
	a='\/';b='\\\/';value=`echo "$2" | sed "s/$a/$b/g"`
	sed -i "s/$1/$value/g" /usr/local/otter/manager/conf/otter.properties 
}

replace_parameter  "@OTTER_MANAGER_DOMAIN_NAME" "$OTTER_MANAGER_DOMAIN_NAME"
replace_parameter  "@OTTER_DATABASE_URL" "$OTTER_DATABASE_URL"
replace_parameter  "@OTTER_DATABASE_USERNAME" "$OTTER_DATABASE_USERNAME"
replace_parameter  "@OTTER_DATABASE_PASSWORD" "$OTTER_DATABASE_PASSWORD"
replace_parameter  "@OTTER_ZOOKEEPER_CLUSTER_DEFAULT" "$OTTER_ZOOKEEPER_CLUSTER_DEFAULT"
replace_parameter  "@OTTER_ZOOKEEPER_SESSIONTIMEOUT" "$OTTER_ZOOKEEPER_SESSIONTIMEOUT"
replace_parameter  "@OTTER_MANAGER_MONITOR_EMAIL_HOST" "$OTTER_MANAGER_MONITOR_EMAIL_HOST"
replace_parameter  "@OTTER_MANAGER_MONITOR_EMAIL_USERNAME" "$OTTER_MANAGER_MONITOR_EMAIL_USERNAME"
replace_parameter  "@OTTER_MANAGER_MONITOR_EMAIL_PASSWORD" "$OTTER_MANAGER_MONITOR_EMAIL_PASSWORD"
replace_parameter  "@OTTER_MANAGER_MONITOR_EMAIL_STMP_PORT" "$OTTER_MANAGER_MONITOR_EMAIL_STMP_PORT"
replace_parameter  "@OTTER_MANAGER_PORT" "$OTTER_MANAGER_PORT"

sed -i "s/@LOG_LEVEL/$LOG_LEVEL/g" /usr/local/otter/manager/conf/logback.xml
sed -i "s/@LOG_APPENDER/$LOG_APPENDER/g" /usr/local/otter/manager/conf/logback.xml

current_path=`pwd`
case "`uname`" in
    Linux)
		bin_abs_path=$(readlink -f $(dirname $0))
		;;
	*)
		bin_abs_path=`cd $(dirname $0); pwd`
		;;
esac
base=${bin_abs_path}/..
otter_conf=$base/conf/otter.properties
logback_configurationFile=$base/conf/logback.xml

export LANG=en_US.UTF-8
export BASE=$base

if [ -f $base/bin/otter.pid ] ; then
	echo "found otter.pid , Please run stop.sh first ,then startup.sh" 2>&2
    exit 1
fi

if [ ! -d $base/logs ] ; then 
	mkdir -p $base/logs
fi

## set java path
if [ -z "$JAVA" ] ; then
  JAVA=$(which java)
fi

ALIBABA_JAVA="/usr/alibaba/java/bin/java"
TAOBAO_JAVA="/opt/taobao/java/bin/java"
if [ -z "$JAVA" ]; then
  if [ -f $ALIBABA_JAVA ] ; then
        JAVA=$ALIBABA_JAVA
  elif [ -f $TAOBAO_JAVA ] ; then
        JAVA=$TAOBAO_JAVA
  else
        echo "Cannot find a Java JDK. Please set either set JAVA or put java (>=1.5) in your PATH." 2>&2
    	exit 1
  fi
fi


case "$#" 
in
0 ) 
	;;
1 )	
	var=$*
	if [ -f $var ] ; then 
		otter_conf=$var
	else
		echo "THE PARAMETER IS NOT CORRECT.PLEASE CHECK AGAIN."
        exit
	fi;;
2 )	
	var=$1
	if [ -f $var ] ; then
		otter_conf=$var
	else 
		if [ "$1" = "debug" ]; then
			DEBUG_PORT=$2
			DEBUG_SUSPEND="n"
			JAVA_DEBUG_OPT="-Xdebug -Xnoagent -Djava.compiler=NONE -Xrunjdwp:transport=dt_socket,address=$DEBUG_PORT,server=y,suspend=$DEBUG_SUSPEND"
		fi
     fi;;
* )
	echo "THE PARAMETERS MUST BE TWO OR LESS.PLEASE CHECK AGAIN."
	exit;;
esac


str=`file $JAVA_HOME/bin/java | grep 64-bit`
if [ -n "$str" ]; then
	JAVA_OPTS="-server -Xms$JAVA_XMS -Xmx$JAVA_XMX -Xmn$JAVA_XMN -XX:SurvivorRatio=2 -XX:PermSize=96m -XX:MaxPermSize=256m -Xss256k -XX:-UseAdaptiveSizePolicy -XX:MaxTenuringThreshold=15 -XX:+DisableExplicitGC -XX:+UseConcMarkSweepGC -XX:+CMSParallelRemarkEnabled -XX:+UseCMSCompactAtFullCollection -XX:+UseFastAccessorMethods -XX:+UseCMSInitiatingOccupancyOnly -XX:+HeapDumpOnOutOfMemoryError"
else
	JAVA_OPTS="-server -Xms$JAVA_XMS -Xmx$JAVA_XMX -XX:NewSize=128m -XX:MaxNewSize=128m -XX:MaxPermSize=128m "
fi

JAVA_OPTS=" $JAVA_OPTS -Djava.awt.headless=true -Djava.net.preferIPv4Stack=true -Dfile.encoding=UTF-8"
OTTER_OPTS="-DappName=otter-manager -Ddubbo.application.logger=slf4j -Dlogback.configurationFile=$logback_configurationFile -Dotter.conf=$otter_conf"

if [ -e $otter_conf -a -e $logback_configurationFile ]
then 
	
	for i in $base/lib/*;
		do CLASSPATH=$i:"$CLASSPATH";
	done
 	CLASSPATH="$base:$base/conf:$CLASSPATH";
 	
 	echo "cd to $bin_abs_path for workaround relative path"
  	cd $bin_abs_path
 	
	echo LOG CONFIGURATION : $logback_configurationFile
	echo otter conf : $otter_conf 
	echo CLASSPATH :$CLASSPATH
	$JAVA $JAVA_OPTS $JAVA_DEBUG_OPT $OTTER_OPTS -classpath .:$CLASSPATH com.alibaba.otter.manager.deployer.OtterManagerLauncher
	# echo $! > $base/bin/otter.pid 
	
	echo "cd to $current_path for continue"
  	cd $current_path
else 
	echo "otter conf("$otter_conf") OR log configration file($logback_configurationFile) is not exist,please create then first!"
fi
