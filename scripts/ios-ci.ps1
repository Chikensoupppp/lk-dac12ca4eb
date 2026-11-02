param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('check', 'list', 'trigger', 'watch', 'errors', 'download')]
    [string]$Action,
    [string]$RunId,
    [string]$Ref
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) is required. Install it and run gh auth login.'
}
$repo = git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) { throw 'Run this script inside the Lock In Git repository.' }
Push-Location $repo
try {
    & gh auth status
    if ($LASTEXITCODE -ne 0) { throw 'GitHub authentication is required: run gh auth login.' }
    if (-not $Ref) { $Ref = git branch --show-current }
    switch ($Action) {
        'check' {
            git status --short --branch
            gh repo view --json nameWithOwner,isPrivate,url
        }
        'list' { gh run list --branch $Ref --limit 10 }
        'trigger' {
            # GitHub requires the workflow to exist on the default branch for dispatch.
            gh workflow run ios-native-ci.yml --ref $Ref
            if ($LASTEXITCODE -eq 0) { Write-Output 'Workflow dispatch requested; use list to find the run.' }
        }
        { $_ -in 'watch','errors','download' } {
            if (-not $RunId -or $RunId -notmatch '^\d+$') { throw 'Supply a numeric -RunId from the list command.' }
            switch ($Action) {
                'watch' { gh run watch $RunId --exit-status }
                'errors' { gh run view $RunId --log-failed }
                'download' { gh run download $RunId --name ios-native-results --dir ".local/ios-results/$RunId" }
            }
        }
    }
    if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code $LASTEXITCODE." }
}
finally { Pop-Location }
