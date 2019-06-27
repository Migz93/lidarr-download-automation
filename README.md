# lidarr-smloadr-script 
Bash script to download artists in Lidarr using smloadr.

I created the original version of this to fill a need i had, i have Lidarr installed but it doesn't grab many releases which is more a fault of my lack of indexers but still. <br>
I found out about smloadr and tried to download every single artist, this left me with a lot of junk that i'd never listen to. I then tried just downloading genres i like but again left me with a lot of junk i'd never listen to.<br>

So i set about trying to find something that would bridge the gap between the artists i have monitored in Lidarr & downloading them with smloadr, I couldn't find anything at all for this so i set about creating my own script to do this.<br>
See bash & powershell scripts within [Legacy](Legacy/) folder.

[permutationalparody](https://github.com/permutationalparody) then improved the bash script in various ways, including adding a seperate config file, adding an option to only search for albums/EPs/singles/ect that are set to monitored in Lidarr, add an option to allow Lidarr to import the downloaded files and generally tidied up the code a large ammount.<br>
[RandomNinjaAtk](https://github.com/RandomNinjaAtk) improved even further by adding some cleanup functions, a fix for lidarr import, allowing the option for external processing of the file.

# Modes
This script has two modes (configured by changing the "mode" paramater in the config file):

<b>Wanted:</b><br>
This it the prefered mode to use, with this option the script will check all artists & check their last album and attempt to find the Deezer ID from this data. If it fails and the "EnableFuzzyAlbumSearch" paramater is "True" then it will fall back to carrying out a fuzzy search of Deezer using the Artist Name & Last Album Name. If it's still unable to find a Deezer ID then the artist will be saved to the skiplog file configured in config. 

Once a Deezer ID has been identified it will then pass this through to smloadr to download, downloading to the path & at the quality speecified within config. Note it will only download the ammount of albums configured under "wantedalbumsamount" each time that the script runs.

If "EnableLidarrProcess" is set to "True" then once the download is complete it will inform Lidarr of the download location, allowing Lidarr to match & import these files.<br>
This mode will only download albums/EPs/singles/ect that you have actually set to monitored within Lidarr.

<b>Artist:</b><br>
This is the way the original legacy script would use, with this option the script will check all artists & check their last album and attempt to find the Deezer ID from this dat. If it fails then it will fall back to carrying out a fuzzy search of Deezer using the Artist Name & Last Album Name. If it's still unable to find a Deezer ID then the artist will be saved to the skiplog file configured in config.<br>
This mode will download everything by the artist that Deezer provides, so you can end up with a lot of unwanted albums/EPs/singles/ect.

# Config
Edit the "config.sample" file, fill your paramaters and save as "config".<br>
* scriptDir - 				Directory that you want log file & artist ID batch file to be stored.<br>
* downloadDir - 			Directory that you want smloadr to download to.<br>
* LidarrUrl - 				Set domain or IP to your Lidarr instance including port. If using reverse proxy, do not use a trailing slash.<br>
* LidarrApikey - 			Lidarr api key.<br>
* quality - 				SMLoadr Download Quality setting (MP3_128,MP3_320,FLAC).<br>
* KeepOnly -					Keeps only the requested Download Quality<br>
* logname -					Log file name.<br>
* skiplogname -				Logs any info if an item was skipped.<br>
* CannotImport -				Removes files that cannot be imported by Lidarr automatically (.jpg, .lrc).<br>
* CleanStart -				Purges files from SMLoadr Download directory at start of script<br>
* mode -					Mode to choose what to scrape from Lidarr, wanted gets only the albums that are marked wanted, artist gets all the albums from the monitored artists.<br>
* ExternalProcess -				Enables the downloaded files to be moved and picked up by other applications/scripts that you have setup. This replaces the EnableLidarrProccess import process.<br>
* externalprocessdirectory -				Directory that you want to move downloaded files to for processing with other scripts or applications such as Beets.<br>
* EnableLidarrProcess -		Set to True to instruct Lidarr to process the download once smloadr finishes.<br>

Below are only used if "mode" is set to "wanted".<br>
* wantedalbumsamount -		The amount of wanted albums to process it will grab the newest x amount of albums from the Lidarr wanted list.<br>
* EnableFuzzyAlbumSearch -	Set to True to enable fuzzy album search if theres no exact match.<br>

# Requirements
* Lidarr installed & running.<br>
* smloadr downloaded & ideally in the same location as the script. I personally bundle them both in /opt/smloadr.<br>
* jq installed (sudo apt-get install jq).<br>

# Other
Lidarr collects its information from https://musicbrainz.org which is open to anyone to edit, so if the Deezer ID in Lidarr is incorrect or missing you can sign up for an account and ammend/add this yourself.

Original Script: Myself<br>
Improved Script: [permutationalparody](https://github.com/permutationalparody)<br>
Further Improvements: [RandomNinjaAtk](https://github.com/RandomNinjaAtk)<br>
