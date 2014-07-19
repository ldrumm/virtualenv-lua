#!/bin/bash

#This is a very simple and dirty way to build Python-virtualenv-like virtual environments for Lua using LuaRocks.
#This script is probably not very robust but allows you to easily create isolated environments into which you install a bunch of packages
#with LuaRocks
#Like the Python program, the system Lua executable is copied, and that version is used for a local LuaRocks build.
#source bin/actvate

LUAROCKS_TAR_GZ_URL="http://www.luarocks.org/releases/luarocks-2.1.2.tar.gz"
LUAROCKS_VERSION_STRING="2.1.2"
LUA_INCLUDE_PATH=/usr/include/
SYS_LUA=`which lua`
INSTALL_DIR=$PWD

usage(){
cat <<EOF
Available options:
    -r <version>    install luarocks version=<version> (default: $LUAROCKS_VERSION_STRING)
    -l <path>       use lua installation from <path> (default: `which lua`)
    -d <dir>        create lua virtualenv in <dir> (defaults to the working directory)
EOF
}

err_exit(){
cat <<EOF
==========================================
An error occurred and installation failed:
==========================================
$1
------------------------------------------
EOF
    exit 1
}

RE="^[0-9]+.[0-9]+.[0-9]+\w*[-]?$"
while getopts ":r:l:d:" opt; do
    case $opt in
        r)
            if [[ "$OPTARG" =~ $RE ]]; then
                LUAROCKS_VERSION_STRING="$OPTARG"
            else
                err_exit "'$OPTARG' does not appear to be a valid luaRocks version"
            fi
            echo $LUAROCKS_TAR_GZ_URL
            LUAROCKS_TAR_GZ_URL="http://www.luarocks.org/releases/luarocks-$LUAROCKS_VERSION_STRING.tar.gz"
        ;;
        l)
            SYS_LUA="$OPTARG"
            if ! [ -f "$SYS_LUA" ] ; then
                err_exit "$SYS_LUA does not exist"
            fi
        ;;
        d)
            INSTALL_DIR="$OPTARG"
            if ! [ -d "$INSTALL_DIR" ] ; then
                mkdir -p "$INSTALL_DIR" || err_exit "Couldn't create $INSTALL_DIR"
            fi
        ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2 ; usage 1
            exit 1
        ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2 ; usage 1
            exit 1
        ;;
    esac
done

echo "installing in $INSTALL_DIR"

if [ ! -n "$SYS_LUA" ] ; then
    err_exit "Couldn't detect Lua installation"
fi

LUA_VERSION=`$SYS_LUA -e 'print(_VERSION:match("%d.%d$"))'`
if [ ! -n "$LUA_VERSION" ] ; then 
    err_exit "Could not detect system Lua version"
fi

if ! [ "$(ls -A $INSTALL_DIR 2> /dev/null)" == "" ]; then
    Y=""
    read -p "$INSTALL_DIR is not empty:continue anyway?(yN)" Y
    if  [ "$Y" != 'y' ] ; then
        err_exit "ABORTING..."
    fi
fi

mkdir -p "$INSTALL_DIR/bin" || err_exit "mkdir failed"
cp "$SYS_LUA" "$INSTALL_DIR/bin/lua"
echo "installing luarocks into $BUILD_DIR..."

BUILD_DIR=`mktemp -d `
cd "$BUILD_DIR"
wget "$LUAROCKS_TAR_GZ_URL" -O - | tar -xzf - || err_exit "Couldn't fetch $LUAROCKS_TAR_GZ_URL"
cd "luarocks-$LUAROCKS_VERSION_STRING"

#configure
(./configure  --prefix="$INSTALL_DIR" --rocks-tree="$INSTALL_DIR" \
--lua-version="$LUA_VERSION" --with-lua="$INSTALL_DIR" \
--sysconfdir="$INSTALL_DIR/luarocks" --force-config \
--with-lua-include="$LUA_INCLUDE_PATH") || err_exit "failed to configure"

(make build && make install) || err_exit "LuaRocks build failed"

cd "$INSTALL_DIR"
./bin/luarocks path > bin/activate
echo "export PATH=$INSTALL_DIR/bin:\$PATH" >> bin/activate
rm -R "$BUILD_DIR/luarocks-$LUAROCKS_VERSION_STRING"
rm -R "$BUILD_DIR"

