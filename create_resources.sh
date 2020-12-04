#!/bin/bash

set -e

usage="Usage: ./create_resources.sh [--help] [--debug] username profile. \nThis script creates the necessary resources for following the activities in Lecture_notebook.ipynb, using username as the name for the IAM user and roles that get created.
The parameter profile represents the second AWS account needed for creation. The first AWS account needs to be default in the credentials file."

if [ $# -eq 0 ] || [$1 = --help] ; then
    printf "${usage}"
    exit 0
elif [$1 = debug]
	set -xe
	echo "Setting script to debug mode"
fi


#Declare core variables
rand=$RANDOM
USERNAME="${1}-${rand}"
DATA_DIRECTORY=${PWD}/data
AWS_DIRECTORY=${PWD}/aws
PROFILE=$2
AWS_ACCOUNT_ID=`aws --profile ${PROFILE} sts get-caller-identity | jq -r .Account`
ROOT_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:root"
ROLE_A_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_A}"
ROLE_B_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_B}"


#Create the user, its access keys, get its arn, and replace the dummy value in both assume policies
aws --profile ${PROFILE} iam create-user --user-name ${USERNAME} > ${DATA_DIRECTORY}/user_output.json
aws --profile ${PROFILE} iam create-access-key --user-name ${USERNAME} > ${DATA_DIRECTORY}/user_keys.json
USER_ARN=`cat ${DATA_DIRECTORY}/user_output.json | jq -r .User.Arn`
sed -e "s|\${USER_ARN}|${USER_ARN}|" ${AWS_DIRECTORY}/assume_A_policy.json > ${DATA_DIRECTORY}/assume_A_policy.json
sed -e "s|\${USER_ARN}|${USER_ARN}|" ${AWS_DIRECTORY}/assume_B_policy.json > ${DATA_DIRECTORY}/assume_B_policy.json

ACCESS_KEY=`cat ${DATA_DIRECTORY}/user_keys.json | jq -r .AccessKey.AccessKeyId`
SECRET_ACCESS_KEY=`cat ${DATA_DIRECTORY}/user_keys.json | jq -r .AccessKey.SecretAccessKey`
sed -e "s|\${ACCESS_KEY}|${ACCESS_KEY}|" ${AWS_DIRECTORY}/environment.py > ${DATA_DIRECTORY}/${USERNAME}-environment.py
sed -i "s|\${SECRET_ACCESS_KEY}|${SECRET_ACCESS_KEY}|" ${DATA_DIRECTORY}/${USERNAME}-environment.py

#Create the roles with the previously created assume policies
aws --profile ${PROFILE} iam create-role --role-name ${USERNAME}-role-A --assume-role-policy-document file://${DATA_DIRECTORY}/assume_A_policy.json > ${DATA_DIRECTORY}/role_A_output.json
aws --profile ${PROFILE} iam create-role --role-name ${USERNAME}-role-B --assume-role-policy-document file://${DATA_DIRECTORY}/assume_B_policy.json > ${DATA_DIRECTORY}/role_B_output.json

#Get the role and user ID for bucket 4
ROLE_A_ID=`cat ${DATA_DIRECTORY}/role_A_output.json | jq -r .Role.RoleId`
USER_ID=`cat ${DATA_DIRECTORY}/user_output.json | jq -r .User.UserId`

#Create buckets 1, 2 and 4
aws --profile ${PROFILE} s3api create-bucket --bucket ${USERNAME}-bucket-1
aws --profile ${PROFILE} s3api create-bucket --bucket ${USERNAME}-bucket-2
aws --profile ${PROFILE} s3api create-bucket --bucket ${USERNAME}-bucket-4

#Copy some demo files in them
aws --profile ${PROFILE} s3 cp ${AWS_DIRECTORY}/bucket1_success.txt s3://${USERNAME}-bucket-1
aws --profile ${PROFILE} s3 cp ${AWS_DIRECTORY}/bucket2_success.txt s3://${USERNAME}-bucket-2
aws --profile ${PROFILE} s3 cp ${AWS_DIRECTORY}/bucket4_success.txt s3://${USERNAME}-bucket-4

#Create buckets 3 and 5
aws s3api create-bucket --bucket ${USERNAME}-bucket-3
aws s3api create-bucket --bucket ${USERNAME}-bucket-5

#Copy some demo files in them
aws s3 cp ${AWS_DIRECTORY}/bucket3_success.txt s3://${USERNAME}-bucket-3

sed -e "s|\${RANDOM}|$RANDOM|" ${AWS_DIRECTORY}/bucket5_success.txt > ${DATA_DIRECTORY}/bucket5_ctf.txt
aws s3 cp ${DATA_DIRECTORY}/bucket5_ctf.txt s3://${USERNAME}-bucket-5

#Replace dummy values in the user policy and attach it to the user
sed -e "s|\${ROLE_A_ARN}|${ROLE_A_ARN}|" ${AWS_DIRECTORY}/user_policy.json > ${DATA_DIRECTORY}/user_policy.json
sed -i "s|\${ROLE_B_ARN}|${ROLE_B_ARN}|" ${DATA_DIRECTORY}/user_policy.json

aws --profile ${PROFILE} iam put-user-policy --user-name ${USERNAME} --policy-name ${USERNAME}-policy --policy-document file://${DATA_DIRECTORY}/user_policy.json


