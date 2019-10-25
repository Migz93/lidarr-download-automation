#!/bin/bash
#####################################################################################################
#                                  Lidarr Download Automation Script                                #
#                                         (SMLoadr / d-fi)                                          #
#####################################################################################################
#                                           Script Start                                            #
#####################################################################################################

ArtistsLidarrReq(){
	wantit=$(curl -s --header "X-Api-Key:"${LidarrApiKey} --request GET  "$LidarrUrl/api/v1/Artist/")
}
GetTotalArtistsLidarrReq(){
	TotalLidArtistNames=$(echo "${wantit}"|jq -r '.[].sortName' |wc -l  )
}
ProcessArtistsLidarrReq(){
	LidArtistID=$(echo "${wantit}" | jq -r .[$i].id)
	LidArtistName=$(echo "${wantit}" | jq -r .[$i].sortName)
	LidArtistNameCap=$(echo "${wantit}" | jq -r .[$i].artistName)
	LidArtistPath=$(echo "${wantit}" | jq -r .[$i].path)
	LidAlbumName=$(echo "${wantit}" | jq -r ".[$i].lastAlbum.title")	
	#M1 -- retrieve deezer artist id -- from lidarr
	DeezerArtistURL=$(echo "${wantit}" | jq ".[$i].links[] "|jq -r 'select(.name=="deezer")|.url')
	DeezerArtistID=$(printf -- "%s" "${DeezerArtistURL##*/}")
	if [ "$LidAlbumName" = "null" ]; then
		if [ "${DeezerArtistURL}" = "" ] || [ "${DeezerArtistID}" = "" ]; then
			##M2 fallback -- retrieve deezer artist id -- from deezer
			#Encode searchQuery in a url encodable format.
			DeezerArtistID=$(curl -s --GET --data-urlencode q="${LidArtistName}" "https://api.deezer.com/search" | jq -r ".data | .[]|.artist|.id" |uniq -c|sort -nr |head -n1 | awk '{print $2}')
			DeezerArtistURL="https://www.deezer.com/artist/"${DeezerArtistID}
		fi
	else
		if [ "${DeezerArtistURL}" = "" ] || [ "${DeezerArtistID}" = "" ]; then
			##M3 fallback -- retrieve deezer artist id using last album-- from deezer
			DeezerArtistID=$(curl -s --GET --data-urlencode q="${LidArtistName} ${LidAlbumName}" "https://api.deezer.com/search" | jq -r ".data | .[]|.artist|.id" |uniq -c|sort -nr |head -n1 | awk '{print $2}')
			DeezerArtistURL="https://www.deezer.com/artist/"${DeezerArtistID}
		fi
	fi
##returns the wanted artists id -- from lidarr or deezer
}

AlbumsLidarrReq(){
	wantit=$(curl -s --header "X-Api-Key:"${LidarrApiKey} --request GET  "$LidarrUrl/api/v1/wanted/missing/?page=1&pagesize=${WantedAlbumsAmount}&includeArtist=true&monitored=true&sortDir=desc&sortKey=releaseDate")
}
GetTotalAlbumsLidarrReq(){
	TotalLidAlbumsNames=$(echo "${wantit}"|jq -r '.records[].title' |wc -l  )
}

ProcessAlbumsLidarrReq(){
	LidArtistName=$(echo "${wantit}" | jq -r .records[${i}].artist.sortName)
	LidArtistDLName=$(echo "${wantit}" | jq -r .records[${i}].artist.artistName)
	LidAlbumName=$(echo "${wantit}" | jq -r .records[${i}].title)
	LidArtistPath=$(echo "${wantit}" | jq -r .records[${i}].artist.path)
	#M1 -- retrieve deezer artist id -- from lidarr
	DeezerArtistURL=$(echo "${wantit}" | jq -r .records[${i}].artist.links[] |jq -r 'select(.name=="deezer")|.url');
	DeezerArtistID=$(printf -- "%s" "${DeezerArtistURL##*/}")
	if [ "${DeezerArtistURL}" = "" ] || [ "${DeezerArtistID}" = "" ]; then
		##M2 fallback -- retrieve deezer artist id -- from deezer
		#Encode searchQuery in a url encodable format.
		DeezerArtistID=$(curl -s --GET --data-urlencode q="${LidArtistName}" "https://api.deezer.com/search" | jq -r ".data | .[]|.artist|.id" |uniq -c|sort -nr |head -n1 | awk '{print $2}')
	fi
##returns the wanted artists id -- from lidarr or deezer
}

