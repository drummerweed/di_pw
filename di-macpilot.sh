#!/bin/zsh -f
# Purpose: Download and install the latest version of MacPilot @TODO - update this?
#
# From:	Tj Luo.ma
# Mail:	luomat at gmail dot com
# Web: 	http://RhymesWithDiploma.com
# Date:	2015-10-27


NAME="$0:t:r"

INSTALL_TO='/Applications/MacPilot.app'

if [ -e "$HOME/.path" ]
then
	source "$HOME/.path"
else
	PATH=/usr/local/scripts:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin
fi

if [[ -e "$INSTALL_TO" ]]
then
	INSTALLED_VERSION=`defaults read "$INSTALL_TO/Contents/Info" CFBundleShortVersionString`
else
	# we need to fake that we've installed something if it isn't installed, so I chose '10'
	# since it's the most recent major version as of this writing
	INSTALLED_VERSION='10'
fi

OS_VER=`sw_vers -productVersion`

XML_FEED="http://www.koingosw.com/postback/versioncheck.php?appname=macpilot&appversion=${INSTALLED_VERSION}&sysplatform=Mac%20OS%20X&sysversion=Mac%20OS%20X%20${OS_VER}"

INFO=($(curl --silent --location "$XML_FEED" \
		| fgrep -A3 '<macpilot>' \
		| egrep '(<version>|<macpath>)' \
		| sort \
		| sed 's#.*<version>##g ; s#</version>##g; s#.*<macpath>##g; s#</macpath>##g; '
	))

URL="$INFO[1]"

	# That's the only version info the app uses
LATEST_VERSION="$INFO[2]"

	# If any of these are blank, we should not continue
if [ "$INFO" = "" -o "$LATEST_VERSION" = "" -o "$URL" = "" ]
then
	echo "$NAME: Error: bad data received:
	INFO: $INFO
	LATEST_VERSION: $LATEST_VERSION
	URL: $URL
	"

	exit 1
fi

if [[ -e "$INSTALL_TO" ]]
then

	if [[ "$LATEST_VERSION" == "$INSTALLED_VERSION" ]]
	then
		echo "$NAME: Up-To-Date ($INSTALLED_VERSION)"
		exit 0
	fi

	autoload is-at-least

	is-at-least "$LATEST_VERSION" "$INSTALLED_VERSION"

	if [ "$?" = "0" ]
	then
		echo "$NAME: Installed version ($INSTALLED_VERSION) is ahead of official version $LATEST_VERSION"
		exit 0
	fi

	echo "$NAME: Outdated (Installed = $INSTALLED_VERSION vs Latest = $LATEST_VERSION)"
fi

if (( $+commands[lynx] ))
then

	RELEASE_NOTES_URL="$XML_FEED"

	echo -n "$NAME: Release Notes for $INSTALL_TO:t:r "

		# have to call lynx twice because the release notes are encoded as HTML characters. Weird.
	curl -sfL "$RELEASE_NOTES_URL" | sed '1,/<macpilot>/d ; /<\/macpilot>/,$d' \
	| egrep -vi "<version|minimumSystemVersion|macpath>" \
	| lynx -dump -nomargins -width='10000' -assume_charset=UTF-8 -pseudo_inlines -stdin \
	| lynx -dump -nomargins -width='10000' -assume_charset=UTF-8 -pseudo_inlines -stdin

	echo "\nSource: XML_FEED <$RELEASE_NOTES_URL>"

fi

FILENAME="$HOME/Downloads/$INSTALL_TO:t:r-$LATEST_VERSION.dmg"

echo "$NAME: Downloading '$URL' to '$FILENAME':"

curl --continue-at - --progress-bar --fail --location --output "$FILENAME" "$URL"

EXIT="$?"

	## exit 22 means 'the file was already fully downloaded'
[ "$EXIT" != "0" -a "$EXIT" != "22" ] && echo "$NAME: Download of $URL failed (EXIT = $EXIT)" && exit 0

[[ ! -e "$FILENAME" ]] && echo "$NAME: $FILENAME does not exist." && exit 0

[[ ! -s "$FILENAME" ]] && echo "$NAME: $FILENAME is zero bytes." && rm -f "$FILENAME" && exit 0

echo "$NAME: Mounting $FILENAME:"

MNTPNT=$(hdiutil attach -nobrowse -plist "$FILENAME" 2>/dev/null \
	| fgrep -A 1 '<key>mount-point</key>' \
	| tail -1 \
	| sed 's#</string>.*##g ; s#.*<string>##g')

if [[ "$MNTPNT" == "" ]]
then
	echo "$NAME: MNTPNT is empty"
	exit 1
fi

if [[ -e "$INSTALL_TO" ]]
then
		# Quit app, if running
	pgrep -xq "$INSTALL_TO:t:r" \
	&& LAUNCH='yes' \
	&& osascript -e 'tell application "$INSTALL_TO:t:r" to quit'

		# move installed version to trash
	mv -vf "$INSTALL_TO" "$HOME/.Trash/$INSTALL_TO:t:r.${INSTALLED_VERSION}_${INSTALLED_BUILD}.app"
fi

echo "$NAME: Installing '$MNTPNT/$INSTALL_TO:t' to '$INSTALL_TO': "

ditto --noqtn -v "$MNTPNT/$INSTALL_TO:t" "$INSTALL_TO"

EXIT="$?"

if [[ "$EXIT" == "0" ]]
then
	echo "$NAME: Successfully installed $INSTALL_TO"
else
	echo "$NAME: ditto failed"

	exit 1
fi

[[ "$LAUNCH" = "yes" ]] && open -a "$INSTALL_TO"

echo "$NAME: Unmounting $MNTPNT:"

diskutil eject "$MNTPNT"

exit 0
#
#EOF
