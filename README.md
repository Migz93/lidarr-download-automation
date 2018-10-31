# lidarr-smloadr-script
Powershell script to download artists in lidarr using smloadr

I created this to fill a need i had, i have lidarr installed but it doesn't grab many releases.
I then found out about smloadr and tried to download every single artist, this left me with a lot of junk that i'd never listen to.
I then tried just downloading genres i like but again left me with a lot of junk i'd never listen to.

So i set about trying to find something that would bridge the gap between the artists i have monitored in lidarr & downloading them with smloadr, I couldn't find anything at all for this so i set about creating my own script to do this. I'm by no means anywhere close to a scripter so there may be better ways of scripting then i've done but it works for me so I would share incase anyone else wants to use it.

It will pull all your artists set up in lidarr and then go through these one by one searching for them on deezer.

Edit lines 1-10 to fill in your variables.
$scriptdir is where you want your script to store its logfile and store the batch file with all artist IDs.
$downloaddir is where you want smloadr to download its files to. This doesn't have to be in the same location or even drive as $scriptdir.
$lidarrurl is either the domain or IP of the machine running lidarr.
$lidarrport is the port that lidarr runs on.
$lidarrapikey is the api key that can be grabbed from Lidarr > Settings > General

Using artist name & the artists last album it will search on deezer, taking the first hit and saving this to a txt file which can then be used in smloadr.
Sometimes last album is not available from lidarr so it will fall back to searching with just the artist name.

It's fairly accurate and out of about 170ish artists it's accurately matched about 160 of them.
I.e having dua lipa in lidarr ends up matching to https://www.deezer.com/us/artist/1198498 which ends up as a 100GB+ download.
You can manually add in your own deezer artist IDs into the generated "lidarr-smloadr.txt" file to fix any incorrect grabs, theres no way yet to remove the incorrect grabs though so it will also download those.
