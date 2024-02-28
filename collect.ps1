$ErrorActionPreference = "Stop"

$osVersion = 1809 # Use 1809 for Windows Server 2019 and ltsc2022 for Windows Server 2022
$nodeName = ""    # The name of the Windows node to collect, this should be the same the container is running on
$collectSec = 30  # The number of seconds to collect the PerfView log
$podNS = ""       # The namspace the pod is running in
$podName = ""     # The name of of the pod

Write-Output "Is the following context correct (Y/N)?"
kubectl config current-context
$answer = Read-Host
if ($answer -ne "Y") {
    Write-Output "Exiting..."
    exit
}

$hostProcessContainer = 
"kind: Namespace
apiVersion: v1
metadata:
  name: perfview
---
apiVersion: v1
kind: Pod
metadata:
  name: hpc
  namespace: perfview
spec:
  securityContext:
    windowsOptions:
      hostProcess: true
      runAsUserName: ""NT AUTHORITY\\SYSTEM""
  hostNetwork: true
  containers:
    - name: hpc
      image: mcr.microsoft.com/windows/servercore:$osVersion
      command:
        - powershell.exe
        - -Command
        - Start-Sleep -Seconds 2147483
      imagePullPolicy: IfNotPresent
  nodeSelector:
    kubernetes.io/os: windows
    kubernetes.io/hostname: $nodeName
  tolerations:
    - effect: NoSchedule
      key: node.kubernetes.io/unschedulable
      operator: Exists
    - effect: NoSchedule
      key: node.kubernetes.io/network-unavailable
      operator: Exists
    - effect: NoExecute
      key: node.kubernetes.io/unreachable
      operator: Exists"      

if (!(Test-Path PerfView.exe)) {
    Write-Output "Downloading PerfView..."
    (New-Object Net.WebClient).DownloadFile("https://github.com/microsoft/perfview/releases/download/v3.1.8/PerfView.exe", "PerfView.exe")
}

Write-Output "Deploying HostProcess container..."
Write-Output $hostProcessContainer | kubectl apply -f -

Write-Output "Waiting for host container to be ready..."
kubectl wait --for=condition=Ready -n perfview pod/hpc

Write-Output "Copying PerfView into host container..."
kubectl cp .\PerfView.exe perfview/hpc:PerfView.exe

Write-Output "Copying script into host container..."
$hc = Get-Content .\host-container.ps1
$hc.Replace("%collectSec%", $collectSec) > .\host-container.tmp.ps1
kubectl cp .\host-container.tmp.ps1 perfview/hpc:host-container.ps1

Write-Output "Running script in host container..."
kubectl exec -it -n perfview hpc -- powershell "./host-container.ps1"

Write-Output "Copying log from host container..."
kubectl cp perfview/hpc:PerfViewData.etl.zip host.etl.zip

Write-Output "Deleting host container..."
kubectl delete -n perfview pod hpc

Write-Output "Deleting namespace..."
kubectl delete namespace perfview

Write-Output "Copying PerfView into target container..."
kubectl cp .\PerfView.exe $podNS/$($podName):PerfView.exe

Write-Output "Copying script into target container..."
kubectl cp target-container.ps1 $podNS/$($podName):target-container.ps1

Write-Output "Copying host log into target container..."
kubectl cp host.etl.zip $podNS/$($podName):host.etl.zip

Write-Output "Running merge in target container..."
kubectl exec -it -n $podNS $podName -- powershell "./target-container.ps1"

Write-Output "Copying merged log from target container..."
kubectl cp $podNS/$($podName):host.etl.zip merged.etl.zip

Write-Output "Done."