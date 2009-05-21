#! /bin/sh
### BEGIN INIT INFO
# Provides:          alsa.backup
# Required-Start:    $network $named $remote_fs $syslog
# Required-Stop:     $network $named $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
### END INIT INFO                                                                                                                                          

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/usr/bin/alsa.backup
DAEMON_OPTS=""
NAME=alsa.backup
DESC="alsa backup"

test -x $DAEMON || exit 0

[ -r /etc/default/$NAME ] && . /etc/default/$NAME

. /lib/lsb/init-functions

is_true() {
    if [ "x$1" = "xtrue" -o "x$1" = "xyes" -o "x$1" = "x0" ] ; then
        return 0
    else
        return 1
    fi
}

start_alsa_backup() {
    if is_true "$START" ; then
	      start-stop-daemon --start --quiet --pidfile /var/run/$NAME.pid \
	          --startas $DAEMON -- $DAEMON_OPTS --config=$CONFIG_FILE --background --pid=/var/run/$NAME.pid
    else
	      echo ""
	      echo "$NAME not configured to start, please edit /etc/default/$NAME enable"
    fi
}

stop_alsa_backup() {
	  start-stop-daemon --stop --quiet --pidfile /var/run/$NAME.pid
}

case "$1" in
    start)
	      log_begin_msg "Starting $DESC"
	      start_alsa_backup
	      log_end_msg 0
	      ;;
    stop)
	      log_begin_msg "Stopping $DESC"
	      stop_alsa_backup
	      log_end_msg 0
	      ;;
    restart|force-reload)
	      log_begin_msg "Restarting $DESC"
	      stop_alsa_backup
	      sleep 1
	      start_alsa_backup
	      log_end_msg 0
	      ;;
    *)
	      echo "Usage: $0 {start|stop|restart|force-reload}" >&2
	      exit 1
	      ;;
esac

exit 0
