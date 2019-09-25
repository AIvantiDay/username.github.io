#!/bin/bash
RedBold="\033[1;31m"
NoFormat="\033[0m"
GreenBold="\033[1;32m"
Bold="\033[1m"
BlueBold="\033[1;94m"
Invert="\033[7m"

if [ $EUID != 0 ]; 
    then
        echo -e "$RedBold This Script requires elevated privileges $NoFormat"
        sudo "$0" "$@"
        exit $?
    else
    :
fi

#This script will run through various Agent Logs and try to identify what is going wrong with the agent in a Particular Component Area
echo
echo -e "$GreenBold This script will take a look at Agent Activity and attempt to Provide some Diagnostic Information Feedback"
sleep 2
echo
echo -e "$GreenBold How long ago did the Task/Process fail? (In minutes 1,2,3 etc)$NoFormat"
echo
read Time
echo
echo -e "$GreenBold What Component are we Looking at? $RedBold(Enter the Corresponding Number)$NoFormat
     $Bold
     1) Patch
     2) Software Distribution
     3) Remote Control
     4) Antivirus
     5) Provisioning
     6) Profiles
     7) Inventory
     $NoFormat" 
     
read ComponentName

if [[ $ComponentName = 1 ]] || [[ $ComponentName = 2 ]] || [[ $ComponentName = 3 ]] || [[ $ComponentName = 4 ]] || [[ $ComponentName = 5 ]] || [[ $ComponentName = 6 ]] || [[ $ComponentName = 7 ]];
    then
        echo
        echo -e "$Bold Ok$NoFormat"
        sleep 2
    else
        echo -e "$RedBold That's not one of the options. Please rerun the script.$NoFormat"
        exit
fi


echo
echo -e "$Bold Gathering a Bunch of Data... $NoFormat"

#Get the "big" log from LANDesk Agent Logging
log show --predicate 'processImagePath contains "LANDesk"' --debug --info --last "${Time}m" > "/Library/Application Support/LANDesk/Big.log"
echo -e "$GreenBold      ...Done$NoFormat"
echo
sleep 2

#Read through the "Big" log and clean out some stuff we won't need (Will make functions quicker later)
input="/Library/Application Support/LANDesk/Big.log"
Cleaned="/Library/Application Support/LANDesk/Cleaned.log"
TotalCount=$(wc -l < "/Library/Application Support/LANDesk/Big.log")
    while read line; do
        counter2=$((counter2 +1))
        PercentageDone=$((100*counter2/TotalCount))
        echo -ne "$Bold Cleaning things up a bit...$PercentageDone%$NoFormat"\\r
            if [[ ($line =~ libnetwork.dylib || $line =~ CFNetwork ||  $line =~ com.apple.network  ||  $line =~ libsystem_info.dylib  ||  $line =~ CoreFoundation  ||  $line =~ CFOpenDirecotry  ||  $line =~ userclean.xml  ||  $line =~ IVMetrics.app || $line =~ LdCustomBanner || $line =~ LdCustomIcon) ]];
            then
                :
            else
            echo $line >> "$Cleaned"
            fi
    done < "$input"
    echo
    echo -e "$GreenBold     ...Finished Cleaning $NoFormat"
    echo
    sleep 2
    
#Where the work is being done based on user Response. Bunch of functions embedded within functions. 

Error=0 #We'll update this value if we find a problem in any of the arguments
DCheck=0
ICheck=0

function DownloadCheck(){ 
    
    input="/Library/Application Support/LANDesk/Cleaned.log"
    echo
    echo -e "$Bold Looks like some files failed to download. Looking at Download History..."
    echo
    sleep 2
    
    while read line; do
        if [[ $line =~ "ldvdownload" ]] && [[ ($line =~ "File Download:" || $line =~ "AddFileToDownloadSet") ]];
            then
                echo -e "$GreenBold   Download Attempted:$NoFormat" #indented 3 spaces
                echo -e "$Bold     Log found:$NoFormat $Invert$line$NoFormat" #indented 5 spaces
                echo  
        elif [[ $line =~ "sdclient:" ]] && [[ ($line =~ "GetPreferredServerList" && $line =~ "returned:") ]];
            then
                echo -e "$GreenBold   Download Attempted:$NoFormat" #indented 3 spaces
                echo -e "$Bold     Log found:$NoFormat $Invert$line$NoFormat" #indented 5 spaces
                echo 
        elif [[ $line =~ "sdclient:" ]] && [[ $line =~ "DOWNLOAD_ERROR_GENERAL_FAILURE" ]];
            then
                echo -e "$RedBold   It looks like a File Download failed. Likely the previous download listed.$NoFormat"
                echo -e "$RedBold     Log found:$NoFormat $Invert$line$NoFormat"
                echo
                Error=2
        elif [[ $line =~ "ldvdownload:" ]] && [[ $line =~ "FAILURE:" ]];
            then
                echo -e "$RedBold   It looks like this File Failed to Download:$NoFormat"
                echo -e "$RedBold     Log found:$NoFormat $Invert$line$NoFormat"
                echo
                Error=2
        elif [[ ($line =~ proxyhost: && $line =~ " 404 ") ]];
            then
                echo -e "$RedBold   File Download Failed - Not found at Source$NoFormat"
                echo -e "$RedBold     Log found:$NoFormat $Invert$line$NoFormat"
                echo
                Error=2
        fi
    done < "$input"
    }
    
