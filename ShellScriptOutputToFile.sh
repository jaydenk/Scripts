#!/bin/bash

# Sets the current date and time to a variable
currentDate="date +%Y-%m-%d_%H:%M"
eval $currentDate

# Creates the output file with the date and time prepended to it
targetFile=$(eval $currentDate)"-<<PROGRAM NAME>>.log"

# file descriptor 4 prints to STDOUT and to TARGET
exec 4> >(while read a; do echo $a; echo $a >>$targetFile; done)
# file descriptor 5 remembers STDOUT
exec 5>&1

# redirect STDOUT
exec >&4

# Insert the body of what you want to have happen here


exec >&5
echo "loop output sent to fd4"
