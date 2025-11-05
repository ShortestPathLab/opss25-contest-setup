# ===============================
# Configuration
# ===============================
$envName = "opss25"
$packagesDir = "$HOME\$envName\packages"
$planvizRepo = "https://github.com/ShortestPathLab/opss25-startkit"
$scriptsRepo = "https://github.com/ShortestPathLab/opss25-contest-setup"  # replace with actual URL
$pythonVersion = "3.11"

# ===============================
# Helper functions
# ===============================

function Add-ToUserPath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FolderPath
    )

    # Get the current user PATH

    $userPath = [System.Environment]::GetEnvironmentVariable("PATH","USER")

    if ($userPath -notlike "*$FolderPath*") {
        [System.Environment]::SetEnvironmentVariable("PATH", "$userPath;$FolderPath", "USER")
        Write-Output "Added '$FolderPath' to user PATH."
    } else {
        Write-Output "'$FolderPath' is already in PATH."
    }
}


function Install-IfMissing {
    param(
        [string]$Command,
        [ScriptBlock]$InstallAction
    )

    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Host "[ERROR] $Command not found. Installing..."
        & $InstallAction
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 
    } else {
        Write-Host "[OK] $Command already installed."
    }
}

function Ensure-CondaEnv {
    param(
        [string]$EnvName,
        [string]$PythonVersion
    )
    
    conda init powershell
    conda activate
    $envs = & conda env list
    if (-not ($envs -match "^\s*$EnvName\s")) {
        Write-Host "[ERROR] Conda environment '$EnvName' not found. Creating..."
        conda create -y -n $EnvName python=$PythonVersion
    } else {
        Write-Host "[OK] Conda environment '$EnvName' already exists."
    }
}

function Clone-IfMissing {
    param(
        [string]$RepoUrl,
        [string]$TargetDir,
        [ScriptBlock]$SetupAction
    )

    if (-not (Test-Path $TargetDir)) {
        Write-Host "[ERROR] $TargetDir not found. Cloning from $RepoUrl..."
        git clone $RepoUrl $TargetDir
    } else {
        Write-Host "[OK] $TargetDir already exists, skipping clone."
    }
    
    Write-Host "[INFO] Running setup commands for $TargetDir..."
    Push-Location $TargetDir
    & $SetupAction
    Pop-Location
    Write-Host "[OK] Finished setup for $TargetDir."
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command opss25-uninstall -ErrorAction SilentlyContinue) {
    Write-Host "[INFO] opss25 environment already set up. If you want to reinstall, first run: opss25-uninstall. Exiting."
    exit 0
}

# ===============================
# 1. Check/install Git
# ===============================
Install-IfMissing "git" {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco install git -y
        refreshenv
    } elseif (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Git.Git -e --source winget

    } else {
        Write-Warning "[WARN] Please install Git manually."
        exit 1
    }
}

# ===============================
# 2. Check/install Docker
# ===============================
Install-IfMissing "docker" {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco install docker-desktop -y
    } elseif (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Docker.DockerDesktop -e --source winget
    } else {
        Write-Warning "[WARN] Please install Docker manually."
        exit 1
    }
}

# ===============================
# 3. Check/install Conda
# ===============================
Install-IfMissing "conda" {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco install miniconda3 -y
    } elseif (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Anaconda.Miniconda3 -e --source winget
    } else {
        Write-Warning "[WARN] Please install Miniconda manually."
        exit 1
    }
    Add-ToUserPath "$HOME/miniconda3/Scripts"
}

# ===============================
# 4. Ensure opss25 environment
# ===============================
Ensure-CondaEnv -EnvName $envName -PythonVersion $pythonVersion

# ===============================
# 5. Activate opss25 environment
# ===============================
Write-Host "[INFO] Activating conda environment '$envName'..."
conda activate $envName

# ===============================
# 6. PlanViz setup
# ===============================
$planvizDir = "$packagesDir\PlanViz"
if (-not (Get-Command planviz -ErrorAction SilentlyContinue)) {
    Clone-IfMissing -RepoUrl $planvizRepo -TargetDir $planvizDir -SetupAction {
        Write-Host "Installing PlanViz..."
        cd "$planvizDir\external\PlanViz"
        python -m pip install -r requirements.txt
        cd "$planvizDir\python\piglet" 
        python -m pip install -r requirements.txt
    }
} else {
    Write-Host "[OK] planviz already in PATH."
}

# ===============================
# 7. Lifelong scripts setup
# ===============================
$scriptsDir = "$packagesDir\setup"
$scriptsSubDir = "$scriptsDir\scripts"
if (-not (Get-Command opss25-uninstall -ErrorAction SilentlyContinue)) {
    Clone-IfMissing -RepoUrl $scriptsRepo -TargetDir $scriptsDir -SetupAction {
        Write-Host "Adding scripts to PATH..."
        Add-ToUserPath -FolderPath "$scriptsSubDir"
    }
} else {
    Write-Host "[OK] scripts already in PATH."
}

# ===============================
# Done
# ===============================
Write-Host ""
Write-Host "[INFO] Setup complete!"
Write-Host "[INFO] You may need to restart your PowerShell session."
Write-Host "[INFO] And activate your environment: conda activate $envName"
Write-Host ""

opss25-help
