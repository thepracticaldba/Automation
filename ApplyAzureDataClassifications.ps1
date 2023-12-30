#Connect-AzAccount 
#(You can use different methods for authentication- MFA, service principal, MSI, credentials. https://learn.microsoft.com/en-us/powershell/module/az.accounts/connect-azaccount?view=azps-11.1.0#examples)
#Install-Module -Name Az.Sql -RequiredVersion 2.6.0 -SkipPublisherCheck -force -AllowClobber
#Install-Module -Name ImportExcel -RequiredVersion 7.8.4
Import-module Az.Sql -RequiredVersion 2.6.0 -ErrorAction Stop
Import-module ImportExcel -RequiredVersion 7.8.4 -ErrorAction Stop
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

$fileName  = "Data Classifications-" + (Get-Date -f yyyyMMdd) + ".xlsx"
#Change the file path as per environment
$outputFile = Join-Path -Path "C:\Security\" -ChildPath $fileName
$startTime = ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date), "AUS Eastern Standard Time")).ToString("dd/MM/yyy HH:mm tt")


$AzureSQLClassStatus1 = @()

$subscriptions = Get-AzSubscription
foreach ($sub in $subscriptions)
{
    $sub | Set-AzContext | Out-Null
    $AzureSQLServers =Get-AzResource |Where-Object ResourceType -EQ Microsoft.SQL/servers

foreach ($AzureSQLServer in $AzureSQLServers)
{
    $AzureSQLServerDataBases = Get-AzSqlDatabase -ServerName $AzureSQLServer.Name -ResourceGroupName $AzureSQLServer.ResourceGroupName |Where-Object {$_.DatabaseName -ne "master"}
        # Where-Object {($_.Tags.Keys -contains 'PROD')} if you have tags set up to identify all Production databases
        foreach ($AzureSQLServerDataBase in $AzureSQLServerDataBases) 
        {
                $svName =$AzureSQLServerDataBase.ServerName
                $DBName =$AzureSQLServerDataBase.DatabaseName
                $ResourceGroupName= $AzureSQLServer.ResourceGroupName

Write-Output "Applying Classifications for database:" $DBName
$classifications=Get-AzSqlDatabaseSensitivityRecommendation -ResourceGroupName $ResourceGroupName -ServerName $svName -DatabaseName $DBName |Set-AzSqlDatabaseSensitivityClassification
$appliedclassifications=Get-AzSqlDatabaseSensitivityClassification -ResourceGroupName $ResourceGroupName -ServerName $svName -DatabaseName $DBName


foreach  ($class in $appliedclassifications) 
       {
            
            $AzureSQLClassStatus = [PSCustomObject]@{

                'ResourceGroupName' = $ResourceGroupName
                'Database Server' = $svName
                'Database Name' = $DBName
                'Sensitivity Labels'=(@($class.SensitivityLabels) -join ',')
            }
            
            $AzureSQLClassStatus1 += $AzureSQLClassStatus
        }
               
      
 }
}
}

# Create spreadsheet
#---------------------------------------
$excelArgs = @{
    AutoSize = $true
    Path = $outputFile
    WorkSheetName = "Data Classifications $(Get-Date -f "yyyy-MM-dd")"
    FreezeTopRow = $true
    TitleFillPattern = 'Solid'
    TableName = 'Table1'
    TableStyle = 'Light9'
}

  Remove-Item -Path $outputFile -Force -ErrorAction SilentlyContinue
  Write-Output "Generating Excel spreadsheet"

  $AzureSQLClassStatus1 | Export-Excel @excelArgs -ea Stop

  