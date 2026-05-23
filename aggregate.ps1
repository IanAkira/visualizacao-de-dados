param(
    [Parameter(Mandatory=$true)][string[]]$Files,
    [string]$OutPath = "$PSScriptRoot\data.json",
    [string]$StatePath = "$PSScriptRoot\state.json"
)

# Carrega estado anterior (se existir) para acumular incrementalmente
if (Test-Path $StatePath) {
    $state = Get-Content $StatePath -Raw | ConvertFrom-Json
    $byIndustry   = @{}; $state.byIndustry.PSObject.Properties   | ForEach-Object { $byIndustry[$_.Name]   = @{ count=$_.Value.count; salarySum=$_.Value.salarySum; autoSum=$_.Value.autoSum; remoteSum=$_.Value.remoteSum; openings2024=$_.Value.openings2024; openings2030=$_.Value.openings2030 } }
    $byStatus     = @{}; $state.byStatus.PSObject.Properties     | ForEach-Object { $byStatus[$_.Name]     = $_.Value }
    $byImpact     = @{}; $state.byImpact.PSObject.Properties     | ForEach-Object { $byImpact[$_.Name]     = $_.Value }
    $byEducation  = @{}; $state.byEducation.PSObject.Properties  | ForEach-Object { $byEducation[$_.Name]  = @{ count=$_.Value.count; salarySum=$_.Value.salarySum } }
    $byLocation   = @{}; $state.byLocation.PSObject.Properties   | ForEach-Object { $byLocation[$_.Name]   = @{ count=$_.Value.count; salarySum=$_.Value.salarySum; autoSum=$_.Value.autoSum } }
    $byJobTitle   = @{}; $state.byJobTitle.PSObject.Properties   | ForEach-Object { $byJobTitle[$_.Name]   = @{ count=$_.Value.count; salarySum=$_.Value.salarySum; autoSum=$_.Value.autoSum; openings2024=$_.Value.openings2024; openings2030=$_.Value.openings2030 } }
    $industryImpact = @{}; $state.industryImpact.PSObject.Properties | ForEach-Object {
        $inner = @{}
        $_.Value.PSObject.Properties | ForEach-Object { $inner[$_.Name] = $_.Value }
        $industryImpact[$_.Name] = $inner
    }
    $salaryBuckets = @{}; $state.salaryBuckets.PSObject.Properties | ForEach-Object { $salaryBuckets[$_.Name] = $_.Value }
    $riskBuckets   = @{}; $state.riskBuckets.PSObject.Properties   | ForEach-Object { $riskBuckets[$_.Name]   = $_.Value }
    $riskVsRemote  = @()
    if ($state.riskVsRemote) { $state.riskVsRemote | ForEach-Object { $riskVsRemote += ,@($_[0], $_[1], $_[2]) } }
    $totalRows = [int]$state.totalRows
    $totalSalary = [double]$state.totalSalary
    $totalAuto = [double]$state.totalAuto
    $totalRemote = [double]$state.totalRemote
    $totalGender = [double]$state.totalGender
    $totalOpen24 = [long]$state.totalOpen24
    $totalOpen30 = [long]$state.totalOpen30
    $processedFiles = @($state.processedFiles)
}
else {
    $byIndustry = @{}; $byStatus = @{}; $byImpact = @{}; $byEducation = @{}; $byLocation = @{}
    $byJobTitle = @{}; $industryImpact = @{}; $salaryBuckets = @{}; $riskBuckets = @{}
    $riskVsRemote = @()
    $totalRows = 0; $totalSalary = 0.0; $totalAuto = 0.0; $totalRemote = 0.0; $totalGender = 0.0
    $totalOpen24 = 0L; $totalOpen30 = 0L
    $processedFiles = @()
}

$salaryEdges = @(0, 40000, 60000, 80000, 100000, 120000, 140000, 160000)
$salaryLabels = @('<40k','40-60k','60-80k','80-100k','100-120k','120-140k','140-160k','160k+')
$riskEdges = @(0, 20, 40, 60, 80)
$riskLabels = @('0-20%','20-40%','40-60%','60-80%','80-100%')

