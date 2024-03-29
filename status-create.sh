#!/bin/bash
#
# Server status script for Linux.
# This script is designed to be run as a cronjob by 'root'.
# Created by sleddog.
# Last revised: 03 Mar 2014.
# Free for everyone.
#
# Capture start time for runtime calculation.
START=`date +%s`
#
# SETTINGS --------------------------------------------------------------------
#
# MEMTYPE=1 for OpenVZ using 'guaranteed/burst' memory (user_beancounters).
# MEMTYPE=2 for everything else (including OpenVZ with vswap).
MEMTYPE=2
#
# Ethernet interface for traffic.
IFACE="venet0"
#
# Path and filename for the HTML report.
REPORT="/var/www/Zeugs/status/srv3.html"
#
# Page title for the HTML report.
PGTITLE="Server Stats : SRV 3 @ Core-Backbone"
#
# Format of the report date/time line. Read 'man date' for details...
REPDATE=`date +'%l:%M %p - %a, %d %b %Y [GMT %:z]'`
#
# Run interval as set in the cronjob. This is used for display purposes
# on the report page.
INTERVAL=5
#
# A place to write temporary files generated by this script.
DATADIR="/tmp"
#
# Disk devices for disk usage report.
# DISKMNT  : the mount point shown in 'df' (column at right, not left!).
# DISKNAME : the name to be displayed in the report; maximum 10 characters.
DISKMNT[0]='/'
DISKNAME[0]='/'
# Add a second disk device:
#DISKMNT[1]='/dev/shm'
#DISKNAME[1]='/dev/shm'
#
# END SETTINGS ----------------------------------------------------------------
#
if [ "$MEMTYPE" -eq "1" ]; then
	BEAN=`cat /proc/user_beancounters`
else
	MEMINFO=`cat /proc/meminfo`
