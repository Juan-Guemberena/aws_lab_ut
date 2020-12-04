#!/bin/bash

set -xe

usage="Usage: ./delete_resources.sh [--help] username profile.\nDeletes resources created by create_resources.sh.\nUsername is the username first used for creation, plus the assigned random suffix.\nProfile is the
name in the credentials file of the profile used for the IAM user, roles and S3 buckets 1, 2 and 4."

if [ $# -eq 0 ] || [$1 = --help] ; then
    printf "${usage}"
    exit 0
fi


USERNAME="${1}"
AWS_ACCOUNT_ID=`aws --profile ut_account sts get-caller-identity | jq -r .Account`
POLICY_A_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${USERNAME}-role-A-policy"
POLICY_B_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${USERNAME}-role-B-policy"


#Delete role policies and roles
aws --profile ${PROFILE} iam detach-role-policy --role-name ${USERNAME}-role-A --policy-arn ${POLICY_A_ARN}
aws --profile ${PROFILE} iam detach-role-policy --role-name ${USERNAME}-role-B --policy-arn ${POLICY_B_ARN}
aws --profile ${PROFILE} iam delete-policy --policy-arn ${POLICY_A_ARN}
aws --profile ${PROFILE} iam delete-policy --policy-arn ${POLICY_B_ARN}
aws --profile ${PROFILE} iam delete-role --role-name ${USERNAME}-role-A
aws --profile ${PROFILE} iam delete-role --role-name ${USERNAME}-role-B


#Delete user policy and user
aws --profile ${PROFILE} iam delete-user-policy --user-name ${USERNAME} --policy-name ${USERNAME}-policy
aws --profile ${PROFILE} iam delete-user --user-name ${USERNAME}

#Remove buckets from second account
aws --profile ${PROFILE} s3 rb s3://${USERNAME}-bucket-1 --force
aws --profile ${PROFILE} s3 rb s3://${USERNAME}-bucket-2 --force
aws --profile ${PROFILE} s3 rb s3://${USERNAME}-bucket-4 --force

#Remove buckets from first account
aws s3 rb s3://${USERNAME}-bucket-3 --force
aws s3 rb s3://${USERNAME}-bucket-5 --force



