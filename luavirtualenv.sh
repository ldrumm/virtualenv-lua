#!/bin/bash

#This is a very simple and dirty way to build Python-virtualenv-like virtual environments for Lua using LuaRocks.
#This script is probably not very robust but allows you to easily create isolated environments into which you install a bunch of packages
#with LuaRocks
#Like the Python program, the system Lua executable is copied, and that version is used for a local LuaRocks build.
#source bin/actvate

LUAROCKS_TAR_GZ_URL="http://www.luarocks.org/releases/luarocks-2.1.2.tar.gz"
LUAROCKS_VERSION_STRING="2.1.2"
LUA_INCLUDE_PATH=/usr/include/

if [ -n $TMPDIR ] ; then
    SCRATCH=/tmp
else
    SCRATCH=$TMPDIR
fi    

INSTALL_DIR=$PWD
SYS_LUA=`which lua`

if [ ! -n "$SYS_LUA" ] ; then
    echo "Couldn't detect Lua installation"  >&2 
fi

LUA_VERSION=`$SYS_LUA -e 'print(_VERSION:match("%d.%d$"))'`
if [ ! -n "$LUA_VERSION" ] ; then 
    echo "Could not detect system Lua version" >&2
    exit 1
fi


mkdir -p "$INSTALL_DIR/bin" || echo "mkdir failed"
cp "$SYS_LUA" "$INSTALL_DIR/bin/lua"
echo "installing luarocks"
BUILD_DIR=`tempfile -d $SCRATCH`

cd "$BUILD_DIR"
wget $LUAROCKS_TAR_GZ_URL -O - | tar -xzf - 
cd "luarocks-$LUAROCKS_VERSION_STRING"

./configure  --prefix="$INSTALL_DIR" --rocks-tree="$INSTALL_DIR" --lua-version="$LUA_VERSION" --with-lua="$INSTALL_DIR" \
--sysconfdir="$INSTALL_DIR/luarocks" --force-config --with-lua-include="$LUA_INCLUDE_PATH"
make build && make install

cd "$INSTALL_DIR"
./bin/luarocks path > bin/activate
echo "export PATH=$INSTALL_DIR/bin/:\$PATH" >> bin/activate
rm -R "$INSTALL_DIR/luarocks-$LUAROCKS_VERSION_STRING"
rm -R "$BUILD_DIR"

