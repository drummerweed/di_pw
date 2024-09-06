#!/usr/bin/env zsh -f
# Purpose: Download and install the latest version of MeetingBar
#
# From:	Patrick Weed
# Date:	2024-09-06

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
fi

NAME="$0:t:r"

INSTALL_TO="/Applications/MeetingBar.app"

HOMEPAGE="https://meetingbar.app/"

DOWNLOAD_PAGE="https://github.com/leits/MeetingBar/releases/latest/download/MeetingBar.dmg"

URL="https://github.com/leits/MeetingBar/releases/latest/download/MeetingBar.dmg"

SUMMARY="MeetingBar is a menu-bar app for your calendar meetings"

LATEST_VERSION=$(curl -s https://api.github.com/repos/leits/MeetingBar/releases/latest | grep '"tag_name":' | sed -E 's/.*"v?([0-9.]+)".*/\1/')

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

TEMP_FILENAME="$FILENAME.tmp"

echo "$NAME: Downloading '$URL' to temporary file '$TEMP_FILENAME':"

# Download the file to a temporary file first
curl --continue-at - --fail --location --output "$TEMP_FILENAME" "$URL"

EXIT="$?"

# Check if the download was successful or if the file was already downloaded (exit code 22)
if [ "$EXIT" != "0" -a "$EXIT" != "22" ]; then
    echo "$NAME: Download of $URL failed (EXIT = $EXIT)"
    exit 0
fi

# Check if the temporary file exists
if [[ ! -e "$TEMP_FILENAME" ]]; then
    echo "$NAME: $TEMP_FILENAME does not exist."
    exit 0
fi

# Check if the temporary file is zero bytes
if [[ ! -s "$TEMP_FILENAME" ]]; then
    echo "$NAME: $TEMP_FILENAME is zero bytes."
    rm -f "$TEMP_FILENAME"
    exit 0
fi

# Move the temporary file to the final destination
mv "$TEMP_FILENAME" "$FILENAME"
echo "$NAME: Download complete and saved as '$FILENAME'."

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
	&& osascript -e "tell application \"$INSTALL_TO:t:r\" to quit"

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
#EOF