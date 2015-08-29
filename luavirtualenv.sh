#!/bin/sh

# This is a very simple and dirty way to build Python-virtualenv-like virtual
# environments for Lua using LuaRocks.
# This script is probably not very robust but allows you to easily create
# isolated environments into which you install a bunch of packages with LuaRocks
# Like the Python program, the system Lua executable is copied, and that version
# is used for a local LuaRocks build.
# Use ``source bin/activate`` to activate the new virtualenv.
# If your shell does not support the ``source`` builtin, use the POSIX-compliant ``. bin/activate``

LUAROCKS_VERSION_STRING="2.2.2"
LUAROCKS_DOWNLOAD_BASEDIR="https://keplerproject.github.io/luarocks/releases"
LUA_INCLUDE_PATH=/usr/include/
SYS_LUA=$(command -v lua)
INSTALL_DIR=$(pwd)

usage(){
cat <<EOF
Available options:
    -r <version>    install luarocks version=<version> (default: $LUAROCKS_VERSION_STRING)
    -l <path>       use lua installation from <path> (default: $SYS_LUA )
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

GREP_VERSIONSTRING_RE="^[0-9]\{1,2\}\.[0-9]\{1,2\}\.[0-9]\{1,3\}\(\-[[:alnum:]]*\)\?$"
while getopts ":r:l:d:" opt; do
    case $opt in
        r)
            if [ $(echo "$OPTARG" | grep -e "$GREP_VERSIONSTRING_RE") ] ; then
                LUAROCKS_VERSION_STRING="$OPTARG"
            else
                err_exit "'$OPTARG' does not appear to be a valid luaRocks version"
            fi
            echo "Will fetch LuaRocks $LUAROCKS_VERSION_STRING"
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

LUAROCKS_TAR_GZ_URL="$LUAROCKS_DOWNLOAD_BASEDIR/luarocks-$LUAROCKS_VERSION_STRING.tar.gz"

if [ ! -n "$SYS_LUA" ] ; then
    err_exit "Couldn't detect Lua installation"
fi

LUA_VERSION=$($SYS_LUA -e 'print(_VERSION:match("%d.%d$"))')
if [ ! -n "$LUA_VERSION" ] ; then
    err_exit "Could not detect system Lua version"
fi

if ! [ "$(ls -A "$INSTALL_DIR" 2> /dev/null)" = "" ] ; then
    Y=""
    read -p "$INSTALL_DIR is not empty:continue anyway?(yN)" Y
    if  [ "$Y" != 'y' ] ; then
        err_exit "User aborted..."
    fi
fi

echo "installing luarocks into $BUILD_DIR..."
mkdir -p "$INSTALL_DIR/bin" || err_exit "mkdir failed"
cp "$SYS_LUA" "$INSTALL_DIR/bin/lua" || err_exit "couldn't copy lua binary"


BUILD_DIR=$(mktemp -d "$INSTALL_DIR/.luarocks_buildXXXX")
cd "$BUILD_DIR"
wget "$LUAROCKS_TAR_GZ_URL" -O - | tar -xz || err_exit "Couldn't fetch $LUAROCKS_TAR_GZ_URL"
cd "luarocks-$LUAROCKS_VERSION_STRING"

#configure
(./configure  --prefix="$INSTALL_DIR" --rocks-tree="$INSTALL_DIR" \
--lua-version="$LUA_VERSION" --with-lua="$INSTALL_DIR" \
--sysconfdir="$INSTALL_DIR/luarocks" --force-config \
--with-lua-include="$LUA_INCLUDE_PATH") || err_exit "failed to configure"

(make build && make install) || err_exit "LuaRocks build failed"


cd "$INSTALL_DIR"
rm -R "$BUILD_DIR"

cat <<EOF >> "$INSTALL_DIR/bin/activate"
_PROMPT="(Lua$LUA_VERSION:rocks-$(dirname "$INSTALL_DIR"))"

deactivate () {
    # reset old environment variables
    export PATH="\$_OLD_PATH"
    export LUA_PATH="\$_OLD_LUA_PATH"
    export LUA_CPATH="\$_OLD_LUA_CPATH"
    export PROMPT="\$_OLD_PROMPT"

    unset _OLD_PATH
    unset _OLD_LUA_PATH
    unset _OLD_LUA_CPATH
    unset _OLD_PROMPT

    unset -f deactivate
}

export _OLD_PATH="\$PATH"
export _OLD_LUA_PATH="\$LUA_PATH"
export _OLD_LUA_CPATH="\$LUA_CPATH"
export _OLD_PROMPT="\$PROMPT"

export PATH="$INSTALL_DIR/bin:\$PATH"
export PROMPT="\$_PROMPT\$PROMPT"
unset _PROMPT

#Now the LuaRocks specifics...
EOF

./bin/luarocks path >> bin/activate
#We're done, notify the user
echo
echo
echo "Successfully installed luarocks-$LUAROCKS_VERSION_STRING into $INSTALL_DIR"
echo "Run 'source $INSTALL_DIR/bin/activate' to activate your LuaRocks environment"

exit 0