QueryAlbumURL(){
	##retrieve all albums for artist -- from deezer
	searchQuery="https://api.deezer.com/artist/${DeezerArtistID}/albums&limit=1000"
	DeezerDiscog=$(curl -s "${searchQuery}"| jq -r .);
	DeezerDiscogTotal=$(echo "${DeezerDiscog}" |jq -r '.total')
	mapfile -t DeezerDiscogArr <<< $(echo ${DeezerDiscog}|jq -c '.[][]?.title')
	##match the wanted album title -- from deezer
	for ((x=0;x<=DeezerDiscogTotal-1;x++)); do
		DeezerDiscogAlbumName=$(echo "${DeezerDiscog}" |jq ".[]|.[$x]?"|jq -r .title )
		if [ "${LidAlbumName,,}" = "${DeezerDiscogAlbumName,,}" ];then
			DeezerAlbumURL=$(echo "${DeezerDiscog}" |jq ".[]|.[$x]?"|jq -r .link )
			break
		fi
	done
	if [ -z "${DeezerAlbumURL}" ] && [ "${EnableFuzzyAlbumSearch}" = True ];then
		logit "Trying fuzzy search"
		SanArtist="${LidArtistName// /%20}"
		SanAlbum="${LidAlbumName// /%20}"
		searchQuery="q=artist:\"${SanArtist//[^[:alnum:]%]}\"&q=album:\"${SanAlbum//[^[:alnum:]%]}\""
		searchQuery="https://api.deezer.com/search?${searchQuery}"
		DeezerDiscogFuzzy=$(curl -s "${searchQuery}");
		DeezerAlbumID=$(echo "${DeezerDiscogFuzzy}" |jq '.[]|.[]?'|jq -r --argjson  DeezerArtistID "$DeezerArtistID" 'select(.artist.id==$DeezerArtistID) |.album.id'|sort -u|head -n1)
		if [ -n "${DeezerAlbumID}" ];then
			DeezerAlbumURL="https://www.deezer.com/album/${DeezerAlbumID}"
			logit "Fuzzy search match ${DeezerAlbumURL}"
		fi
			logit "Fuzzy search cant find a match"
	fi
##returns wanted album URL -- from deezer
}

