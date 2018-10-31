#Directory that you want log file & artist ID batch file to be stored.
$scriptdir = "C:\Scripts\smloadr\lidarr"
#Directory that you want smloadr to download to.
$downloaddir = "C:\Scripts\smloadr"
#Set domain or IP to your lidarr instance
$lidarrurl = "192.168.1.x"
#Set port that ldiarr runs on, must begin with ":"
$lidarrport = ":8686"
#Lidarr api key
$lidarrapikey = "08d108d108d108d108d108d108d108d1"

Write-Host "Collecting data from lidarr, this may take some time depending on how many artists you have."
$artists = Invoke-RestMethod -Method 'GET' -uri "$lidarrurl$lidarrport/api/v1/Artist/?apikey=$lidarrapikey"
#Test if script dir doesn't exist, if true then create directory.
if(!(Test-Path -Path "$scriptdir" )){New-Item -ItemType directory -Path "$scriptdir"}

#Go through all artists pulled from lidarr one by one, carrying out following actions.
Foreach ($artist in $artists)
{
write-host ""
#create wantedartist variable from sortName provided by lidarr
$wantedartist = $artist | Select -ExpandProperty sortName
#create lastalbum variable from lastAlbum provided by lidarr.
$lastalbum = $artist | Select -ExpandProperty lastAlbum | Select -ExpandProperty title
#Replace spaces in lastalbum name with "%20"
$lastalbum = $lastalbum -replace '\s','%20'
#Check if lastAlbum variable doesn't exist. Sometimes this isn't provided by lidarr.
if (!$lastalbum)
    {
	#Replace spaces in artist name with "%20" and search deezer using only artist name. Not as accurate as using with last album name but better then nothing.
    $searchquery = "https://api.deezer.com/search?q=$wantedartist"
    $searchquery = $searchquery -replace '\s','%20'
    $searchdata = Invoke-RestMethod -Method 'GET' -uri $searchquery | Select -ExpandProperty data | Select-Object -first 1
    }
else
    {
	#Otherwise if lastAlbum variable exists. Generate searchquery variable, replace spaces with "%20", search deezer for artist, take first result and set the artistID from deezer as variable wantedartistid.
    $searchquery = "https://api.deezer.com/search?q=$wantedartist $lastalbum"
    $searchquery = $searchquery -replace '\s','%20'
    $searchdata = Invoke-RestMethod -Method 'GET' -uri $searchquery | Select -ExpandProperty data
    $wantedartistid = $searchdata | Select -ExpandProperty artist | Select -ExpandProperty id | Select-Object -first 1
    }
	#Check if wantedartistid is empty following search, if so it means no results were found.
    if (!$wantedartistid)
        {
		#Search deezer again using only artist name, take first result, set the artistID from deezer as variable wantedartistid, save wantedartistid to lidarr-smloadr.txt file which will be used by smloadr.
        write-host "First search of artist + album failed, searching with just artist."
        $searchquery = "https://api.deezer.com/search?q=$wantedartist"
        $searchdata = Invoke-RestMethod -Method 'GET' -uri $searchquery | Select -ExpandProperty data
        $wantedartistid = $searchdata | Select -ExpandProperty artist | Select -ExpandProperty id | Select-Object -first 1
        Write-Output "SMloadr url for $wantedartist - https://www.deezer.com/artist/$wantedartistid found using $searchquery" | Out-File -FilePath $scriptdir\log.txt -Append
        Write-Host "$wantedartistid id located for $wantedartist"
        Write-Output $wantedartistid | Out-File -FilePath $scriptdir\lidarr-smloadr.txt -Append
        }
     else
     {
	 #Save wantedartistid to lidarr-smloadr.txt file which will be used by smloadr.
     Write-Output "SMloadr url for $wantedartist - https://www.deezer.com/artist/$wantedartistid found using $searchquery" | Out-File -FilePath $scriptdir\log.txt -Append
     Write-Host "$wantedartistid id located for $wantedartist"
     Write-Output $wantedartistid | Out-File -FilePath $scriptdir\lidarr-smloadr.txt -Append
     }
#Small sleep to not hammer deezer with api search requests.
write-host ""
Start-Sleep -m 250
}
#Take all entries into lidarr-smloadr.txt sort it numerically, remove any duplicates, save into temp file, remove original file, rename temp file back to original.
Get-Content -Path "$scriptdir\lidarr-smloadr.txt" | sort-object | get-unique > "$scriptdir\lidarr-smloadr-temp.txt"
Remove-Item -Path "$scriptdir\lidarr-smloadr.txt"
Rename-Item -Path "$scriptdir\lidarr-smloadr-temp.txt" -NewName "lidarr-smloadr.txt"

#Test if download dir doesn't exist, if true then create directory.
if(!(Test-Path -Path "$downloaddir" )){New-Item -ItemType directory -Path "$downloaddir"}
#Set smloadrartists variable from lidarr-smloadr.txt file, this has the IDs of all the artists we want to download with smloadr.
$smloadrartists = Get-Content -Path "$scriptdir\lidarr-smloadr.txt"
#Loop through each ID from smloadrartists.
Foreach ($smloadrartist in $smloadrartists)
{Write-Host "Starting grab - Artist Number $smloadrartist"
#Download smloadrartists with smloadr to downloaddir.
SMLoadr-win-x64 -q MP3_320 -p $downloaddir https://www.deezer.com/artist/$smloadrartist
#Copy files to another location. I use this to upload files to my google drive but you can remove if you store locally or want to upload manually.
#(Note COPY rather then move, if files are moved next time you run this script smloadr witll download everything again.)
rclone copy "E:\smloadr" "G:\My Drive\Media\Music" --log-level INFO --ignore-checksum --stats 5s --max-age 6h
}