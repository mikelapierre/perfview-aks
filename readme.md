# Collect PerfView logs for Windows Containers on AKS

### Pre-requisites
- PowerShell
- kubectl and a valid context
- Access to https://msdl.microsoft.com/download/symbols from AKS
- Access to download https://github.com/microsoft/perfview/releases/download/v3.1.8/PerfView.exe (can be copied manually into this folder)

### Instructions
 - Connect to AKS with kubectl
 - Update the following variables in collect.ps1:
   - $osVersion: Use **1809** for Windows Server 2019 and **ltsc2022** for Windows Server 2022
   - $nodeName: The name of the Windows node to collect, this should be the same the container is running on
   - $collectSec: The number of seconds to collect the PerfView log
   - $podNS: The namspace the pod is running in
   - $podName = The name of of the pod
 - Run collect.ps1 with PowerShell
 - Confirm the context is correct by answering Y or N
 - When the collection is done, the output will and should end with a line looking like this:
   - [DONE 14:55:01 SUCCESS: PerfView /logFile=log.txt /maxCollectSec=30 /threadTime /EnableEventsInContainers collect]
 - Hit Ctrl+C to let the script continue
 - When the merging is done, the output will stop again and should end with a line looking like this:
   - [DONE 14:57:53 SUCCESS: PerfView merge Host.etl.zip -ImageIDsOnly /logFile=log.txt]
 - Hit Ctrl+C to let the script continue
 - When the script outputs Done. the process is complete and you can analyze the merged.etl.zip file with PerfView