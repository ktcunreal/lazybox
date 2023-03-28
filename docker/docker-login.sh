#!/bin/bash
#########################################
#### Login docker private registry                     ####
#### Author: ktcunreal@gmail.com                  ####
#### 2021                                                                      ####
#########################################

REGISTRI_ADDR=

echo '{
  "insecure-registries" : ["${REGISTRI_ADDR}"]
}' > /etc/docker/daemon.json

systemctl restart docker

docker login ${REGISTRI_ADDR} --username docker --password