DownloadURL(){
	DLURL=${1}
	logit "Starting Download ... "
	if [ ! -f SMLoadr-linux-x64 ]; then
		logit "SMLoadr-Linux-x64 not found, using \"d-fi\""
		if [ ! -f d-fi ]; then
			rm "d-fi.zip" 2>/dev/null
			logit "downloading \"d-fi\"..."
			curl -o d-fi.zip https://notabug.org/attachments/43e8fbbf-6b4e-4353-8890-97b9622ada8f
			logit "download complete"
			unzip "d-fi.zip" 2>/dev/null
			rm "d-fi.zip"
		fi
		if [ "${Quality}" = FLAC ]; then
			aquality="FLAC"
		fi
		if [ "${Quality}" = MP3_320 ]; then
			aquality="320"
		fi
		if [ "${Quality}" = MP3_128 ]; then
			aquality="128"
		fi
		chmod +x "d-fi" 2>/dev/null
		./d-fi -q ${aquality} -p "${DownloadDir}/files/" "${DLURL}"
		move=($(find "${DownloadDir}"/files/* -type d -not -name "*(WEB)-DFI"))
		for m in "${move[@]}"; do
			if [[ ! -d "${m} (WEB)-DFI" ]]; then
				mv "${m}" "${m} (WEB)-DFI"
			else
				logit "\"${m} (WEB)-DFI\" Already exists, removing duplicate"
				rm -rf "${m}"
			fi
		done
	else
		chmod +x "SMLoadr-linux-x64" 2>/dev/null
     		timeout --foreground $Timeout ./SMLoadr-linux-x64 -q ${Quality} -p "${DownloadDir}/files/" "${DLURL}" && DownloadComplete="Yes"
		if [ $? == "124" ]; then
			logit "Download Timeout, retrying 1 more time..." && timeout --foreground $Timeout ./SMLoadr-linux-x64 -q ${Quality} -p "${DownloadDir}/files/" "${DLURL}"
		fi
		move=($(find "${DownloadDir}"/files/* -type d -not -name "*(WEB)-SMLOADR"))
		for m in "${move[@]}"; do
			if [[ ! -d "${m} (WEB)-SMLOADR" ]]; then
				mv "${m}" "${m} (WEB)-SMLOADR"
			else
				logit "\"${m} (WEB)-SMLOADR\" Already exists, removing duplicate"
				rm -rf "${m}"
			fi
		done
	fi
	logit "Download Complete"
	echo "${DLURL}" >> "${LogDir}"/${DownloadLogName}
	Permissions "${DownloadDir}"
}

Permissions () {
	logit "Setting Permissions"
	find "${1}/files/" -type d -exec chmod ${FolderPermissions} {} \;
	find "${1}/files/" -type f -exec chmod ${FilePermissions} {} \;
}

Convert () {
	if [ -x "$(command -v ffmpeg)" ]; then
		if [ "${ConversionFormat}" = OPUS ]; then
			echo "OPUS CONVERSION START"
			find "${DownloadDir}/files/" -name "*.flac" | sed -e 's/.flac$//' -e "s/'/\\'/g" -e 's/\$/\\$/g' | xargs -d '\n' -n1 -I@ -P ${Threads} bash -c "ffmpeg -loglevel warning -hide_banner -stats -i \"@.flac\" -n -vn -acodec libopus -ab 160k -application audio \"@.opus\" && echo \"CONVERSION SUCCESS: @.opus\" && rm \"@.flac\" && echo \"SOURCE FILE DELETED: @.flac\"" && echo "OPUS CONVERSION COMPLETE"	
			FileTypeExtension="opus"
		fi
		if [ "${ConversionFormat}" = AAC ]; then
			echo "AAC CONVERSION START"
			find "${DownloadDir}/files/" -name "*.flac" | sed -e 's/.flac$//' -e "s/'/\\'/g" -e 's/\$/\\$/g' | xargs -d '\n' -n1 -I@ -P ${Threads} bash -c "ffmpeg -loglevel warning -hide_banner -stats -i \"@.flac\" -n -vn -acodec libfdk_aac -ab 320k -movflags faststart \"@.m4a\" && echo \"CONVERSION SUCCESS: @.m4a\" && rm \"@.flac\" && echo \"SOURCE FILE DELETED: @.flac\"" && echo "AAC CONVERSION COMPLETE"	
			FileTypeExtension="m4a"
		fi			
		if [ "${ConversionFormat}" = MP3 ]; then
			echo "MP3 CONVERSION START"
			find "${DownloadDir}/files/" -name "*.flac" | sed -e 's/.flac$//' -e "s/'/\\'/g" -e 's/\$/\\$/g' | xargs -d '\n' -n1 -I@ -P ${Threads} bash -c "ffmpeg -loglevel warning -hide_banner -stats -i \"@.flac\" -n -vn -acodec libmp3lame -ab 320k \"@.mp3\" && echo \"CONVERSION SUCCESS: @.mp3\" && rm \"@.flac\" && echo \"SOURCE FILE DELETED: @.flac\"" && echo "MP3 CONVERSION COMPLETE"
			FileTypeExtension="flac"
		fi
		if [ "${ConversionFormat}" = FLAC ]; then
			echo "FLAC CONVERSION START"
			find "${DownloadDir}/files/" -name "*.flac" | sed -e 's/.flac$//' -e "s/'/\\'/g" -e 's/\$/\\$/g' | xargs -d '\n' -n1 -I@ -P ${Threads} bash -c "ffmpeg -loglevel warning -hide_banner -stats -i \"@.flac\" -n -vn -acodec flac \"@.temp.flac\" && echo \"CONVERSION SUCCESS: @.flac\" && rm \"@.flac\" && mv \"@.temp.flac\" \"@.flac\" && echo \"SOURCE FILE DELETED: @.flac\"" && echo "FLAC CONVERSION COMPLETE"
			FileTypeExtension="flac"
		fi
	else
		logit "FFMPEG not installed, please install ffmpeg to use this conversion feature"
		FileTypeExtension="flac"
		sleep 5s
	fi
}

Verify () {
	logit "START VERIFICATION"
	if ! [ -x "$(command -v flac)" ]; then
		logit "ERROR: FLAC verification utility not installed (ubuntu: apt-get install -y flac)"
	else
		if find "${DownloadDir}/files/" -name "*.flac"  | read;	then
			find "${DownloadDir}/files/" -name "*.flac" -newer "${DownloadDir}/temp-hold" | sed -e "s/'/\\'/g" -e 's/\$/\\$/g' | xargs -d '\n' -n1 -I@ -P ${Threads} bash -c "if flac -t --totally-silent \"@\"; then echo \"FLAC CHECK PASSED: @\"; else rm \"@\" && echo \"FAILED FLAC CHECK, FILE DELETED: @\"; fi;" && logit "FLAC FILES VERIFIED"
		fi
	fi
	if ! [ -x "$(command -v mp3val)" ]; then
		logit "MP3VAL verification utility not installed (ubuntu: apt-get install -y mp3val)"
	else
		if find "${DownloadDir}/files/" -name "*.mp3"  | read; then
			find "${DownloadDir}/files/" -name "*.mp3" -newer "${DownloadDir}/temp-hold" | sed -e "s/'/\\'/g" -e 's/\$/\\$/g' | xargs -d '\n' -n1 -I@ -P ${Threads} bash -c "mp3val -f -nb \"@\"" && logit "MP3 FILES VERIFIED"
		fi
	fi
	logit "VERIFICATION COMPLETE"
}

Replaygain () {
	logit "START REPLAYGAIN TAGGING"
	if ! [ -x "$(command -v mp3val)" ]; then
		logit "ERROR: METAFLAC replaygain utility not installed (ubuntu: apt-get install -y flac)"
	else
		find "${DownloadDir}/files/" -name "*.flac" -newer "${DownloadDir}/temp-hold" -printf '%h\n' | sort -u | sed -e "s/'/\\'/g" -e 's/\$/\\$/g' | xargs -d '\n' -n1 -I@ -P ${Threads} bash -c "find \"@\" -name \"*.flac\" -exec metaflac --add-replay-gain \"{}\" + && echo \"TAGGED: @\""
	fi
	logit "REPLGAINGAIN TAGGING COMPLETE"
}

DeleteDownloadLog () {
	if [ "${ClearDownloadLog}" = True ]; then
		if [ -a "${LogDir}"/${DownloadLogName} ]; then
			rm "${LogDir}"/${DownloadLogName}
		else
			logit "No Download log to clear"
		fi
	else
		logit "ClearDownloadLog is disabled"
	fi
	if [ ! -a "${LogDir}"/${DownloadLogName} ]; then
		touch "${LogDir}"/${DownloadLogName} && logit "${DownloadLogName} created..."
	fi
}

CleanStart(){
	if [ "${CleanStart}" = True ]; then
		logit "Removing previously downloaded files from SMLoadr downloads directory".
		rm -rf "${DownloadDir}"/files/*
	else
		logit "Skipping CleanStart"
	fi
}

Cleanup(){
	if [ "${KeepOnly}" = True ]; then
		if [ "${Quality}" = FLAC ]; then
			logit "Removing unwanted MP3's"
			find "${DownloadDir}"/. -iname "*.mp3" -type f -delete
		else
			logit "Removing unwanted FLAC's"
			find "${DownloadDir}"/. -type f -iname "*.flac" -type f -delete
		fi
	else
		logit "Skipping KeepOnly Quality Cleanup"
	fi
	if [ "${CannotImport}" = True ]; then
		logit "Removing files that cannot be imported to Lidarr and empty folders"
		find "${DownloadDir}"/. -type f -iname "*.lrc" -type f -delete
		find "${DownloadDir}"/. -type f -iname "*.jpg" -type f -delete
		find "${DownloadDir}"/ -empty -type d -delete
	else
		logit "Skipping Unwanted file removal"
	fi
}

LidarrProcess(){
	dlloc=($(find "${DownloadDir}" -type f -iregex ".*/.*\.\(flac\|mp3\|opus\|m4a\)" -printf '%h\n' | sed -e "s/'/\\'/g" -e 's/\$/\$/g' | sort -u))
	for d in "${dlloc[@]}"; do
		if [ "${EnableWSLMode}" = True ];then
			dwrap=($( echo "${d}"|sed -e 's/mnt\///' -e 's/^\///' -e 's/^./\0:/' -e 's/\//\\\\/g' -e 's/^/\"/g' -e 's/$/\"/g'))
		else
			dwrap=($( echo "${d}"|sed -e 's/^/\"/g' -e 's/$/\"/g'))
		fi
		if ! cat "${LogDir}/${SentToLidarrLogName}" | grep "${dwrap}" | read; then
			logit "Sending ${dwrap} to Lidarr for post processing"
			LidarrProcessIt=$(curl -s "$LidarrUrl/api/v1/command" --header "X-Api-Key:"${LidarrApiKey} --data '{"name":"DownloadedAlbumsScan", "path":'"${dwrap}"'}' );
			echo ${dwrap} >> "${LogDir}/${SentToLidarrLogName}"
		fi
	done
	sleep 3s
}

ExternalProcess(){
	logit "Moving downloads for external post processing."
	dlloc="${DownloadDir}"/*
	for d in $dlloc; do
		mv "$d" "${ExternalProcessDirectory}"
	done
	rm -rf "${DownloadDir}"/*
	sleep 3s
}

LidarrImport () {
	if [ ! -d "${LidArtistPath}" ];	then
		logit "Destination Does not exist, creating ${LidArtistPath}"
		mkdir "${LidArtistPath}"
		chmod ${FolderPermissions} "${LidArtistPath}"
	fi
	find "${DownloadDir}/files/" -type f -iregex ".*/.*\.\(flac\|mp3\|opus\|m4a\)" -printf '%h\n' | sort -u | sed -e "s/'/\\'/g" -e 's/\$/\\$/g' | xargs -d '\n' -n1 -I@ -P ${Threads} bash -c "mv \"@\" \"${LidArtistPath}/\" 2>/dev/null"
	logit "Moved to Lidarr"
	Permissions "${LidArtistPath}"
	LidarrProcessIt=$(curl -s $LidarrUrl/api/v1/command -X POST -d "{\"name\": \"RefreshArtist\", \"artistID\": \"${LidArtistID}\"}" --header "X-Api-Key:${LidarrApiKey}" );
	logit "Notified Lidarr to scan ${LidArtistNameCap}"
	rm -rf "${DownloadDir}/files"
}

ErrorExit(){
	case ${2} in
		2)	echo ${1};exit ${2};;
		144)	echo ${1};exit ${2};;
		*)	echo ${1} |tee -a "${LogDir}"/${LogName};exit ${2};;
	esac
}

