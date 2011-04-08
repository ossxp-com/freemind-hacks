#!/bin/sh

set -e
set -x

die()
{
  echo $*
  exit 1
}

clean_workcopy()
{
  cd ${SRCDIR}/
  git clean -fdx | grep -v debian || true
  git reset --hard > /dev/null || true
  cd ${SRCDIR}/debian
  git clean -fdx || true
  git reset --hard > /dev/null || true
}


format_files()
{
  cd ${SRCDIR}
	for i in freemind/build.xml \
		freemind/freemind.properties \
		freemind/freemind.bat \
		freemind/freemind/controller/Controller.java \
		freemind/freemind/main/FreeMind.java \
		freemind/freemind/main/Tools.java    \
		freemind/freemind/main/XMLElement.java \
		freemind/freemind/modes/mindmapmode/MindMapMapModel.java \
		freemind/freemind/modes/MindMapNode.java \
		freemind/freemind/modes/NodeAdapter.java \
		freemind/freemind.sh \
		freemind/Resources_zh_CN.properties \
		; do
		${SED} -i -e 's/\r$//g' -e 's/\r/\n/g' $i || true
	done
}


build_vanilla()
{
  echo "Build freemind vanilla version..."
  cd ${SRCDIR}/freemind
  ant dist
  mv ${SRCDIR}/bin/dist/lib/freemind.jar ${SRCDIR}/bin/dist/lib/freemind.vanilla.jar
  cp ${SRCDIR}/debian/freemind/windows-launcher/FreeMind.vanilla.exe ${SRCDIR}/freemind/windows-launcher/
  cp ${SRCDIR}/bin/dist/freemind.sh ${SRCDIR}/bin/dist/freemind.vanilla.sh
  ${SED} -i -e 's/freemind.jar/freemind.vanilla.jar/g' ${SRCDIR}/bin/dist/freemind.vanilla.sh
}


if [ "$(printf "a\rb" | sed -e 's/\r/\n/')" = "$(printf "a\nb")" ]; then
  SED=sed
elif which gsed >/dev/null 2>&1; then
  SED=gsed
else
  die "GNU sed not installed!"
fi

if ! which quilt >/dev/null 2>&1; then
  die "Quilt not installed!"
fi

if ! which ant >/dev/null 2>&1; then
  die "Ant not installed!"
fi

CURDIR=$(cd $(dirname $0); pwd)
SRCDIR=${CURDIR}/freemind

# do some cleaning.
clean_workcopy

# build vanilla freemind.jar
build_vanilla

# format files.
echo "Format files..."
format_files

# patch files.
echo "Patch files..."
cd ${SRCDIR}
QUILT_PATCHES=debian/patches quilt push -a

# copy files
cp ${SRCDIR}/debian/freemind/lib/saxon.jar ${SRCDIR}/freemind/lib/

# upate version number
echo "Set Revision..."
HACKREV=`head -1 ${SRCDIR}/debian/changelog | ${SED} -e "s/.*(.*-\([^-~+]*\).*).*/\1/"`
${SED} -ie "/public static final String HACKEDVERSION/ s/<REVISION>/r${HACKREV}/" \
   ${SRCDIR}/freemind/freemind/main/FreeMind.java

# Build
cd ${SRCDIR}/freemind
ant -Dlight_bulb=yes dist

# Create Install packages
cd ${SRCDIR}/freemind
ant post

echo "Build successfully."
echo "Build packages are in folder 'freemind/post'"
ls ${SRCDIR}/post
