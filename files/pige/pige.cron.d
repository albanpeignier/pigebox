#
# cron-jobs for pige
#

MAILTO=root
1,16,31,46 * * * *     root   /usr/share/pige/bin/pige-cron
