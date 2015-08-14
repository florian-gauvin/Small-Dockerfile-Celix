# Version 1.0
FROM ubuntu:14.04
MAINTAINER Florian GAUVIN "florian.gauvin@nl.thalesgroup.com"

ENV DEBIAN_FRONTEND noninteractive

#Download all the packages needed

RUN apt-get update && apt-get install -y \
	cmake \
	git \
	python \
	wget \
        && apt-get clean 

#Download and install the latest version of Docker (You need to be the same version to use this Dockerfile)

RUN wget -qO- https://get.docker.com/ | sh

#Prepare the usr directory by downloading in it : the base image and celix

WORKDIR /usr/

RUN 	git clone https://github.com/florian-gauvin/rootfs.tar-celix.git && \
	wget https://github.com/apache/celix/archive/develop.tar.gz && \
	tar -xf develop.tar.gz && \
	mkdir celix-build

#Decompress the base image

WORKDIR /usr/rootfs.tar-celix

RUN tar -xf rootfs.tar &&\
	rm rootfs.tar

#Install etcd

RUN cd /tmp && curl -k -L https://github.com/coreos/etcd/releases/download/v2.0.12/etcd-v2.0.12-linux-amd64.tar.gz | tar xzf - && \
cp etcd-v2.0.12-linux-amd64/etcd /usr/rootfs.tar-celix/bin/ && cp etcd-v2.0.12-linux-amd64/etcdctl /usr/rootfs.tar-celix/bin/ 

#Add the resources
ADD resources /usr/rootfs.tar-celix/tmp

#Build Celix and link against the libraries in the buildroot environment. It's not a real good way to do so but it's the only one that I have found : I remove the link.txt file and replace it by one created manualy and not during the configuration, otherwise I don't have all the libraries linked against the environment in buildroot

WORKDIR /usr/celix-build

RUN cmake ../celix-develop -DWITH_APR=OFF -DCURL_LIBRARY=/usr/rootfs.tar-celix/usr/lib/libcurl.so.4 -DZLIB_LIBRARY=/usr/rootfs.tar-celix/usr/lib/libz.so.1 -DUUID_LIBRARY=/usr/rootfs.tar-celix/usr/lib/libuuid.so -DBUILD_SHELL=TRUE -DBUILD_SHELL_TUI=TRUE -DBUILD_REMOTE_SHELL=TRUE -DBUILD_DEPLOYMENT_ADMIN=ON -DCMAKE_INSTALL_PREFIX=/usr/rootfs.tar-celix/usr && \
	rm -f /usr/celix-build/launcher/CMakeFiles/celix.dir/link.txt && \
	echo "/usr/bin/cc  -D_GNU_SOURCE -std=gnu99 -Wall  -g CMakeFiles/celix.dir/private/src/launcher.c.o  -o celix -rdynamic ../framework/libcelix_framework.so /usr/rootfs.tar-celix/lib/libpthread.so.0 /usr/rootfs.tar-celix/lib/libdl.so.2 /usr/rootfs.tar-celix/lib/libc.so.6 /usr/rootfs.tar-celix/usr/lib/libcurl.so.4 ../utils/libcelix_utils.so -lm /usr/rootfs.tar-celix/usr/lib/libuuid.so /usr/rootfs.tar-celix/usr/lib/libz.so.1" > /usr/celix-build/launcher/CMakeFiles/celix.dir/link.txt && \
	make all && \
	make install-all 

#We have all we need for the futur image so we can compress all the files
WORKDIR /usr/rootfs.tar-celix

RUN tar -cf rootfs.tar * && \
	mkdir /usr/image && \
	cp rootfs.tar /usr/image && \ 
	cd /usr && \
	rm -fr rootfs.tar-celix develop.tar.gz celix-develop celix-build

#When the builder image is launch, it creates the celix docker image that you will be able to see by running the command : docker images

ENTRYPOINT for i in `seq 0 100`; do sudo mknod -m0660 /dev/loop$i b 7 $i; done && \
	service docker start && \
	docker import - inaetics/celix-agent < /usr/image/rootfs.tar &&\
	/bin/bash 