fi
STAT=`cat /proc/stat`
LOADAVG=`cat /proc/loadavg`
UPTIME=`cat /proc/uptime`
DISKUSE=`df -h`
#
function calc_wait {
        IO=`echo $STAT | awk '{ print $6 }'`
        TTL=`echo $STAT | awk '{ print($2 + $3 + $4 + $5 + $6) }'`
}
function format_wait {
        IO=$2
	IOPdisp=`echo $1 $2 | awk '{ printf("%.2f", $2 * 100 / $1) }'`
}
function sec2dhm {
        DAYS=$((SEC/86400))
        HOURS=$(((SEC/3600) - ($DAYS*24)))
        MINS=$(((SEC - (($DAYS*86400) + ($HOURS*3600)))/60))
        if [ "$DAYS" -eq "1" ]; then
                UP="1 day "
        elif [ "$DAYS" -gt "1" ]; then
                UP="$DAYS days "
        fi
        if [ "$HOURS" -eq "1" ]; then
                UP="${UP}1 hour "
        elif [ "$HOURS" -gt "1" ]; then
                UP="${UP}${HOURS} hours "
        fi
        if [ "$MINS" -eq "1" ]; then
                UP="${UP}1 minute"
        elif [ "$MINS" -gt "1" ]; then
                UP="${UP}$MINS minutes"
        fi
}
#
# Uptime & load
#
SEC=`echo "$UPTIME" | awk '{ print $1 }' | awk 'BEGIN { FS="." } { print $1 }'`
sec2dhm
LOAD=`echo "$LOADAVG" | awk '{ print $1" "$2" "$3 }'`
#
# Memory
#
if [ "$MEMTYPE" -eq "1" ]; then
	PRIVBAR=$((`echo "$BEAN" | grep privvm | awk '{ print $4 }'`/ 256))
	PRIVCUR=`echo "$BEAN" | grep privvm | awk '{ printf("%.0f", $2 / 256) }'`
	PRIVFAI=`echo "$BEAN" | grep privvm | awk '{ print $6 }'`
	PRIVCURPER=`echo $PRIVBAR $PRIVCUR | awk '{ printf("%.0f", $2 * 100 / $1) }'`
	APPBAR=$((`echo "$BEAN" | grep vmguar | awk '{ print $4 }'`/ 256))
	APPCUR=`echo "$BEAN" | grep oomguar | awk '{ printf("%.0f", $2 / 256) }'`
	APPFAI=`echo "$BEAN" | grep oomguar | awk '{ print $6 }'`
	APPCURPER=`echo $APPBAR $APPCUR | awk '{ printf("%.0f", $2 * 100 / $1) }'`
	if [ "$PRIVFAI" -gt "0" ]; then
		PRIVFAI="[${PRIVFAI}]"
	else
		PRIVFAI=''
	fi
	if [ "$APPFAI" -gt "0" ]; then
		APPFAI="[${APPFAI}]"
	else
		APPFAI=''
	fi
	SWAPPED=`echo "$BEAN" | awk '$1 ~ /^physpages$/ { phys=$2 } $1 ~ /^oomguarpages$/ { oomguar=$2 } END { printf "%.0f", (oomguar - phys) / 256 }'`
	PLEN=%$((${#PRIVCUR}))s
	PRIVCUR=`printf "$PLEN" $PRIVCUR`
	APPCUR=`printf "$PLEN" $APPCUR`
	SWAPPED=`printf "$PLEN" $SWAPPED`
	MEMORY=`echo -e "Privvmpages  : $PRIVCUR / $PRIVBAR M (${PRIVCURPER}%) $PRIVFAI \nOomguarpages : $APPCUR / $APPBAR M (${APPCURPER}%) $APPFAI\nSwapped      : $SWAPPED M"`
else
	MEMITEMS=('MemTotal' 'MemFree' 'Buffers' 'Cached' 'SwapTotal' 'SwapFree')
	for ITEM in ${MEMITEMS[@]}; do
		VAL=`echo "$MEMINFO" | grep "^${ITEM}:" | awk '{ print $2 }'`
		if [ -n "$VAL" ]; then
			let $ITEM=$VAL
		else
			let $ITEM=0
		fi
	done
	let APPS=$((MemTotal - $MemFree - $Buffers - $Cached))
	APPS_PER=$((APPS * 100 / $MemTotal))
	APPS=`printf '%4s' $((APPS / 1024))`
	let BC=$((Buffers + $Cached))
	BC_PER=$((BC * 100 / $MemTotal))
	BC=`printf '%4s' $((BC / 1024))`
	let FREE1=$((MemFree))
	FREE1_PER=$((FREE1 * 100 / $MemTotal))
	FREE1=`printf '%4s' $((FREE1 / 1024))`
	let FREE2=$((MemFree + $Buffers + $Cached))
	FREE2_PER=$((FREE2 * 100 / $MemTotal))
	FREE2=`printf '%4s' $((FREE2 / 1024))`
	if [ "$SwapTotal" -gt "0" ]; then
		let SWAP=$((SwapTotal - $SwapFree))
		SWAP_PER=$((SWAP * 100 / $SwapTotal))
	else
		SWAP=0
		SWAP_PER=0
	fi
	SWAP=`printf '%4s' $((SWAP / 1024))`
	MEMORY=`echo -e "Applications : $APPS MB (${APPS_PER}%)\nB/C          : $BC MB (${BC_PER}%)\nFree         : $FREE1 MB (${FREE1_PER}%)\nFree (-B/C)  : $FREE2 MB (${FREE2_PER}%)\nSwapped      : $SWAP MB (${SWAP_PER}%)"`
fi
#
# Disk
#
i=0
for DEV in ${DISKMNT[@]}; do
	DISKARR=(`echo "$DISKUSE" | grep -m1 " ${DEV}$" | awk '{ print $2" "$3" "$4" "$5 }'`)
	# if the df output is line-wrapped (because of a long filesystem name)
	# then the items are off by one. Check for a % symbol at the end...
	if [[ ! ${DISKARR[3]} == *% ]]; then
		DISKARR=(`echo "$DISKUSE" | grep -m1 " ${DEV}$" | awk '{ print $1" "$2" "$3" "$4 }'`)
	fi
	for ITEM in ${DISKARR[@]}; do
		DISK="${DISK}`printf "%-7s" $ITEM`"
	done
	DISKLBL=`printf "%-10s" ${DISKNAME[$i]}`
	if [ -n "$DISKS" ]; then
		DISKS="${DISKS}\n$DISKLBL ${DISK}"
	else
		DISKS="$DISKLBL $DISK"
	fi
	unset DISK
	i=$((i+1))
done
DISKS=`echo -e "FS         Size   Used   Avail  Use%\n$DISKS"`
#
# IO Wait
#
if [ -f "${DATADIR}/cpu" ]; then
        /bin/cp -af ${DATADIR}/cpu ${DATADIR}/cpu.prev
fi
echo $STAT > $DATADIR/cpu
calc_wait
format_wait $TTL $IO
IOP_BOOT=`printf "%5s" $IOPdisp`"%"
if [ -f "${DATADIR}/cpu.prev" ]; then
	TTL_1=$TTL
	IO_1=$IO
	STAT=`cat ${DATADIR}/cpu.prev`
	calc_wait
	TTL_DUR=`awk -v e1="$TTL_1" -v e2="$TTL" 'BEGIN {print e1-e2}'`
	IO_DUR=$(($IO_1-$IO))
	if [ "$TTL_DUR" -gt "0" ]; then
		format_wait $TTL_DUR $IO_DUR
	else
		IOPdisp="0.00"
	fi
	IOP_INT=`printf "%5s" $IOPdisp`"%"
else
	IOP_INT="-"
fi
IOLBL="Last $INTERVAL mins :"
if [ "$INTERVAL" -lt "10" ]; then
	IOLBL="Last $INTERVAL mins  :"
fi
IOWAIT=`echo -e "Since boot   : ${IOP_BOOT}\n$IOLBL ${IOP_INT} "`
#
# Transfer
#
if [ -e "$REPORT" ]; then
        LASTRUN=`stat -c %Y $REPORT`
        ELAPSED=$((START-$LASTRUN))
fi
DATARAW=(`cat /proc/net/dev | grep $IFACE | sed "s/${IFACE}://" | awk '{ print $1" "$9 }'`)
RECVD=${DATARAW[0]}
TRANS=${DATARAW[1]}
RECVD_DIFF=0
TRANS_DIFF=0
if [ -e "${DATADIR}/txlast" ]; then
	TRANS_LAST=`cat ${DATADIR}/txlast`
fi
if [ -e "${DATADIR}/rxlast" ]; then
	RECVD_LAST=`cat ${DATADIR}/rxlast`
fi
if [[ -n "$TRANS_LAST" && -n "$ELAPSED" ]]; then
	TRANS_DIFF=$(((TRANS-$TRANS_LAST) / 1024))
	if [ "$TRANS_DIFF" -lt "0" ]; then
		TRANS_DIFF=$(((4294967296+TRANS-$TRANS_LAST) / 1024))
	fi
	TX_UNITS=KB
	if [ "$TRANS_DIFF" -gt "9999" ]; then
		TX=$((TRANS_DIFF / 1024))
		TX_UNITS=MB
	else
		TX=$TRANS_DIFF
	fi
fi
if [[ -n "$RECVD_LAST" && -n "$ELAPSED" ]]; then
	RECVD_DIFF=$(((RECVD-$RECVD_LAST) / 1024))
	if [ "$RECVD_DIFF" -lt "0" ]; then
		RECVD_DIFF=$(((4294967296+RECVD-$RCVD_LAST) / 1024))
	fi
	RX_UNITS=KB
	if [ "$RECVD_DIFF" -gt "9999" ]; then
		RX=$((RECVD_DIFF / 1024))
		RX_UNITS=MB
	else
		RX=$RECVD_DIFF
	fi
fi
PLEN=%$((${#TRANS_DIFF}))s
if [ "$RECVD_DIFF" -gt "$TRANS_DIFF" ]; then
	PLEN=%$((${#RECVD_DIFF}))s
fi
TX=`printf "$PLEN" $TX`
RX=`printf "$PLEN" $RX`
echo $RECVD > ${DATADIR}/rxlast
echo $TRANS > ${DATADIR}/txlast
#
#
FINISH=`date +%s`
ELSEC=$((FINISH-$START))
if [ "$ELSEC" -lt "1" ]; then
        RUNTIME="Runtime: &lt;1 sec."
elif [ "$ELSEC" -eq "1" ]; then
        RUNTIME="Runtime: 1 sec."
else
        RUNTIME="Runtime: $ELSEC secs."
fi
cat > $REPORT <<END
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<META HTTP-EQUIV="refresh" CONTENT="120">
<head>
<meta http-equiv="content-type" content="text/html; charset=ISO-8859-1">
<meta name="viewport" content="width=device-width; initial-scale=1.0;">
<title>$PGTITLE</title>
<style type='text/css'> 
body { margin: 0; padding: 0; text-align: center; font-family: sans-serif; background-color: #1E4561; color: #CCC }
.box { width: 400px; margin: 50px auto 0 auto; padding: 18px 10px 15px 25px; text-align: left; box-shadow: 0px 16px 20px -16px #000; border-radius: 5px; background-color: #F6F6F6; color: #202020 }
h1, h2 { margin: 0; padding: 0 }
h1 { font-size: 19px }
h2, .repdate { font-size: 14px }
.repdate { margin: 5px 0 15px 0 }
pre { font-family: monospace; font-size: 13px; margin: 5px 0 7px 35px; padding: 0; line-height: 17px }
.footer { text-align: center; font-size: 11px; margin-top: 15px; line-height: 15px }
@media only screen and (max-width: 480px) {
body { background-color: #F6F6F6; color: #202020 }
.box { width: auto; margin: 0; padding: 0; border: none; border-radius: 0; box-shadow: none; overflow: hidden; background-color: inherit; color: inherit }
h1 { font-size: 17px; margin-top: 15px }
.repdate { font-size: 13px }
h1, .repdate, h2 { margin-left: 10px }
pre { font-size: 12px; margin-left: 20px }
.footer { text-align: left; border-top: 1px solid #999; margin: 10px; padding: 10px }
}
</style>
</head>
<body>
<div class='box'>
<h1>$PGTITLE</h1>
<div class='repdate'>$REPDATE</div>
<h2>Uptime</h2>
<pre>$UP</pre>
<h2>Load</h2>
<pre>$LOAD</pre>
<h2>Memory</h2>
<pre>$MEMORY</pre>
<h2>Disk</h2>
<pre>$DISKS</pre>
<h2>IO Wait</h2>
<pre>$IOWAIT</pre>
<h2>Transfer (last $INTERVAL mins)</h2>
<pre>Transmit     :  $TX $TX_UNITS
Receive      :  $RX $RX_UNITS</pre>
</div>
<div class='footer'>$RUNTIME<br>Regenerated every $INTERVAL minutes.</div>
</body>
</html>
END
exit 0
# end
