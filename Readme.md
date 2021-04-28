# Cross-Account vs Intra-Account Rules, and What is Root?

In particular, what does the following mean when used as the principal in an IAM resource policy?

```
"Principal": {"AWS": ["arn:aws:iam::111122223333:root]}
```

## Introduction
This is a modified version of Lab2 from [these labs](https://github.com/kbroughton/aws-labs/), tailored for a class or interactive presentation.

This lab examines the difference between IAM vs AWS Resource based policies. In particular, we seek to understand the
policy evaluation logic for S3 buckets with cross account access. For a refresher on IAM basics, see
[Reference Policies Evaluation Logic](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html)
which is valid for when the IAM Principal and S3 Resource are in the same AWS account. 

To summarize the above, if an action is allowed by an identity-based policy, a resource-based policy, or both, then 
AWS allows the action. An explicit deny in either of these policies overrides the allow.

The situation changes for [cross account access](https://aws.amazon.com/premiumsupport/knowledge-center/cross-account-access-s3/). 
In this case, access must be explicitly allowed in both
the picincipal's AWS access policy and the resource policy. Unfortunately, the latter reference does not
mention the confused deputy issue for cross-account access which occurs when the trusted account is a
3rd party SaaS vendor. As a result, many vendors which operate on customer's S3 buckets do so insecurely.

For this lab, we will assume both AWS accounts are owned by the same entity and will leave confused deputy 
issues for Lab 4 - Direct Access vs Assume Role: Granting cross account access to resources.

![s3-cross-account.png](s3-cross-account.png)
Granting permissions for Principal-A to access Resource-B when both are in the same account can be done by giving Principal-A
a permissions policy to access Resource-B.


### Assume Role
Assume Role access requires adding statements 
like the following in a role's assume-role trust policy.

IAM Role Assume-Role Trust Policy
```
"Principal":{"AWS":"arn:aws:iam::AWSTargetAccountID:root"}
```

## Setup

### By yourself
In order to test this, you will want two accounts where you have been granted admin, since you will need the ability
to create users, roles and policies. If an instructor wanted to run this in a class without granting full admin, then
a permissions boundary which allows creating roles and users, but not policies could be tailored to this lab following
the [AWS documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html).

### For a class or presentation
Follow [this tutorial](https://tljh.jupyter.org/en/latest/install/amazon.html) to set up an EC2 instance running the
JupyterHub, and set up up to 30 users (This is to accommodate the 100 S3 buckets soft limit. Otherwise, ask for an [Increase in quotas](https://docs.aws.amazon.com/servicequotas/latest/userguide/request-quota-increase.html)). 

Create a new terminal inside the JupyterHub as admin and run

```
sudo -E apt-get install jq awscli

sudo -E touch /opt/tljh/config/jupyterhub_config.d/<username>-environment.py
```

Go inside environment.py with your favourite text editor (remember to add sudo -E) and paste in the contents of the provided <username>-environment.py, inside /data.

Lastly, run

```
sudo -E tljh-config reload
```

Unfortunately, this has to be done for every user, in order to not expose AWS keys. Another way of doing it is setting up a user with sts:AssumeRole permissions for all the lab roles, setting those keys
in environment.py (removing ${Username}) and removing {username}_ in the following two lines in the notebook.
```
!aws configure set aws_access_key_id  ${username}_AWS_KEY --profile lab2
!aws configure set aws_secret_access_key ${username}_AWS_SECRET_KEY --profile lab2
```

Afer all this, you're ready to go! The last thing to do would be to give the users their usernames, and have them log in to the already set up Lecture_notebook.ipynb, using [nbgitpuller](https://tljh.jupyter.org/en/latest/howto/content/nbgitpuller.html).



We summarize the results of the lab as follows:

When a role and resource are in the same account permssion is granted if
either the role or resource grants access (union).
When a role and resource are in distinct accounts, permission must be
granted by both the role and the resource (intersection).