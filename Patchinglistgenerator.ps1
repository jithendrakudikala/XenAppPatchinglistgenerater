<#
.synopsis
   <<synopsis goes here>>
.Description
  <<Description goes here>>
.Notes
  ScriptName  : PatchingListgenerater.PS1
  Requires    : Powershell Version 5.0
  Author      : Jithendra Kudikala
  EMAIL       : jithendra.kudikala@gmail.com
  Version     : 1.1 Script will get server information from Xenapp Sites and devide them into 3 phases(UAT Phase1, PROD will be devided into PHASE2 & PHASE3) and updated the SCCM respective SCCM collections
.Parameter
   None
 .Example
   None
#>

add-pssnapin Citric*

#pass the DDCs in different file or this can be amended to pass in one file and filer based on site name.
$UATDDCs = Get-Content "location of UAT DDCs in .txt file" 
$PRODDDCs = Get-Content "location of PROD DDCs in .txt file"

$outputname = "./" + (Get-Date -format yyyy-MMM) + " - Members servers patching schedule.csv" # output file name
$output = @()

#generate list of UAT servers, all machines will be in phase 0 including unconfigured servers
foreach($ddc in $UATDDCs)
{
    #Get reboot schedule
    $site = get-brokersite -adminaddress $ddc | select name
    $reboot = @()
    $desktopgroups = get-brokerdesktopgroups -adminaddress $ddc -maxrecordcount 999999

    foreach($desktopgroup in $desktopgroups)
    {
        $rebootfreqency = (get-brokerrebootschedule - adminaddress $ddc -desktopgroupuid $desktopgroup.uid -erroraction silentlycontinue).frequency

        if($rebootfreqency -eq "weekly")
        {
            (get-brokerrebootschedule - adminaddress $ddc -desktopgroupuid $desktopgroup.uid -erroraction silentlycontinue).day   
        }

        $rebootstarttime = (get-brokerrebootschedule - adminaddress $ddc -desktopgroupuid $desktopgroup.uid -erroraction silentlycontinue).starttime

        if ($rebootstarttime -ne $null) 
        {
            $rebootstarttime = ([timespan].$rebootstarttime).tostring("hhmm")
        }

        $Machines = get-brokermachine -adminaddress $ddc -desktopgroupuid $desktopgroup.uid -maxrecordcount 99999

        foreach($machine in $machines)
        {
            $objreboot = [PSCustomObject] @{
                Machine = $machine.machineName.split("\")[1]
                "Reboot Schedule" = "$rebootfrequency$rebootstarttime"
            }

            $reboot += $objreboot
        }

    }

    #Get servers
    $servers = @()
    $servers = [array]$servers + (get-brokermachine -adminaddress $ddc -maxrecordcount 99999 | Select-Object -Property Machinename, desktopgroupname, ostype)
    $servers = [array]$servers + (get-brokerunconfiguredmachine -adminaddress $ddc -maxrecordcount 99999 | Select-Object -Property Machinename, desktopgroupname, ostype)
    foreach($server in $servers)
    {
        if((($reboot | Where-Object -FilterScript {$_.Machine -eq $server.machinename.split("\")[1]})."reboot schedule" -eq $null) -or (($reboot | Where-Object -FilterScript {$_.Machine -eq $server.machinename.split("\")[1]})."reboot schedule" -eq ""))
        {
            $rebootschedule = "TBC"
        }
        else {
            $rebootschedule = ($reboot | Where-Object -FilterScript {$_.Machine -eq $server.machinename.split("\")[1]})."reboot schedule"
        }
        
        if ($server.desktopgroupname -eq $null) {
            $server.desktopgroupname = "TBC"
        }
        if($server.ostype -ne $null)
        {
            $operatingsystem = $servers.ostype
        }
        else {
            $operatingsystem = "TBC"
        }

        $serveroutput = @()
        $serveroutput = New-Object psobject -Property @{
            Server = $server.machinename.split("\")[1]
            Site = $site.name
            Desktopgroupname = $server.desktopgroupname
            "Operating System" = $operatingsystem
            PatchingPhase = "Phase1"
            Reboot = $rebootschedule
        }
        $output += $serveroutput
    }

}

#Generating List for production servers, Dividing servers into 2 phases for each delivary group and adding unconfigured servers into phase 2 list

foreach($ddc in $PRODDDCs)
{   
    $serversphase2 = @()
    $serversphase3 = @()
    #Get reboot schedule
    $site = get-brokersite -adminaddress $ddc | select name
    $reboot = @()
    $desktopgroups = get-brokerdesktopgroups -adminaddress $ddc -maxrecordcount 999999

    foreach($desktopgroup in $desktopgroups)
    {
        $rebootfreqency = (get-brokerrebootschedule - adminaddress $ddc -desktopgroupuid $desktopgroup.uid -erroraction silentlycontinue).frequency

        if($rebootfreqency -eq "weekly")
        {
            (get-brokerrebootschedule - adminaddress $ddc -desktopgroupuid $desktopgroup.uid -erroraction silentlycontinue).day   
        }

        $rebootstarttime = (get-brokerrebootschedule - adminaddress $ddc -desktopgroupuid $desktopgroup.uid -erroraction silentlycontinue).starttime

        if ($rebootstarttime -ne $null) 
        {
            $rebootstarttime = ([timespan].$rebootstarttime).tostring("hhmm")
        }

        $Machines = get-brokermachine -adminaddress $ddc -desktopgroupuid $desktopgroup.uid -maxrecordcount 99999

        foreach($machine in $machines)
        {
            $objreboot = [PSCustomObject] @{
                Machine = $machine.machineName.split("\")[1]
                "Reboot Schedule" = "$rebootfrequency$rebootstarttime"
            }

            $reboot += $objreboot
        }

        #dividing servers into phases
        for ($index = 0; $index -lt $Machines.Count; ) {
            $serversphase2 += $machines[$index]| select machinename,desktopgroupname,ostype
            $index++
            $serversphase3 += $Machines[$index] | select machineName,desktopgroupname,ostype
            $index++
        }
}

#adding unconfigured and free(Servers in MC but not in DG) servers to Phase 2 list
$serversphase2 += get-brokermachine -adminaddress $ddc -desktopgroupname $null -maxrecordcount 99999 | Select-Object -Property machineName,desktopgroupname,ostype
$serversphase2 += get-brokeunconfiguredrmachine -adminaddress $ddc -desktopgroupname $null -maxrecordcount 99999 | Select-Object -Property machineName,desktopgroupname,ostype

foreach($server in $serversphase2)
    {
        if((($reboot | Where-Object -FilterScript {$_.Machine -eq $server.machinename.split("\")[1]})."reboot schedule" -eq $null) -or (($reboot | Where-Object -FilterScript {$_.Machine -eq $server.machinename.split("\")[1]})."reboot schedule" -eq ""))
        {
            $rebootschedule = "TBC"
        }
        else {
            $rebootschedule = ($reboot | Where-Object -FilterScript {$_.Machine -eq $server.machinename.split("\")[1]})."reboot schedule"
        }
        
        if ($server.desktopgroupname -eq $null) {
            $server.desktopgroupname = "TBC"
        }
        if($server.ostype -ne $null)
        {
            $operatingsystem = $servers.ostype
        }
        else {
            $operatingsystem = "TBC"
        }

        $serveroutput = @()
        $serveroutput = New-Object psobject -Property @{
            Server = $server.machinename.split("\")[1]
            Site = $site.name
            Desktopgroupname = $server.desktopgroupname
            "Operating System" = $operatingsystem
            PatchingPhase = "Phase2"
            Reboot = $rebootschedule
        }
        $output += $serveroutput
    }

    foreach($server in $serversphase3)
    {
        if((($reboot | Where-Object -FilterScript {$_.Machine -eq $server.machinename.split("\")[1]})."reboot schedule" -eq $null) -or (($reboot | Where-Object -FilterScript {$_.Machine -eq $server.machinename.split("\")[1]})."reboot schedule" -eq ""))
        {
            $rebootschedule = "TBC"
        }
        else {
            $rebootschedule = ($reboot | Where-Object -FilterScript {$_.Machine -eq $server.machinename.split("\")[1]})."reboot schedule"
        }
        
        if ($server.desktopgroupname -eq $null) {
            $server.desktopgroupname = "TBC"
        }
        if($server.ostype -ne $null)
        {
            $operatingsystem = $servers.ostype
        }
        else {
            $operatingsystem = "TBC"
        }

        $serveroutput = @()
        $serveroutput = New-Object psobject -Property @{
            Server = $server.machinename.split("\")[1]
            Site = $site.name
            Desktopgroupname = $server.desktopgroupname
            "Operating System" = $operatingsystem
            PatchingPhase = "Phase3"
            Reboot = $rebootschedule
        }
        $output += $serveroutput
    }
}

$output | Select-Object -Property Server,"operating system",desktopgroupname, site,reboot,PatchingPhase | Sort-Object -Property desktopgroupname | Export-Csv $outputname -NoTypeInformation


#SCCM Site configuration
$sitecode = "Enter Site code here" #site code
$providermachinename = "Enter SMS provider machine name here" #SMS provider machine name

$parms = @()
if((get-module configurationmanager) -eq $null)
{
    Import-Module "c:\program files (x86)\microsoft endpoint manager\adminconsole\bin\configurationmanager\configurationmanager.psd1" @parms -ErrorAction SilentlyContinue
}
New-PSDrive -Name $sitecode -PSProvider "adminUI.PS.Provider\CMSite" -root $providermachine -Description "SCCM SIte" -ErrorAction SilentlyContinue
Set-Location -Path ($sitecode + ':')
if(get-cmsite)
{
    Write-Host "Connected to SCCM Console"
}
else {
    Write-Host "Unable to Connect SCCM Console"
}

$Phase1withReboot = $output | Where-Object {$_.PatchingPhase -eq "Phase1" -and $_.desktopgroupname -eq "TBC"} | Select server
$Phase1SUpressReboot = $output | Where-Object {$_.PatchingPhase -eq "Phase1" -and $_.desktopgroupname -ne "TBC"} | Select server
$Phase2withReboot = $output | Where-Object {$_.PatchingPhase -eq "Phase2" -and $_.desktopgroupname -eq "TBC"} | Select server
$Phase2SupressReboot = $output | Where-Object {$_.PatchingPhase -eq "Phase2" -and $_.desktopgroupname -ne "TBC"} | Select server
$Phase3SupressReboot = $output | Where-Object {$_.PatchingPhase -eq "Phase3" -and $_.desktopgroupname -ne "TBC"} | Select server

Function update-SCCMCOllection
{
    param($SCCMCOllectionName,$SCCMcollectionmemberlist)
    if($SCCMcollectionmemberlist -gt 0)
    {
        try {
            if ($rules = get-cmdevicecollectionquerymembershiprule -collectionname $SCCMCOllectionName) {
                foreach($rule in $rules)
                {
                    remove-cmdevicecollectionquerymembershiprule -collectionname $SCCMCOllectionName -rulename $rule.rulename -force -erroraction stop 
                }
            }
        }
        catch {
            Write-Host $_.Exception
            exit     
        }
        $sccmquerytemp = @()
        foreach($member in $SCCMcollectionmemberlist.server)
        {
            $sccmquerytemp += '"' + $member + '"' + ','
        }
        [system.collections.arraylist]$sccmquerytemp = $sccmquerytemp
        [int]$ruleindex = 0
        try {
            do {
              $rulename = "rule" + $ruleindex
              Write-Host $sccmquerytemp.Count "start"
              if($sccmquerytemp.Count -le 999)
              {
                    [string]$range = $sccmquerytemp.GetRange(0,$sccmquerytemp.Count)
              }
              else {
                  [string]$range = $sccmquerytemp.GetRange(0,1000)
              }

                  $sccmmemberqueylist = $sccmquerytemp.trimend(',')

                  $sccmquery = "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,
                  SMS_R_SYSTEM.SMSUniqueIdentifier, SMS_R_SYSTEM.ResourceDomainORWorkgroup,
                  SMS_R_SYSTEM.Client from SMS_R_SYSTEM where SMS_R_SYSTEM.name in($sccmmemberqueylist)"

                  add-CMdevicecollectionquerymembershiprule -collectionname $sccmcollectionname -queryexpression $sccmquery -rulename $rulename -erroraction stop
                  if ($sccmquerytemp -le 999) {
                      $sccmquerytemp.RemoveRange(0,$sccmquerytemp.Count)
                  }
                  else {
                      $sccmquerytemp.RemoveRange(0,1000)
                  }
              $ruleindex ++
              
              } until($null -eq $sccmquerytemp -or $sccmquerytemp -eq 0) 
            } 
            catch
            {
                Write-Host $_.Exception
                exit
            }
        }
        else {
            Write-Host "List contains ZERO servers"
        }
}

#update SCCM collections using membership rule(each rule adds 1000 members to collection)
update-SCCMCOllection -SCCMCOllectionName "Collection Name for $Phase1withReboot" -SCCMcollectionmemberlist $Phase1withReboot
update-SCCMCOllection -SCCMCOllectionName "Collection Name for $Phase1SUpressReboot" -SCCMcollectionmemberlist $Phase1SUpressReboot
update-SCCMCOllection -SCCMCOllectionName "Collection Name for $Phase2withReboot" -SCCMcollectionmemberlist $Phase2withReboot
update-SCCMCOllection -SCCMCOllectionName "Collection Name for $Phase2SupressReboot" -SCCMcollectionmemberlist $Phase2SupressReboot
update-SCCMCOllection -SCCMCOllectionName "Collection Name for $Phase3SupressReboot" -SCCMcollectionmemberlist $Phase3SupressReboot 

#Get the member count of the collections updated for verification
get-cmdevicecollection -Name "Collection name for $Phase1withReboot" | select name,membercount
get-cmdevicecollection -Name "Collection name for $Phase1SUpressReboot" | select name,membercount
get-cmdevicecollection -Name "Collection name for $Phase2withReboot" | select name,membercount
get-cmdevicecollection -Name "Collection name for $Phase2SupressReboot" | select name,membercount
get-cmdevicecollection -Name "Collection name for $Phase3SupressReboot" | select name,membercount
