Clear-Host
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) #make me admin if I'm not already
{   
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Break
}

Write-Host """
      _            _       _ 
     | |          | |     (_)
   __| | ___ _ __ | | ___  _ 
  / _` |/ _ \ '_ \| |/ _ \| |
 | (_| |  __/ |_) | | (_) | |
  \__,_|\___| .__/|_|\___/|_|
            | |              
            |_|              
 ___________________________________
|-------- version 1.0.1 ------------|
|----- https://github.com/b3b0 -----|
|___________________________________|           

"""

$global:commandstring = "nothing"
Write-Output "" > thissession.lst #clear the old session
Function Get-FileName($initialDirectory)
{  
 [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
 $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
 $OpenFileDialog.initialDirectory = $initialDirectory
 $OpenFileDialog.filter = "All files (*.*)| *.*"
 $OpenFileDialog.ShowDialog() | Out-Null
 $OpenFileDialog.filename
}
function importProc()
{
    [System.Collections.ArrayList]$procElements = @()
    Get-ChildItem C:\Users\$env:UserName\remote-installer\ | Select-Object -ExpandProperty Name
    Write-Host "----------------------------------"
    $usedProc = Read-Host "Which will you use?"
    $readProcFile = "C:\Users\$env:UserName\remote-installer\$usedProc.proc"
    foreach($line in (Get-Content $readProcFile))
    {
        $procElements.Add($line)
    }
    Write-Host $procElements[0]
    Write-Host $procElements[1]
    $global:commandstring = $procElements[1]
    $listOfSourceFiles.Add($procElements[0])
}
function newProc()
{
    Write-Host "Select at least one file!"
    $source1 = Get-Filename -initialDirectory "c:\users"
    $listOfSourceFiles.Add($source1)
    Write-Host "You added $sourceother to the list.
    --------------------
    Here's the list now:
    --------------------
    $listOfSourceFiles
    --------------------"
    $addingmore = 1     #bool to check whether or not we are gonna keep adding more
    while ($addingmore -eq 1)
    {
        $addmore = Read-Host "Do you need to add another file?"
        if ($addmore -eq "y")
        {
            $sourceother = Get-Filename -initialDirectory "c:\users"
            $listOfSourceFiles.Add($sourceother)
            Write-Host "You added $sourceother to the list.
    --------------------
    Here's the list now:
    --------------------
    $listOfSourceFiles
    --------------------"
        }
        else
        {
            $addingmore = 0
        }
    }
    Write-Host "Now let's get the final commands from you."
    $global:commandstring = Read-host "COMMAND STRING:"
}
[System.Collections.ArrayList]$listOfSourceFiles = @() #create an empty array that will later be defined with files to send
$typeOf = Read-Host "Will you use an existing procedure?"
if ($typeOf -eq "y")
{
    importProc
}
else 
{
    newProc
}
Write-Host "Select your list of hosts to receive the files!"
$hostlist = Get-Filename -initialDirectory "c:\users"
foreach ($hostguy in (Get-Content $hostlist)) #check to see which ones are pingable so we don't waste time or get a bunch of errors trying to do this against a machine that's not on
{
    Write-Host "Checking $hostguy ..."
    $alivetest = Test-Connection -Quiet -Count 1 -ComputerName $hostguy
    if ($alivetest -eq "True")
    {
        Write-Output $hostguy >> thissession.lst  #add it to the session list if it's live
        Write-Host "Alive!" -ForegroundColor Green
    }
    else
    {
        Write-Host "Dead :(" -ForegroundColor Red
    }
}
(Get-Content ./thissession.lst) | ? {$_.trim() -ne "" } | set-content thissession.lst #this mess gets rid of empty lines in the sessionlist so we dont try this stuff against NULL lines.
$content = [System.IO.File]::ReadAllText("./thissession.lst")
$content = $content.Trim()
[System.IO.File]::WriteAllText("./thissession.lst", $content)
foreach ($finalhost in Get-Content thissession.lst)
{
    Write-Host "++++++++++++++++++++++++"
    foreach ($item in $listOfSourceFiles)
    {
        $tempdir = "\\$finalhost\c$\deploi"
        Write-Host "Tranferring $item to $tempdir"
        if (-not (Test-Path $tempdir))
            { 
                Write-Host "Creating staging directory at $tempdir" # create the staging directory for the files if it doesnt exist on the remote machine
                New-Item -ItemType "directory" $tempdir
            }
        Copy-Item -Path "$item" -Destination "\\$finalhost\c$\deploi" -Force
        Write-Host "Done transferring. About to start running a command."
    }
    Write-Host "Running $global:commandstring against $finalhost"
    & psexec \\$finalhost cmd /c "cd C:\deploi\ & $global:commandstring" > $finalhost-results.txt
    Write-Host "------------------------"
}
Write-Host "
D O N E
"
if (-not($typeOf -eq "y"))
{
    $saveQuestion = Read-Host "Will you save these settings to procedure file?"
    if ($saveQuestion -eq "y")
    {
        $procName = Read-Host("Name of procedure?")
        Write-Output "$listOfSourceFiles`n$global:commandstring" > "C:\Users\$env:UserName\remote-installer\$procName.proc"
    }
}
Write-Host "Press any key to continue..."
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
