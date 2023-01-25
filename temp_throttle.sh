#!/bin/bash

# Usage: temp_throttle.sh max_temp
# USE CELSIUS TEMPERATURES.
# version 2.21

cat << EOF
Author: Sepero 2016 (sepero 111 @ gmx . com)
URL: http://github.com/Sepero/temp-throttle/

EOF

# Additional Links
# http://seperohacker.blogspot.com/2012/10/linux-keep-your-cpu-cool-with-frequency.html

# Additional Credits
# Wolfgang Ocker <weo AT weo1 DOT de> - Patch for unspecified cpu frequencies.

# Additional Credits
# ps1code <ps1code@outlook.com> - Patch for checking all cores for max 
				  temperature instead of the first three.
# ps1code <ps1code@outlook.com> - New feature, can now use lm-sensors (tested on v3.06)
#				  to get cpu temperature
# License: GNU GPL 2.0

# Generic  function for printing an error and exiting.
err_exit () {
	echo ""
	echo "Error: $@" 1>&2
	exit 128
}

if [ $# -lt 1 ]; then
	# If temperature wasn't given, then print a message and exit.
	echo "Please supply a maximum desired temperature in Celsius." 1>&2
	echo "For example:  ${0} 60" 1>&2
	echo "You can add second argument to grab cpu temperature from lm-sensors instead." 1>&2
	echo "For example: ${0} 60 lm-sensors" 1>&2
	exit 2
else
	#Set the first argument as the maximum desired temperature.
	MAX_TEMP=$1
	LM_SENSORS=$2
	echo "Using Parameters: $MAX_TEMP $LM_SENSORS" 1>&2
fi


### START Initialize Global variables.

# The frequency will increase when low temperature is reached.
LOW_TEMP=$((MAX_TEMP - 5))

CORES=$(nproc) # Get number of CPU cores.
echo -e "Number of CPU cores detected: $CORES\n"
CORES=$((CORES - 1)) # Subtract 1 from $CORES for easier counting later.

# Temperatures internally are calculated to the thousandth.
MAX_TEMP=${MAX_TEMP}000
LOW_TEMP=${LOW_TEMP}000

if [ "$LM_SENSORS" == "lm-sensors" ]; then
	LM_SENSORS=true
	if ! sensors > /dev/null; then
		err_exit "lm-sensors not installed or sensors not in PATH." 
	fi
	echo "Using lm-sensors" 1>&2
else
	LM_SENSORS=false
fi

FREQ_FILE="/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies"
FREQ_MIN="/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq"
FREQ_MAX="/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq"

# Store available cpu frequencies in a space separated string FREQ_LIST.
if [ -f $FREQ_FILE ]; then
	# If $FREQ_FILE exists, get frequencies from it.
	FREQ_LIST=$(cat $FREQ_FILE | xargs -n1 | sort -g -r | xargs) || err_exit "Could not read available cpu frequencies from file $FREQ_FILE"
elif [ -f $FREQ_MIN -a -f $FREQ_MAX ]; then
	# Else if $FREQ_MIN and $FREQ_MAX exist, generate a list of frequencies between them.
	FREQ_LIST=$(seq $(cat $FREQ_MAX) -100000 $(cat $FREQ_MIN)) || err_exit "Could not compute available cpu frequencies"
else
	err_exit "Could not determine available cpu frequencies"
fi

FREQ_LIST_LEN=$(echo $FREQ_LIST | wc -w)

# CURRENT_FREQ will save the index of the currently used frequency in FREQ_LIST.
CURRENT_FREQ=2

# Get all files that stores temperature information for all cores.
START=0
for (( c=$START; c<$CORES; c++ )) 
do
	# Possible locations to read the current system temperature.
	TF=${TF}"/sys/class/thermal/thermal_zone${c}/temp "
	TF=${TF}"/sys/class/hwmon/hwmon${c}/temp1_input "
	TF=${TF}"/sys/class/hwmon/hwmon${c}/device/temp1_input "
done

TEMPERATURE_FILES=${TF}

# Store the first temperature location that exists in the variable TEMP_FILE.
# The location stored in $TEMP_FILE will be used for temperature readings.
for file in $TEMPERATURE_FILES; do
	TEMP_FILE=$file
	[ -f $TEMP_FILE ] && break
done

[ $TEMP_FILE == "null" ] && err_exit "The location for temperature reading was not found."

### END Initialize Global variables.


### START define script functions.

# Set the maximum frequency for all cpu cores.
set_freq () {
	# From the string FREQ_LIST, we choose the item at index CURRENT_FREQ.
	FREQ_TO_SET=$(echo $FREQ_LIST | cut -d " " -f $CURRENT_FREQ)
	echo $FREQ_TO_SET
	for i in $(seq 0 $CORES); do
		# Try to set core frequency by writing to /sys/devices.
		{ echo $FREQ_TO_SET 2> /dev/null > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq; } ||
		# Else, try to set core frequency using command cpufreq-set.
		{ cpufreq-set -c $i --max $FREQ_TO_SET > /dev/null; } ||
		# Else, return error message.
		{ err_exit "Failed to set frequency CPU core$i. Run script as Root user. Some systems may require to install the package cpufrequtils."; }
	done
}

# Will reduce the frequency of cpus if possible.
throttle () {
	if [ $CURRENT_FREQ -lt $FREQ_LIST_LEN ]; then
		CURRENT_FREQ=$((CURRENT_FREQ + 1))
		echo -n "throttle "
		set_freq $CURRENT_FREQ
	fi
}

# Will increase the frequency of cpus if possible.
unthrottle () {
	if [ $CURRENT_FREQ -ne 1 ]; then
		CURRENT_FREQ=$((CURRENT_FREQ - 1))
		echo -n "unthrottle "
		set_freq $CURRENT_FREQ
	fi
}

get_temp () {
	# Get the system temperature. Take the max of all counters
	if [ "$LM_SENSORS" == "true" ]; then
		TEMP=$(sensors | grep -A 0 'CPU T' | cut -d' ' -f 6 | sed 's/+//' | sed 's/°C//')
		TEMP=$(echo "$TEMP/1" | bc)000
	else
		TEMP=$(cat $TEMPERATURE_FILES 2>/dev/null | xargs -n1 | sort -g -r | head -1)
	fi
	echo  "Current Temp: $TEMP"
}

### END define script functions.

echo "Initialize to max CPU frequency"
unthrottle


# Main loop
while true; do
	get_temp # Gets the current temperature and set it to the variable TEMP.
	if   [ $TEMP -gt $MAX_TEMP ]; then # Throttle if too hot.
		throttle
	elif [ $TEMP -le $LOW_TEMP ]; then # Unthrottle if cool.
		unthrottle
	fi
	sleep 3 # The amount of time between checking temperatures.
done
