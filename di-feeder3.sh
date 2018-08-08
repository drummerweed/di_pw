#!/bin/zsh -f
# Purpose: Download and install latest version of Feeder 3 from <https://reinventedsoftware.com/feeder/>
#
# From:	Tj Luo.ma
# Mail:	luomat at gmail dot com
# Web: 	http://RhymesWithDiploma.com
# Date:	2015-10-26

NAME="$0:t:r"

INSTALL_TO='/Applications/Feeder 3.app'

XML_FEED="https://reinventedsoftware.com/feeder/downloads/Feeder3.xml"

if [ -e "$HOME/.path" ]
then
	source "$HOME/.path"
else
	PATH=/usr/local/scripts:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin
fi

INFO=($(curl -sfL "$XML_FEED" \
	| tr ' |>|<' '\012' \
	| egrep '^url="|^sparkle:version|^sparkle:shortVersionString' \
	| head -3 \
	| sort \
	| awk -F'"' '//{print $2}'))

LATEST_VERSION="$INFO[1]"
LATEST_BUILD="$INFO[2]"
URL="$INFO[3]"

	# If any of these are blank, we should not continue
if [ "$INFO" = "" -o "$LATEST_BUILD" = "" -o "$URL" = "" -o "$LATEST_VERSION" = "" ]
then
	echo "$NAME: Error: bad data received:
	INFO: $INFO
	LATEST_VERSION: $LATEST_VERSION
	LATEST_BUILD: $LATEST_BUILD
	URL: $URL
	"

	exit 1
fi

if [[ -e "$INSTALL_TO" ]]
then

	INSTALLED_VERSION=`defaults read "$INSTALL_TO/Contents/Info"  CFBundleShortVersionString 2>/dev/null || echo '0'`

	INSTALLED_BUILD=`defaults read "$INSTALL_TO/Contents/Info"  CFBundleVersion 2>/dev/null || echo '0'`

	if [ "$LATEST_BUILD" = "$INSTALLED_BUILD" -a "$LATEST_VERSION" = "$INSTALLED_VERSION" ]
	then
		echo "$NAME: Up-To-Date ($INSTALLED_VERSION)"
		exit 0
	fi

	autoload is-at-least

	is-at-least "$LATEST_BUILD" "$INSTALLED_BUILD"

	if [ "$?" = "0" ]
	then
		echo "$NAME: Installed version ($INSTALLED_BUILD) is ahead of official version $LATEST_BUILD"
		exit 0
	fi

	echo "$NAME: Outdated (Installed = $INSTALLED_BUILD vs Latest = $LATEST_BUILD)"

fi

if (( $+commands[lynx] ))
then

	RELEASE_NOTES_URL=`curl -sfL "$XML_FEED" \
	| egrep '<sparkle:releaseNotesLink>.*</sparkle:releaseNotesLink>' \
	| head -1 \
	| sed 's#.*<sparkle:releaseNotesLink>##g; s#</sparkle:releaseNotesLink>.*##g;' `

	echo -n "$NAME: Release Notes for $INSTALL_TO:t:r Version $LATEST_VERSION / $LATEST_BUILD: "

	curl -sfL "$RELEASE_NOTES_URL" \
	| sed '1,/<h2>/d; /<h2>/,$d' \
	| lynx -dump -nomargins -nonumbers -width=10000 -assume_charset=UTF-8 -pseudo_inlines  -stdin

	echo "Source: <$RELEASE_NOTES_URL>"
fi

	# Note that we include 'Feeder' because we don't want 'Feeder 3'
FILENAME="$HOME/Downloads/Feeder-${LATEST_VERSION}-${LATEST_BUILD}.dmg"

echo "$NAME: Downloading $URL to $FILENAME"

	# Download it
curl --continue-at - --fail --location --referer ";auto" --progress-bar --output "${FILENAME}" "$URL"

EXIT="$?"

	## exit 22 means 'the file was already fully downloaded'
[ "$EXIT" != "0" -a "$EXIT" != "22" ] && echo "$NAME: Download of $URL failed (EXIT = $EXIT)" && exit 0

[[ ! -e "$FILENAME" ]] && echo "$NAME: $FILENAME does not exist." && exit 0

[[ ! -s "$FILENAME" ]] && echo "$NAME: $FILENAME is zero bytes." && rm -f "$FILENAME" && exit 0

	# Mount the DMG
MNTPNT=$(hdiutil attach -nobrowse -plist "$FILENAME" 2>/dev/null \
		| fgrep -A 1 '<key>mount-point</key>' \
		| tail -1 \
		| sed 's#</string>.*##g ; s#.*<string>##g')

if [[ "$MNTPNT" == "" ]]
then
	echo "$NAME: MNTPNT is empty"
	exit 0
fi

	# Move the old version (if any) to trash
if [ -e "$INSTALL_TO" ]
then
	mv -vf "$INSTALL_TO" "$HOME/.Trash/$INSTALL_TO:t:r.${INSTALLED_VERSION}.app"
fi

echo "$NAME: Installing $MNTPNT/$INSTALL_TO:t to $INSTALL_TO..."

	# Install it
ditto -v --noqtn "$MNTPNT/$INSTALL_TO:t" "$INSTALL_TO"

EXIT="$?"

if [ "$EXIT" = "0" ]
then

	echo "$NAME: Successfully updated/installed $INSTALL_TO"

else
	echo "$NAME: 'ditto' failed (\$EXIT = $EXIT)"

	exit 1
fi


	# Eject the DMG
if (( $+commands[unmount.sh] ))
then
	unmount.sh "$MNTPNT"
else
	diskutil eject "$MNTPNT"
fi


exit 0
#
#EOF
