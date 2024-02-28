$osVersion = 1809 # ltsc2022
$nodeName = "akswinnon00000q"
$collectSec = 30
$podNS = "msdtcpoc"
$podName = "msdtcpoc-wcf-0"

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

Write-Output "Deploying HostProcess container..."
Write-Output $hostProcessContainer | kubectl apply -f -

Write-Output "Waiting for host container to be ready..."
kubectl wait --for=condition=Ready -n perfview pod/hpc

Write-Output "Copying script into host container..."
$hc = Get-Content .\host-container.ps1
$hc.Replace("%collectSec%", $collectSec) > .\host-container.tmp.ps1
kubectl cp .\host-container.tmp.ps1 perfview/hpc:host-container.ps1

Write-Output "Running script in host container..."
kubectl exec -it -n perfview hpc -- powershell "./host-container.ps1"

Write-Output "Copying file from host container..."
kubectl cp perfview/hpc:PerfViewData.etl.zip Host.etl.zip

Write-Output "Copying script into target container..."
kubectl cp target-container.ps1 $podNS/$($podName):target-container.ps1

Write-Output "Copying host file into target container..."
kubectl cp Host.etl.zip $podNS/$($podName):Host.etl.zip

Write-Output "Running merge in target container..."
kubectl exec -it -n $podNS $podName -- powershell "./target-container.ps1"

Write-Output "Copying file from target container..."
kubectl cp $podNS/$($podName):Host.etl.zip Merged.etl.zip

Write-Output "Deleting host container..."
kubectl delete -n perfview pod hpc

Write-Output "Done."