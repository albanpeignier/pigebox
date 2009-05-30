#
# cron-jobs for pige
#

MAILTO=root
*/15 * * * *     root   /usr/share/pige/bin/pige-cron clean
*/15 * * * *     root   /usr/share/pige/bin/pige-cron encode
