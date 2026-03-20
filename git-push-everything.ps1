# git-push-everything.ps1
# Usage: .\git-push-everything.ps1 repo1, repo2, repo3

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RepoNames
)

# Clean up commas and whitespace from args (supports "a, b, c" style input)
$RepoNames = ($RepoNames -join ' ') -split '[,\s]+' | Where-Object { $_ -ne '' }

if ($RepoNames.Count -eq 0) {
    Write-Host "Usage: .\git-push-everything.ps1 repo1, repo2, repo3" -ForegroundColor Yellow
    return
}

foreach ($name in $RepoNames) {
    $repoPath = Join-Path (Get-Location) $name

    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host " $name" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor DarkGray

    # 1. Validate it's a git repo
    if (-not (Test-Path (Join-Path $repoPath ".git"))) {
        Write-Host "  SKIPPED: Not a git repo." -ForegroundColor Red
        continue
    }

    Push-Location $repoPath
    try {
        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        if (-not $branch) {
            Write-Host "  SKIPPED: Could not determine branch." -ForegroundColor Red
            continue
        }

        # 2. Summarize the diff
        $diffStat = git diff --stat 2>$null
        $untrackedFiles = git ls-files --others --exclude-standard 2>$null

        if (-not $diffStat -and -not $untrackedFiles) {
            Write-Host "  Nothing to commit - working tree is clean." -ForegroundColor Green
            continue
        }

        Write-Host "  Branch: $branch" -ForegroundColor White
        if ($diffStat) {
            Write-Host ""
            Write-Host "  Changes:" -ForegroundColor Yellow
            $diffStat | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
        if ($untrackedFiles) {
            Write-Host ""
            Write-Host "  Untracked files:" -ForegroundColor Red
            $untrackedFiles | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }

        Write-Host ""
        $confirm = Read-Host "  Commit and push to '$branch'? (y/N)"
        if ($confirm -ne 'y') {
            Write-Host "  Skipped by user." -ForegroundColor DarkGray
            continue
        }

        # 3. Stage everything and commit
        git add -A 2>$null
        git commit -m "forced update" 2>$null

        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Commit failed." -ForegroundColor Red
            continue
        }
        Write-Host "  Committed." -ForegroundColor Green

        # 4. Push to current branch
        git push origin $branch 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Pushed to origin/$branch." -ForegroundColor Green
        } else {
            Write-Host "  Push failed." -ForegroundColor Red
        }
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Cyan
