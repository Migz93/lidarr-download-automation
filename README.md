# lidarr-smloadr-script - Powershell
Powershell script to download artists in lidarr using smloadr.
Edit: Now with bash version, please see below.

I created this to fill a need i had, i have lidarr installed but it doesn't grab many releases which is more a fault of my lack of indexers but still. <br>
I then found out about smloadr and tried to download every single artist, this left me with a lot of junk that i'd never listen to.<br>
I then tried just downloading genres i like but again left me with a lot of junk i'd never listen to.<br>

So i set about trying to find something that would bridge the gap between the artists i have monitored in lidarr & downloading them with smloadr, I couldn't find anything at all for this so i set about creating my own script to do this.
<br> I'm by no means anywhere close to a scripter so there probably will be better ways of scripting then i've done but it works for me so I wanted to share incase anyone else wanted to use it.

It will pull all your artists set up in lidarr and then go through these one by one searching for them on deezer.

Using artist name & the artists last album it will search on deezer, taking the first hit and saving this to a txt file which can then be used in smloadr.<br>
Sometimes last album is not available from lidarr so it will fall back to searching with just the artist name.<br>

Even though this is a very very simple search of just searching with artist name + last album or just artist name, it's still fairly accurate and out of 169 artists it's correctly matched 161 of them. Although bear in mind if it does match incorrectly it can sometimes be a large mistake I.e having "Dua Lipa" in lidarr ends up matching to https://www.deezer.com/us/artist/1198498 which ends up as a 100GB+ download.<br>
You can manually add in your own deezer artist IDs into the generated "lidarr-smloadr.txt" file to fix any incorrect grabs, theres no way yet to remove the incorrect grabs though so it will also download those.<br>
You can review the log file generated in the $scriptdir, this log shows the deezer url returned for the artist, along with the specific search query that was used to find this.<br>

Lidarr should pick up the files if you have it pointed at the same place your files download.

Requirements:
* smloadr downloaded & ideally added to your path, if not you would need to edit the smloadr download line towards the end to point at the location it's in. <br>
* rclone downloaded & idealy added to your path,  if not you would need to edit the rclone copy line towards the end to point at the location it's in. Only required if you're planning on using rclone, if not you can just remove/comment out this line.<br>

Varriables. Edit lines 1-10 to fill in your variables: <br>
* $scriptdir is where you want your script to store its logfile and store the batch file with all artist IDs.<br>
* $downloaddir is where you want smloadr to download its files to. This doesn't have to be in the same location or even drive as $scriptdir.<br>
* $lidarrurl is either the domain or IP of the machine running lidarr.<br>
* $lidarrport is the port that lidarr runs on.<br>
* $lidarrapikey is the api key that can be grabbed from Lidarr > Settings > General<br>



# lidarr-smloadr-script - Bash Version
I've now created a bash version of the original powershell script. It carries out the same task in the same way, just using bash, python & jq.
This has been tested working on Ubuntu 16.04 but should work on later versions.

Requirements:
* smloadr downloaded & ideally in the same location as the script. I personally bundle them both in /opt/smloadr <br>
* jq installed (sudo apt-get install jq)
* python version 2.7 installed (sudo apt-get install python)

Varriables. Edit lines 1-10 to fill in your variables: <br>
* scriptDir is where you want your script to store its logfile and store the batch file with all artist IDs.<br>
* downloadDir is where you want smloadr to download its files to. This doesn't have to be in the same location or even drive as scriptdir.<br>
* lidarrUrl is either the domain or IP of the machine running lidarr.<br>
* lidarrPort is the port that lidarr runs on.<br>
* lidarrApikey is the api key that can be grabbed from Lidarr > Settings > General<br>


I'm not a script wizard in the slightest, not in bash or powershell. So if you see anything that could be improved in either then please let me know.
