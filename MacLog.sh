#!/bin/bash
RedBold="\033[1;31m"
NoFormat="\033[0m"
GreenBold="\033[1;32m"
Bold="\033[1m"

if [ $EUID != 0 ]; 
    then
        echo -e "$RedBold This Script requires elevated privileges $NoFormat"
        sudo "$0" "$@"
        exit $?
    else
    :
fi

#Find out how far back we want to go for logging

echo
echo -e "$GreenBold This script will gather Ivanti Agent Logging from the Apple Unified Logging Database"
echo
sleep 1
echo -e " How many hours should we look back for logs? $NoFormat"
echo

read time

#Gather Logging from the Unified Logging System according to requested timeframe and pipe it to file

echo
echo -e "$Bold Gathering... $NoFormat"
echo

log show --predicate 'processImagePath contains "LANDesk"' --debug --info --last "${time}h" > "/Library/Application Support/LANDesk/Unfiltered.log"
Unfiltered="/Library/Application Support/LANDesk/Unfiltered.log"

echo -e "$GreenBold Enter one of the Following Components to filter (CASE SENSITVE): $NoFormat
     $Bold
     Patch
     Software Distribution
     Remote Control
     Antivirus
     Provisioning
     Profiles
     Inventory
     All Components
     $NoFormat"
         
read varname
echo

#Ask the user if they want ProxyHost Traffic as well for Web Traffic Logging
echo -e "$GreenBold Should we Filter out ProxyHost Logging too? (Web Traffic to and from Core) (y/n) $NoFormat"
echo
read proxyname
echo

TEMP_FILE="/Library/Application Support/LANDesk/TEMP.log"
input="/Library/Application Support/LANDesk/Unfiltered.log"
TotalCount=$(wc -l < "/Library/Application Support/LANDesk/Unfiltered.log")

#This loop will strip out the component logging that we care about based on the user response
while read line; do
    counter=$((counter +1))
    PercentageDone=$((100*counter/TotalCount))
    echo -ne "$Bold Filtering out $varname Logs...$PercentageDone%"\\r
        
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
                if [[ $line =~ "deferring to MDM to manage profiles" ]];
                    then
                        #If we're looking at profiles and MDM is enrolled, we'll break the loop here and get MDM logging instead
                        echo -e "$GreenBold It looks like this device is enrolled in MDM, which handles profile installation. We'll get logs from MDM as well $NoFormat"
                        MDMEnrolled=y
                        sleep 3
                        break
                else
                    :
                fi
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

#If we're looking at Profile logging and found that MDM was enrolled, we have to get some different logging and append it to the TEMP Log
if [[ $MDMEnrolled = "y" ]];
    then
        echo
        echo -e "$GreenBold Getting MDM Logs...$NoFormat"
        log show --predicate 'processImagePath contains "mdm"' --debug --info --last "${time}h" >> "/Library/Application Support/LANDesk/TEMP.log"
    else
    :
fi

echo
echo -e "$GreenBold Finished Filtering $varname Logs $NoFormat"
echo
sleep 1

#Check what the user said to getting ProxyHost
if [[ $proxyname = "y" ]];
    then
        input="/Library/Application Support/LANDesk/Unfiltered.log"
        PROXY_FILE="/Library/Application Support/LANDesk/proxyhosttemp.log"
        while read line; do
            counter3=$((counter3 +1))
            PercentageDone=$((100*counter3/TotalCount))
            echo -ne "$Bold Filtering Proxyhost Logs...$PercentageDone%"\\r
                if [[ $line =~ proxyhost ]];
                    then 
                        echo $line >> "$PROXY_FILE"
                        else 
                        :
                fi
        done <"$input"
        echo
        echo -e "$GreenBold Finished Filtering ProxyHost Logs $NoFormat"
        sleep 2
        echo
    else
        echo
        sleep 1
fi