function InstallCheck(){

    nput="/Library/Application Support/LANDesk/Cleaned.log"
        echo
        echo -e "$Bold Looks like a Package(s) tried to install. Looking at Install History..."
        echo
        sleep 2
    
    while read line; do
        if [[ $line =~ "Readying command line" ]];
            then
                echo -e "$GreenBold   Install Queued:$NoFormat" #indented 3 spaces
                echo -e "$Bold     Log found:$NoFormat $Invert$line$NoFormat" #indented 5 spaces
                echo 
        elif [[ $line =~ "sdclient:" ]] && [[ $line =~ "executed:" ]];
            then
                echo -e "$GreenBold   Install Executed with Status:$NoFormat"
                echo -e "$GreenBold     Log found:$NoFormat $Invert$line$NoFormat"
                echo
        elif [[ $line =~ "ldswd:" ]] && [[ $line =~ "installPackages failed:" ]];
            then
                echo -e "$RedBold   It looks like the Previously listed Install Failed:$NoFormat"
                echo -e "$RedBold     Log found:$NoFormat $Invert$line$NoFormat"
                echo
                Error=2
        fi
    done < "$input"
}

##############################################################

#Placeholder for each function executed by User. Will call functions defined above based on what's found. 

function Patch(){
    
    input="/Library/Application Support/LANDesk/Cleaned.log"
    sleep 2
    echo
    
    while read line; do
        if [[ ($line =~ proxyhost: && $line =~ " 404 ") && $DCheck == 0 ]];
            then
                DCheck=1 #Every Function needs to increment its variable check so we know if we've already run it before. 
                DownloadCheck  #Run the function for download failed defined above
        fi
    done < "$input"
    
    if [[ $Error == 2 ]]; #Since Every error found increments this value, we'll keep going back and trying again until we haven't found anything. 
        then
        Error=0 #Reset it back so we'll pass this next time if nothing is found. 
        echo
        echo -e "$Bold Looking for other $ComponentName Errors$NoFormat"
        echo
            Patch
    else
        :
    fi
    
}

function SoftwareDistribution() {
    input="/Library/Application Support/LANDesk/Cleaned.log"
    Sleep 2
    
    while read line; do
        if [[ ($line =~ proxyhost: && $line =~ " 404 ") && $DCheck == 0 ]];
            then
                DCheck=1 #Every Function needs to increment its variable check so we know if we've already run it before. 
                DownloadCheck   #Run the function for download failed defined above
        elif [[ ( $line =~ "install Packages failed:" && $ICheck == 0) ]];
            then
                ICheck=1
                InstallCheck
        fi
    done < "$input"
    
    if [[ $Error == 2 ]]; #Since Every error found increments this value, we'll keep going back and trying again until we haven't found anything. 
    then
    Error=0 #Reset it back so we'll pass this next time if nothing is found. 
    echo
    echo
        SoftwareDistribution
    else
        :
    fi
    
}

function RemoteControl() {
    input="/Library/Application Support/LANDesk/Cleaned.log"
    echo -e "$Bold Looking at Remote Control...$NoFormat"

}

function Antivirus() {
    input="/Library/Application Support/LANDesk/Cleaned.log"
    echo -e "$Bold Looking at Antivirus...$NoFormat"

}

function Provisioning() {
    input="/Library/Application Support/LANDesk/Cleaned.log"

}

function Profiles() {
    input="/Library/Application Support/LANDesk/Cleaned.log"
    sleep 2
    
    while read line; do
        if [[ $line =~ "Unable to resolve profile with the core" ]];
            then
                echo -e "$RedBold   It looks like the Agent can't Decrypt the Profile with the Core Server using its Certificate. Is this Agent's Certificate Approved?$NoFormat"
                echo
                echo -e "$RedBold   Log found:$NoFormat $Invert$line$NoFormat"
                Error=2
                exit
                
        fi
    done < "$input"
}

function Inventory() {
    input="/Library/Application Support/LANDesk/Cleaned.log"
    echo -e "$GreenBold Looking at Inventory...$NoFormat"

}

##############################################################

#Check user Response and execute corresponding Function

if [[ $ComponentName = "1" ]];
    then
        ComponentName=Patch
        echo -e "$Bold Looking at $ComponentName...$NoFormat"
        Patch
        
elif [[ $ComponentName = "2" ]];
    then
        ComponentName="Software Distribution"
        echo -e "$Bold Looking at $ComponentName...$NoFormat"
        SoftwareDistribution
        
elif [[ $ComponentName = "3" ]];
    then
        RemoteControl
        
elif [[ $ComponentName = "4" ]];
    then
        Antivirus
        
elif [[ $ComponentName = "5" ]];
    then
        echo -e "$Bold Looking at Provisioning...$NoFormat"
        Provisioning
        
elif [[ $ComponentName = "6" ]];
    then
        echo -e "$Bold Looking at Profiles...$NoFormat"
        Profiles
        
elif [[ $ComponentName = "7" ]];
    then
        Inventory
fi

#Let the user know if we didn't find anything
if [[ $Error = 0 ]];
    then   
        echo -e "$Bold Didn't find any (more) known errors in $ComponentName.$NoFormat"
        echo
fi

rm -f "/Library/Application Support/LANDesk/Big.log"
rm -f "/Library/Application Support/LANDesk/Cleaned.log"
