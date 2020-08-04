Configuration Main
{

Param ( [string] $nodeName, [string] $webDeployPackage )

Import-DscResource -ModuleName PSDesiredStateConfiguration
#Import-DscResource -ModuleName xPSDesiredStateConfiguration
#Import-DscResource -ModuleName xNetworking

Node $nodeName
  {
   		# Install the IIS role 
		WindowsFeature IIS 
		{ 
			Ensure          = "Present" 
			Name            = "Web-Server" 
		} 
		# Install the ASP .NET 4.5 role 
		WindowsFeature AspNet45 
		{ 
			Ensure          = "Present" 
			Name            = "Web-Asp-Net45" 
		} 

		# Install the IIS Management Tools 
		WindowsFeature Web-Mgmt-Console 
		{ 
			Ensure          = "Present" 
			Name            = "Web-Mgmt-Console" 
		} 

		# Install the IIS Management Tools 
		WindowsFeature Web-Mgmt-Service 
		{ 
			Ensure          = "Present" 
			Name            = "Web-Mgmt-Service" 
		} 

		 <#
            Download dotnet core hosting bundle
        #>
		 
		$Uri = "https://download.visualstudio.microsoft.com/download/pr/a9bb6d52-5f3f-4f95-90c2-084c499e4e33/eba3019b555bb9327079a0b1142cc5b2/dotnet-hosting-2.2.6-win.exe"
		$destination = "D:\dotnet-hosting-2.2.6-win.exe"

		Invoke-WebRequest $Uri -OutFile $destination -UseBasicParsing

       
        Package InstallDotNetCoreHostingBundle {
            Name = "Microsoft ASP.NET Core Module"
            ProductId = "045E5948-E882-4957-890D-6387E3AD463A"
            Arguments = "/quiet /install /norestart /log D:\dotnet-hosting-2.2.6-win_install.log"
            Path = "D:\dotnet-hosting-2.2.6-win.exe"
            DependsOn = @("[WindowsFeature]IIS")
        }
	   
	   


		Script DeployWebPackage
		{
			GetScript = {@{Result = "DeployWebPackage"}}
			TestScript = {$false}
			SetScript ={
				[system.io.directory]::CreateDirectory("C:\WebApp")
				$dest = "C:\WebApp\Site.zip" 
				Remove-Item -path "C:\inetpub\wwwroot" -Force -Recurse -ErrorAction SilentlyContinue
				Invoke-WebRequest $using:webDeployPackage -OutFile $dest
				Add-Type -assembly "system.io.compression.filesystem"
				[io.compression.zipfile]::ExtractToDirectory($dest, "C:\inetpub\wwwroot")
			}
		#	DependsOn  = "[WindowsFeature]IIS"
		}

		# Copy the website content 
		File WebContent 
		{ 
			Ensure          = "Present" 
			SourcePath      = "C:\WebApp"
			DestinationPath = "C:\Inetpub\wwwroot"
			Recurse         = $true 
			Type            = "Directory" 
			DependsOn       = "[Script]DeployWebPackage" 
		}    
		
  }
}