foreach ($file in $Files) {
    $name = Split-Path $file -Leaf
    if ($processedFiles -contains $name) { Write-Host "Pulando $name (ja processado)"; continue }
    Write-Host "Processando $name..."
    Import-Csv -Path $file | ForEach-Object {
        $totalRows++
        $industry = $_.Industry
        $status   = $_.'Job Status'
        $impact   = $_.'AI Impact Level'
        $salary   = [double]$_.'Median Salary (USD)'
        $edu      = $_.'Required Education'
        $open24   = [int]$_.'Job Openings (2024)'
        $open30   = [int]$_.'Projected Openings (2030)'
        $remote   = [double]$_.'Remote Work Ratio (%)'
        $auto     = [double]$_.'Automation Risk (%)'
        $loc      = $_.Location
        $gender   = [double]$_.'Gender Diversity (%)'
        $job      = $_.'Job Title'

        $totalSalary += $salary; $totalAuto += $auto; $totalRemote += $remote; $totalGender += $gender
        $totalOpen24 += $open24; $totalOpen30 += $open30

        if (-not $byIndustry.ContainsKey($industry)) { $byIndustry[$industry] = @{ count=0; salarySum=0.0; autoSum=0.0; remoteSum=0.0; openings2024=0L; openings2030=0L } }
        $byIndustry[$industry].count++; $byIndustry[$industry].salarySum += $salary
        $byIndustry[$industry].autoSum += $auto; $byIndustry[$industry].remoteSum += $remote
        $byIndustry[$industry].openings2024 += $open24; $byIndustry[$industry].openings2030 += $open30

        if (-not $byStatus.ContainsKey($status)) { $byStatus[$status] = 0 }
        $byStatus[$status]++

        if (-not $byImpact.ContainsKey($impact)) { $byImpact[$impact] = 0 }
        $byImpact[$impact]++

        if (-not $byEducation.ContainsKey($edu)) { $byEducation[$edu] = @{ count=0; salarySum=0.0 } }
        $byEducation[$edu].count++; $byEducation[$edu].salarySum += $salary

        if (-not $byLocation.ContainsKey($loc)) { $byLocation[$loc] = @{ count=0; salarySum=0.0; autoSum=0.0 } }
        $byLocation[$loc].count++; $byLocation[$loc].salarySum += $salary; $byLocation[$loc].autoSum += $auto

        if (-not $byJobTitle.ContainsKey($job)) { $byJobTitle[$job] = @{ count=0; salarySum=0.0; autoSum=0.0; openings2024=0L; openings2030=0L } }
        $byJobTitle[$job].count++; $byJobTitle[$job].salarySum += $salary; $byJobTitle[$job].autoSum += $auto
        $byJobTitle[$job].openings2024 += $open24; $byJobTitle[$job].openings2030 += $open30

        if (-not $industryImpact.ContainsKey($industry)) { $industryImpact[$industry] = @{ Low=0; Moderate=0; High=0 } }
        $industryImpact[$industry][$impact]++

        $bIdx = 0
        for ($i = 1; $i -lt $salaryEdges.Length; $i++) { if ($salary -ge $salaryEdges[$i]) { $bIdx = $i } }
        $bLabel = $salaryLabels[$bIdx]
        if (-not $salaryBuckets.ContainsKey($bLabel)) { $salaryBuckets[$bLabel] = 0 }
        $salaryBuckets[$bLabel]++

        $rIdx = [Math]::Min([Math]::Floor($auto / 20), 4)
        $rLabel = $riskLabels[$rIdx]
        if (-not $riskBuckets.ContainsKey($rLabel)) { $riskBuckets[$rLabel] = 0 }
        $riskBuckets[$rLabel]++

        # amostragem para scatter (1 a cada 30 linhas)
        if ($totalRows % 30 -eq 0) { $riskVsRemote += ,@([math]::Round($auto,1), [math]::Round($remote,1), [math]::Round($salary,0)) }
    }
    $processedFiles += $name
}

# ----- monta saida final -----
function ConvertHashToObj($h) {
    $o = [ordered]@{}
    foreach ($k in $h.Keys) { $o[$k] = $h[$k] }
    return $o
}

$state = [ordered]@{
    processedFiles  = $processedFiles
    totalRows       = $totalRows
    totalSalary     = $totalSalary
    totalAuto       = $totalAuto
    totalRemote     = $totalRemote
    totalGender     = $totalGender
    totalOpen24     = $totalOpen24
    totalOpen30     = $totalOpen30
    byIndustry      = ConvertHashToObj $byIndustry
    byStatus        = ConvertHashToObj $byStatus
    byImpact        = ConvertHashToObj $byImpact
    byEducation     = ConvertHashToObj $byEducation
    byLocation      = ConvertHashToObj $byLocation
    byJobTitle      = ConvertHashToObj $byJobTitle
    industryImpact  = @{}
    salaryBuckets   = ConvertHashToObj $salaryBuckets
    riskBuckets     = ConvertHashToObj $riskBuckets
    riskVsRemote    = $riskVsRemote
}
foreach ($k in $industryImpact.Keys) { $state.industryImpact[$k] = $industryImpact[$k] }
$state | ConvertTo-Json -Depth 10 | Out-File -FilePath $StatePath -Encoding utf8

