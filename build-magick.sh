# Copyright (c) 2010 Per Johansson, per at morth.org
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

set -e

if ! test -d ImageMagick; then
	echo Downloading...
	curl http://ftp.sunet.se/pub/multimedia/graphics/ImageMagick/ImageMagick.tar.bz2 | bsdtar -x -s ',^ImageMagick[^/]*,ImageMagick,' -f -
	echo Download done.
fi

#if [ "$ACTION" = clean ]; then
#	rm -rf "$TARGET_TEMP_DIR"
#	exit 0
#fi

mkdir -p "$TARGET_TEMP_DIR"
cd "$TARGET_TEMP_DIR"

# Check for config mismatch
config="-g -O${OPTIMIZATION_LEVEL}"
for a in $ARCHS; do
	config="$config -arch $a"
done
if test -f Makefile; then
	if ! test -f .config || [ "$config" != "$(< .config)" ]; then
		make distclean
	fi
fi
echo "$config" > .config

if ! test -f Makefile; then
	echo "Patching configure to ignore MacPorts/fink"
	sed -i .bak -E -e 's,^[[:space:]]*(CPP|LD)FLAGS=.*(/opt/local/|/sw/),: &,' "$SRCROOT/ImageMagick/configure"
	echo "Running configure"
	env -i "$SRCROOT/ImageMagick/configure" --disable-installed --without-x --without-magick-plus-plus --disable-dependency-tracking --disable-shared CFLAGS="$config" CC='clang'
fi

#printenv

echo make "$@"
make "$@"

mkdir -p "$BUILT_PRODUCTS_DIR"
for f in magick/.libs/libMagickCore-6.Q16.a config/coder.xml config/delegates.xml; do
	dst="$BUILT_PRODUCTS_DIR/`basename $f`"
	if ! test -f "$f" ; then
		echo rm -f "\"$dst\""
		rm -f "$dst"
	elif ! test -f "$dst" || test "$f" -nt "$dst" ; then
		echo cp -p "\"$f\"" "\"$dst\""
		cp -p "$f" "$dst"
	fi
done
