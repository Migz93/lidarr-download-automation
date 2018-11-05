#!/bin/bash
#Directory that you want log file & artist ID batch file to be stored.
scriptDir="/opt/smloadr/lidarr"
#Directory that you want smloadr to download to.
downloadDir="/mnt/unionfs/Media/Music/"
#Set domain or IP to your lidarr instance
lidarrUrl="192.168.1.x"
#Set port that ldiarr runs on, must begin with ":"
lidarrPort=":8686"
#Lidarr api key
lidarrApiKey="08d108d108d108d108d108d108d108d1"

#Test if script dir doesn't exist, if true then create directory.
if [ ! -d "$scriptDir" ]; then
  mkdir $scriptDir
fi

echo "Collecting data from lidarr, this may take some time depending on how many artists you have." 
curl "$lidarrUrl$lidarrPort/api/v1/Artist/?apikey=$lidarrApiKey" -o $scriptDir/artists-lidarr.json
artists=$(cat $scriptDir/artists-lidarr.json | jq -r '.[].sortName')

totalArtists=$(wc -l <<< "$artists")
totalArtists=$((totalArtists-1))
echo $totalArtists total artists pulled from Lidarr
for ((i=1;i<=totalArtists;i++));
do
	#create wantedArtist variable from sortName provided by lidarr
	wantedArtist=$(cat $scriptDir/artists-lidarr.json | jq -r ".[$i].sortName")
	#create lastAlbum variable from lastAlbum provided by lidarr.
	lastAlbum=$(cat $scriptDir/artists-lidarr.json | jq -r ".[$i].lastAlbum | .title")
	#Attempt to pull deezer link directly from lidarr if it is provided by musicbrainz.
	wantedArtistID=$(cat $scriptDir/artists-lidarr.json | jq -r ".[$i].links | .[]")
	wantedArtistID=$(echo $wantedArtistID | jq 'select(.name=="deezer") | .url')
	
	#If deezer link not provided by lidarr then fall back to search method.
	if [ "$wantedArtistID" = "" ];
	then
	lidarrGrab="False"
	#Check if lastAlbum variable doesn't exist. Sometimes this isn't provided by lidarr.
		if [ "$lastAlbum" = "null" ];
		then
			#Search deezer using only artist name. Not as accurate as using with last album name but better then nothing.
			searchQuery="https://api.deezer.com/search?q=$wantedArtist"
			#Encode searchQuery in a url encodable format.
			searchQuery=$(/usr/bin/python -c "import urllib, sys; print urllib.quote(sys.argv[1])"  "$searchQuery")
			wantedArtistID=$(curl -s https://api.deezer.com/search?q=$searchQuery | jq -r ".data | .[0] | .artist | .id")	
		else
			#Otherwise if lastAlbum variable exists. Generate searchQuery variable, take first result and set the artistID from deezer as variable wantedArtistID.
			searchQuery="$wantedArtist%20$lastAlbum"
			#Encode searchQuery in a url encodable format.
			searchQuery=$(/usr/bin/python -c "import urllib, sys; print urllib.quote(sys.argv[1])"  "$searchQuery")
			wantedArtistID=$(curl -s https://api.deezer.com/search?q=$searchQuery | jq -r ".data | .[0] | .artist | .id")
			#Check if wantedArtistID is empty following search, if so it means no results were found, fall back to searching with just artist.
			if [ "$wantedArtistID" = "null" ];
			then
				searchQuery="$wantedArtist"
				#Encode searchQuery in a url encodable format.
				searchQuery=$(/usr/bin/python -c "import urllib, sys; print urllib.quote(sys.argv[1])"  "$searchQuery")
				wantedArtistID=$(curl -s https://api.deezer.com/search?q=$searchQuery | jq -r ".data | .[0] | .artist | .id")
			fi
		fi
	else
	lidarrGrab="True"
	fi

if [ "$lidarrGrab" = "True" ];
then
	#Save output to log file. Save wantedArtistID to wantedArtistID.txt file which will be used by smloadr.
	echo "SMloadr url for $wantedArtist - $wantedArtistID found using data from lidarr." >> $scriptDir/lidarr-smloadr.log
	echo "SMloadr url for artist $i - $wantedArtist - $wantedArtistID found using data from lidarr."
else
	#Save output to log file. Save wantedArtistID to wantedArtistID.txt file which will be used by smloadr.
	echo "SMloadr url for $wantedArtist - https://www.deezer.com/artist/$wantedArtistID found using search query $searchQuery" >> $scriptDir/lidarr-smloadr.log
	echo "SMloadr url for artist $i - $wantedArtist - https://www.deezer.com/artist/$wantedArtistID found using search query https://api.deezer.com/search?q=$searchQuery"
fi
	
	#Save output to log file. Save wantedArtistID to wantedArtistID.txt file which will be used by smloadr.
	echo $wantedArtistID >> $scriptDir/wantedArtistID.txt

	#Small sleep to not hammer deezer with api search requests.
	sleep .25s
done

#Take all entries from wantedArtistID.txt remove anything that isn't a number, save into temp file, move temp file back to original.
sed 's/[^0-9]*//g' $scriptDir/wantedArtistID.txt > $scriptDir/wantedArtistID-temp.txt && mv $scriptDir/wantedArtistID-temp.txt $scriptDir/wantedArtistID.txt

#Take all entries from wantedArtistID.txt remove any duplicates, save into temp file, move temp file back to original.
awk '!a[$0]++' $scriptDir/wantedArtistID.txt > $scriptDir/wantedArtistID-temp.txt && mv $scriptDir/wantedArtistID-temp.txt $scriptDir/wantedArtistID.txt

#Load IDs from wantedArtistID.txt file and Loop through each ID from smloadrartists.
smloadrArtists=$(cat "$scriptDir/wantedArtistID.txt")
for smloadrArtist in $smloadrArtists;
	do
	#Download smloadrArtist with smloadr to downloadDir.
	./SMLoadr-linux-x64 -q MP3_320 -p $downloadDir https://www.deezer.com/artist/$smloadrArtist
done

echo "Task Complete"
