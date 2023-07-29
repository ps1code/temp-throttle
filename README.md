temp-throttle
=============

Linux shell script for throttling system CPU frequency based on a desired maximum temperature (celsius).

Set a maximum temperature for your system using this script. If the maximum temperature is exceeded, the script will limit the speed of your CPU cores incrementally until the system is again below your desired maximum temperature. (If your system remains above maximum temperature after completely limiting your CPU cores, it will simply stay limited until temperatures drop below the maximum desired.)


This script must be run with root or sudo privileges. Only Celsius temperatures are supported. This example will limit system temperatures to 80 Celsius:

    sudo ./temp_throttle.sh 80


For more instructions, see here:  
http://seperohacker.blogspot.com/2012/10/linux-keep-your-cpu-cool-with-frequency.html


Author: Sepero (sepero 111 @ gmx . com)

Links: http://github.com/Sepero/temp-throttle/  
Links: http://seperohacker.blogspot.com/2012/10/linux-keep-your-cpu-cool-with-frequency.html  

License: GNU GPL 2.0

Usage: `temp_throttle.sh max_temp`  
USES CELSIUS TEMPERATURES 

Updates
=======

Author: ps1code (ps1code@outlook.com)

fix:  Existing problem of not using all cores to get max temperature. 

feat:  Now allows you to obtain cpu temperature from lm-sensors.

You can use an optional second comand line argument "lm-sensors" to read
temperature from lm-sensors.

	sudo ./temp_throttle.sh 80 lm-sensors

feat:  Once program is started, it is now possible to adjust max and 
       low cpu temperatures.  The low temperature value is used to determine
       when the system can start increasing cpu speed.  If the low
       temperature is equal or greater than the max it will be adjusted
       to low = (max - 5 degrees celsius).

       Note: cpu temperature is measured in millidegree celsius.
             so for example 55 degrees celsius would be 55000.

       Files to adjust temperatures:
            /tmp/temp_throttle/low_temp
            /tmp/temp_throttle/max_temp


#To install and use with systemd:


$ sudo cp temp_throttle.sh /usr/local/bin/

Modify temp_throttle.service to suit your situation.

$ sudo cp temp_throttle.service /etc/systemd/system

$ sudo systemctl enable temp_throttle

$ sudo systemctl start temp_throttle

To stop service:

$ sudo systemctl stop temp_throttle

To disable:

$ sudo systemctl disable temp_throttle
