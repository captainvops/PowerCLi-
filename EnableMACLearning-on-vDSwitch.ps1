#Every PG on DSwitch inherits this configuration and will have MAC learning enabled unless specifically disabled

$vds = get-vdswitch 'DSwitch1'
$spec = New-Object VMware.Vim.VMwareDVSConfigSpec
$spec.DefaultPortConfig = New-Object VMware.Vim.VMwareDVSPortSetting
$spec.DefaultPortConfig.MacManagementPolicy = New-Object VMware.Vim.DVSMacManagementPolicy
$spec.DefaultPortConfig.MacManagementPolicy.MacLearningPolicy = New-Object VMware.Vim.DVSMacLearningPolicy
 
$spec.DefaultPortConfig.MacManagementPolicy.MacLearningPolicy.Enabled = $True
$spec.DefaultPortConfig.MacManagementPolicy.MacLearningPolicy.AllowUnicastFlooding = $True
$spec.DefaultPortConfig.MacManagementPolicy.MacLearningPolicy.Limit = 4000
$spec.DefaultPortConfig.MacManagementPolicy.MacLearningPolicy.LimitPolicy = "DROP"
$vds.ExtensionData.ReconfigureDvs_Task($spec)
