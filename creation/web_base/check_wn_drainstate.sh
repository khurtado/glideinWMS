#!/bin/bash
#
# Project:
#   glideinWMS
#
# Description:
#   Script to be periodically executed to check if the WN
#   is in draining mode.
#
#   The script implements one of the use case forseen by the
#   WLCG Machine / Job Features Task Force :
#   https://twiki.cern.ch/twiki/bin/view/LCG/MachineJobFeatures
#
#   The script check the existance of the shutdowntime_job file
#   in the $JOBFEATURES directory (or shutdowntime in $MACHINEFEATURES).
#   If one of the files is present then
#   a shutdown is scheduled and the script will output
#   "SiteWMS_WN_Draining = True" so the pilot will stop accepting jobs.
#   $JOBFEATURES/shutdowntime_job ($MACHINEFEATURES/shutdowntime) could also
#   be a URL that the script tries to download.
#   The script also checks the shutdown time contaned in the file and if
#   less than 30 minutes are left before it, then it will preempt the job
#   by setting SiteWMS_WN_Preempt
#   If one of the two files contains a non numeric value the script will exit
#   leaving everything untouched (it considers this an error)
#   More details about this:
#   https://twiki.cern.ch/twiki/bin/view/LCG/WMTEGEnvironmentVariables
#

function getValueFromFileOrURL {
    # The function takes as an argument a filename and a variable name
    # The variable containsthe url or the directory location of the file,
    # so $1 can be shutdowntime_job
    # and $2 /path/to/jobfeature/dir
    # The function returns the value found in the file (by cat-ing it), or false
    # if the file does not exist or $2 is empty
    FILENAME="$1"
    VARNAME="$2"
    if [ -n "$VARNAME" ]; then
        if [ -f "$VARNAME/$FILENAME" ]; then
            cat "$VARNAME/$FILENAME"
            return
        else
            #check if shutdowntime job is a URL and wget it
            ADDRESS="$VARNAME/$FILENAME"
            echo $ADDRESS | grep -E '^https?' > /dev/null
            if [ $? -eq 0 ]; then
                #use quiet mode and redirect file to a temporary one
                wget -qO- $ADDRESS > tmp_MJF
                if [ $? -eq 0 ]; then
                    cat tmp_MJF
                    return
                fi
            fi
        fi
    fi
    echo false
}

function isNumberOrFalse {
    # the function verifies that the argument (i.e.: $1) is a number, and exts otherwise
    # printing a message to stderr
    echo $1 | grep -Eq '(^\-?[0-9]+$)|(^false$)'
    if [ $? -eq 1 ]; then
        echo "JOBFEATURES ($JOBFEATURES) or MACHINEFEATURES ($MACHINEFEATURES) variable found, but shutdown file NOT containing a number (contains '$1' instead)" >&2
        exit 1
    fi
}

J=$(getValueFromFileOrURL shutdowntime_job "$JOBFEATURES")
isNumberOrFalse $J
M=$(getValueFromFileOrURL shutdowntime "$MACHINEFEATURES")
isNumberOrFalse $M

EXIT_MESSAGE_FILE=$start_dir/exit_message
if [ "$J" != false ] || [ "$M" != false ] ; then
    echo "SiteWMS_WN_Draining = True"
    if [ ! -f $EXIT_MESSAGE_FILE ] ; then
        echo "Stopping accepting jobs since site admins are going to shut down the node. Time is `date`" >> $EXIT_MESSAGE_FILE
    fi
    CURR_TIME=$(date +%s)
    if ( [ "$J" != false ] && [ $((J - CURR_TIME)) -lt 1800 ] ) || ( [ "$M" != false ] && [ $((M - CURR_TIME)) -lt 1800 ] ); then
        echo "Preempting user job since less then 1800 seconds are left before machine shutdown. Time is `date`" >> $EXIT_MESSAGE_FILE
        echo "SiteWMS_WN_Preempt = True"
    fi
else
    if [ -f $EXIT_MESSAGE_FILE ] ; then
        echo "Aborting shutdown of pilot. New jobs will be accepted. Time is `date`" >> $EXIT_MESSAGE_FILE
        #shutdown can be aborted. Do not print in the logs
        rm $EXIT_MESSAGE_FILE
    fi
    echo "SiteWMS_WN_Draining = False"
    echo "SiteWMS_WN_Preempt = False"
fi

exit 0
