#!/usr/bin/env zsh -f
# Purpose: Download and install latest BitTorrent Sync (aka Resilio Sync)
#
# From:	Tj Luo.ma
# Mail:	luomat at gmail dot com
# Web: 	http://RhymesWithDiploma.com
# Date:	2014-10-11

	# 2018-08-02 - this is what the newest version available calls itself
#INSTALL_TO='/Applications/BitTorrent Sync.app'

INSTALL_TO='/Applications/Resilio Sync.app'

HOMEPAGE="https://www.resilio.com"

DOWNLOAD_PAGE="https://download-cdn.resilio.com/stable/osx/Resilio-Sync.dmg"

SUMMARY="Sync any folder to all your devices. Sync photos, videos, music, PDFs, docs or any other file types to/from your mobile phone, laptop, or NAS."

if [ -e "$HOME/.path" ]
then
	source "$HOME/.path"
else
	PATH=/usr/local/scripts:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin
fi

NAME="$0:t:r"

zmodload zsh/datetime

	# I cannot figure out where the '33685507' comes from
	# but I'll use it until it breaks
# URL="http://update.getsync.com/cfu.php?cl=BitTorrent%20Sync&pl=osx&v=33685507&cmp=0&lang=en&sysver=10.13.0"

URL="https://update.resilio.com/cfu.php?forced=1&b=sync&lang=en&pl=mac&rn=19&sysver=10.13.6&v=33882125"

# curl "https://update.resilio.com/cfu.php?b=sync&lang=en&pl=mac&rn=19&sysver=10.13.6&v=33947648" \
#   -H "Accept: application/rss+xml,*/*;q=0.1" \
#   -H "Accept-Language: en-us" \
#   -H "User-Agent: Resilio Sync/2.6.0 Sparkle/1.16.0"
#
# got '<rss></rss>'
#
# Is that just because we're up to date?

#
# out of date
#
# first sent this
#
#
# curl "https://update.resilio.com/cfu.php?forced=1&b=sync&lang=en&pl=mac&rn=19&sysver=10.13.6&v=33882125" \
#   -H "Accept: application/rss+xml,*/*;q=0.1" \
#   -H "Accept-Language: en-us" \
#   -H "User-Agent: Resilio Sync/2.5.13 Sparkle/1.16.0"
#
# which gave me the non-changelog information -- URL, versions, etc
#
# Then sent this
#
# curl "https://update.resilio.com/cfu.php?v=33882125&pl=osx&relnotes=1&forced=1&beta=0" \
#   -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
#   -H "Accept-Language: en-us" \
#   -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/605.1.15 (KHTML, like Gecko)"
#
# which gave me the changelog
#
#
# when mounted, it's /Volumes/Resilio\ Sync/Resilio\ Sync.app/
#


LOG="$HOME/Library/Logs/${NAME}.log"

[[ -d "$LOG:h" ]] || mkdir -p "$LOG:h"
[[ -e "$LOG" ]]   || touch "$LOG"

function timestamp { strftime "%Y-%m-%d at %H:%M:%S" "$EPOCHSECONDS" }

function log { echo "$NAME [`timestamp`]: $@" | tee -a "$LOG" }

TEMPFILE="${TMPDIR-/tmp}/${NAME}.${TIME}.$$.$RANDOM"

####|####|####|####|####|####|####|####|####|####|####|####|####|####|####
#
#		Check to see what the latest version is
#

## TEMP - manually setting latest version
# curl -sfL "$URL" \
# | sed '1,/<item>/d; /<\/item>/,$d' \
# | tr -s ' |\t' '\012' > "$TEMPFILE"
#
# LATEST_VERSION=`awk -F'"' '/sparkle:version/{print $2}' "$TEMPFILE"`
#
# URL=`awk -F'"' '/url/{print $2}' "$TEMPFILE"`

URL='http://internal.resilio.com/support/debug/sync/2.6.10073/Resilio-Sync.dmg'

LATEST_VERSION='2.6.10073'

	# If any of these are blank, we should not continue
if [ "$LATEST_VERSION" = "" -o "$URL" = "" ]
then
	echo "$NAME: Error: bad data received:
	LATEST_VERSION: $LATEST_VERSION
	URL: $URL
	"

	exit 1
fi

####|####|####|####|####|####|####|####|####|####|####|####|####|####|####
#
#		Compare installed version with latest version
#

if [ -e "$INSTALL_TO" ]
then
	INSTALLED_VERSION=`defaults read $INSTALL_TO/Contents/Info CFBundleShortVersionString 2>/dev/null || echo 0`
else
	INSTALLED_VERSION='0'
fi

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

####|####|####|####|####|####|####|####|####|####|####|####|####|####|####
#
#		Download the latest version to a file with the version number in the name
#

FILENAME="$HOME/Downloads/${${INSTALL_TO:t:r}// /}-${LATEST_VERSION}.dmg"

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
else
	echo "$NAME: MNTPNT is $MNTPNT"
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

echo -n "$NAME: Unmounting $MNTPNT: " && diskutil eject "$MNTPNT"

open -a "$INSTALL_TO:t:r"

exit 0
#
#EOF
