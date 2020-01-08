#!/bin/bash
#####################################################################################################
#                                  Lidarr Download Automation Script                                #
#                                          (Deezloader Remix)                                       #
#                                    Credit: RandomNinjaAtk, Migz93                                 #
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
	MBArtistID=$(echo "${wantit}" | jq -r .[$i].foreignArtistId)
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
	wantit=$(curl -s --header "X-Api-Key:"${LidarrApiKey} --request GET  "$LidarrUrl/api/v1/wanted/${WantedModeType}/?page=1&pagesize=${WantedAlbumsAmount}&includeArtist=true&monitored=true&sortDir=desc&sortKey=releaseDate")
}
GetTotalAlbumsLidarrReq(){
	TotalLidAlbumsNames=$(echo "${wantit}"|jq -r '.records[].title' |wc -l  )
}

ProcessAlbumsLidarrReq(){
	LidArtistName=$(echo "${wantit}" | jq -r .records[${i}].artist.sortName)
	LidArtistDLName=$(echo "${wantit}" | jq -r .records[${i}].artist.artistName)
	LidArtistNameCap=$(echo "${wantit}" | jq -r .records[${i}].artist.artistName)
	LidAlbumName=$(echo "${wantit}" | jq -r .records[${i}].title | iconv -f UTF-8 -t ASCII//TRANSLIT | tr '[:upper:]' '[:lower:]' | tr -cd '[:print:]' | tr -d '[:punct:]' | tr -s '[:space:]' )
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
		DeezerDiscogAlbumName=$(echo "${DeezerDiscog}" |jq ".[]|.[$x]?"|jq -r .title | iconv -f UTF-8 -t ASCII//TRANSLIT | tr '[:upper:]' '[:lower:]' | tr -cd '[:print:]' | tr -d '[:punct:]' | tr -s '[:space:]' )
		if [ "${LidAlbumName,,}" = "${DeezerDiscogAlbumName,,}" ];then
			DeezerAlbumURL=$(echo "${DeezerDiscog}" |jq ".[]|.[$x]?"|jq -r .link )
			break
		fi
	done
	if [ -z "${DeezerAlbumURL}" ] && [ "${EnableFuzzyAlbumSearch}" = True ];then
		logit "Trying fuzzy search"
		SanArtist="${LidArtistName// /%20}"
		SanAlbum="${LidAlbumName// /%20}"
		if [ "${LidArtistName}" = "various artists" ]; then 
			searchQuery="q=album:\"${SanAlbum//[^[:alnum:]%]}\""
		else
			searchQuery="q=artist:\"${SanArtist//[^[:alnum:]%]}\"&q=album:\"${SanAlbum//[^[:alnum:]%]}\""
		fi
		searchQuery="https://api.deezer.com/search?${searchQuery}"
		DeezerDiscogFuzzy=$(curl -s "${searchQuery}");
		if [ "${LidArtistName}" = "various artists" ]; then 
			DeezerAlbumID=$(echo "${DeezerDiscogFuzzy}" | jq -r ".data | .[] | .album | .id" | sort -u|head -n1)
		else
			DeezerAlbumID=$(echo "${DeezerDiscogFuzzy}" |jq '.[]|.[]?'|jq -r --argjson  DeezerArtistID "$DeezerArtistID" 'select(.artist.id==$DeezerArtistID) |.album.id'|sort -u|head -n1)
		fi		
		if [ -n "${DeezerAlbumID}" ];then
			DeezerAlbumURL="https://www.deezer.com/album/${DeezerAlbumID}"
			logit "Fuzzy search match ${DeezerAlbumURL}"
		else
			logit "Fuzzy search cant find a match"
		fi
	fi
##returns wanted album URL -- from deezer
}

DownloadURL(){
	DLURL=${1}
	check=1
	if curl -s --request GET  "${DeezloaderRemixUrl}/api/download/?url=${DLURL}&quality=${Quality}" >/dev/null; then
		logit "Sent ${DLURL} for download via Deezloader Remix"
		sleep 3s
		while [[ "$check" -le 1 ]]; do
			if curl -s --request GET "${DeezloaderRemixUrl}/api/queue/" | grep "length\":0,\"items\":\[\]" >/dev/null; then
				check=2
				logit "Download Complete"
				move=($(find "${DownloadDir}"/* -type d -not -name "*(WEB)-DREMIX"))
				for m in "${move[@]}"; do
					if [[ ! -d "${m} (WEB)-DREMIX" ]]; then
						mv "${m}" "${m} (WEB)-DREMIX"
					else
						logit "\"${m} (WEB)-DREMIX\" Already exists, removing duplicate"
						rm -rf "${m}"
					fi
				done
				logit "${LidArtistNameCap}: ${DLURL}" >> "${LogDir}"/${DownloadLogName}
				Permissions "${DownloadDir}"
			else 
				logit "still downloading... $URL"
				sleep 2s
			fi
		done

	
	else
	    logit "Deezloader-Remix Download Error"
	fi
}

Permissions () {
	logit "Setting Permissions"
	find "${1}/" -type d -exec chmod ${FolderPermissions} {} \;
	find "${1}/" -type f -exec chmod ${FilePermissions} {} \;
}

Convert () {
	if [ -x "$(command -v ffmpeg)" ]; then
		if [ "${ConversionFormat}" = OPUS ]; then
			logit "OPUS CONVERSION START"
			find "${DownloadDir}/" -name "*.flac" -newer "${DownloadDir}/temp-hold" | sed -e 's/.flac$//' -e "s/'/\\'/g" -e 's/\$/\\$/g' | xargs -d '\n' -n1 -I@ -P ${Threads} bash -c "ffmpeg -loglevel warning -hide_banner -stats -i \"@.flac\" -n -vn -acodec libopus -ab 128k -application audio \"@.opus\" && echo \"CONVERSION SUCCESS: @.opus\" && rm \"@.flac\" && echo \"SOURCE FILE DELETED: @.flac\"" && logit "OPUS CONVERSION COMPLETE"	
		fi
		if [ "${ConversionFormat}" = AAC ]; then
			logit "AAC CONVERSION START"
			find "${DownloadDir}/" -name "*.flac" -newer "${DownloadDir}/temp-hold" | sed -e 's/.flac$//' -e "s/'/\\'/g" -e 's/\$/\\$/g' | xargs -d '\n' -n1 -I@ -P ${Threads} bash -c "ffmpeg -loglevel warning -hide_banner -stats -i \"@.flac\" -n -vn -acodec aac -ab 320k -movflags faststart \"@.m4a\" && echo \"CONVERSION SUCCESS: @.m4a\" && rm \"@.flac\" && echo \"SOURCE FILE DELETED: @.flac\"" && logit "AAC CONVERSION COMPLETE"	
		fi			
		if [ "${ConversionFormat}" = MP3 ]; then
			logit "MP3 CONVERSION START"
			find "${DownloadDir}/" -name "*.flac" -newer "${DownloadDir}/temp-hold" | sed -e 's/.flac$//' -e "s/'/\\'/g" -e 's/\$/\\$/g' | xargs -d '\n' -n1 -I@ -P ${Threads} bash -c "ffmpeg -loglevel warning -hide_banner -stats -i \"@.flac\" -n -vn -acodec libmp3lame -ab 320k \"@.mp3\" && echo \"CONVERSION SUCCESS: @.mp3\" && rm \"@.flac\" && echo \"SOURCE FILE DELETED: @.flac\"" && logit "MP3 CONVERSION COMPLETE"
		fi
		if [ "${ConversionFormat}" = FLAC ]; then
			logit "FLAC CONVERSION START"
			find "${DownloadDir}/" -name "*.flac" -newer "${DownloadDir}/temp-hold" | sed -e 's/.flac$//' -e "s/'/\\'/g" -e 's/\$/\\$/g' | xargs -d '\n' -n1 -I@ -P ${Threads} bash -c "ffmpeg -loglevel warning -hide_banner -stats -i \"@.flac\" -n -vn -acodec flac \"@.temp.flac\" && echo \"CONVERSION SUCCESS: @.flac\" && rm \"@.flac\" && mv \"@.temp.flac\" \"@.flac\" && echo \"SOURCE FILE DELETED: @.flac\"" && logit "FLAC CONVERSION COMPLETE"
		fi
		if [ "${ConversionFormat}" = ALAC ]; then
			logit "ALAC CONVERSION START"
			find "${DownloadDir}/" -name "*.flac" -newer "${DownloadDir}/temp-hold" | sed -e 's/.flac$//' -e "s/'/\\'/g" -e 's/\$/\\$/g' | xargs -d '\n' -n1 -I@ -P ${Threads} bash -c "ffmpeg -loglevel warning -hide_banner -stats -i \"@.flac\" -n -vn -acodec alac -movflags faststart \"@.m4a\" && rm \"@.flac\" && echo \"SOURCE FILE DELETED: @.flac\"" && logit "ALAC CONVERSION COMPLETE"
		fi
	else
		logit "FFMPEG not installed, please install ffmpeg to use this conversion feature"
		sleep 5s
	fi
}

Verify () {
	logit "START VERIFICATION"
	if ! [ -x "$(command -v flac)" ]; then
		logit "ERROR: FLAC verification utility not installed (ubuntu: apt-get install -y flac)"
	else
		if find "${DownloadDir}/" -name "*.flac"  | read; then
			find "${DownloadDir}/" -name "*.flac" -newer "${DownloadDir}/temp-hold" | sed -e "s/'/\\'/g" -e 's/\$/\\$/g' | xargs -d '\n' -n1 -I@ -P ${Threads} bash -c "if flac -t --totally-silent \"@\"; then echo \"FLAC CHECK PASSED: @\"; else rm \"@\" && echo \"FAILED FLAC CHECK, FILE DELETED: @\"; fi;" && logit "FLAC FILES VERIFIED"
		fi
	fi
	if ! [ -x "$(command -v mp3val)" ]; then
		logit "MP3VAL verification utility not installed (ubuntu: apt-get install -y mp3val)"
	else
		if find "${DownloadDir}/" -name "*.mp3"  | read; then
			find "${DownloadDir}/" -name "*.mp3" -newer "${DownloadDir}/temp-hold" | sed -e "s/'/\\'/g" -e 's/\$/\\$/g' | xargs -d '\n' -n1 -I@ -P ${Threads} bash -c "mp3val -f -nb \"@\"" && logit "MP3 FILES VERIFIED"
		fi
	fi
	logit "VERIFICATION COMPLETE"
}

Replaygain () {
	if ! [ -x "$(command -v flac)" ]; then
		logit "ERROR: METAFLAC replaygain utility not installed (ubuntu: apt-get install -y flac)"
	elif find "${DownloadDir}/" -name "*.flac" -newer "${DownloadDir}/temp-hold" | read; then
		logit "START REPLAYGAIN TAGGING"
		find "${DownloadDir}/" -name "*.flac" -newer "${DownloadDir}/temp-hold" -printf '%h\n' | sort -u | sed -e "s/'/\\'/g" -e 's/\$/\\$/g' | xargs -d '\n' -n1 -I@ -P ${Threads} bash -c "find \"@\" -name \"*.flac\" -exec metaflac --add-replay-gain \"{}\" + && echo \"TAGGED: @\""
		logit "REPLGAINGAIN TAGGING COMPLETE"
	fi
}

DeleteDownloadLog () {
	if [ "${ClearDownloadLog}" = True ]; then
		if [ -f "${LogDir}"/${DownloadLogName} ]; then
			rm "${LogDir}"/${DownloadLogName}
		else
			logit "No Download log to clear"
		fi
	elif [ ! -f "${LogDir}"/${DownloadLogName} ]; then
		touch "${LogDir}"/${DownloadLogName} && logit "${DownloadLogName} created..."
	fi
}

CleanStart(){
	if [ "${CleanStart}" = True ]; then
		logit "Removing previously downloaded files from downloads directory".
		rm -rf "${DownloadDir}"/*
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
	fi
	if [ "${CannotImport}" = True ]; then
		logit "Removing files that cannot be imported to Lidarr and empty folders"
		find "${DownloadDir}"/. -type f -iname "*.lrc" -type f -delete
		find "${DownloadDir}"/. -type f -iname "*.jpg" -type f -delete
		find "${DownloadDir}"/ -empty -type d -delete
	fi
}

LidarrProcess(){
    #INSERT
    if [ "$(ls -A "${DownloadDir}")" ]; then
        import=($(find "${DownloadDir}" -type f -iregex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" -newer "${DownloadDir}/temp-hold" -printf '%h\n' | sed -e "s/'/\\'/g" -e 's/\$/\$/g' | sort -u))
        for d in "${import[@]}"; do
            if [ "${EnableWSLMode}" = True ];then
                dwrap=($( echo "${d}"|sed -e 's/mnt\///' -e 's/^\///' -e 's/^./\0:/' -e 's/\//\\\\/g' -e 's/^/\"/g' -e 's/$/\"/g'))
            else
                dwrap=($( echo "${d}"|sed -e 's/^/\"/g' -e 's/$/\"/g'))
            fi
            logit "Sending ${dwrap} to Lidarr for post processing"
            LidarrProcessIt=$(curl -s "$LidarrUrl/api/v1/command" --header "X-Api-Key:"${LidarrApiKey} --data '{"name":"DownloadedAlbumsScan", "path":'"${dwrap}"'}' );
        done
    fi
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
	artistname="${LidArtistNameCap//\ /*}"
	if find "${DownloadDir}" -type d -iname "*(${DeezerArtistID}) - *" | read; then
		searchstring="*(${DeezerArtistID}) - *"
	elif find "${DownloadDir}" -type d -iname "*${artistname}* - *" -newer "${DownloadDir}/temp-hold" | read; then
		searchstring="${artistname} (*) - *"
	else
		searchstring="${artistname} (*) - *"
	fi
	if find "${DownloadDir}" -type d -iname "${searchstring}" | read; then
		if [ ! -d "${LidArtistPath}" ];	then
			logit "Destination Does not exist, creating ${LidArtistPath}"
			mkdir "${LidArtistPath}"
			chmod ${FolderPermissions} "${LidArtistPath}"
		fi
		find "${DownloadDir}" -type d -iname "${searchstring}" -print0 | while IFS= read -r -d '' folder; do
			if mv "$folder" "${LidArtistPath}/"; then
				logit "Moved \"$folder\" to \"${LidArtistPath}\" for import"
				Permissions "${LidArtistPath}"
				if [ "${DeDupe}" = True ]; then
					DeDupeProcess
				else
					logit "Skipping DeDupe of files"
				fi
				LidarrProcessIt=$(curl -s $LidarrUrl/api/v1/command -X POST -d "{\"name\": \"RefreshArtist\", \"artistID\": \"${LidArtistID}\"}" --header "X-Api-Key:${LidarrApiKey}" );
				logit "Notified Lidarr to scan ${LidArtistNameCap}"
			else
				logit "ERROR: \"$folder\" - Already exists in destination, deleting..."
				rm -rf "$folder"
			fi
		done
	elif find "${DownloadDir}" -type d -iname "*-DREMIX" -newer "${DownloadDir}/temp-hold" | read; then
		logit "Searching for downloaded files"
		logit "ERROR: Non-mathching files found, but not imported"
		logit "INFO: See: ${LogDir}/error.log for more detail..."
		find "${DownloadDir}" -type d -iname "*-DREMIX" -newer "${DownloadDir}/temp-hold" -print0 | while IFS= read -r -d '' folder; do
			logit "ERROR: Cannot Import, Artist does not match \"${searchstring}\", file: $folder" >> "${LogDir}"/error.log
		done
	fi
}

DeDupeProcess () {
	logit "Beginning DeDupe proceess"
	
	if find "${LidArtistPath}" -type d -not -iname "*Explicit*" -regex ".*([a-zA-Z]+) ([0-9]+) ([0-9]+) (WEB)-DREMIX$" | read; then
		logit "Clean albums found for renaming"
		find "${LidArtistPath}" -type d -not -iname "*Explicit*" -regex ".*([a-zA-Z]+) ([0-9]+) ([0-9]+) (WEB)-DREMIX$" -print0 | while IFS= read -r -d '' folder; do
			cleannewname="$(echo $folder | sed "s/([0-9]*) ([0-9]*) (WEB)-DREMIX$/(WEB)-DREMIX/g" | sed "s/(Explicit) //g")"
			if [ -d "$cleannewname" ]; then
				echo "Duplicate, deleting..."
				rm -rf "$folder"
				logit "Deleted: $folder"
			else
				logit "Original Name: $folder"
				logit "New Name: $cleannewname"
				mv "$folder" "$cleannewname"
				logit "Clean album renamed"
			fi

		done
		logit "Clean albums renamed and deduped..." 
	fi

	if find "${LidArtistPath}" -type d -iname "*Explicit*" -regex ".*([a-zA-Z]+) ([0-9]+) ([0-9]+) (WEB)-DREMIX$" | read; then
		logit "Finding explicit albums"
		logit "Explicit albums found, renaming and removing matched clean versions..."
		find "${LidArtistPath}" -type d -iname "*Explicit*" -regex ".*([a-zA-Z]+) ([0-9]+) ([0-9]+) (WEB)-DREMIX$" -print0 | while IFS= read -r -d '' folder; do
			explicitnewname="$(echo $folder | sed "s/([0-9]*) ([0-9]*) (WEB)-DREMIX$/(WEB)-DREMIX/g" | sed "s/(Explicit) //g")"
			if [ -d "$explicitnewname" ]; then
				logit "Clean version found, deleting..."
				rm -rf "$explicitnewname"
				logit "Renaming Explicit Album"
				logit "Original Name: $folder"
				logit "New Name: $explicitnewname"
				mv "$folder" "$explicitnewname"
			else
				logit "Renaming Explicit Album"
				logit "Original Name: $folder"
				logit "New Name: $explicitnewname"
				mv "$folder" "$explicitnewname"
			fi
		done
		logit "Renaming and cleanup of clean versions complete"
	fi
	
	if find "${LidArtistPath}" -type d -regex ".*([0-9]+) (WEB)-DREMIX$" | read; then
		logit "Finding folders that do not meet required naming pattern"
		logit "Folders found, cleaning up folders"
		find "${LidArtistPath}" -type d -regex ".*([0-9]+) (WEB)-DREMIX$" -print0 | while IFS= read -r -d '' folder; do
			rm -rf "$folder"
		done
		logit "Cleanup complete"
	elif find "${LidArtistPath}" -type d -iname "*(WEB)-DREMIX" -not -regex ".*([a-zA-Z]+) (WEB)-DREMIX$" | read; then
		logit "Folders found, cleaning up folders"
		find "${LidArtistPath}" -type d -iname "*(WEB)-DREMIX" -not -regex ".*([a-zA-Z]+) (WEB)-DREMIX$"  -print0 | while IFS= read -r -d '' folder; do
			rm -rf "$folder"
		done
	fi	
	logit "DeDupe processing complete"
}

DLArtistArtwork () {
	if [ -d "${LidArtistPath}" ];	then
		if [ ! -f "${LidArtistPath}/folder.jpg"  ]; then
			logit "Downloading artist artwork..."
			artistartwork=($(curl -s --GET "https://api.deezer.com/artist/${DeezerArtistID}" | jq -r '.picture_xl'))
			logit "Downloading: ${artistartwork}"
			curl -o "${LidArtistPath}/folder.jpg" ${artistartwork} && logit "Download success!"
			chmod ${FolderPermissions} "${LidArtistPath}"
			if find "${LidArtistPath}/folder.jpg" -type f -size -${MinArtistArtworkSize} | read; then
				logit "ERROR: Only artwork is smaller than \"${MinArtistArtworkSize}\", removing to allow lidarr to update it"
				rm "${LidArtistPath}/folder.jpg"
			else 
				echo "SUCCESS: Artwork downloaded successfully"
			fi
		fi
	fi
}

ErrorExit(){
	case ${2} in
		2)	echo ${1};exit ${2};;
		144)	echo ${1};exit ${2};;
		*)	echo ${1} |tee -a "${LogDir}"/${LogName};exit ${2};;
	esac
}

timestamp()
{
 date +"%Y-%m-%d %T"
}

logit(){
	echo "[INFO:$(timestamp)] ${1}" | tee -a "${LogDir}"/${LogName}
}

skiplog(){
	echo "[INFO:$(timestamp)] ${1}" | tee -a "${LogDir}"/${SkipLogName}
}

InitLogs(){
	logit "Beginning Log" |tee "${LogDir}"/${LogName} || ErrorExit "Cant create log file" 144
	logit "LidArtistName;DeezerArtistID;DeezerArtistURL;LidAlbumName;DeezerDiscog" |tee "${LogDir}"/${SkipLogName} || ErrorExit "Cant create skiplog file" 144
}

WantedModeBegin(){
	AlbumsLidarrReq
	GetTotalAlbumsLidarrReq
	let loopindex=TotalLidAlbumsNames-1
	[ ${loopindex} = "-1" ] && ErrorExit "Lidarr communication error, check LidarrUrl in config or LidarrApiKey"
	logit ""
	logit "${TotalLidAlbumsNames} Lidarr Records Found"
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
		logit "Processing ${i} of ${loopindex}"
		if [ -n "${wantit}" ]; then
			ProcessAlbumsLidarrReq
			logit "ArtistName: ${LidArtistDLName}"
			logit "LidarrAlbumName: ${LidAlbumName}"
			logit "ArtistID: ${DeezerArtistID}"
		else
			ErrorExit "Lidarr communication error, check LidarrUrl in config or LidarrApiKey"
		fi
		
		logit "Querying ${i} of ${loopindex}"
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
						
			if [ "${AppProcess}" = AllDownloads ]; then
				LidarrImport
			fi
			
			if [ "${PreviouslyDownloaded}" = True ] && cat "${LogDir}/${DownloadLogName}" | grep "${DeezerAlbumURL}" | read; then 
				logit "Previously Downloaded: ${DeezerAlbumURL}, skipping..."
			else
				if [ -f "${DownloadDir}/temp-hold"  ]; then					
					rm "${DownloadDir}/temp-hold"
				fi
				touch "${DownloadDir}/temp-hold"
				DownloadURL "${DeezerAlbumURL}"
				if [ "$(ls -A "${DownloadDir}")" ]; then
					Cleanup
					if [ "${Verification}" = True ]; then
						Verify
					fi
					if [ "${Convert}" = True ]; then
						Convert
					fi
					if [ "${ReplaygainTagging}" = True ]; then
						Replaygain
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
					if [ "${DownloadArtistArtwork}" = True ]; then 
						DLArtistArtwork
					fi
				fi
				if [ -f "${DownloadDir}/temp-hold"  ]; then					
					rm "${DownloadDir}/temp-hold"
				fi
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
	logit ""
	logit "${TotalLidArtistNames} Lidarr Records Found"
	for ((i=0;i<=(loopindex);i++)); do
		logit ""
		DeezerArtistID=""
		DeezerArtistURL=""
		currentartist=$(( $i + 1 ))
		logit "Processing $currentartist of $TotalLidArtistNames"
		if [ -n "${wantit}" ]; then
			ProcessArtistsLidarrReq
			logit "ArtistName: ${LidArtistNameCap}"
		else
			ErrorExit "Lidarr communication error, check LidarrUrl in config or LidarrApiKey"
		fi
		if [ -n "${DeezerArtistID}" ] || [ -n "${LidArtistName}" ] || [ -n "${DeezerArtistURL}" ]; then
			
			if [ ${DeezerArtistURL} = "https://www.deezer.com/artist/" ];then
				logit "ERROR: Cant get DeezerArtistURL or artistid.."
				logit "INFO: Update MusicBrainz Artist record with Deezer Artist url to fix error in future runs"
				logit "INFO: URL to MB page for update: https://musicbrainz.org/artist/${MBArtistID}/relationships"
				logit "INFO: See ${LogDir}/error.log for more detail..."
				if cat "${LogDir}/${DownloadLogName}" | grep "${MBArtistID}" | read; then
					logit "skipping..."
				else
					logit "${LidArtistNameCap} - Update Musicbrainz Relationship Page (https://musicbrainz.org/artist/${MBArtistID}/relationships) with Deezer Artist Link" >> "${LogDir}"/error.log
					logit "skipping..."
				fi
				skiplog "${LidArtistName};${DeezerArtistID};${DeezerArtistURL};${LidAlbumName}"
				continue
			fi
			
			if [ "${AppProcess}" = AllDownloads ]; then
				LidarrImport
			fi
			
			if [ "${LyricType}" = explicit ]; then
				logit "Downloading all explicit albums..."
				albumlist=($(curl -s --GET "https://api.deezer.com/artist/${DeezerArtistID}/albums&limit=1000" | jq -r ".data | .[]| select(.explicit_lyrics==true)| .id" | sort -u))
				totalnumberalbumlist=($(curl -s --GET "https://api.deezer.com/artist/${DeezerArtistID}/albums&limit=1000" | jq -r ".data | .[]| select(.explicit_lyrics==true)| .id" | sort -u | wc -l))
			elif [ "${LyricType}" = clean ]; then
				logit "Downloading all clean albums..."
				albumlist=($(curl -s --GET "https://api.deezer.com/artist/${DeezerArtistID}/albums&limit=1000" | jq -r ".data | .[]| select(.explicit_lyrics==false)| .id" | sort -u))
				totalnumberalbumlist=($(curl -s --GET "https://api.deezer.com/artist/${DeezerArtistID}/albums&limit=1000" | jq -r ".data | .[]| select(.explicit_lyrics==false)| .id" | sort -u | wc -l))
			else 
				logit "Downloading all albums..."
				albumlist=($(curl -s --GET "https://api.deezer.com/artist/${DeezerArtistID}/albums&limit=1000" | jq -r ".data | .[]| .id" | sort -u))
				totalnumberalbumlist=($(curl -s --GET "https://api.deezer.com/artist/${DeezerArtistID}/albums&limit=1000" | jq -r ".data | .[]| .id" | sort -u | wc -l))
			fi
			
			logit "Total # Albums to Process: $totalnumberalbumlist"
					
			for album in ${!albumlist[@]}; do
				albumnumber=$(( $album + 1 ))
				if [ "${PreviouslyDownloaded}" = True ] && cat "${LogDir}/${DownloadLogName}" | grep "${albumlist[$album]}" | read; then 
					logit "Previously Downloaded ${albumnumber} of ${totalnumberalbumlist} (ID: ${albumlist[$album]}), skipping..."
				else
					if [ -f "${DownloadDir}/temp-hold"  ]; then					
						rm "${DownloadDir}/temp-hold"
					fi
					touch "${DownloadDir}/temp-hold"
					logit "Processing $currentartist of $TotalLidArtistNames"
					logit "ArtistName: ${LidArtistNameCap} (ID: ${DeezerArtistID})"
					logit "Downloading Album: ${albumnumber} of ${totalnumberalbumlist} (ID: ${albumlist[$album]})"
					DownloadURL "https://www.deezer.com/album/${albumlist[$album]}" 
				
					if [ "$(ls -A "${DownloadDir}")" ]; then
						Cleanup
						if [ "${Verification}" = True ]; then
							Verify
						fi
						if [ "${Convert}" = True ]; then
							Convert
						fi
						if [ "${ReplaygainTagging}" = True ]; then
							Replaygain
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
						if [ "${DownloadArtistArtwork}" = True ]; then 
							DLArtistArtwork
						fi
					fi
					if [ -f "${DownloadDir}/temp-hold"  ]; then					
						rm "${DownloadDir}/temp-hold"
					fi
				fi
			done
			logit "Processing Complete"
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

EnabledOptions () {
	logit ""
	logit "Global Configured Options:"
	logit "Quality = ${Quality}"
	if [ "${CleanStart}" = True ]; then
		logit "CleanStart = Enabled"
	else
		logit "CleanStart = Disabled"
	fi
	if [ "${ClearDownloadLog}" = True ]; then
		logit "ClearDownloadLog = Enabled"
	else
		logit "ClearDownloadLog = Disabled"
	fi
	if [ "${KeepOnly}" = True ]; then
		logit "KeepOnly = Enabled"
	else
		logit "KeepOnly = Disabled"
	fi
	if [ "${CannotImport}" = True ]; then
		logit "CannotImport = Enabled"
	else
		logit "CannotImport = Disabled"
	fi
	if [ "${Verification}" = True ]; then
		logit "Verification = Enabled"
	else
		logit "Verification = Disabled"
	fi
	if [ "${Convert}" = True ]; then
		logit "Convert = Enabled"
	else
		logit "Convert = Disabled"
	fi
	if [ "${ReplaygainTagging}" = True ]; then
		logit "ReplaygainTagging = Enabled"
	else
		logit "ReplaygainTagging = Disabled"
	fi
	if [ "${DownloadArtistArtwork}" = True ]; then 
		logit "DownloadArtistArtwork = Enabled"
	else
		logit "DownloadArtistArtwork = Disabled"
	fi
	if [ "${AppProcess}" = External ]; then
		logit "AppProcess = External"
	elif [ "${AppProcess}" = Lidarr ]; then
		logit "AppProcess = Lidarr"
	elif [ "${AppProcess}" = AllDownloads ]; then
		logit "AppProcess = AllDownloads"
	else
		logit "AppProcess = Skip"
	fi
	logit ""
}

main(){
	OLDIFS=$IFS
	IFS=$'\n'
	logit "Starting up"
	source ./config || ErrorExit "Configuration file not found" 2
	CheckLogPath
	InitLogs
	EnabledOptions
	CheckdlPath
	CleanStart
	DeleteDownloadLog
	case "${Mode}" in
		wanted)	WantedModeBegin;;
		artist) ArtistModeBegin;;
		*) logit "Mode error, check Mode variable in config valid = wanted/artist" ;;
	esac
	IFS=$OLDIFS
}

main ${@}

#####################################################################################################
#                                              Script End                                           #
#####################################################################################################
exit 0
