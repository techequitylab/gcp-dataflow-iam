#!/bin/bash
# 
# Copyright 2019 Shiyghan Navti. Email shiyghan@gmail.com
#
#################################################################################
###            Setup IAM and Networking for your Dataflow Jobs               ####
#################################################################################

# User prompt function
function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
    read -p "$1 ([y]es to change, or any key to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=$(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=$(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

function join_by { local IFS="$1"; shift; echo "$*"; }

mkdir -p `pwd`/gcp-dataflow-iam > /dev/null 2>&1
export SCRIPTNAME=gcp-dataflow-iam.sh
export PROJDIR=`pwd`/gcp-dataflow-iam

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=us-central1
export GCP_ZONE=us-central1-b
EOF
source $PROJDIR/.env
fi

# Display menu options
while :
do
clear
cat<<EOF
======================================================================
Menu for Exploring IAM Setup and Networking for Dataflow Jobs
----------------------------------------------------------------------
Please enter number to select your choice:
 (0) Set script mode
 (1) Enable APIs
 (2) Create GCS bucket
 (3) Launch Dataflow job with IAM roles
 (4) Launch Dataflow job with private IPs
 (G) Launch user guide
 (Q) Quit
----------------------------------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 5
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ gcloud services enable --project=\$GCP_PROJECT compute.googleapis.com dataflow.googleapis.com datapipelines.googleapis.com # to enable APIs" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ gcloud services enable --project=$GCP_PROJECT compute.googleapis.com dataflow.googleapis.com datapipelines.googleapis.com # to enable APIs" | pv -qL 100
    gcloud services enable --project=$GCP_PROJECT compute.googleapis.com dataflow.googleapis.com datapipelines.googleapis.com 
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},1i"
    echo
    echo "1. Enable APIs" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},2i"   
    echo
    echo "$ gsutil mb -p \$GCP_PROJECT -b on gs://\$GCP_PROJECT # to create Cloud Storage bucket" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"   
    echo
    echo "$ gsutil mb -p $GCP_PROJECT -b on gs://$GCP_PROJECT # to create Cloud Storage bucket" | pv -qL 100
    gsutil mb -p $GCP_PROJECT -b on gs://$GCP_PROJECT
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"   
    echo
    echo "$ gcloud storage rm --recursive gs://$GCP_PROJECT # to delete bucket" | pv -qL 100
    gcloud storage rm --recursive gs://$GCP_PROJECT
else
    export STEP="${STEP},2i"
    echo
    echo "1. Create GCS bucket" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},3i"
    echo
    echo "$ gcloud projects get-iam-policy \$GCP_PROJECT --format='table(bindings.role)' --flatten=\"bindings[].members\" --filter=\"bindings.members:\$USER_EMAIL\" # to verify the IAM roles" | pv -qL 100
    echo
    echo "$ gcloud dataflow jobs run job1 --gcs-location gs://dataflow-templates-us-central1/latest/Word_Count --region \$GCP_REGION --staging-location gs://\$GCP_PROJECT/tmp --parameters inputFile=gs://dataflow-samples/shakespeare/kinglear.txt,output=gs://\$GCP_PROJECT/results/outputs # to launch a Dataflow job" | pv -qL 100
    echo
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=user:\$USER_EMAIL --role=roles/dataflow.admin # to add Dataflow Admin role " | pv -qL 100
    echo
    echo "$ gcloud dataflow jobs run job2 --gcs-location gs://dataflow-templates-us-central1/latest/Word_Count --region \$GCP_REGION --staging-location gs://\$GCP_PROJECT/tmp --parameters inputFile=gs://dataflow-samples/shakespeare/kinglear.txt,output=gs://\$GCP_PROJECT/results/outputs # to launch a Dataflow job" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    echo
    echo "$ export USER_EMAIL=\`gcloud config list account --format \"value(core.account)\"\` # to set email" | pv -qL 100
    export USER_EMAIL=`gcloud config list account --format "value(core.account)"`
    echo
    echo "$ gcloud projects get-iam-policy $GCP_PROJECT --format='table(bindings.role)' --flatten=\"bindings[].members\" --filter=\"bindings.members:$USER_EMAIL\" # to verify the IAM roles" | pv -qL 100
    gcloud projects get-iam-policy $GCP_PROJECT --format='table(bindings.role)' --flatten="bindings[].members" --filter="bindings.members:$USER_EMAIL"
    echo
    echo "$ gcloud dataflow jobs run job1 --gcs-location gs://dataflow-templates-us-central1/latest/Word_Count --region $GCP_REGION --staging-location gs://$GCP_PROJECT/tmp --parameters inputFile=gs://dataflow-samples/shakespeare/kinglear.txt,output=gs://$GCP_PROJECT/results/outputs # to launch a Dataflow job" | pv -qL 100
    gcloud dataflow jobs run job1 --gcs-location gs://dataflow-templates-us-central1/latest/Word_Count --region $GCP_REGION --staging-location gs://$GCP_PROJECT/tmp --parameters inputFile=gs://dataflow-samples/shakespeare/kinglear.txt,output=gs://$GCP_PROJECT/results/outputs
    echo
    read -n 1 -s -r -p "*** Job should fail due to missing IAM permissions ***" | pv -qL 100
    echo && echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=user:$USER_EMAIL --role=roles/dataflow.admin # to add Dataflow Admin role " | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member=user:$USER_EMAIL --role=roles/dataflow.admin
    echo
    echo "$ gcloud dataflow jobs run job2 --gcs-location gs://dataflow-templates-us-central1/latest/Word_Count --region $GCP_REGION --staging-location gs://$GCP_PROJECT/tmp --parameters inputFile=gs://dataflow-samples/shakespeare/kinglear.txt,output=gs://$GCP_PROJECT/results/outputs # to launch a Dataflow job" | pv -qL 100
    gcloud dataflow jobs run job2 --gcs-location gs://dataflow-templates-us-central1/latest/Word_Count --region $GCP_REGION --staging-location gs://$GCP_PROJECT/tmp --parameters inputFile=gs://dataflow-samples/shakespeare/kinglear.txt,output=gs://$GCP_PROJECT/results/outputs
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"   
    echo
    echo "*** Cancel job on console ***" | pv -qL 100
