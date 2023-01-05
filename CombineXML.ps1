
function Write-Log {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [Alias('LogPath')]
        [string]$Path = 'C:\Logs\PowerShellLog.log',
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Error", "Warn", "Info")]
        [string]$Level = "Info",
        
        [Parameter(Mandatory = $false)]
        [switch]$NoClobber
    )

    Begin {
        # Set VerbosePreference to Continue so that verbose messages are displayed.
        $VerbosePreference = 'Continue'
    }
    Process {
        
        # If the file already exists and NoClobber was specified, do not write to the log.
        if ((Test-Path $Path) -AND $NoClobber) {
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name."
            Return
        }

        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
        elseif (!(Test-Path $Path)) {
            Write-Verbose "Creating $Path."
            $NewLogFile = New-Item $Path -Force -ItemType File
        }

        else {
            # Nothing to see here yet.
        }

        # Format Date for our Log File
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Write message to error, warning, or verbose pipeline and specify $LevelText
        switch ($Level) {
            'Error' {
                Write-Error $Message
                $LevelText = 'ERROR:'
            }
            'Warn' {
                Write-Warning $Message
                $LevelText = 'WARNING:'
            }
            'Info' {
                Write-Verbose $Message
                $LevelText = 'INFO:'
            }
        }
        
        # Write log entry to $Path
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append
    }
    End {
    }
}

Import-Module .\Set-Owner.ps1 -Force


function combine-XMLFiles {

    param
    (
        [string]$path = "D:\FTP\Ftp.GPOS.KSG.ie\FtpGpos\R0003\",
        [string]$archive = "D:\CombineXML\archive\",
        [string]$log = "D:\CombineXML\logs\",
        [string]$dest = "\\KSGPRDWFS01\EPOS\",
        [int]$tills = 7
    )

    $dfilename, $headerFile, $filesname = $null
    Get-Variable -Name var* | Remove-Variable -Force

    $Noahfile = Get-ChildItem -Path $path -Filter *R0003*
    if ( $null -ne $Noahfile) {
        $noahys = $Noahfile.Name.Substring(0, 8) | Get-Unique
        foreach ($noahy in $noahys) {
            $filter1 = "$noahy" + "*R1.xml"
            $Headerfiles = Get-ChildItem -Path $path -Filter $filter1

            foreach ($headerFile in $Headerfiles) {

                $value = Get-Content -Path $headerFile.FullName
                if (($value -match '<KsgPaymSales>Payment</KsgPaymSales>').Count -ne 0) {
                    Write-Log -Path "$log\$(Get-Date -Format "dd-MM-yyyy").log" "Loading file $headerFile"
                    [xml]$var1 = Get-Content -Path $headerFile.FullName
                    $dfilename = $headerFile.Name
                    [string]$handheld = "Handheld"
                    $destinationfile = "$dest" + "$Handheld"+ "_" + "$dfilename"
                    Move-Item -Path $headerFile.FullName -Destination $archive -Force
                    Write-Log -Path "$log\$(Get-Date -Format "dd-MM-yyyy").log" "file moved to archive $headerFile.FullName"
                }
                else {
                    Write-Log -Path "$log\$(Get-Date -Format "dd-MM-yyyy").log" "No New files to load"
                    Move-Item -Path $headerFile.FullName -Destination $archive -Force
                    Write-Log -Path "$log\$(Get-Date -Format "dd-MM-yyyy").log" "file moved to archive with payment on it $headerFile.FullName"
                }
            }
            $filesname = $(Get-ChildItem -Path $path -Filter *$noahy* | Where-Object { $_.Name -notlike '*R1*' })

            if ( $null -ne $var1 -and $null -ne $filesname) {
                $i = 1
                foreach ( $file in $filesname.FullName) {
                    $i++
                    Remove-Variable -Name "var$i" -ErrorAction SilentlyContinue
                    New-Variable -Name "var$i" -Value ($(Get-Content -Path $file) -as [xml])
                    Write-Log -Path "$log\$(Get-Date -Format "dd-MM-yyyy").log" "Loading file $file"
                    Move-Item -Path $file -Destination $archive -Force
                }

                for ($i = 2 ; $i -le ($filesname.count + 1); $i++) {
                    if ($null -ne "var$i") {
                        
                        $xmlnodes = $null
                        
                        $xmlnodes = $($(Get-Variable -Name "var$i").Value).DocumentElement.Body.MessageParts.KsgRetailStaging.ChildNodes
						
                        ForEach ($XmlNode in $($(Get-Variable -Name "var$i").Value).DocumentElement.Body.MessageParts.KsgRetailStaging.ChildNodes) {
                            $var1.DocumentElement.Body.MessageParts.KsgRetailStaging.AppendChild($var1.ImportNode($XmlNode, $true)) | Out-Null
                        }
                    }
                }

                $nodes = $var1.DocumentElement.Body.MessageParts.KsgRetailStaging.ChildNodes

                foreach ($node in $nodes) {
                    $node.RetailTerminalId = $node.RetailTerminalId.Replace('R0003_R2', 'R0003_R1')
                    $node.RetailTerminalId = $node.RetailTerminalId.Replace('R0003_R3', 'R0003_R1')
                    $node.RetailTerminalId = $node.RetailTerminalId.Replace('R0003_R4', 'R0003_R1')
                    $node.RetailTerminalId = $node.RetailTerminalId.Replace('R0003_R5', 'R0003_R1')
                    $node.RetailTerminalId = $node.RetailTerminalId.Replace('R0003_R6', 'R0003_R1')
                    $node.RetailTerminalId = $node.RetailTerminalId.Replace('R0003_R7', 'R0003_R1')
            
                }

                Write-Log -Path "$log\$(Get-Date -Format "dd-MM-yyyy").log" "String replace completed"

                $var1.save("$destinationfile")

                #Set-Owner -Path "D:\share\EPOS" -Account "KSG\EPOS" -Recurse -Verbose

                Write-Log -Path "$log\$(Get-Date -Format "dd-MM-yyyy").log" "writing to destination $destinationfile"

            }
            else {
                if ($null -ne $filesname) {
                    foreach ($file in $filesname.fullname) {
                        #Move-Item -Path $file -Destination $archive -Force
                        Write-Log -Path "$log\$(Get-Date -Format "dd-MM-yyyy").log" "No header to load moved the the files only"
                    }
                }
            }
        }  
    }
    else {
        Write-Log -Path "$log\$(Get-Date -Format "dd-MM-yyyy").log" "No New files to load"

    }


}

combine-XMLFiles



