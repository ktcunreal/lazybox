#!/bin/bash

## ARGUMENTS SETTINGS
while getopts "a:t:d:e:h" arg; do
    case $arg in 
        t)  ## SPECIFY TARGET FILE.USE ABSOLUTE PATH
            TARGET=$OPTARG
            echo "USING FILE FROM: $TARGET" ;;
	d)  ## DESTINATION HOST TO PUSH THE DOCKER IMAGE
	    DEST=$OPTARG 
            echo "DESTINATION HOST: $DEST" ;;
	e)  ## PORT TO EXPOSE
	    EXPOSED=$OPTARG
	    echo "EXPOSE PORT: $EXPOSED" ;;
        h)  ## HELPER TEXTBOX
            echo -e "			USAGE\n"
	    echo "	-t		Location of target file" 
	    echo "	-d		Destination Host"	
	    echo "	-e		Expose target port"
	    exit 1 ;;
        ?)
            echo "Unknown argument $arg=$OPTARG" exit 1 ;;
    esac
done

## PREPARE WORKING DIRECTORY
rm -rf /tmp/.dtmp && mkdir /tmp/.dtmp && cd /tmp/.dtmp 
PROJECT=`echo ${TARGET##*/} | awk -F '[.]' '{print $1}'`
RELEASE=`date +%m%d%k%M`
TYPE=`echo $TARGET | awk -F '[.]' '{print $2}'`
APPENV=${TARGET%/*}
echo PROJECT: $PROJECT
echo RELEASE: $RELEASE
echo TYPE: $TYPE file

## MAKE SYSTEMD UNIT
if [ $TYPE == 'jar' ];then
touch $PROJECT.service
echo "[Unit]
Desc = $PROJECT 
[Service]
WorkingDirectory=/PROJECT/
ExecStart=/bin/bash -c \"java -jar /PROJECT/$PROJECT.jar > $PROJECT.log\"
Restart=always
RestartSec=30s
[Install]
WantedBy=multi-user.target
" > $PROJECT.service
fi

## MAKE NGINX CONF
if [ $TYPE == 'tar' ];then
touch $PROJECT.conf
echo "server {
        listen       $EXPOSED;
        location / {
           root /PROJECT/$PROJECT/;
           try_files \$uri \$uri/ @router;
           index  index.html;
        }
        location @router {
           rewrite ^.*$ /index.html last;
        }
}
" > $PROJECT.conf
fi

## MAKE DOCKERFILE
touch Dockerfile
if [ $TYPE == 'jar' ];then
echo "from centos7-custom
COPY $PROJECT.service /etc/systemd/system/$PROJECT.service
COPY ./PROJECT /PROJECT
RUN systemctl enable $PROJECT
CMD [ \"/usr/sbin/init\" ]
" > Dockerfile
fi

if [ $TYPE == 'tar' ];then
echo "from nginx
COPY ./$PROJECT.conf /etc/nginx/conf.d/$PROJECT.conf
COPY ./PROJECT/$PROJECT /PROJECT/$PROJECT
RUN rm -f /etc/nginx/conf.d/default.conf
" > Dockerfile
fi

## PREPARE PROJECT FILES & BUILD IMAGE
mkdir PROJECT && cd PROJECT
if [ $TYPE == 'jar' ];then
touch $PROJECT.log && \
cp $TARGET ./$PROJECT.jar && \
cp $APPENV/application-env.yml ./application-env.yml
fi

if [ $TYPE == 'tar' ];then
cp $TARGET ./$PROJECT.tar && \
tar -xvf $PROJECT.tar && \
mv dist $PROJECT
fi

docker build -t $PROJECT:$RELEASE ..
docker save -o $PROJECT_$RELEASE.tar $PROJECT:$RELEASE

## DEPLOY CONTAINER ON REMOTE HOST
scp -o "StrictHostKeyChecking=no" $PROJECT_$RELEASE.tar root@$DEST:/tmp/$PROJECT_$RELEASE.tar
ssh -o "StrictHostKeyChecking=no" root@$DEST -t "
docker stop $PROJECT || true >/dev/null 2>&1 && \
docker rm $PROJECT || true >/dev/null 2>&1 && \
docker images |grep '$PROJECT'|awk '{print \$1\":\"\$2}' | xargs docker rmi -f || true >/dev/null 2>&1 && \
docker load -i /tmp/$PROJECT_$RELEASE.tar && \
rm -rf /tmp/$PROJECT_$RELEASE.tar
"
if [ $TYPE == 'jar' ];then
ssh -o "StrictHostKeyChecking=no" root@$DEST -t "
docker create -h $PROJECT \
	--name $PROJECT\
	--privileged \
	--network host \
	-v /sys/fs/cgroup:/sys/fs/cgroup:ro \
	$PROJECT:$RELEASE && \
docker start $PROJECT && \
iptables -I INPUT -p tcp --dport $EXPOSED -j ACCEPT >/dev/null 2>&1
"
fi

if [ $TYPE == 'tar' ];then
ssh -o "StrictHostKeyChecking=no" root@$DEST -t "
docker create -h $PROJECT \
        --name $PROJECT\
        --network host \
        $PROJECT:$RELEASE && \
docker start $PROJECT && \
iptables -I INPUT -p tcp --dport $EXPOSED -j ACCEPT >/dev/null 2>&1
"
fi

## CLEAN ENTIRE WORKING DIRECTORY
echo CLEANING UP AFTERWARD...
rm -rf /tmp/.dtmp
docker images |grep $PROJECT| awk '{print $1":"$2}'| xargs docker rmi
