#!/bin/bash

if [ $EUID != 0 ]; then
    echo This Script requires elevated privileges
    sudo "$0" "$@"
    exit $?
fi

#Find out how far back we want to go for logging

echo This script will gather Ivanti Agent Logging from the Apple Unified Logging Database

echo How many hours should we look back for logs?

read varname

#Gather Logging from the Unified Logging System according to requested timeframe and pipe it to file

echo Gathering...

log show --predicate 'processImagePath contains "LANDesk"' --debug --info --last "${varname}h" > "/Library/Application Support/LANDesk/Unfiltered.log"

echo "Enter one of the Following Components to filter (CASE SENSITVE):
     Patch
     Software Distribution
     Remote Control
     Antivirus
     Provisioning
     Profiles
     Inventory
     All Components"
         
read varname

TEMP_FILE="/Library/Application Support/LANDesk/TEMP.log"
input="/Library/Application Support/LANDesk/Unfiltered.log"
TotalCount=$(wc -l < "/Library/Application Support/LANDesk/Unfiltered.log")

#This loop will strip out the component logging that we care about based on the user response
while read line; do
    counter=$((counter +1))
    PercentageDone=$((100*counter/TotalCount))
    echo -ne " Filtering...$PercentageDone%"\\r
        
        if [[ $varname = "Patch" ]];
        then
            if [[ $line =~ vulscan ]] || [[ $line =~ ldpsoftwaredist ]] || [[ $line =~ ldvdetect ]] || [[ $line =~ sdclient ]] || [[ $line =~ stmacpatch ]] || [[ $line =~ ldscriptrunner ]] || [[ $line =~ ldtmc ]] || [[ $line =~ ldvpatch ]];
            then 
                echo $line >> "$TEMP_FILE"
            else 
                :
            fi
        elif [[ $varname = "Software Distribution" ]];
         then
            if [[ $line =~ sdclient ]] || [[ $line =~ ldswd ]] || [[ $line =~ ldapm ]] || [[ $line =~ sdclient ]] || [[ $line =~ ldtmc ]] || [[ $line =~ ldvdownload ]];
            then 
                echo $line >> "$TEMP_FILE"
            else 
                :
            fi
        elif [[ $varname = "Remote Control" ]];
         then
            if [[ $line =~ ivremotecontrol ]] || [[ $line =~ ldobserve ]] || [[ $line =~ ldremote ]] || [[ $line =~ ldremotelaunch ]] || [[ $line =~ ldremotemenu ]] || [[ $line =~ ldwatch ]] || [[ $line =~ ivremote ]];
            then 
                echo $line >> "$TEMP_FILE"
            else 
                :
            fi
        elif [[ $varname = "Antivirus" ]];
         then
            if [[ $line =~ IvantiAV ]] || [[ $line =~ ivantiavcontrol ]];
            then 
                echo $line >> "$TEMP_FILE"
            else 
                :
            fi
        elif [[ $varname = "Provisioning" ]];
         then
            if [[ $line =~ ldp ]];
            then 
                echo $line >> "$TEMP_FILE"
            else 
                :
            fi
        elif [[ $varname = "Profiles" ]];
         then
            if [[ $line =~ ldinstallprofile ]] || [[ $line =~ ldapm ]] || [[ $line =~ ldagentsettings ]];
            then 
                echo $line >> "$TEMP_FILE"
            else 
                :
            fi
        elif [[ $varname = "Inventory" ]];
         then
            if [[ $line =~ ldiscan ]];
            then 
                echo $line >> "$TEMP_FILE"
            else 
                :
            fi
        elif [[ $varname = "All Components" ]];
            then
            echo $line >> "$TEMP_FILE"
        else
            echo "That's not one of the options. Please rerun the Script."  
                exit
        fi
done < "$input"


echo "Finished filtering $varname logs"
echo
sleep 1

#Ask the user if they want ProxyHost Traffic as well for Web Traffic Logging
echo -e "Should we get ProxyHost Logging too? (Web Traffic to and from Core) (y/n)"

read proxyname

