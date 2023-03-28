#!/bin/bash

## CHECK PARAMETER
if  [ ! -n "$1" ] ;then
    echo "INVALID INPUT!"
    exit 1 ;
else
    echo "LOOKING FOR PROJECT $1"
fi

## ENVIRONMENT VARIABLES
ARCHIVE=/root/ARCHIVE
GROUP=`echo $1 |awk -F '[/]' '{print $1}'`
PROJECT=`echo $1 |awk -F '[/]' '{print $2}'`
DATE=`date +"%Y%m%d"`

## CREATE PROJECT DIRECTORY
mkdir $ARCHIVE/$GROUP >/dev/null 2>&1
mkdir $ARCHIVE/$GROUP/$PROJECT >/dev/null 2>&1
mkdir $ARCHIVE/$GROUP/$PROJECT/$DATE >/dev/null 2>&1

## SET RELEASE VERSION
CALC=`ls -l $ARCHIVE/$GROUP/$PROJECT/$DATE |grep '^-' | wc -l`
RELEASE=`echo $CALC + 1 | bc`

## CLONE REPO
git clone -b develop git@192.168.0.12:$GROUP/$PROJECT.git /tmp/$GROUP-$PROJECT && cd /tmp/$GROUP-$PROJECT
if [ -f "package.json" ];then

## BUILD FRONTEND
cnpm install && cnpm run build --prod && tar -cvf dist.tar dist/*
mv dist.tar $ARCHIVE/$GROUP/$PROJECT/$DATE/$GROUP-$PROJECT-$DATE-$RELEASE.tar
echo -e "Build complete!\n$ARCHIVE/$GROUP/$PROJECT/$DATE/$GROUP-$PROJECT-$DATE-$RELEASE.tar"
else

## BUILD BACKEND
mvn clean package
JARSRC=`find /tmp/$GROUP-$PROJECT/ -name '*.jar'| grep -v api`
DST=$ARCHIVE/$GROUP/$PROJECT/$DATE/$GROUP-$PROJECT-$DATE-$RELEASE
    if [ -f "$JARSRC" ];then
    mv $JARSRC $DST.jar
    else
    mv `find /tmp/$GROUP-$PROJECT/ -name '*.war'` $ARCHIVE/$GROUP/$PROJECT/$DATE/$GROUP-$PROJECT-$DATE-$RELEASE.war
    fi
	find /tmp/$GROUP-$PROJECT/ -name "application-env.yml" | grep -v api
fi

## CLEAN WORKDIR
rm -rf /tmp/$GROUP-$PROJECT

