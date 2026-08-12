# ============================================================================
# EduZone Supabase Schema Deployment Script (PowerShell)
# Handles full schema setup, seed data, and validation
# ============================================================================

param(
    [Parameter(Position = 0)]
    [ValidateSet("local", "staging", "production")]
    [string]$Environment = "local",
    
    [Parameter(Position = 1)]
    [ValidateSet("false", "true")]
    [string]$DryRun = "false"
)

$ErrorActionPreference = "Stop"

# ============================================================================
# Configuration
# ============================================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommandPath
$CanonicalSchema = Join-Path $ScriptDir "..\Eduzone_schema_v13.sql"
$SeedQA = Join-Path $ScriptDir "..\Eduzone_seed_qa.sql"
$SystemSeed = Join-Path $ScriptDir "seed\00_system_seed_helper.sql"
$ValidationScript = Join-Path $ScriptDir "schema\VALIDATION.sql"
$MigrationsDir = Join-Path $ScriptDir "migrations"

# ============================================================================
# Logging Functions
# ============================================================================

function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[✓] $Message" -ForegroundColor Green
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[✗] $Message" -ForegroundColor Red
}

function Print-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host "========== $Title ==========" -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================================
# Validation
# ============================================================================

function Validate-Prerequisites {
    Print-Header "Validating Prerequisites"
    
    # Check for required commands
    $requiredCommands = @("psql", "supabase")
    foreach ($cmd in $requiredCommands) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            Write-LogError "$cmd is not installed or not in PATH"
            exit 1
        }
    }
    Write-LogSuccess "Required commands found"
    
    # Check for schema files
    foreach ($file in $CanonicalSchema, $SeedQA) {
        if (-not (Test-Path $file)) {
            Write-LogError "Missing file: $file"
            exit 1
        }
    }
    Write-LogSuccess "Schema files found"
    
    # Check DB connection
    if ($Environment -eq "local") {
        try {
            $status = & supabase status 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-LogError "Supabase is not running. Run: supabase start"
                exit 1
            }
            Write-LogSuccess "Supabase is running"
        }
        catch {
            Write-LogError "Cannot connect to Supabase"
            exit 1
        }
    }
    else {
        Write-LogWarning "Skipping Supabase status check for $Environment environment"
    }
}

# ============================================================================
# Schema Deployment
# ============================================================================

function Deploy-CanonicalSchema {
    Print-Header "Deploying Canonical Schema ($Environment)"
    
    if ($DryRun -eq "true") {
        Write-LogWarning "DRY RUN MODE - No changes will be made"
        return
    }
    
    if ($Environment -eq "local") {
        Write-LogInfo "Applying schema via supabase db push..."
        & supabase db push
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "Canonical schema deployed"
        }
        else {
            Write-LogError "Schema deployment failed"
            exit 1
        }
    }
    else {
        Write-LogError "Remote deployment requires manual setup"
        Write-LogInfo "Contact DevOps team for remote deployments"
        exit 1
    }
}

# ============================================================================
# Seed Data
# ============================================================================

function Apply-SystemSeed {
    Print-Header "Applying System Seed Data"
    
    if ($DryRun -eq "true") {
        Write-LogWarning "DRY RUN MODE - No changes will be made"
        return
    }
    
    if ($Environment -eq "local") {
        Write-LogInfo "Applying system seed via supabase db execute..."
        
        # Read seed file and execute via psql
        $seedContent = Get-Content $SystemSeed -Raw
        $seedContent | & supabase db execute
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "System seed applied"
        }
        else {
            Write-LogError "System seed application failed"
            exit 1
        }
    }
    else {
        Write-LogError "Remote execution not yet implemented"
        exit 1
    }
}

function Apply-QASeed {
    Print-Header "Applying QA Seed Data (Optional)"
    
    if ($DryRun -eq "true") {
        Write-LogWarning "DRY RUN MODE - No changes will be made"
        return
    }
    
    $response = Read-Host "Apply QA seed data? (y/n)"
    if ($response -eq "y" -or $response -eq "Y") {
        if ($Environment -eq "local") {
            Write-LogInfo "Applying QA seed via supabase db execute..."
            
            $seedContent = Get-Content $SeedQA -Raw
            $seedContent | & supabase db execute
            
            if ($LASTEXITCODE -eq 0) {
                Write-LogSuccess "QA seed applied"
            }
            else {
                Write-LogError "QA seed application failed"
                exit 1
            }
        }
    }
    else {
        Write-LogWarning "Skipped QA seed"
    }
}

# ============================================================================
# Validation
# ============================================================================

function Validate-Schema {
    Print-Header "Validating Schema"
    
    if ($Environment -eq "local") {
        Write-LogInfo "Running validation checks..."
        
        $validationContent = Get-Content $ValidationScript -Raw
        $validationContent | & supabase db execute
        
        Write-LogSuccess "Validation complete - check results above"
    }
    else {
        Write-LogWarning "Validation not available for $Environment"
    }
}

# ============================================================================
# Migration Info
# ============================================================================

function Show-MigrationsStatus {
    Print-Header "Migration Status"
    
    if (-not (Test-Path $MigrationsDir) -or (Get-ChildItem $MigrationsDir -Filter "*.sql" -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) {
        Write-LogInfo "No pending migrations"
        return
    }
    
    Write-LogInfo "Pending migrations (auto-applied by Supabase CLI):"
    Get-ChildItem $MigrationsDir -Filter "*.sql" | ForEach-Object {
        Write-Host "  - $($_.Name)"
    }
    
    Write-LogInfo "These are automatically applied when you run 'supabase db push'"
}

# ============================================================================
# Main Deployment Flow
# ============================================================================

function Main {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║     EduZone Supabase Schema Deployment Tool            ║" -ForegroundColor Cyan
    Write-Host "║     Environment: $Environment                               ║" -ForegroundColor Cyan
    Write-Host "║     Mode: $($DryRun -eq 'true' ? 'DRY RUN' : 'LIVE')                                  ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Pre-flight checks
    Validate-Prerequisites
    
    # Deployment sequence
    Deploy-CanonicalSchema
    Apply-SystemSeed
    Apply-QASeed
    
    # Validation
    Validate-Schema
    
    # Info
    Show-MigrationsStatus
    
    # Summary
    Print-Header "Deployment Summary"
    Write-LogSuccess "Schema deployment completed successfully!"
    Write-LogInfo "Next steps:"
    Write-Host "  1. Review validation results above"
    Write-Host "  2. Test authentication in the admin app"
    Write-Host "  3. Start development: cd apps/admin && pnpm dev"
}

# ============================================================================
# Run Main
# ============================================================================

try {
    Main
}
catch {
    Write-LogError "Deployment failed: $_"
    exit 1
}
