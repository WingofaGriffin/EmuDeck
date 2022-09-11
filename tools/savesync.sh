
SAVESYNC_toolName="EmuDeck SaveSync"
SAVESYNC_toolType="AppImage"
SAVESYNC_toolPath="$HOME/Applications/EmuDeck_SaveSync.AppImage"
SAVESYNC_systemd_path="$HOME/.config/systemd/user"
#SAVESYNC_Shortcutlocation="$HOME/Desktop/EmuDeckBinUpdate.desktop"


function getReleaseURLGH(){	
	local repository=$1
	local fileType=$2
	local url
	#local token=$(tokenGenerator)

	if [ "$url" == "" ]; then
		url="https://api.github.com/repos/$repository/releases"
	fi
	curl -fSs "$url" | \
	jq -r '[ .[].assets[] | select(.name | endswith("'"$fileType"'")).browser_download_url ][0]'
	
}


SAVESYNC_install(){	

	rm "$SAVESYNC_toolPath"
	curl -L "$(getReleaseURLGH "EmuDeck/savesync" "AppImage")" --output "$SAVESYNC_toolPath"
	chmod +x "$SAVESYNC_toolPath"

}

#$1 = gdrive,dropbox,onedrive,box,nextcloud
SAVESYNC_setup(){
	local cloudProvider=$1
	if [[ -z "$cloudProvider" ]]; then
		echo "no cloud provider selected"
	else
		echo "cloud provider: $cloudProvider"
		systemctl --user stop emudeck_savesync.service

		mv "${toolsPath}/savesync/config.yml" "${toolsPath}/savesync/config.yml.bak"
		mv "$HOME/.config/rclone/rclone.conf"  "$HOME/.config/rclone/rclone.conf.bak"

		"$SAVESYNC_toolPath" "$emulationPath" --setup "$cloudProvider"
		echo "pausing before creating service"
		sleep 20
		SAVESYNC_createService
	fi
}

SAVESYNC_createService(){
	echo "Creating SaveSync service"
	systemctl --user stop emudeck_savesync.service

	mkdir -p "$SAVESYNC_systemd_path"
	echo \
	"[Unit]
	Description=Emudeck SaveSync service

	[Service]
	Type=simple
	Restart=always
	RestartSec=1
	ExecStart=$SAVESYNC_toolPath --sync $emulationPath

	[Install]
	WantedBy=default.target" > "$SAVESYNC_systemd_path/emudeck_savesync.service"
	chmod +x "$SAVESYNC_systemd_path/emudeck_savesync.service"

	echo "Setting SaveSync service to start on boot"
	systemctl --user enable emudeck_savesync.service

	echo "Starting SaveSync Service. First run may take a while."
	systemctl --user start emudeck_savesync.service
}

if [[ $doSetupSaveSync == "true" ]]; then

	cloudProviders=()
	cloudProviders+=(1 "gdrive")
	cloudProviders+=(2 "dropbox")
	cloudProviders+=(3 "onedrive")
	cloudProviders+=(4 "box")
	cloudProviders+=(5 "nextcloud")

	syncProvider=$(zenity --list \
			--title="EmuDeck SaveSync Host" \
			--height=500 \
			--width=500 \
			--ok-label="OK" \
			--cancel-label="Exit" \
			--text="Choose the service you would like to use to host your cloud saves.\n\nKeep in mind they can take a fair amount of space.\n\nThis will open a browser window for you to sign into your chosen cloud provider." \
			--radiolist \
			--column="Select" \
			--column="Provider" \
			"${cloudProviders[@]}" 2>/dev/null)
	if [[ -n "$syncProvider" ]]; then
		SAVESYNC_install
		SAVESYNC_setup "$syncProvider"
	fi
fi

