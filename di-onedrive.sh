#!/bin/zsh -f
# Purpose: Download and install the latest OneDrive client from Microsoft: <https://onedrive.live.com/about/en-us/download/>
#
# From:	Timothy J. Luoma
# Mail:	luomat at gmail dot com
# Date:	2018-08-15


## 2019-10-23 @TODO  - well this doesn't seem right:
## di-onedrive: Up-To-Date (19.152.1013.0012 vs Stapled)


NAME="$0:t:r"

INSTALL_TO="/Applications/OneDrive.app"

HOMEPAGE="https://onedrive.live.com/about/en-us/"

DOWNLOAD_PAGE='https://go.microsoft.com/fwlink/?LinkId=823060'

SUMMARY="Save your files and photos to OneDrive and get them from any device, anywhere."

# https://rink.hockeyapp.net/api/2/apps/58bdcef2b1db4db38e0c2fb8a84ac168 -- outdated?

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
else
	PATH='/usr/local/scripts:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin'
fi

URL=$(curl -sSfL --head 'https://go.microsoft.com/fwlink/?LinkId=823060' | awk -F' |\r' '/^.ocation/{print $2}' | tail -1)

LATEST_VERSION=$(echo "$URL:h")

LATEST_VERSION=$(echo "$LATEST_VERSION:t")

	# If either of these are blank, we should not continue
if [ "$URL" = "" -o "$LATEST_VERSION" = "" ]
then
	echo "$NAME: Error: bad data received:
	LATEST_VERSION: $LATEST_VERSION
	URL: $URL
	"

	exit 1
fi

if [[ -e "$INSTALL_TO" ]]
then
		## this is odd. On the website, the LATEST_VERSION is 19.070.0410.0007
		##
		## but in the app, it looks like this:
		##
		## /Applications/OneDrive.app:
		## 	CFBundleShortVersionString: 19.070.0410
		## 	CFBundleVersion: 19070.0410.0007
		##
		##  so we need CFBundleShortVersionString plus the last number from CFBundleVersion

	MAJOR_INSTALLED_VERSION=$(defaults read "${INSTALL_TO}/Contents/Info" CFBundleShortVersionString)

	MINOR_INSTALLED_VERSION=$(defaults read "${INSTALL_TO}/Contents/Info" CFBundleVersion | sed 's#.*\.##g')

	INSTALLED_VERSION="${MAJOR_INSTALLED_VERSION}.${MINOR_INSTALLED_VERSION}"

	autoload is-at-least

	is-at-least "$LATEST_VERSION" "$INSTALLED_VERSION"

	VERSION_COMPARE="$?"

	if [ "$VERSION_COMPARE" = "0" ]
	then
		echo "$NAME: Up-To-Date ($INSTALLED_VERSION vs $LATEST_VERSION)"
		exit 0
	fi

	echo "$NAME: Outdated: $INSTALLED_VERSION vs $LATEST_VERSION"

	FIRST_INSTALL='no'

	if [[ -e "$INSTALL_TO/Contents/_MASReceipt/receipt" ]]
	then
		echo "$NAME: $INSTALL_TO was installed from the Mac App Store and cannot be updated by this script."
		echo "	See <https://itunes.apple.com/us/app/onedrive/id823766827?mt=12> or"
		echo "	<macappstore://itunes.apple.com/us/app/onedrive/id823766827>"
		echo "	Please use the App Store app to update it: <macappstore://showUpdatesPage?scan=true>"
		exit 0
	fi

else

	FIRST_INSTALL='yes'
fi

FILENAME="$HOME/Downloads/$INSTALL_TO:t:r-${LATEST_VERSION}.pkg"

echo "$NAME: Downloading '$URL' to '$FILENAME':"

curl --continue-at - --fail --location --output "$FILENAME" "$URL"

EXIT="$?"

	## exit 22 means 'the file was already fully downloaded'
[ "$EXIT" != "0" -a "$EXIT" != "22" ] && echo "$NAME: Download of $URL failed (EXIT = $EXIT)" && exit 0

[[ ! -e "$FILENAME" ]] && echo "$NAME: $FILENAME does not exist." && exit 0

[[ ! -s "$FILENAME" ]] && echo "$NAME: $FILENAME is zero bytes." && rm -f "$FILENAME" && exit 0

if (( $+commands[pkginstall.sh] ))
then
	pkginstall.sh "$FILENAME"
else
	sudo /usr/sbin/installer -verbose -pkg "$FILENAME" -dumplog -target / -lang en 2>&1
fi

exit 0
#EOF