logit(){
	echo ${1} | tee -a "${LogDir}"/${LogName}
}

skiplog(){
	echo ${1} | tee -a "${LogDir}"/${SkipLogName}
}

InitLogs(){
	echo "Beginning Log" |tee "${LogDir}"/${LogName} || ErrorExit "Cant create log file" 144
	echo "LidArtistName;DeezerArtistID;DeezerArtistURL;LidAlbumName;DeezerDiscog" |tee "${LogDir}"/${SkipLogName} || ErrorExit "Cant create skiplog file" 144
}

WantedModeBegin(){
	AlbumsLidarrReq
	GetTotalAlbumsLidarrReq
	let loopindex=TotalLidAlbumsNames-1
	[ ${loopindex} = "-1" ] && ErrorExit "Lidarr communication error, check LidarrUrl in config or LidarrApiKey"
	logit "Going to process and download ${TotalLidAlbumsNames} records"
	for ((i=0;i<=(loopindex);i++)); do
			logit ""
			LidArtistName=""
			LidArtistDLName=""
			DeezerArtistID=""
			DeezerArtistURL=""
			LidAlbumName=""
			DeezerDiscogAlbumName=""
			DeezerAlbumURL=""
			DeezerAlbumID=""
		echo "-Processing ${i} of ${loopindex}"
		if [ -n "${wantit}" ]; then
			ProcessAlbumsLidarrReq
			logit "ArtistName: ${LidArtistDLName}"
			logit "LidarrAlbumName: ${LidAlbumName}"
			logit "ArtistID: ${DeezerArtistID}"
		else
			ErrorExit "Lidarr communication error, check LidarrUrl in config or LidarrApiKey"
		fi
		echo "Querying ${i} of ${loopindex}"
		if [ -n "${DeezerArtistID}" ] || [ -n "${LidArtistName}" ] || [ -n "${LidAlbumName}" ]; then
			QueryAlbumURL
			logit "DeezerAlbumName: ${DeezerDiscogAlbumName}"
			logit "DeezerAlbumURL: ${DeezerAlbumURL}"
		else
			logit "Cant get artistname or artistid or albumname .. skipping"
			skiplog "${LidArtistName};${DeezerArtistID};${DeezerArtistURL};${LidAlbumName}"
			continue
		fi
		if [ -n "${DeezerAlbumURL}" ]; then
			if [ "${PreviouslyDownloaded}" = True ] && cat "${LogDir}/${DownloadLogName}" | grep "${DeezerAlbumURL}" | read
				then 
					logit "Previously Downloaded, skipping..."
					sleep 1s
				else
					rm "${DownloadDir}/temp-hold" 2>/dev/null
					touch "${DownloadDir}/temp-hold"
					sleep 1s
					DownloadURL "${DeezerAlbumURL}"
					if [ "${Verification}" = True ]; then
						Verify
					else
						logit "Skipping File Verification"
					fi
					if [ "${Convert}" = True ]; then
						Convert
					else
						logit "Skipping FLAC Conversion"
					fi
					if [ "${ReplaygainTagging}" = True ]; then
						Replaygain
					else
						logit "Skipping Replaygain Tagging"
					fi
					Cleanup
					if [ "${AppProcess}" = External ]; then
						ExternalProcess
					elif [ "${AppProcess}" = Lidarr ]; then
						LidarrProcess
					elif [ "${AppProcess}" = AllDownloads ]; then
						LidarrImport
					else
						logit "Skipping Any Processing"
					fi
					rm "${DownloadDir}/temp-hold"
			fi
		else
			logit "Cant match the wanted album to an album on deezer .. skipping"
			skiplog "${LidArtistName};${DeezerArtistID};${DeezerArtistURL};${LidAlbumName};${DeezerDiscogArr[*]}"
			continue
		fi
	done
}

