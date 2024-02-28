Write-Output "Configuring symbols..."
if (!(Test-Path ~\appdata\roaming\perfview)) {
    New-Item -ItemType Directory -Path ~\appdata\roaming\perfview
}
Write-Output "<ConfigData><_NT_SOURCE_PATH /><_NT_SYMBOL_PATH>SRV*%TEMP%\SymbolCache*https://msdl.microsoft.com/download/symbols</_NT_SYMBOL_PATH><EULA_Accepted>1</EULA_Accepted></ConfigData>" > ~\appdata\roaming\perfview\userconfig.xml
Write-Output "Cleaning up old log file..."
if (Test-Path log.txt) { Remove-Item log.txt }
Write-Output "Running PerfView..."
./PerfView merge Host.etl.zip -ImageIDsOnly /logFile=log.txt
Write-Output "*** Press CTRL+C when the process is complete, the line will start with [DONE ***"
do {
    Start-Sleep -Seconds 1
} until (
    Test-Path log.txt
)
Get-Content log.txt -Wait