#!/bin/bash

#########################################
#### Docker registry clean script                        ####
#### Author: ktcunreal@gmail.com                  ####
#### 2022                                                                     ####
#########################################

docker images | grep 127.0.0.1 | egrep -v 'chromium|openjdk|backup|base' | awk '{print $3}' | xargs docker rmi