#Replace dummy values in bucket1's policy
sed -e "s|\${ROOT_ARN}|${ROOT_ARN}|" ${AWS_DIRECTORY}/mybucket1_policy.json > ${DATA_DIRECTORY}/mybucket1_policy.json
sed -i "s|\${ROLE_B_ARN}|${ROLE_B_ARN}|" ${DATA_DIRECTORY}/mybucket1_policy.json
sed -i "s|\${BUCKET_ONE}|${USERNAME}-bucket-1|" ${DATA_DIRECTORY}/mybucket1_policy.json

#Replace dummy values in bucket3's policy
sed -e "s|\${ROOT_ARN}|${ROOT_ARN}|" ${AWS_DIRECTORY}/mybucket3_crossaccount_policy.json > ${DATA_DIRECTORY}/mybucket3_crossaccount_policy.json
sed -i "s|\${ROLE_B_ARN}|${ROLE_B_ARN}|" ${DATA_DIRECTORY}/mybucket3_crossaccount_policy.json
sed -i "s|\${BUCKET_THREE}|${USERNAME}-bucket-3|" ${DATA_DIRECTORY}/mybucket3_crossaccount_policy.json

#Replace dummy values in bucket4's policy
sed -e "s|\${ROLE_A_ID}|${ROLE_A_ID}|" ${AWS_DIRECTORY}/mybucket4_deny_policy.json > ${DATA_DIRECTORY}/mybucket4_deny_policy.json
sed -i "s|\${AWS_ACCOUNT_ID}|${AWS_ACCOUNT_ID}|" ${DATA_DIRECTORY}/mybucket4_deny_policy.json
sed -i "s|\${BUCKET_FOUR}|${USERNAME}-bucket-4|" ${DATA_DIRECTORY}/mybucket4_deny_policy.json
sed -i "s|\${USER_ID}|${USER_ID}|" ${DATA_DIRECTORY}/mybucket4_deny_policy.json

#Replace dummy values in bucket5's policy
sed -e "s|\${ROLE_A_ARN}|${ROLE_A_ARN}|" ${AWS_DIRECTORY}/mybucket5_divided_policy.json > ${DATA_DIRECTORY}/mybucket5_divided_policy.json
sed -i "s|\${ROLE_B_ARN}|${ROLE_B_ARN}|" ${DATA_DIRECTORY}/mybucket5_divided_policy.json
sed -i "s|\${BUCKET_FIVE}|${USERNAME}-bucket-5|" ${DATA_DIRECTORY}/mybucket5_divided_policy.json

#Replace dummy values in role A's permissions policy
sed -e "s|\${BUCKET_TWO}|${USERNAME}-bucket-2|" ${AWS_DIRECTORY}/role_A_permissions_policy.json > ${DATA_DIRECTORY}/role_A_permissions_policy.json
sed -i "s|\${BUCKET_THREE}|${USERNAME}-bucket-3|" ${DATA_DIRECTORY}/role_A_permissions_policy.json
sed -i "s|\${BUCKET_FOUR}|${USERNAME}-bucket-4|" ${DATA_DIRECTORY}/role_A_permissions_policy.json
sed -i "s|\${BUCKET_FIVE}|${USERNAME}-bucket-5|" ${DATA_DIRECTORY}/role_A_permissions_policy.json

#Replace dummy values in role B's permissions policy
sed -e "s|\${BUCKET_FOUR}|${USERNAME}-bucket-4|" ${AWS_DIRECTORY}/role_B_permissions_policy.json > ${DATA_DIRECTORY}/role_B_permissions_policy.json
sed -i "s|\${BUCKET_FIVE}|${USERNAME}-bucket-5|" ${DATA_DIRECTORY}/role_B_permissions_policy.json

#Create both roles' permissions policies
aws --profile ${PROFILE} iam create-policy --policy-name ${USERNAME}-role-A-policy --policy-document file://${DATA_DIRECTORY}/role_A_permissions_policy.json > ${DATA_DIRECTORY}/role_A_permissions_policy_output.json
aws --profile ${PROFILE} iam create-policy --policy-name ${USERNAME}-role-B-policy --policy-document file://${DATA_DIRECTORY}/role_B_permissions_policy.json > ${DATA_DIRECTORY}/role_B_permissions_policy_output.json

#Get the policies' arn, for later attaching
POLICY_A_ARN=`cat ${DATA_DIRECTORY}/role_A_permissions_policy_output.json | jq -r '.Policy.Arn'`
POLICY_B_ARN=`cat ${DATA_DIRECTORY}/role_B_permissions_policy_output.json | jq -r '.Policy.Arn'`

#Attach the policies to the roles
aws --profile ${PROFILE} iam attach-role-policy --role-name ${USERNAME}-role-A --policy-arn ${POLICY_A_ARN}
aws --profile ${PROFILE} iam attach-role-policy --role-name ${USERNAME}-role-B --policy-arn ${POLICY_B_ARN}

#Put buckets 1 and 4 policies
aws --profile ${PROFILE} s3api put-bucket-policy --bucket ${USERNAME}-bucket-1 --policy file://${DATA_DIRECTORY}/mybucket1_policy.json
aws --profile ${PROFILE} s3api put-bucket-policy --bucket ${USERNAME}-bucket-4 --policy file://${DATA_DIRECTORY}/mybucket4_deny_policy.json

#Put buckets 3 and 5 policies
aws s3api put-bucket-policy --bucket ${USERNAME}-bucket-3 --policy file://${DATA_DIRECTORY}/mybucket3_crossaccount_policy.json
aws s3api put-bucket-policy --bucket ${USERNAME}-bucket-5 --policy file://${DATA_DIRECTORY}/mybucket5_divided_policy.json





