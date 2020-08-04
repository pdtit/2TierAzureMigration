Configuration Main
{

Param ( [string] $nodeName )

Import-DscResource -ModuleName PSDesiredStateConfiguration

Node $nodeName
  {
  Script InstallSQL
    {
        TestScript = {
            return $false
        }
        SetScript ={

		$disks = Get-Disk | Where partitionstyle -eq 'raw' 
		if($disks -ne $null)
		{
			# Create a new storage pool using all available disks 
			New-StoragePool –FriendlyName "VMStoragePool" `
				–StorageSubsystemFriendlyName "Storage Spaces*" `
				–PhysicalDisks (Get-PhysicalDisk –CanPool $True)

			# Return all disks in the new pool
			$disks = Get-StoragePool –FriendlyName "VMStoragePool" `
					-IsPrimordial $false | 
					Get-PhysicalDisk

			# Create a new virtual disk 
			New-VirtualDisk –FriendlyName "DataDisk" `
				-ResiliencySettingName Simple `
						–NumberOfColumns $disks.Count `
						–UseMaximumSize –Interleave 256KB `
						-StoragePoolFriendlyName "VMStoragePool" 

			# Format the disk using NTFS and mount it as the F: drive
			Get-Disk | 
			Where partitionstyle -eq 'raw' |
			Initialize-Disk -PartitionStyle MBR -PassThru |
			New-Partition -DriveLetter "F" -UseMaximumSize |
			Format-Volume -FileSystem NTFS -NewFileSystemLabel "DataDisk" -Confirm:$false

		Start-Sleep -Seconds 60

		$logs = "F:\Logs"
		$data = "F:\Data"
		$backups = "F:\Backup" 
		[system.io.directory]::CreateDirectory($logs)
		[system.io.directory]::CreateDirectory($data)
		[system.io.directory]::CreateDirectory($backups)
		[system.io.directory]::CreateDirectory("C:\SQLDATA")

		# Setup the data, backup and log directories as well as mixed mode authentication
		Import-Module "sqlps" -DisableNameChecking
		[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
		$sqlesq = new-object ('Microsoft.SqlServer.Management.Smo.Server') Localhost
		$sqlesq.Settings.LoginMode = [Microsoft.SqlServer.Management.Smo.ServerLoginMode]::Mixed
		$sqlesq.Settings.DefaultFile = $data
		$sqlesq.Settings.DefaultLog = $logs
		$sqlesq.Settings.BackupDirectory = $backups
		$sqlesq.Alter() 

		# Restart the SQL Server service
		Restart-Service -Name "MSSQLSERVER" -Force
		# Re-enable the sa account and set a new password to enable login
		Invoke-Sqlcmd -ServerInstance Localhost -Database "master" -Query "ALTER LOGIN sa ENABLE"
		Invoke-Sqlcmd -ServerInstance Localhost -Database "master" -Query "ALTER LOGIN sa WITH PASSWORD = 'L@BadminPa55w.rd'"

		# Download the SimplCommerce database backup 
		$dbsource = "https://pdtitlabsstorage.blob.core.windows.net/templates/SimplCommerce/simplcommerce.bak"
		$dbbackupfile = "C:\SQLDATA\simplcommerce.bak"
		$dbdestination = "C:\SQLDATA\simplcommerce.bak"

		Invoke-WebRequest $dbsource -OutFile $dbdestination -UseBasicParsing

		# Define parameters for the actual restore
		#RelocateData = sets the location for the database
		#RelocateLog = sets the location for the logfiles
		#$file = sets the parameter to both database and logfiles
		#$myarr = data and logfile is stored as an array, which is picked up by the restore-sqldatabase PowerSHell cmd

		#try without relocate 
		#$RelocateData = New-Object 'Microsoft.SqlServer.Management.Smo.RelocateFile, Microsoft.SqlServer.SmoExtended, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ArgumentList "SimplCommerce2014_Data", "F:\Data\SimplCommerceDB.mdf"
		#$RelocateLog = New-Object 'Microsoft.SqlServer.Management.Smo.RelocateFile, Microsoft.SqlServer.SmoExtended, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ArgumentList "SimplCommerce2014_Log", "F:\Logs\SimplCommerceDB.ldf"
		#$file = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($RelocateData,$RelocateLog) 
		#$myarr=@($RelocateData,$RelocateLog)

		#run the actual database restore
		#original cmdlet Restore-SqlDatabase -ServerInstance Localhost -Database "SimplCommerce" -BackupFile $dbbackupfile -RelocateFile $myarr
		
		Restore-SqlDatabase -ServerInstance Localhost -Database "SimplCommerce" -RestoreAction Database -BackupFile $dbbackupfile 


		#allow connection to SQL Instance
		New-NetFirewallRule -DisplayName "SQL Server" -Direction Inbound –Protocol TCP –LocalPort 1433 -Action allow 
		}
		}
     GetScript = {@{Result = "ConfigureSql"}}
	}
  }
}
