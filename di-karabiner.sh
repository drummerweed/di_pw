#!/usr/bin/env zsh -f
# Purpose: Download and install the latest version of Karabiner-Elements from <https://pqrs.org/osx/karabiner/>
#
# From:	Timothy J. Luoma
# Mail:	luomat at gmail dot com
# Date:	2018-08-11

NAME="$0:t:r"

# It doesn't really matter which one we check, they both have the same version information
#INSTALL_TO="/Applications/Karabiner-EventViewer.app"

	# Installed via pkg
INSTALL_TO="/Applications/Karabiner-Elements.app"

HOMEPAGE="https://pqrs.org/osx/karabiner/"

DOWNLOAD_PAGE="https://pqrs.org/osx/karabiner/"

SUMMARY="A powerful and stable keyboard customizer for macOS."

	# if you want to install beta releases
	# create a file (empty, if you like) using this file name/path:
PREFERS_BETAS_FILE="$HOME/.config/di/karabiner-elements-prefer-betas.txt"

if [[ -e "$PREFERS_BETAS_FILE" ]]
then
	XML_FEED="https://pqrs.org/osx/karabiner/files/karabiner-elements-appcast-devel.xml"
	NAME="$NAME (beta releases)"
else
	XML_FEED="https://pqrs.org/osx/karabiner/files/karabiner-elements-appcast.xml"
fi

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
else
	PATH='/usr/local/scripts:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin'
fi

	# for Mac OS X '10.11.6' this will give us '11' since we need to test the major version
OS_VER=$(sw_vers -productVersion | cut -d. -f2)

if [ "$OS_VER" -ge "12" ]
then

	INFO=($(curl -sfL "$XML_FEED" \
		| tr -s ' |\t' '\012' \
		| egrep -i '^(sparkle:version|url)=' \
		| head -2 \
		| sort \
		| awk -F'"' '//{print $2}'))

	LATEST_VERSION="$INFO[1]"

	URL="$INFO[2]"

		# If any of these are blank, we should not continue
	if [ "$INFO" = "" -o "$URL" = "" -o "$LATEST_VERSION" = "" ]
	then
		echo "$NAME: Error: bad data received:
		INFO: $INFO
		LATEST_VERSION: $LATEST_VERSION
		URL: $URL
		"

		exit 1
	fi

elif [ "$OS_VER" -lt "12" ]
then
		# n.b. Not sure how far back Karabiner version 10.22 supports.
	INSTALL_TO="/Applications/Karabiner.app"
	LATEST_VERSION="10.22.0"
	URL="https://pqrs.org/osx/karabiner/files/Karabiner-10.22.0.dmg"

	echo "$NAME [info]: Using Karabiner version 10.22.0 for Mac OS X 10.$OS_VER."

else
	echo "$NAME: Don't know what to do for OS_VER = '$OS_VER'."
	exit 1

fi

if [[ -e "$INSTALL_TO" ]]
then

	INSTALLED_VERSION=$(defaults read "${INSTALL_TO}/Contents/Info" CFBundleShortVersionString)

	autoload is-at-least

	is-at-least "$LATEST_VERSION" "$INSTALLED_VERSION"

	VERSION_COMPARE="$?"

	if [ "$VERSION_COMPARE" = "0" ]
	then
		echo "$NAME: Up-To-Date ($INSTALLED_VERSION)"
		exit 0
	fi

	echo "$NAME: Outdated: $INSTALLED_VERSION vs $LATEST_VERSION"

	FIRST_INSTALL='no'

else

	FIRST_INSTALL='yes'
fi

FILENAME="$HOME/Downloads/$INSTALL_TO:t:r-${LATEST_VERSION}.dmg"

if [[ "$XML_FEED" != "" ]]
then
	if (( $+commands[lynx] ))
	then

		RELEASE_NOTES_URL="$XML_FEED"

		( echo "$NAME: Release Notes for $INSTALL_TO:t:r ($LATEST_VERSION):\n" ;
		curl -sfL "$XML_FEED" \
		| sed '1,/ update-description-begin /d; / update-description-end /,$d' \
		| lynx -dump -nomargins -width='10000' -assume_charset=UTF-8 -pseudo_inlines -stdin ;
		echo "\nSource: XML_FEED <$RELEASE_NOTES_URL>" ) | tee "$FILENAME:r.txt"

	fi
fi

echo "$NAME: Downloading '$URL' to '$FILENAME':"

curl --continue-at - --fail --location --output "$FILENAME" "$URL"

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

PKG=$(find "$MNTPNT" -maxdepth 2 -iname \*.pkg -print)

if [[ "$PKG" == "" ]]
then
	echo "$NAME: Failed to find a .pkg file in $MNTPNT"
	exit 1
fi

if (( $+commands[pkginstall.sh] ))
then
	pkginstall.sh "$PKG"
else
	sudo /usr/sbin/installer -verbose -pkg "$PKG" -dumplog -target / -lang en 2>&1
fi

EXIT="$?"

if [ "$EXIT" != "0" ]
then

	echo "$NAME: installation of $PKG failed (\$EXIT = $EXIT)."

		# Show the .pkg file at least, to draw their attention to it.
	open -R "$PKG"

	exit 1
fi

echo "$NAME: Unmounting $MNTPNT:"

diskutil eject "$MNTPNT"

if (( $+commands[tag-karabiner.sh] ))
then

		## This is a separate script I need to run after updates happen
		## with specific changes for how I use macOS so I don't include them here

	tag-karabiner.sh

fi

exit 0
#EOF