if [[ $proxyname = "y" ]];
    then
        input="/Library/Application Support/LANDesk/Unfiltered.log"
        PROXY_FILE="/Library/Application Support/LANDesk/proxyhosttemp.log"
        while read line; do
            counter3=$((counter3 +1))
            PercentageDone=$((100*counter3/TotalCount))
            echo -ne " Getting Proxyhost Traffic...$PercentageDone%"\\r
                if [[ $line =~ proxyhost ]];
                    then 
                        echo $line >> "$PROXY_FILE"
                        else 
                        :
                fi
        done <"$input"
    else
        echo OK
        sleep 1
fi

echo 
echo Done Filtering
sleep 2

#This loop will strip out "superflous" stuff we don't need from the Component log
input="$TEMP_FILE"
FINAL_OUTPUT="/Library/Application Support/LANDesk/$varname.log"
TotalCount=$(wc -l < "/Library/Application Support/LANDesk/TEMP.log")

while read line; do
    counter2=$((counter2 +1))
    PercentageDone=$((100*counter2/TotalCount))
    echo -ne " Cleaning $varname log...$PercentageDone%"\\r
        if [[ $line =~ libnetwork.dylib ]] || [[ $line =~ CFNetwork ]] || [[ $line =~ com.apple.network ]] || [[ $line =~ libsystem_info.dylib ]] || [[ $line =~ CoreFoundation ]] || [[ $line =~ userclean.xml ]];
        then
            :
        else
        echo $line >> "$FINAL_OUTPUT"
        fi
done < "$input"

echo 

#This loop will strip out "superflous" stuff we don't need from the ProxyHost Log (If the User said Yes)
if [[ $proxyname = "y" ]];
    then
        input="$PROXY_FILE"
        FINAL_PROXY="/Library/Application Support/LANDesk/ProxyHost.log"
        TotalCount=$(wc -l < "/Library/Application Support/LANDesk/proxyhosttemp.log")      
        while read line; do
            counter4=$((counter4 +1))
            PercentageDone=$((100*counter4/TotalCount))
            echo -ne " Cleaning ProxyHost log...$PercentageDone%"\\r
                if [[ $line =~ libnetwork.dylib ]] || [[ $line =~ CFNetwork ]] || [[ $line =~ com.apple.network ]] || [[ $line =~ libsystem_info.dylib ]] || [[ $line =~ CoreFoundation ]] || [[ $line =~ userclean.xml ]];
                then
                    :
                else
                echo $line >> "$FINAL_PROXY"
                fi
        done < "$input"
    else
        :
fi


echo
echo Done Cleaning
echo
sleep 2

if [ -f "$FINAL_OUTPUT" ]; #check if the final log actually exists. There may have been no logging that fit the criteria
    then
        if [[ $proxyname = "y" ]]; #do this if the user said "yes" to ProxyHost
          then
            cp "$FINAL_OUTPUT" ~/Desktop #Copy file to Desktop to grab easily
            cp "$FINAL_PROXY" ~/Desktop
            cp "/Library/Application Support/LANDesk/Unfiltered.log" ~/Desktop #Copy original unfiltered log in case comparison is needed
            echo "All Done - The requested log files "$varname.log," proxyhost.log, and the Unfiltered.log are on the Desktop"
            
            rm "$TEMP_FILE" #Delete the other files created since we have to append stuff and we don't want the same logging over again
            rm "$FINAL_OUTPUT"
            rm "$PROXY_FILE"
        elif [[ $proxyname = "n" ]]; #do this if the user said "no" to ProxyHost
          then
            cp "$FINAL_OUTPUT" ~/Desktop #Copy file to Desktop to grab easily
            cp "/Library/Application Support/LANDesk/Unfiltered.log" ~/Desktop #Copy original unfiltered log in case comparison is needed
            echo "All Done - The requested log files "$varname.log" as well as the Unfiltered.log are on the Desktop"
            rm "$TEMP_FILE" #Delete the other files created since we have to append stuff and we don't want the same logging over again
            rm "$FINAL_OUTPUT"
        fi
    else
        echo "No Log Generated - probably wasn't anything in there for $varname"
        rm "/Library/Application Support/LANDesk/Unfiltered.log"
            exit
fi
rm "/Library/Application Support/LANDesk/Unfiltered.log"






