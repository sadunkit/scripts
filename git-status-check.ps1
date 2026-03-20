# git-status-check.ps1
# Scans immediate child directories for git repos and reports their status.

# 1. List all directories (1 level deep)
$directories = Get-ChildItem -Directory

if ($directories.Count -eq 0) {
    Write-Host "No directories found in $(Get-Location)" -ForegroundColor Yellow
    return
}

Write-Host ""
Write-Host "Scanning $($directories.Count) directories in $(Get-Location)..." -ForegroundColor Cyan
Write-Host ("-" * 60) -ForegroundColor DarkGray

# 2. Check which directories contain a .git folder (1 level only)
$gitRepos = @()
$nonRepos = @()

foreach ($dir in $directories) {
    if (Test-Path (Join-Path $dir.FullName ".git")) {
        $gitRepos += $dir
    } else {
        $nonRepos += $dir
    }
}

# 3. Check git status for each repo
$results = @()

foreach ($repo in $gitRepos) {
    Push-Location $repo.FullName
    try {
        $branch   = git rev-parse --abbrev-ref HEAD 2>$null
        $status   = git status --porcelain 2>$null
        $ahead    = git rev-list --count "@{upstream}..HEAD" 2>$null
        $behind   = git rev-list --count "HEAD..@{upstream}" 2>$null

        $modified  = ($status | Where-Object { $_ -match '^ M|^MM' }).Count
        $staged    = ($status | Where-Object { $_ -match '^[MADRC]' }).Count
        $untracked = ($status | Where-Object { $_ -match '^\?\?' }).Count

        $results += [PSCustomObject]@{
            Name      = $repo.Name
            Branch    = if ($branch) { $branch } else { "N/A" }
            Staged    = $staged
            Modified  = $modified
            Untracked = $untracked
            Ahead     = if ($ahead) { [int]$ahead } else { 0 }
            Behind    = if ($behind) { [int]$behind } else { 0 }
            Clean     = ($status.Count -eq 0)
        }
    } finally {
        Pop-Location
    }
}

# 4. Display results
Write-Host ""
Write-Host " GIT REPOSITORIES ($($gitRepos.Count) found)" -ForegroundColor Green
Write-Host ("-" * 60) -ForegroundColor DarkGray

foreach ($r in $results) {
    if ($r.Clean) {
        $icon = "[OK]"
        $color = "Green"
    } else {
        $icon = "[!!]"
        $color = "Yellow"
    }

    Write-Host ""
    Write-Host "  $icon $($r.Name)" -ForegroundColor $color
    Write-Host "      Branch:    $($r.Branch)" -ForegroundColor White

    if (-not $r.Clean) {
        if ($r.Staged -gt 0)    { Write-Host "      Staged:    $($r.Staged) file(s)" -ForegroundColor Cyan }
        if ($r.Modified -gt 0)  { Write-Host "      Modified:  $($r.Modified) file(s)" -ForegroundColor Yellow }
        if ($r.Untracked -gt 0) { Write-Host "      Untracked: $($r.Untracked) file(s)" -ForegroundColor Red }
    } else {
        Write-Host "      Working tree is clean" -ForegroundColor DarkGreen
    }

    if ($r.Ahead -gt 0)  { Write-Host "      Ahead:     $($r.Ahead) commit(s)" -ForegroundColor Magenta }
    if ($r.Behind -gt 0) { Write-Host "      Behind:    $($r.Behind) commit(s)" -ForegroundColor Magenta }
}

if ($nonRepos.Count -gt 0) {
    Write-Host ""
    Write-Host ("-" * 60) -ForegroundColor DarkGray
    Write-Host " NON-GIT DIRECTORIES ($($nonRepos.Count))" -ForegroundColor DarkGray
    $nonRepos | ForEach-Object { Write-Host "      $($_.Name)" -ForegroundColor DarkGray }
}

# Summary
$cleanCount = ($results | Where-Object { $_.Clean }).Count
$dirtyCount = $results.Count - $cleanCount

Write-Host ""
Write-Host ("-" * 60) -ForegroundColor DarkGray
Write-Host " Summary: $($gitRepos.Count) repo(s) | $cleanCount clean | $dirtyCount dirty" -ForegroundColor Cyan

# Print dirty repo paths
$dirtyRepos = $results | Where-Object { -not $_.Clean } | ForEach-Object { $_.Name }
if ($dirtyRepos.Count -gt 0) {
    Write-Host " Dirty:   $($dirtyRepos -join ', ')" -ForegroundColor Yellow
}
Write-Host ""