ArtistModeBegin(){
	ArtistsLidarrReq
	GetTotalArtistsLidarrReq
	let loopindex=TotalLidArtistNames-1
	[ ${loopindex} = "-1" ] && ErrorExit "Lidarr communication error, check LidarrUrl in config or LidarrApiKey"
	logit "Going to process and download ${TotalLidArtistNames} records"
	for ((i=0;i<=(loopindex);i++)); do
		logit ""
		DeezerArtistID=""
		DeezerArtistURL=""
		echo "Processing ${i} of ${loopindex}"
		if [ -n "${wantit}" ]; then
			ProcessArtistsLidarrReq
			logit "ArtistName: ${LidArtistNameCap}"
			logit "ArtistID: ${DeezerArtistID}"
		else
			ErrorExit "Lidarr communication error, check LidarrUrl in config or LidarrApiKey"
		fi
		echo "-Querying ${i} of ${loopindex}"
		if [ -n "${DeezerArtistID}" ] || [ -n "${LidArtistName}" ] || [ -n "${DeezerArtistURL}" ]; then
			if [ ${DeezerArtistURL} = "https://www.deezer.com/artist/" ];then
				logit "Cant get DeezerArtistURL or artistid.. skipping"
				skiplog "${LidArtistName};${DeezerArtistID};${DeezerArtistURL};${LidAlbumName}"
				continue
			fi
			if [ "${PreviouslyDownloaded}" = True ] && cat "${LogDir}/${DownloadLogName}" | grep "artist/${DeezerArtistID}" | read
				then 
					logit "Previously Downloaded, skipping..."
					sleep 1s
				else
					rm "${DownloadDir}/temp-hold" 2>/dev/null
					touch "${DownloadDir}/temp-hold"
					sleep 1s
					DownloadURL "${DeezerArtistURL}"
					logit "DeezerArtistURL: ${DeezerArtistURL}"
					Cleanup
					if [ "${Verification}" = True ]; then
						Verify
					else
						logit "Skipping File Verification"
					fi
					if [ "${Convert}" = True ]; then
						Convert
					else
						logit "Skipping FLAC Conversion"
					fi
					if [ "${ReplaygainTagging}" = True ]; then
							Replaygain
						else
							logit "Skipping Replaygain Tagging"
					fi
					if [ "${AppProcess}" = External ]; then
						ExternalProcess
					elif [ "${AppProcess}" = Lidarr ]; then
						LidarrProcess
					elif [ "${AppProcess}" = AllDownloads ]; then
						LidarrImport
					else
						logit "Skipping Any Processing"
					fi
					rm "${DownloadDir}/temp-hold"
			fi
		else
			logit "Cant get artistname or or DeezerArtistURL or artistid.. skipping"
			skiplog "${LidArtistName};${DeezerArtistID};${DeezerArtistURL};${LidAlbumName}"
			continue
		fi
	done
}

