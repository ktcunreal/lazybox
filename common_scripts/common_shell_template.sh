#!/usr/bin/env bash

#########################################
#### Simple Bash Script Template                     ####
#### Author: ktcunreal@gmail.com                  ####
#### 2020-05-12                                                         ####
#########################################


## Set Global Vars
IDENTIFIER="Script-Template-1.0"
PREDEFINED_VAR="0"
PREDEFINED_FLAG=0
PREDEFINED_ARR=("1: Tick" "2: Tok" "3: Tick" "4: Tok" "5: Tick" "6: Tok")
TMPDIR="./.tmp.`date +%Y%m%d%H%M%S`"


## Enable Strict Mode
set -ue


## Put your script below
function main() {
    print_highlight "Demo val is ${PREDEFINED_VAR}"
    print_highlight "Demo flag is ${PREDEFINED_FLAG}"
    for (( i=0;i<${#PREDEFINED_ARR[*]};i++ )); do
        print_format "${PREDEFINED_ARR[$i]}"
        sleep 1;
    done;
}

## Script usage
function usage() {
echo -n \
"$IDENTIFIER        [OPTION]...
    -h,             Display this message
    -a,             Demo value
    -f,             Demo flag
"
}


## Pre-run function
function pre_exec(){
    if [[ -e ${IDENTIFIER}.lock ]] ; then
        print_err "Found ${IDENTIFIER}.lock. Is this script already running?"
        exit 1;
    fi
    touch ${IDENTIFIER}.lock; 
    mkdir ${TMPDIR};
}


## Post-run function
function post_exec() {
    print_format "Exiting";
    if [[ -e ${IDENTIFIER}.lock ]] ; then
        rm -f "${IDENTIFIER}.lock";
    fi

    if [[ -d "${TMPDIR}" ]] ; then
        rm -rf "${TMPDIR}";
    fi
}


## Parse opts
function parse() {
OPTIONS="a:h:f"
while getopts ${OPTIONS} OPT; do
    case $OPT in
        h) 
            usage; 
            exit 0;
        ;;
        a) 
            PREDEFINED_VAR=$OPTARG;
        ;; 
        f)  
            PREDEFINED_FLAG=1;
        ;;
        *) 
            print_err "Invalid option: '$1'.";
            exit 1; 
        ;;
    esac
done
shift $((OPTIND-1))
return 0
}


## Color settings
function print_format() {
    echo "[`date +%Y-%m-%d' '%H:%M:%S`] $1";
}

function print_green() {
    echo -n "[`date +%Y-%m-%d' '%H:%M:%S`] `tput setaf 2; echo $1; tput setaf 9;`"; 
}

function print_highlight() {
    echo -n "[`date +%Y-%m-%d' '%H:%M:%S`] `tput setaf 3; echo $1; tput setaf 9;`"; 
}

function print_err(){
    echo -n "[`date +%Y-%m-%d' '%H:%M:%S`] `tput setaf 1; echo $1; tput setaf 9;`"; 
}


## Script entry
parse "$@"; if [[ $? = 0 ]]; then
     # Create tmpdir & lock
    pre_exec;
      
    # Capture Ctrl^C signal
    trap post_exec INT;

    # Script starts here
    print_green "Script started";
    main;
  
    # Clean up tmpdir
    post_exec;
    exit 0;
fi


###########################
#### set -x

###################################
#### Intereactive User Warning ####
###################################
#### read -p "Are you ready to do this? (y/n) " CONFIRM
#### if [[ "$CONFIRM" = "y" ]] || [[ "$CONFIRM" = "Y" ]]; then
####    ...
#### fi