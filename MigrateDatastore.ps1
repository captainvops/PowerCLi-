# MigrateDatastore.ps1
# Curtis Salinas, 2011
# Twitter: @virtualcurtis
# Blog: virtualcurtis.wordpress.com

$sourceDatastore = "DatastoreVMFS5-01"
$destinationDatastore = "clu01_test"


<#
param($VIServer, $sourceDatastore, $destinationDatastore)

function InitializePCLI($VIServer) {
  # add VMware PS snapin
  if (-not (Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
      Add-PSSnapin VMware.VimAutomation.Core
  }
  
  # Set PowerCLI to single server mode
  Set-PowerCLIConfiguration -DefaultVIServerMode Single -Confirm:$False
  
  # connect vCenter server session
  if ($VIServer -eq $null) {
  	Connect-VIServer "myvcenter.mydomain.com" | Out-Null
  } else {
  	Connect-VIServer $VIServer | Out-Null
  }
}
#>
function migrateDatastore($sourceDatastore, $destinationDatastore) {
	
	$sourceDS = Get-Datastore $sourceDatastore
	$destinationDS = Get-Datastore $destinationDatastore
	$proceedWithMigration = $False

	# confirm space is available on destination datastore
	if ((($sourceDS | Get-View).Summary.Capacity) -le (($destinationDS | Get-View).Summary.Capacity)) {
		if (((($sourceDS | Get-View).Summary.Capacity) - (($sourceDS | Get-View).Summary.FreeSpace)) -le (($destinationDS | Get-View).Summary.FreeSpace)) {
			$proceedWithMigration = $True
		}
	}
	
	if ($proceedWithMigration -eq $True) {
		
		# convert all appropriate templates to VMs
		$templates = Get-Template
		$templatesToConvert = @()
		
		foreach ($tmpl in $templates) {
			if ($templates -ne $null) {
  			foreach ($ds in $tmpl.DatastoreIdList) {
  				if ($ds.Contains(($sourceDS | Get-View).Summary.Datastore.Value)) {
  					Set-Template -Template $tmpl -ToVM
  					$templatestoConvert += $tmpl
  				}
  			}
			}
		
		}
		
  	# grab all VM disks from source datastore & create array object to represent move plan
  	$VMstoMove = @()
  	foreach ($vm in ($sourceDS | Get-View).vm) {
  		$vmID = $vm.Type + "-" + $vm.Value
  		$VMstoMove += Get-VM | Where {$_.Id -eq $vmID}
  	}
  	
  	$DiskstoMove = @()
  	foreach ($vm in $VMstoMove) {
  		$disks = Get-HardDisk $vm
  		foreach ($disk in $disks) {
  			if ($disk.filename.Contains("[" + $sourceDS.Name + "]")) {
  				$DiskstoMove += $disk
  			}
  		}
  	}
  	
  	$DiskstoMove
  	
  	# move each VM disk to the destination datastore, if scsi Hard disk 1 lives on source, also migrate VM (.vmx, .vswp, etc.)
  	foreach ($disk in $DiskstoMove) {  	
  		if ($disk.Name -eq "Hard disk 1") {
  			# move VM config
  			Write-Host "Moving VM" $disk.Parent
  			migrateVMConfig -vm $disk.Parent -destinationDatastore $destinationDS.Name
  			# move disk
  			Write-Host "Moving disk" $disk.Name "on VM" $disk.Parent
  			Set-Harddisk -Harddisk $disk -Datastore $destinationDS -Confirm:$False
  		} else {
  			# move disk
  			Write-Host "Moving disk" $disk.Name "on VM" $disk.Parent
  			Set-Harddisk -Harddisk $disk -Datastore $destinationDS -Confirm:$False
  		}
  	}
  	
  	# convert appropriate VMs back to templates
  	foreach ($tmpl in $templatesToConvert) {
  		Set-VM -VM (Get-VM $tmpl) -ToTemplate -Confirm:$False
		}
	}
}

# Code in the migrateVMConfig function migrates only the VM config, swp, etc. files
# This was taken from a post on the VMware Community forums by Luc Dekens (LucD)
# relevant thread: http://communities.vmware.com/thread/299279/
# Luc's blog: http://www.lucd.info/
function migrateVMConfig($vm, $destinationDatastore) {
	$vmName = $vm 
	$tgtConfigDS = $destinationDatastore
	
	$vm = Get-VM -Name $vmName 
	$hds = Get-HardDisk -VM $vm
	
	$spec = New-Object VMware.Vim.VirtualMachineRelocateSpec 
	$spec.datastore = (Get-Datastore -Name $tgtConfigDS).Extensiondata.MoRef
	$hds | %{
	   $disk = New-Object VMware.Vim.VirtualMachineRelocateSpecDiskLocator
	   $disk.diskId = $_.Extensiondata.Key
	   $disk.datastore = $_.Extensiondata.Backing.Datastore
	   $spec.disk += $disk
	}

	$vm.Extensiondata.RelocateVM_Task($spec, "defaultPriority")
}

# Connect to vCenter Server
#InitializePCLI -VIServer $VIServer

# Migrate Datastore
migrateDatastore -sourceDatastore $sourceDatastore -destinationDatastore $destinationDatastore
