# lidarr-smloadr-script
Bash script to download your artists that have been added to Lidarr using SMLoadr.
The script communicates with Lidarr over it's API to find get a list of your Artists/Albums, using this data it then searches Deezer for a matching Artist/Album and downloads what it finds.<br>
This script runs externally to Lidarr and isn't added anywhere to Lidarr, instead you add Lidarrs info to the config file and run this script directly.

# Modes
This script has two modes (configured by changing the 'Mode' parameter in the config file):

<b>Wanted:</b><br>
This mode will only download albums/EPs/singles/ect that you have actually set to monitored within Lidarr.<br>
This is the preferred mode to use, with this option the script will grab a list of all artists in Lidarr, check the artists last album and attempt to find the Deezer ID from this data. If it fails and the 'EnableFuzzyAlbumSearch' parameter is 'True' then it will fall back to carrying out a fuzzy search of Deezer using the Artist Name & Last Album Name. If it's still unable to find a Deezer ID then the artist will be saved to the SkipLog file configured in config.

It will only download the amount of albums configured under 'WantedAlbumsAmount' each time that the script runs, so for your initial run of a large amount of albums, you may want to temporarily set this number much higher then the default of 10.



<b>Artist:</b><br>
This mode will download everything by the artist that Deezer provides, so you can end up with a lot of unwanted albums/EPs/singles/ect.<br>
With this option the script will check all artists, check their last album and attempt to find the Deezer ID from this data. If it fails then it will fall back to carrying out a fuzzy search of Deezer using the Artist Name & Last Album Name. If it's still unable to find a Deezer ID then the artist will be saved to the SkipLog file configured in config.<br>



# Config
Edit the "config.sample" file, fill your paramaters and save as "config".<br>
* **ScriptDir** - 				Directory of script, to save log file & artist ID batch file.<br>
* **DownloadDir** - 			Directory that you want SMLoadr to download to.<br>
* **EnableWSLmode** - Set to true if you're running Lidarr on windows and this script on subsystem for Linux ('True' or 'False').<br>
* **LidarrUrl** - 				Set domain or IP to your Lidarr instance including port. If using reverse proxy, do not use a trailing slash.<br>
* **LidarrApikey** - 			Lidarr API key.<br>
* **Quality** - 				SMLoadr Download Quality setting ('MP3_128', 'MP3_320' or 'FLAC').<br>
* **KeepOnly** -					Keeps only the requested Download Quality. ('True' or 'False').<br>
* **LogName** -					Log file name.<br>
* **SkipLogName** -				Log file name to record if an item was skipped.<br>
* **CannotImport** -				Removes files that cannot be imported by Lidarr automatically (.jpg, .lrc)('True' or 'False').<br>
* **CleanStart** -				Purges files from SMLoadr Download directory at start of script ('True' or 'False').<br>
* **Mode** -					Mode to run script as, wanted gets only the albums that are marked wanted, artist gets everything available on Deezer for artists ('Wanted' or 'Artist').<br>
* **AppProcess** - Specify which app to use for processing. ('Lidarr', 'External' or leave it empty for None).<br>
* **ExternalProcessDirectory** -				Directory that you want to move downloaded files to for processing with other scripts or applications such as Beets. Only runs if 'AppProcess' is set to 'External'.<br>

Below are only used if "mode" is set to "wanted".<br>
* **WantedAlbumsAmount** -		The amount of wanted albums to process it will grab the newest x amount of albums from the Lidarr wanted list.<br>
* **EnableFuzzyAlbumSearch** -	Set to True to enable fuzzy album search if their is no exact match ('True' or 'False').<br>

# Requirements
* Lidarr installed & running.<br>
* SMLoadr downloaded & in the same location as the script. I personally bundle them both in /opt/smloadr.<br>
* jq installed (sudo apt-get install jq).<br>

# Other
Lidarr collects its information from https://musicbrainz.org which is open to anyone to edit, so if the Deezer ID in Lidarr is incorrect or missing you can sign up for an account and amend/add this yourself. This can take a few days to propagate to Lidarr.

The legacy version of this script that runs in bash & powershell but only grabs everything by an artist is available within [Legacy](https://github.com/Migz93/lidarr_smloadr_script/tree/legacy) branch.<br>

# Credit
Original Script: Myself<br>
Improvements: [permutationalparody](https://github.com/permutationalparody)<br>
Improvements: [RandomNinjaAtk](https://github.com/RandomNinjaAtk)<br>
