# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

ARG BASE_IMAGE_VERSION=latest

ARG DATASKETCHES_CPP_HASH=8135b65408947694e13bd131038889e439847aa2
ARG DATASKETCHES_CPP_VERSION=2.0.0-incubating

FROM postgres:$BASE_IMAGE_VERSION

MAINTAINER dev@datasketches.apache.org

ENV APACHE_DIST_URLS \
  https://www.apache.org/dyn/closer.cgi?action=download&filename= \
  https://www-us.apache.org/dist/ \
  https://www.apache.org/dist/ \
  https://archive.apache.org/dist

ARG DATASKETCHES_CPP_VERSION
ARG DATASKETCHES_CPP_HASH

ENV DS_CPP_VER=$DATASKETCHES_CPP_VERSION
ENV DS_CPP_HASH=$DATASKETCHES_CPP_HASH


ADD . /datasketches-postgresql
WORKDIR /datasketches-postgresql

RUN echo "===> Adding prerequisites..."                      && \
    export PG_MAJOR=`apt list 2>&1 | sed -n "s/^postgresql-\([0-9.]*\)\/.*/\1/p"`             && \
    export PG_MINOR=`apt list 2>&1 | sed -n "s/^postgresql-$PG_MAJOR\/\S*\s\(\S*\)\s.*/\1/p"` && \
    apt-get update -y                                        && \
    DEBIAN_FRONTEND=noninteractive                              \
        apt-get install --no-install-recommends --allow-downgrades -y -q \
                ca-certificates                                 \
                build-essential wget unzip                      \
                postgresql-server-dev-$PG_MAJOR=$PG_MINOR       \
                libpq-dev=$PG_MINOR libpq5=$PG_MINOR         && \
    \
    \                
    echo "===> Building datasketches..."                     && \
    set -eux;                                                   \
    download_bin() {                                            \
        local f="$1"; shift;                                    \
        local hash="$1"; shift;                                 \
        local distFile="$1"; shift;                             \
        local success=;                                         \
        local distUrl=;                                         \
        for distUrl in $APACHE_DIST_URLS; do                    \
          if wget -nv -O "$f" "$distUrl$distFile"; then         \
            success=1;                                          \
            # Checksum the download                             \
            echo "$hash" "*$f" | sha1sum -c -;                  \
            break;                                              \
          fi;                                                   \
        done;                                                   \
        [ -n "$success" ];                                      \
    }                                                        && \
    download_bin "datasketches-cpp.zip" "$DS_CPP_HASH" "incubator/datasketches/cpp/$DS_CPP_VER/apache-datasketches-cpp-$DS_CPP_VER-src.zip" && \
    unzip datasketches-cpp.zip                               && \
    mv apache-datasketches-cpp-$DS_CPP_VER-src datasketches-cpp  && \
    make                                                     && \
    make install                                             && \
    \
    \
    echo "===> Clean up..."                                  && \
    apt-get -y remove --purge --auto-remove                     \
            ca-certificates                                     \
            build-essential wget unzip                          \ 
            postgresql-server-dev-$PG_MAJOR libpq-dev libpq5 && \
    apt-get clean                                            && \
    rm -rf /datasketches-postgresql /var/lib/apt/lists/* /tmp/* /var/tmp/*

ADD /docker-entrypoint-initdb.d /docker-entrypoint-initdb.d

WORKDIR /

ENTRYPOINT ["/docker-entrypoint.sh"]
EXPOSE 5432
CMD ["postgres"]