else
    export STEP="${STEP},3i"   
    echo
    echo "1. Launch Dataflow job" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},4i"
    echo
    echo "$ gcloud dataflow jobs run job3 --gcs-location gs://dataflow-templates-us-central1/latest/Word_Count --region \$GCP_REGION --staging-location gs://\$GCP_PROJECT/tmp --parameters inputFile=gs://dataflow-samples/shakespeare/kinglear.txt,output=gs://\$GCP_PROJECT/results/outputs --disable-public-ips # to launch a Dataflow job" | pv -qL 100
    echo
    echo "$ gcloud compute networks subnets update default --region=\$GCP_REGION --enable-private-ip-google-access # to enable Private Google Access" | pv -qL 100
    echo
    echo "$ gcloud dataflow jobs run job4 --gcs-location gs://dataflow-templates-us-central1/latest/Word_Count --region \$GCP_REGION --staging-location gs://\$GCP_PROJECT/tmp --parameters inputFile=gs://dataflow-samples/shakespeare/kinglear.txt,output=gs://\$GCP_PROJECT/results/outputs --disable-public-ips # to launch Dataflow job with PGA" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    echo
    echo "$ gcloud dataflow jobs run job3 --gcs-location gs://dataflow-templates-us-central1/latest/Word_Count --region $GCP_REGION --staging-location gs://$GCP_PROJECT/tmp --parameters inputFile=gs://dataflow-samples/shakespeare/kinglear.txt,output=gs://$GCP_PROJECT/results/outputs --disable-public-ips # to launch a Dataflow job" | pv -qL 100
    gcloud dataflow jobs run job3 --gcs-location gs://dataflow-templates-us-central1/latest/Word_Count --region $GCP_REGION --staging-location gs://$GCP_PROJECT/tmp --parameters inputFile=gs://dataflow-samples/shakespeare/kinglear.txt,output=gs://$GCP_PROJECT/results/outputs --disable-public-ips
    echo
    read -n 1 -s -r -p "*** Job should fail because Private Google Access is not turned on ***" | pv -qL 100
    echo && echo
    echo "$ gcloud compute networks subnets update default --region=$GCP_REGION --enable-private-ip-google-access # to enable Private Google Access" | pv -qL 100
    gcloud compute networks subnets update default --region=$GCP_REGION --enable-private-ip-google-access
    echo
    echo "$ gcloud dataflow jobs run job4 --gcs-location gs://dataflow-templates-us-central1/latest/Word_Count --region $GCP_REGION --staging-location gs://$GCP_PROJECT/tmp --parameters inputFile=gs://dataflow-samples/shakespeare/kinglear.txt,output=gs://$GCP_PROJECT/results/outputs --disable-public-ips # to launch Dataflow job with PGA" | pv -qL 100
    gcloud dataflow jobs run job4 --gcs-location gs://dataflow-templates-us-central1/latest/Word_Count --region $GCP_REGION --staging-location gs://$GCP_PROJECT/tmp --parameters inputFile=gs://dataflow-samples/shakespeare/kinglear.txt,output=gs://$GCP_PROJECT/results/outputs --disable-public-ips
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4x"   
    echo
    echo "$ gcloud compute networks subnets update default --region=$GCP_REGION --disable-private-ip-google-access # to enable Private Google Access" | pv -qL 100
    gcloud compute networks subnets update default --region=$GCP_REGION --disable-private-ip-google-access
    echo
    echo "*** Cancel job on console ***" | pv -qL 100
else
    export STEP="${STEP},4i"   
    echo
    echo "1. Launch Dataflow job with private IPs" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app
 
Email:support@techequity.cloud 
Web: https://techequity.cloud

Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done
