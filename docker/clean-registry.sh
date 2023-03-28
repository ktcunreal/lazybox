#!/bin/bash

#########################################
#### Docker registry clean script                        ####
#### Author: ktcunreal@gmail.com                  ####
#### 2021                                                                      ####
#########################################

# Path to repositories
BASEDIR=/var/lib/registry/docker/registry/v2/repositories

# Delete files
for ln in `ls -1 $BASEDIR`;do
# Keep last 5 builds for each project
cd $BASEDIR/$ln/_manifests/tags && ls -1t |awk '{if (NR>5){print $1}}'|xargs rm -rf;
cd $BASEDIR/$ln/_manifests/revisions/sha256 && ls -1t |awk '{if (NR>5){print $1}}'|xargs rm -rf;
done;

# Clean registry
registry garbage-collect /etc/docker/registry/config.yml