#This loop will strip out "superflous" stuff we don't need from the Component log, but only if it exists.
if [ -f "$TEMP_FILE" ];
    then
        input="$TEMP_FILE"
        FINAL_OUTPUT="/Library/Application Support/LANDesk/$varname.log"
        TotalCount=$(wc -l < "/Library/Application Support/LANDesk/TEMP.log")

        while read line; do
        counter2=$((counter2 +1))
        PercentageDone=$((100*counter2/TotalCount))
        echo -ne " Cleaning $varname Log...$PercentageDone%"\\r
            if [[ $line =~ libnetwork.dylib ]] || [[ $line =~ CFNetwork ]] || [[ $line =~ com.apple.network ]] || [[ $line =~ libsystem_info.dylib ]] || [[ $line =~ CoreFoundation ]] || [[ $line =~ CFOpenDirecotry ]] || [[ $line =~ userclean.xml ]];
            then
                :
            else
            echo $line >> "$FINAL_OUTPUT"
            fi
    done < "$input"
    echo
    echo -e "$GreenBold Done Cleaning $varname Log $NoFormat"
    echo
    sleep 2
else
    :
fi

echo 

#This loop will strip out "superflous" stuff we don't need from the ProxyHost Log (If the User said Yes)
if [ $proxyname = "y" ] && [ -f "$TEMP_FILE" ];
    then
        input="$PROXY_FILE"
        FINAL_PROXY="/Library/Application Support/LANDesk/ProxyHost.log"
        TotalCount=$(wc -l < "/Library/Application Support/LANDesk/proxyhosttemp.log")      
        while read line; do
            counter4=$((counter4 +1))
            PercentageDone=$((100*counter4/TotalCount))
            echo -ne " Cleaning ProxyHost Log...$PercentageDone%"\\r
                if [[ $line =~ libnetwork.dylib ]] || [[ $line =~ CFNetwork ]] || [[ $line =~ com.apple.network ]] || [[ $line =~ libsystem_info.dylib ]] || [[ $line =~ CoreFoundation ]] || [[ $line =~ userclean.xml ]];
                then
                    :
                else
                echo $line >> "$FINAL_PROXY"
                fi
        done < "$input"
        rm "/Library/Application Support/LANDesk/proxyhosttemp.log"
        echo
        echo -e "$GreenBold Done Cleaning ProxyHost Log $NoFormat"
        echo
        sleep 2
    else
        :
fi

if [ -f "$FINAL_OUTPUT" ]; #check if the final log actually exists. There may have been no logging that fit the criteria
    then
        if [[ $proxyname = "y" ]]; #do this if the user said "yes" to ProxyHost
          then
            cp "$FINAL_OUTPUT" ~/Desktop #Copy file to Desktop to grab easily
            cp "$FINAL_PROXY" ~/Desktop
            cp "/Library/Application Support/LANDesk/Unfiltered.log" ~/Desktop #Copy original unfiltered log in case comparison is needed
            echo -e "$GreenBold All Done - The requested log files "$varname.log," proxyhost.log, and the Unfiltered.log are on the Desktop $NoFormat"
            
            rm "$TEMP_FILE" #Delete the other files created since we have to append stuff and we don't want the same logging over again
            rm "$FINAL_OUTPUT"
            rm "$PROXY_FILE"
            rm "$FINAL_PROXY"
        elif [[ $proxyname = "n" ]]; #do this if the user said "no" to ProxyHost
          then
            cp "$FINAL_OUTPUT" ~/Desktop #Copy file to Desktop to grab easily
            cp "/Library/Application Support/LANDesk/Unfiltered.log" ~/Desktop #Copy original unfiltered log in case comparison is needed
            echo -e "$GreenBold All Done - The requested log files "$varname.log" as well as the Unfiltered.log are on the Desktop $NoFormat"
            rm "$TEMP_FILE" #Delete the other files created since we have to append stuff and we don't want the same logging over again
            rm "$FINAL_OUTPUT"
        fi
    else
        echo -e "$RedBold Looks like there wasn't anything in there for $varname. No Logs were Generated. $NoFormat"
fi

#Clean up some stuff if it still exists somehow. Be quiet about it. 
rm -f "$Unfiltered"

rm -f "$PROXY_FILE"