# ----- dataset compactado para o frontend -----
$industryArr = @()
foreach ($k in $byIndustry.Keys) {
    $v = $byIndustry[$k]
    $industryArr += [ordered]@{
        name           = $k
        count          = $v.count
        avgSalary      = [math]::Round($v.salarySum / $v.count, 0)
        avgAutomation  = [math]::Round($v.autoSum / $v.count, 1)
        avgRemote      = [math]::Round($v.remoteSum / $v.count, 1)
        openings2024   = $v.openings2024
        openings2030   = $v.openings2030
        growth         = [math]::Round((($v.openings2030 - $v.openings2024) / [double]$v.openings2024) * 100, 1)
    }
}
$industryArr = $industryArr | Sort-Object { -$_.count }

$locationArr = @()
foreach ($k in $byLocation.Keys) {
    $v = $byLocation[$k]
    $locationArr += [ordered]@{
        name           = $k
        count          = $v.count
        avgSalary      = [math]::Round($v.salarySum / $v.count, 0)
        avgAutomation  = [math]::Round($v.autoSum / $v.count, 1)
    }
}
$locationArr = $locationArr | Sort-Object { -$_.count }

$educationArr = @()
foreach ($k in $byEducation.Keys) {
    $v = $byEducation[$k]
    $educationArr += [ordered]@{
        name      = $k
        count     = $v.count
        avgSalary = [math]::Round($v.salarySum / $v.count, 0)
    }
}
$eduOrder = @('High School','Associate Degree','Bachelor’s Degree','Master’s Degree','PhD')
$educationArr = $educationArr | Sort-Object { $eduOrder.IndexOf($_.name) }

$topJobs = @()
foreach ($k in $byJobTitle.Keys) {
    $v = $byJobTitle[$k]
    $topJobs += [ordered]@{
        name          = $k
        count         = $v.count
        avgSalary     = [math]::Round($v.salarySum / $v.count, 0)
        avgAutomation = [math]::Round($v.autoSum / $v.count, 1)
        openings2024  = $v.openings2024
        openings2030  = $v.openings2030
    }
}
$topJobsMostListed = ($topJobs | Sort-Object { -$_.count } | Select-Object -First 10)
$topJobsHighestPaid = ($topJobs | Where-Object { $_.count -ge 5 } | Sort-Object { -$_.avgSalary } | Select-Object -First 10)
$topJobsMostAutomatable = ($topJobs | Where-Object { $_.count -ge 5 } | Sort-Object { -$_.avgAutomation } | Select-Object -First 10)
$topJobsGrowing = ($topJobs | Where-Object { $_.openings2024 -ge 5000 } | Sort-Object { -(($_.openings2030 - $_.openings2024) / [double]$_.openings2024) } | Select-Object -First 10)

$industryImpactArr = @()
foreach ($k in $industryImpact.Keys) {
    $v = $industryImpact[$k]
    $industryImpactArr += [ordered]@{
        name     = $k
        Low      = [int]$v.Low
        Moderate = [int]$v.Moderate
        High     = [int]$v.High
    }
}

$salaryBucketArr = @()
foreach ($l in $salaryLabels) { $salaryBucketArr += [ordered]@{ bucket = $l; count = [int]($salaryBuckets[$l]) } }

$riskBucketArr = @()
foreach ($l in $riskLabels) { $riskBucketArr += [ordered]@{ bucket = $l; count = [int]($riskBuckets[$l]) } }

$out = [ordered]@{
    generatedAt   = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
    filesIncluded = $processedFiles
    totals = [ordered]@{
        rows             = $totalRows
        avgSalary        = [math]::Round($totalSalary / $totalRows, 0)
        avgAutomation    = [math]::Round($totalAuto / $totalRows, 1)
        avgRemote        = [math]::Round($totalRemote / $totalRows, 1)
        avgGender        = [math]::Round($totalGender / $totalRows, 1)
        totalOpenings2024 = $totalOpen24
        totalOpenings2030 = $totalOpen30
        growth           = [math]::Round((($totalOpen30 - $totalOpen24) / [double]$totalOpen24) * 100, 1)
    }
    industries     = @($industryArr)
    locations      = @($locationArr)
    education      = @($educationArr)
    jobStatus      = ConvertHashToObj $byStatus
    aiImpact       = ConvertHashToObj $byImpact
    industryImpact = @($industryImpactArr)
    salaryBuckets  = @($salaryBucketArr)
    riskBuckets    = @($riskBucketArr)
    topMostListed  = @($topJobsMostListed)
    topHighestPaid = @($topJobsHighestPaid)
    topAutomatable = @($topJobsMostAutomatable)
    topGrowing     = @($topJobsGrowing)
    riskVsRemote   = $riskVsRemote
}

$out | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutPath -Encoding utf8
Write-Host "OK - $totalRows linhas | $($processedFiles.Count) arquivos | $OutPath"
