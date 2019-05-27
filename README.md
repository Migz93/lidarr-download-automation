# modified usage
Edit the "config.sample" file  with your variables and save as config
run lidarr-smloadr2.sh

# what changed
Added a config file.<br>
Added a way to grab albums marked as wanted in lidarr instead of everything by an artist. Change mode=wanted in config to use it, change mode=artist to use the old method.<br>
Added a connection to Lidarr to allow automatic importing of downloads.<br>
Removed dependency on python.<br>

The powershell version remains unchanged

# lidarr-smloadr-script 
Bash & powershell scripts to download artists in lidarr using smloadr.

I created this to fill a need i had, i have lidarr installed but it doesn't grab many releases which is more a fault of my lack of indexers but still. <br>
I then found out about smloadr and tried to download every single artist, this left me with a lot of junk that i'd never listen to.<br>
I then tried just downloading genres i like but again left me with a lot of junk i'd never listen to.<br>

So i set about trying to find something that would bridge the gap between the artists i have monitored in lidarr & downloading them with smloadr, I couldn't find anything at all for this so i set about creating my own script to do this.
<br> I'm by no means anywhere close to a scripter so there probably will be better ways of scripting then i've done but it works for me so I wanted to share incase anyone else wanted to use it.

It will pull all your artists set up in lidarr and then go through these one by one, lidarr sometimes has the deezer ID stored in the data that it collects from Musicbrainz, if it has this then it will save this ID to a file to be used by smloadr, if it doesn't have the ID then it will search the Deezer API using artist name & the artists last album, taking the first hit and saving this to a txt file which can then be used in smloadr.<br>
Sometimes last album is not available from Lidarr so it will fall back to searching with just the artist name.<br>

If the Deezer ID is provided by Lidarr then this should be 100% accurate, lidarr collects its information from https://musicbrainz.org which is open to anyone to edit, so if the ID is incorrect or missing you can sign up for an account and ammend/add this yourself.
If the ID isn't provided and it does need to do a manual search then even though this is a very very simple search of just searching with artist name + last album or just artist name, it's still fairly accurate and out of 169 artists it's correctly matched 161 of them. Although bear in mind if it does match incorrectly it can sometimes be a large mistake I.e having "Dua Lipa" in my Lidarr initially matched to https://www.deezer.com/us/artist/1198498 which ends up as a 100GB+ download.<br>
You can manually add in your own deezer artist IDs into the generated "lidarr-smloadr.txt" file to fix any incorrect grabs, theres no way yet to remove the incorrect grabs though so it will also download those.<br>
You can review the log file generated in the $scriptdir, this log shows the deezer url returned for the artist, along with the specific search query that was used to find this or if the ID was grabbed from Lidarr/Musicbrainz directly.<br>

Lidarr should pick up the files and show them as downloaded if you have it pointed at the same place your files download.

I'm not a script wizard in the slightest, not in bash or powershell. So if you see anything that could be improved in either then please let me know.


# lidarr-smloadr-script - Bash Version

Requirements:
* smloadr downloaded & ideally in the same location as the script. I personally bundle them both in /opt/smloadr <br>
* jq installed (sudo apt-get install jq)
* python version 2.7 installed (sudo apt-get install python)

Varriables. Edit lines 1-14 to fill in your variables: <br>
* scriptDir - #Directory that you want log file & artist ID batch file to be stored.<br>
* downloadDir - Directory that you want smloadr to download to.<br>
* lidarrUrl - iSet domain or IP to your lidarr instance including port. If using reverse proxy, do not use a trailing slash.<br>
* lidarrApikey - Lidarr api key.<br>
* fallbackSearch - Fallback to searching if lidarr doesn't provide deezer ID, only supports "true", if anything else it won't fallback.
* quality - SMLoadr Download Quality setting (MP3_128,MP3_320,FLAC)

Tested and working on Ubuntu 16.04 but should work on later versions

# lidarr-smloadr-script - Powershell Version
(Powershell version currently does not check if Lidarr has provided the Deezer ID. This version only takes your artist + last album and searches Deezer for it.

Requirements:
* smloadr downloaded & ideally added to your path, if not you would need to edit the smloadr download line towards the end to point at the location it's in. <br>
* rclone downloaded & idealy added to your path,  if not you would need to edit the rclone copy line towards the end to point at the location it's in. Only required if you're planning on using rclone, if not you can just remove/comment out this line.<br>

Varriables. Edit lines 1-10 to fill in your variables: <br>
* $scriptDir - #Directory that you want log file & artist ID batch file to be stored.<br>
* $downloadDir - Directory that you want smloadr to download to.<br>
* $lidarrurl is either the domain or IP of the machine running lidarr.<br>
* $lidarrport is the port that lidarr runs on.<br>
* $lidarrApikey - Lidarr api key.<br>

Tested and working on Windows 10.
