# Overnight Experiment Runner - 8 Remaining Scenarios
# Oliur Rahman Safwan | Leeds Beckett University | 2026

$NAMESPACE = "dissertation-eval"
$DEPLOYMENT = "nginx-microservice"
$HOST_URL = "http://127.0.0.1:8080"

# ============================================================
# PREREQUISITE: kubectl port-forward must be running before this script.
# Open a SEPARATE PowerShell window and run:
#   kubectl port-forward service/nginx-service 8080:80 -n dissertation-eval
# Keep that window open for the entire session.
#
# NOTE: minikube tunnel does NOT work here — the nginx service uses
# NodePort (not LoadBalancer), so port-forward is required to map
# the service to 127.0.0.1:8080.
#
# Verify port-forward is working before starting:
#   curl http://127.0.0.1:8080
# Expected: StatusCode 200 (nginx welcome page)
# If you get connection refused - port-forward is not running.
#
# PATH NOTE: Run this script from the root dissertation/ folder:
#   cd "C:\Users\admin\OneDrive - Leeds Beckett University\Desktop\dissertation"
#   .\04_automation\run-overnight.ps1
# The script references locustfile.py and YAML files by relative name.
# If you run it from inside 04_automation/, those files will not be found.
# ============================================================

Write-Host "Starting 8 experiments..." -ForegroundColor Cyan
Write-Host "Estimated time: 4.5 hours" -ForegroundColor Cyan
Write-Host ""

# Prevent sleep
powercfg /change standby-timeout-ac 0

function Run-Experiment {
    param($Scenario, $Threshold, $Workload, $HpaFile, $LocustClass, $Users, $Rate, $Duration)
    
    $csvName = "results-T$Threshold-$Workload-Run1"
    
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  Scenario $Scenario - T$Threshold $Workload" -ForegroundColor Yellow
    Write-Host "  $(Get-Date)" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Yellow
    
    # Step 1: Switch HPA
    Write-Host "  Switching HPA..." -ForegroundColor Gray
    kubectl delete hpa --all -n $NAMESPACE 2>$null
    Start-Sleep -Seconds 5
    kubectl apply -f $HpaFile
    
    # Step 2: Reset to 1 replica
    Write-Host "  Resetting to 1 replica..." -ForegroundColor Gray
    kubectl scale deployment $DEPLOYMENT --replicas=1 -n $NAMESPACE
    Start-Sleep -Seconds 30
    
    # Step 3: Wait for pod ready
    Write-Host "  Waiting for pod ready..." -ForegroundColor Gray
    Start-Sleep -Seconds 30
    
    # Step 4: Stabilisation
    Write-Host "  Stabilisation wait (60s)..." -ForegroundColor Gray
    Start-Sleep -Seconds 60
    
    # Step 5: Warm-up
    Write-Host "  Warm-up wait (5 min)..." -ForegroundColor Gray
    Start-Sleep -Seconds 300
    
    # Step 6: Log state
    Write-Host "  Logging pre-experiment state..." -ForegroundColor Gray
    kubectl get hpa -n $NAMESPACE | Out-File -FilePath "log_T${Threshold}_${Workload}.txt"
    kubectl get pods -n $NAMESPACE | Out-File -FilePath "log_T${Threshold}_${Workload}.txt" -Append
    
    # Step 7: Run Locust
    Write-Host "  RUNNING: $LocustClass - $Users users - $Duration" -ForegroundColor Green
    locust -f ".\03_load_testing\locustfile.py" $LocustClass --headless -u $Users -r $Rate --host=$HOST_URL --run-time $Duration --csv ".\07_results_csv\$csvName"
    
    # Log post state
    kubectl get hpa -n $NAMESPACE | Out-File -FilePath "log_T${Threshold}_${Workload}.txt" -Append
    kubectl describe hpa -n $NAMESPACE | Out-File -FilePath "log_T${Threshold}_${Workload}.txt" -Append
    
    Write-Host "  DONE: $csvName" -ForegroundColor Green
    Write-Host ""
}

# Run all 8 experiments in order
Run-Experiment -Scenario 1  -Threshold 50 -Workload "Steady" -HpaFile ".\02_kubernetes_config\C3-hpa-50.yaml" -LocustClass "SteadyWorkload" -Users 50 -Rate 5  -Duration "10m"
Run-Experiment -Scenario 9  -Threshold 90 -Workload "Steady" -HpaFile ".\02_kubernetes_config\C5-hpa-90.yaml" -LocustClass "SteadyWorkload" -Users 50 -Rate 5  -Duration "10m"
Run-Experiment -Scenario 2  -Threshold 50 -Workload "Step"   -HpaFile ".\02_kubernetes_config\C3-hpa-50.yaml" -LocustClass "StepWorkload"   -Users 10 -Rate 2  -Duration "16m"
Run-Experiment -Scenario 6  -Threshold 70 -Workload "Step"   -HpaFile ".\02_kubernetes_config\C4-hpa-70.yaml" -LocustClass "StepWorkload"   -Users 10 -Rate 2  -Duration "16m"
Run-Experiment -Scenario 10 -Threshold 90 -Workload "Step"   -HpaFile ".\02_kubernetes_config\C5-hpa-90.yaml" -LocustClass "StepWorkload"   -Users 10 -Rate 2  -Duration "16m"
Run-Experiment -Scenario 3  -Threshold 50 -Workload "Bursty" -HpaFile ".\02_kubernetes_config\C3-hpa-50.yaml" -LocustClass "BurstyWorkload" -Users 10 -Rate 5  -Duration "10m"
Run-Experiment -Scenario 7  -Threshold 70 -Workload "Bursty" -HpaFile ".\02_kubernetes_config\C4-hpa-70.yaml" -LocustClass "BurstyWorkload" -Users 10 -Rate 5  -Duration "10m"
Run-Experiment -Scenario 11 -Threshold 90 -Workload "Bursty" -HpaFile ".\02_kubernetes_config\C5-hpa-90.yaml" -LocustClass "BurstyWorkload" -Users 10 -Rate 5  -Duration "10m"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ALL 8 EXPERIMENTS COMPLETE" -ForegroundColor Cyan
Write-Host "  $(Get-Date)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Check CSV files:" -ForegroundColor Yellow
Get-ChildItem ".\07_results_csv\results-*_stats.csv" | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