CheckdlPath(){
if [ -d ${DownloadDir} ] && [ -w ${DownloadDir} ]; then
	dlcontento=($(find "${DownloadDir}" -maxdepth 1 -type d -not -path "${DownloadDir}"))
else
	# ErrorExit "download directory not writeable or doesnt exist ${DownloadDir}"
	logit "Creating Download Directory"
	mkdir "${DownloadDir}"
	chmod ${FolderPermissions} "${DownloadDir}"
fi
}

CheckLogPath(){
if [ -d ${LogDir} ] && [ -w ${LogDir} ]; then
	logcontentto=($(find "${LogDir}" -maxdepth 1 -type d -not -path "${LogDir}"))
else
	# ErrorExit "download directory not writeable or doesnt exist ${LogDir}"
	logit "Creating Download Directory"
	mkdir "${LogDir}"
	chmod ${FolderPermissions} "${LogDir}"
fi
}

main(){
	OLDIFS=$IFS
	IFS=$'\n'
	echo "Starting up"
	source ./config || ErrorExit "Configuration file not found" 2
	CheckLogPath
	InitLogs
	CleanStart
	CheckdlPath
	DeleteDownloadLog
	rm "${DownloadDir}/temp-hold" 2>/dev/null
	rm "${LogDir}/${SentToLidarrLogName}" 2>/dev/null
	logit "Creating ${LogDir}/${SentToLidarrLogName} to prevent duplicate Lidarr Notifications"
	touch "${LogDir}/${SentToLidarrLogName}" && logit "${SentToLidarrLogName} created..."
	case "${Mode}" in
		wanted)	WantedModeBegin;;
		artist) ArtistModeBegin;;
		*) logit "Mode error, check Mode variable in config valid = wanted/artist" ;;
	esac
	rm "${LogDir}/${SentToLidarrLogName}" 2>/dev/null
	IFS=$OLDIFS
}

main ${@}

#####################################################################################################
#                                              Script End                                           #
#####################################################################################################
exit 0
