# Dockerfile for building the toolchains and octopus
# the build is split into 3 stages:
# 1. base-environment: contains the base environment for building the toolchain
# 2. toolchain-environment: contains the toolchain
# 3. octopus-build: contains the octopus build
FROM debian:bullseye AS base-environment

RUN cat /etc/issue
# Install dependencies
RUN apt-get -y update
# From https://github.com/ax3l/dockerfiles/blob/master/spack/base/Dockerfile:
# install minimal spack dependencies
RUN apt-get install -y --no-install-recommends \
              autoconf \
              build-essential \
              ca-certificates \
              coreutils \
              curl \
              environment-modules \
	            file \
              gfortran \
              git \
              openssh-server \
    python \
              unzip

# Convenience tools, if desired for debugging etc
RUN apt-get -y install wget time nano vim emacs vim

# Tools needed by mpsd-software-environment.py (and ../spack-setup.sh)
RUN apt-get -y install rsync automake libtool linux-headers-amd64


# prepare for pipx installation (to enable archspec installation)
RUN echo "deb http://deb.debian.org/debian bullseye-backports main" >> /etc/apt/sources.list
RUN apt-get -y update
CMD bash -l
RUN apt-get -y install pipx
# use funny locations so user 'user' can execute the program
RUN PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install archspec

# Tools needed by install-octopus.sh
# install lmod from debian testing as we need lmod 8.6.5 or newer
RUN echo "deb http://deb.debian.org/debian testing main" >> /etc/apt/sources.list
RUN apt-get -y update && apt-get -y install lmod

# tidy up
# RUN rm -rf /var/lib/apt/lists/*

RUN adduser user

# prepare mount point
RUN mkdir /io
RUN chown -R user /io

USER user

WORKDIR /home/user
# for debugging, switch to root
USER root
RUN echo "use user 'user' for normal operation ('su - user')"
# Provide bash in case the image is meant to be used interactively
CMD /bin/bash


FROM base-environment AS toolchain-environment 
# This part of the docker file contains instructions to build the toolchain
# needs the following arguments:
# TOOLCHAIN: the name of the toolchain to build (e.g. foss2022a-mpi)
# MPSD_RELEASE: the name of the mpsd release to build (e.g. dev-23a)
USER user
WORKDIR /home/user
ARG TOOLCHAIN=UNDEFINED
ARG MPSD_RELEASE=dev-23a
RUN echo "MPSD_RELEASE=${MPSD_RELEASE}"
RUN echo "TOOLCHAIN=${TOOLCHAIN}"
RUN cat /etc/issue

# for debugging, switch to root
USER root
RUN echo "use user 'user' for normal operation ('su - user')"
# Provide bash in case the image is meant to be used interactively
CMD /bin/bash


FROM toolchain-environment AS octopus-build
# This part of the docker file contains instructions to build octopus 
# with the toolchain built in the previous step

USER user
WORKDIR /home/user
ARG TOOLCHAIN=UNDEFINED
ARG MPSD_RELEASE=dev-23a
RUN echo "MPSD_RELEASE=${MPSD_RELEASE}"
RUN echo "TOOLCHAIN=${TOOLCHAIN}"
RUN cat /etc/issue
ADD install-toolchain.sh .
RUN bash install-toolchain.sh ${TOOLCHAIN} ${MPSD_RELEASE}


# we follow instructions from
# https://computational-science.mpsd.mpg.de/docs/mpsd-hpc.html#loading-a-toolchain-to-compile-octopus

RUN mkdir -p build-octopus
WORKDIR /home/user/build-octopus
RUN git clone https://gitlab.com/octopus-code/octopus.git
WORKDIR /home/user/build-octopus/octopus
RUN pwd
RUN ls -l
RUN autoreconf -fi
RUN mkdir _build
WORKDIR /home/user/build-octopus/octopus/_build
RUN pwd
RUN cp /home/user/mpsd-software/${MPSD_RELEASE}/spack-environments/octopus/${TOOLCHAIN}-config.sh .
RUN ls -l
ADD install-octopus.sh .
RUN bash install-octopus.sh ${TOOLCHAIN} ${MPSD_RELEASE}


