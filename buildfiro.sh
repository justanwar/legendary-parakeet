#!/bin/bash -x

## to create the buildimage
## git clone https://github.com/fanquake/core-review.git
## cd core-review/guix/
## DOCKER_BUILDKIT=1 docker build --pull --no-cache -t alpine-guix - < Dockerfile

export FIRO_SRC="$PWD/firo/"

set -e

running=$(docker container list | grep firobuild || :)

# Original lines
#if [ -z "$running" ];then
#    docker container stop firobuild || :
#    docker container rm -f firobuild || :
#    docker run -dt --name firobuild --privileged -v "$FIRO_SRC":/firo/ ghcr.io/delta1/alpine-guix
#fi

if [ -z "$running" ];then
    docker container stop firobuild || :
    docker container rm -f firobuild || :
    git clone https://github.com/fanquake/core-review code-review
    pushd code-review/guix/
    DOCKER_BUILDKIT=1 docker build --pull --no-cache -t alpine-guix - < Dockerfile
    popd
    #docker run -dt --name firobuild --privileged -v "$FIRO_SRC":/firo/ ghcr.io/delta1/alpine-guix
    docker run -dt --name firobuild --privileged -v "$FIRO_SRC":/firo/ alpine-guix
fi

#if you build a hash instead of a tag, remember to use only the first 12 chars
tag=$BUILD_TAG
echo "tag: ${tag}"

tagbuild=${tag#firo-}
echo "tagbuild: ${tagbuild}"

builddir="guix-build-${tagbuild#v}"
echo "builddir: ${builddir}"

echo "host: $HOST"
NAME=${HOST//-/_}
echo "name: $NAME"

echo "macos sdk: $MACOS_SDK"


cat >tmpfirobuild.sh <<__EOF__
#!/bin/bash

set -ex
chown -R root:root /firo
cd /firo
# # git checkout $tag
export SOURCES_PATH=/sources
export BASE_CACHE=/base_cache

export HOSTS="$HOST"
echo $HOST
echo $NAME

./contrib/guix/guix-clean

if [[ $HOST == *"apple"* ]];then
    if [ ! -d /firo/depends/SDKs/$MACOS_SDK ];then
        mkdir -p /firo/depends/SDKs/
        pushd /firo/depends/SDKs/
        wget https://bitcoincore.org/depends-sources/sdks/$MACOS_SDK.tar.gz
        tar -xf /sources/$MACOS_SDK.tar.gz
        popd
    fi
fi

export FORCE_DIRTY_WORKTREE=true
time ./contrib/guix/guix-build
pwd
ls -alht
echo $builddir
ls -alht $builddir
ls -alht $builddir/output/
find $builddir/output/ -type f -print0 | env LC_ALL=C sort -z | xargs -r0 sha256sum | tee $NAME.txt
mv $NAME.txt $builddir/output/$NAME.txt
__EOF__

chmod 700 tmpfirobuild.sh
docker cp tmpfirobuild.sh firobuild:/root/firobuild.sh
pwd
ls
docker cp sources/. firobuild:/sources/
docker exec -i firobuild /root/firobuild.sh
mkdir -p output/
docker cp firobuild:/firo/"$builddir"/output/ output/