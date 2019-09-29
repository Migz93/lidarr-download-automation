#!/bin/bash

ArtistsLidarrReq(){
	wantit=$(curl -s --header "X-Api-Key:"${LidarrApiKey} --request GET  "$LidarrUrl/api/v1/Artist/")
}
GetTotalArtistsLidarrReq(){
	TotalLidArtistNames=$(echo "${wantit}"|jq -r '.[].sortName' |wc -l  )
}
ProcessArtistsLidarrReq(){
	LidArtistName=$(echo "${wantit}" | jq -r .[$i].sortName)
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
	logit "Starting Download ... "
	DLURL=${1}
	timeout $Timeout ./SMLoadr-linux-x64 -q ${Quality} -p "${DownloadDir}" "${DLURL}"
	logit "Download Complete"
}

CleanStart(){
	if [ "${CleanStart}" = True ];then
		logit "Removing previously downloaded files from SMLoadr downloads directory".
		rm -rf ${DownloadDir}/*
	else
		logit "Skipping CleanStart"
	fi
}

Cleanup(){
	if [ "${KeepOnly}" = True ];then
		if [ "${Quality}" = FLAC ];then
			logit "Removing unwanted MP3's"
			find ${DownloadDir}/. -name "*.mp3" -type f -delete
		else
			logit "Removing unwanted FLAC's"
			find ${DownloadDir}/. -type f -name "*.flac" -type f -delete
		fi
	else
		logit "Skipping KeepOnly Quality Cleanup"
	fi
	if [ "${CannotImport}" = True ];then
		logit "Removing files that cannot be imported to Lidarr and empty folders"
		find ${DownloadDir}/. -type f -name "*.lrc" -type f -delete
		find ${DownloadDir}/. -type f -name "*.jpg" -type f -delete
		find ${DownloadDir}/ -empty -type d -delete
	else
		logit "Skipping Unwanted file removal"
	fi
}

LidarrProcess(){
	logit "Sending to Lidarr for post processing"
	dlloc=($(find "${DownloadDir}" -maxdepth 1 -type d -not -path "${DownloadDir}"))
	for d in "${dlloc[@]}"; do
		if [ "${EnableWSLMode}" = True ];then
			dwrap=($( echo "${d}"|sed -e 's/mnt\///' -e 's/^\///' -e 's/^./\0:/' -e 's/\//\\\\/g' -e 's/^/\"/g' -e 's/$/\"/g'))
		else
			dwrap=($( echo "${d}"|sed -e 's/^/\"/g' -e 's/$/\"/g'))
		fi
		LidarrProcessIt=$(curl -s "$LidarrUrl/api/v1/command" --header "X-Api-Key:"${LidarrApiKey} --data '{"name":"DownloadedAlbumsScan", "path":'"${dwrap}"'}' );
	done
	sleep 3s
}

ExternalProcess(){
	logit "Moving downloads for external post processing."
	dlloc=${DownloadDir}/*
	for d in $dlloc; do
		mv "$d" ${ExternalProcessDirectory}
	done
	rm -rf ${DownloadDir}/*
	sleep 3s
}


ErrorExit(){
	case ${2} in
		2)	echo ${1};exit ${2};;
		144)	echo ${1};exit ${2};;
		*)	echo ${1} |tee -a ${ScriptDir}/${LogName};exit ${2};;
	esac
}

logit(){
	echo ${1} | tee -a ${ScriptDir}/${LogName}
}

skiplog(){
	echo ${1} | tee -a ${ScriptDir}/${SkipLogName}
}

InitLogs(){
	echo "Beginning Log" |tee ${ScriptDir}/${LogName} || ErrorExit "Cant create log file" 144
	echo "LidArtistName;DeezerArtistID;DeezerArtistURL;LidAlbumName;DeezerDiscog" |tee ${ScriptDir}/${SkipLogName} || ErrorExit "Cant create skiplog file" 144
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
			logit "ArtistName: ${LidArtistName}"
			logit "LidarrAlbumName: ${LidAlbumName}"
			logit "ArtistID: ${DeezerArtistID}"
		else
			ErrorExit "Lidarr communication error, check LidarrUrl in config or LidarrApiKey"
		fi
		echo "-Querying ${i} of ${loopindex}"
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
			DownloadURL "${DeezerAlbumURL}"
		else
			logit "Cant match the wanted album to an album on deezer .. skipping"
			skiplog "${LidArtistName};${DeezerArtistID};${DeezerArtistURL};${LidAlbumName};${DeezerDiscogArr[*]}"
			continue
		fi
		Cleanup
		if [ "${AppProcess}" = External ];then
			ExternalProcess
		elif [ "${AppProcess}" = Lidarr ];then
			LidarrProcess
		else
			logit "Skipping Any Processing"
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
		LidArtistName=""
		DeezerArtistID=""
		DeezerArtistURL=""
		LidAlbumName=""
		DeezerDiscogAlbumName=""
		DeezerAlbumURL=""
		echo "-Processing ${i} of ${loopindex}"
		if [ -n "${wantit}" ]; then
			ProcessArtistsLidarrReq
			logit "ArtistName: ${LidArtistName}"
			logit "LidarrAlbumName: ${LidAlbumName}"
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
			DownloadURL "${DeezerArtistURL}"
			logit "DeezerArtistURL: ${DeezerArtistURL}"
		else
			logit "Cant get artistname or or DeezerArtistURL or artistid.. skipping"
			skiplog "${LidArtistName};${DeezerArtistID};${DeezerArtistURL};${LidAlbumName}"
			continue
		fi
		Cleanup
		if [ "${AppProcess}" = External ];then
			ExternalProcess
		elif [ "${AppProcess}" = Lidarr ];then
			LidarrProcess
		else
		logit "Skipping Any Processing"
		fi
	done
}

CheckdlPath(){
if [ -d ${DownloadDir} ] && [ -w ${DownloadDir} ]; then
	dlcontento=($(find "${DownloadDir}" -maxdepth 1 -type d -not -path "${DownloadDir}"))
else
	ErrorExit "download directory not writeable or doesnt exist ${DownloadDir}"
fi
}

main(){
	OLDIFS=$IFS
	IFS=$'\n'
	echo "Starting up"
	source ./config || ErrorExit "Configuration file not found" 2
	InitLogs
	CleanStart
	CheckdlPath
	case "${Mode}" in
		wanted)	WantedModeBegin;;
		artist) ArtistModeBegin;;
		*) logit "Mode error, check Mode variable in config valid = wanted/artist" ;;
	esac
	IFS=$OLDIFS
}

main ${@}
