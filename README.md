================================================================================
  README — COMPLETE TESTING & REPLICATION MANUAL
================================================================================

  Evaluating Kubernetes Horizontal Pod Autoscaling Using Prometheus:
  A Comparative Study of CPU Thresholds, Workload Patterns,
  and Load Balancing Performance

  Author:       Oliur Rahman Safwan
  Student ID:   77547231
  Supervisor:   Dr Satish Kumar
  University:   Leeds Beckett University
  Programme:    MSc (School of Built Environment, Engineering and Computing)
  Submission:   4 May 2026

  STATUS: All 12 primary experiments COMPLETE (20 CSV files collected).
          Validation experiment (Scenario 13 — PHP-Apache) COMPLETE.

================================================================================
  TABLE OF CONTENTS
================================================================================

  PART A — PREREQUISITES & INSTALLATION
    A1.  Hardware Requirements
    A2.  Software Prerequisites
    A3.  Installation Verification

  PART B — CLUSTER SETUP & CONFIGURATION
    B1.  Minikube Cluster Creation
    B2.  Namespace & Microservice Deployment
    B3.  Prometheus & Grafana Monitoring Stack
    B4.  Metrics Server Configuration
    B5.  HPA Configuration Files
    B6.  Locust Load Testing Setup

  PART C — EXPERIMENTAL PROCEDURE
    C1.  Pre-Run Checklist
    C2.  Seven-Step Run Procedure
    C3.  The 12-Scenario Experimental Matrix
    C4.  Running Each Workload Type
    C5.  Data Collection During Runs

  PART D — MONITORING & OBSERVATION
    D1.  Grafana Dashboard Setup
    D2.  PromQL Queries Reference
    D3.  kubectl Monitoring Commands
    D4.  Capturing Screenshots & Evidence

  PART E — VALIDATION EXPERIMENT (Scenario 13 — PHP-Apache)
    E1.  Purpose
    E2.  Setup
    E3.  Running the Validation
    E4.  Expected Results

  PART F — POST-EXPERIMENT ANALYSIS
    F1.  Collecting Locust CSV Output
    F2.  Extracting Prometheus Data
    F3.  Computing Scaling Delay
    F4.  Computing Load Balance CV
    F5.  Running the Analysis Script

  PART G — TROUBLESHOOTING
    G1.  Common Issues & Fixes
    G2.  Known Limitations

  PART H — FILE MANIFEST
    H1.  Kubernetes Configuration Files
    H2.  Load Testing Scripts
    H3.  Results CSV Files (All 20 — Completed)
    H4.  Analysis and Automation Scripts
    H5.  Dissertation Files

  PART I — AUTOMATED EXECUTION (run-overnight.ps1)
    I1.  Overview
    I2.  Prerequisites
    I3.  Usage

  PART J — COMPLETED RESULTS SUMMARY
    J1.  All 12 Scenarios — Verified Values
    J2.  Key Finding Summary
    J3.  CSV Cross-Check Notes


================================================================================
  PART A — PREREQUISITES & INSTALLATION
================================================================================

A1. HARDWARE REQUIREMENTS
-------------------------
  Item                  Minimum             Used in This Study
  --------------------  ------------------  --------------------------
  Processor             4-core x86_64       Intel Core i9 13th Gen
  RAM                   8 GB total          16 GB (6 GB to Minikube)
  Storage               20 GB free          SSD
  Operating System      Windows 10/11 Pro   Windows 11 Pro
                        macOS 12+
                        Ubuntu 22.04+

  NOTE: 4 CPU cores and 6 GB RAM are allocated to the Minikube virtual
  machine. The host system needs additional resources for Docker Desktop,
  Locust, and the terminal. 16 GB total RAM is strongly recommended.


A2. SOFTWARE PREREQUISITES
--------------------------
  Install the following BEFORE proceeding to cluster setup:

  1. Docker Desktop (v4.30+)
     https://www.docker.com/products/docker-desktop/
     - Enable WSL 2 backend (Windows)
     - Allocate at least 4 CPUs and 8 GB RAM in Docker Settings > Resources

  2. Minikube (v1.33+)
     https://minikube.sigs.k8s.io/docs/start/
     Windows:  winget install minikube
     macOS:    brew install minikube

  3. kubectl (v1.29+)
     https://kubernetes.io/docs/tasks/tools/
     Bundled with Docker Desktop, or install separately.

  4. Helm (v3.14+)
     https://helm.sh/docs/intro/install/
     Windows:  winget install Helm.Helm
     macOS:    brew install helm

  5. Python (v3.10+)
     https://www.python.org/downloads/

  6. Locust (v2.20+)
     pip install locust


A3. INSTALLATION VERIFICATION
------------------------------
  Run these commands to verify all tools are installed:

    docker --version           # Expected: Docker version 29.x+
    minikube version           # Expected: minikube v1.38+
    kubectl version --client   # Expected: Client Version v1.35+
    helm version               # Expected: version.BuildInfo{Version:"v3.14+"}
    python --version           # Expected: Python 3.10+
    locust --version           # Expected: locust 2.x


================================================================================
  PART B — CLUSTER SETUP & CONFIGURATION
================================================================================

B1. MINIKUBE CLUSTER CREATION
-----------------------------
  Start the Minikube cluster with required resources:

    minikube start --driver=docker --cpus=4 --memory=6144

  Verify cluster is running:

    minikube status
    kubectl cluster-info
    kubectl get nodes

  Expected: One node in "Ready" status.

  IMPORTANT: Do NOT use minikube tunnel. This project uses kubectl
  port-forward to connect Locust to the nginx service. See B6.


B2. NAMESPACE & MICROSERVICE DEPLOYMENT
---------------------------------------
  All YAML files are provided in the 02_kubernetes_config/ folder.
  Apply them in this exact order:

  STEP 1: Create the namespace

    kubectl apply -f C8-namespace.yaml

  STEP 2: Deploy the Nginx microservice

    kubectl apply -f C1-deployment.yaml

    KEY FIELDS in C1-deployment.yaml:
      resources.requests.cpu: "100m"  -- HPA denominator; 70m usage = 70% utilisation
      resources.limits.cpu: "500m"    -- max CPU before throttling
      readinessProbe: / every 10s x3  -- pod needs 35s minimum before receiving traffic

  STEP 3: Deploy the NodePort Service

    kubectl apply -f C2-service.yaml

  STEP 4: Verify deployment

    kubectl get all -n dissertation-eval

    Expected: 1 Deployment, 1 ReplicaSet, 1 Pod (Running 1/1), 1 Service


B3. PROMETHEUS & GRAFANA MONITORING STACK
-----------------------------------------
  STEP 1: Add the Helm repository

    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update

  STEP 2: Install the kube-prometheus-stack

    helm install prometheus prometheus-community/kube-prometheus-stack \
      --namespace monitoring --create-namespace \
      --set prometheus.prometheusSpec.scrapeInterval=15s \
      --set grafana.adminPassword=dissertation2026 \
      --set grafana.service.type=NodePort \
      --set prometheus.service.type=NodePort

    NOTE: 15-second scrape interval is deliberate — it captures scaling
    events that occur in 30-90 second windows. Default is 30 seconds.

  STEP 3: Wait for all pods to be ready (2-5 minutes)

    kubectl get pods -n monitoring -w

    Wait until ALL pods show "Running" with "1/1" or "2/2" Ready.

  STEP 4: Access Grafana

    minikube service prometheus-grafana -n monitoring --url
    Login: admin / dissertation2026

  STEP 5: Access Prometheus

    minikube service prometheus-kube-prometheus-prometheus -n monitoring --url


B4. METRICS SERVER CONFIGURATION
---------------------------------
  The Metrics Server is REQUIRED for HPA to function. Without it,
  HPA shows "<unknown>" for CPU targets and will never scale.

  STEP 1: Enable the addon

    minikube addons enable metrics-server

  STEP 2: Apply the TLS patch (REQUIRED for Minikube Docker driver)

    kubectl patch deployment metrics-server -n kube-system \
      --type='json' \
      -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-",
            "value":"--kubelet-insecure-tls"}]'

    WHY: Minikube uses self-signed TLS certificates. Without this patch,
    Metrics Server cannot communicate with the kubelet and HPA cannot
    read CPU utilisation data.

  STEP 3: Verify Metrics Server is working

    kubectl top pods -n dissertation-eval

    Expected: Shows CPU and memory for the nginx pod.
    If "error: Metrics API not available", wait 2 minutes and retry.

  STEP 4: Verify HPA can read metrics

    kubectl get hpa -n dissertation-eval

    Expected: TARGETS shows "2%/70%" or similar (not "<unknown>/70%").


B5. HPA CONFIGURATION FILES
----------------------------
  Three HPA files are provided — one per threshold experiment.
  ONLY ONE should be active at a time.

  Files: C3-hpa-50.yaml, C4-hpa-70.yaml, C5-hpa-90.yaml

  The only field that differs across the three files is averageUtilization.
  All other parameters are identical to ensure fair comparison:

    stabilizationWindowSeconds (scaleUp):  0    -- immediate scale-up
    stabilizationWindowSeconds (scaleDown): 300 -- 5-minute scale-down wait
    scaleUp max:    4 pods per 15 seconds
    scaleDown max:  1 pod per 60 seconds
    minReplicas: 1 (always available)
    maxReplicas: 10 (10 x 100m = 1000m, within 4000m Minikube node)

  To switch threshold between experiments:

    kubectl delete hpa --all -n dissertation-eval
    kubectl apply -f C4-hpa-70.yaml           # change filename per threshold
    kubectl scale deployment nginx-microservice \
      -n dissertation-eval --replicas=1


B6. LOCUST LOAD TESTING SETUP
-------------------------------
  Locust runs on the Windows HOST (outside the cluster). It connects
  to the Nginx service via kubectl port-forward — NOT minikube tunnel.

  STEP 1: Start the port-forward tunnel (keep this terminal open)

    kubectl port-forward service/nginx-service 8080:80 -n dissertation-eval

    WHY port-forward: The nginx-service uses NodePort, which is not
    reachable from the host on the Minikube Docker driver without
    port-forward. All Locust commands use --host=http://127.0.0.1:8080.

  STEP 2: Verify the connection

    curl http://127.0.0.1:8080

    Expected: 200 OK with nginx welcome page HTML.

  STEP 3: The load testing script

    File: 03_load_testing/locustfile.py

    Contains four workload classes:
      SteadyWorkload  -- 50 constant users, 10 minutes
      StepWorkload    -- 10 to 150 users, +20 every 2 minutes
      BurstyWorkload  -- 10 to 200 random users every 30 seconds
      SpikeWorkload   -- 10 baseline, 500-user spike at 5 minutes

    BurstyController uses random.seed(77547231) for reproducibility.
    This ensures the same random sequence across all Bursty runs.

    NOTE on stub_status: The final locustfile.py has the /stub_status
    task commented out. Default nginx:latest does not expose stub_status
    and it would produce artificial failures unrelated to HPA behaviour.
    All analysis uses GET / requests only.


================================================================================
  PART C — EXPERIMENTAL PROCEDURE
================================================================================

C1. PRE-RUN CHECKLIST
---------------------
  Before EVERY experimental run, verify ALL of the following:

  [ ] Docker Desktop is running with sufficient resources
  [ ] kubectl get nodes shows "Ready"
  [ ] kubectl get pods -n monitoring shows all pods Running
  [ ] kubectl top pods -n dissertation-eval returns CPU values (not error)
  [ ] HPA shows correct threshold: kubectl get hpa -n dissertation-eval
  [ ] HPA TARGETS shows a value like "2%/70%" (not "<unknown>")
  [ ] Deployment is at exactly 1 replica
  [ ] port-forward is active: curl http://127.0.0.1:8080 returns 200
  [ ] 60-second stabilisation period has elapsed since last run
  [ ] Grafana is accessible in browser


C2. SEVEN-STEP RUN PROCEDURE
-----------------------------
  Follow this procedure for every experimental scenario.

  NOTE: This study ran each scenario once (single run). The procedure
  below documents the exact steps followed for each of the 12 runs.

  STEP 1 — Delete previous HPA, apply target HPA:

    kubectl delete hpa --all -n dissertation-eval
    kubectl apply -f 02_kubernetes_config/C4-hpa-70.yaml   # change per scenario

  STEP 2 — Reset deployment to 1 replica:

    kubectl scale deployment nginx-microservice \
      -n dissertation-eval --replicas=1

  STEP 3 — Verify baseline state:

    kubectl get pods -n dissertation-eval    # confirm 1/1 Running
    kubectl get hpa -n dissertation-eval     # confirm TARGETS shows cpu:%/threshold%

  STEP 4 — Wait 60 seconds for Metrics Server baseline:

    # Ensures Metrics Server has fresh, stable CPU data before load begins.

  STEP 5 — Start port-forward (if not already running):

    kubectl port-forward service/nginx-service 8080:80 -n dissertation-eval

  STEP 6 — Launch Locust with appropriate workload:

    # See C4 below for exact commands per workload type.

  STEP 7 — Monitor during run (separate terminals):

    kubectl get hpa -n dissertation-eval --watch
    kubectl get pods -n dissertation-eval -w


C3. THE 12-SCENARIO EXPERIMENTAL MATRIX
----------------------------------------
  #   Threshold  Workload  HPA File          Locust Class     Duration  Status
  --- ---------  --------  ----------------  ---------------  --------  ------
   1   50%       Steady    C3-hpa-50.yaml    SteadyWorkload   10 min    DONE
   2   50%       Step      C3-hpa-50.yaml    StepWorkload     16 min    DONE
   3   50%       Bursty    C3-hpa-50.yaml    BurstyWorkload   10 min    DONE
   4   50%       Spike     C3-hpa-50.yaml    SpikeWorkload     9 min    DONE
   5   70%       Steady    C4-hpa-70.yaml    SteadyWorkload   10 min    DONE
   6   70%       Step      C4-hpa-70.yaml    StepWorkload     16 min    DONE
   7   70%       Bursty    C4-hpa-70.yaml    BurstyWorkload   10 min    DONE
   8   70%       Spike     C4-hpa-70.yaml    SpikeWorkload     9 min    DONE
   9   90%       Steady    C5-hpa-90.yaml    SteadyWorkload   10 min    DONE
  10   90%       Step      C5-hpa-90.yaml    StepWorkload     16 min    DONE
  11   90%       Bursty    C5-hpa-90.yaml    BurstyWorkload   10 min    DONE
  12   90%       Spike     C5-hpa-90.yaml    SpikeWorkload     9 min    DONE

  All 12 scenarios complete. All CSV files available in 07_results_csv/.


C4. RUNNING EACH WORKLOAD TYPE
-------------------------------
  All commands use --host=http://127.0.0.1:8080 (port-forward endpoint).
  Replace <THRESHOLD> with 50, 70, or 90.

  STEADY WORKLOAD (Scenarios 1, 5, 9):

    locust -f 03_load_testing/locustfile.py SteadyWorkload --headless \
      -u 50 -r 5 \
      --host=http://127.0.0.1:8080 \
      --run-time 10m \
      --csv 07_results_csv/results-T<THRESHOLD>-Steady-Run1

  STEP WORKLOAD (Scenarios 2, 6, 10):

    locust -f 03_load_testing/locustfile.py StepWorkload --headless \
      -u 10 -r 2 \
      --host=http://127.0.0.1:8080 \
      --run-time 16m \
      --csv 07_results_csv/results-T<THRESHOLD>-Step-Run1

  BURSTY WORKLOAD (Scenarios 3, 7, 11):

    locust -f 03_load_testing/locustfile.py BurstyWorkload --headless \
      -u 10 -r 5 \
      --host=http://127.0.0.1:8080 \
      --run-time 10m \
      --csv 07_results_csv/results-T<THRESHOLD>-Bursty-Run1

  SPIKE WORKLOAD (Scenarios 4, 8, 12):

    locust -f 03_load_testing/locustfile.py SpikeWorkload --headless \
      -u 10 -r 2 \
      --host=http://127.0.0.1:8080 \
      --run-time 9m \
      --csv 07_results_csv/results-T<THRESHOLD>-Spike-Run1

  EXAMPLE — Scenario 8 (T70 Spike):

    kubectl delete hpa --all -n dissertation-eval
    kubectl apply -f 02_kubernetes_config/C4-hpa-70.yaml
    kubectl scale deployment nginx-microservice -n dissertation-eval --replicas=1
    # Wait 60 seconds
    kubectl port-forward service/nginx-service 8080:80 -n dissertation-eval &
    locust -f 03_load_testing/locustfile.py SpikeWorkload --headless \
      -u 10 -r 2 --host=http://127.0.0.1:8080 \
      --run-time 9m --csv 07_results_csv/results-T70-Spike-Run1


C5. DATA COLLECTION DURING RUNS
---------------------------------
  Open three terminal windows during each run:

  TERMINAL 1 — port-forward (keep open throughout):
    kubectl port-forward service/nginx-service 8080:80 -n dissertation-eval

  TERMINAL 2 — HPA watch:
    kubectl get hpa -n dissertation-eval --watch

  TERMINAL 3 — Locust execution:
    locust -f 03_load_testing/locustfile.py <WorkloadClass> --headless ...

  Keep Grafana dashboard open in a browser for visual monitoring.


================================================================================
  PART D — MONITORING & OBSERVATION
================================================================================

D1. GRAFANA DASHBOARD SETUP
----------------------------
  Four panels were configured for this study:

  PANEL 1 — CPU Utilisation per Pod:
    Query:  rate(container_cpu_usage_seconds_total
              {namespace="dissertation-eval",container="nginx"}[1m]) * 100
    Type:   Time series
    Y-axis: 0 to 100 (%)

  PANEL 2 — Pod Count:
    Query:  kube_hpa_status_current_replicas{namespace="dissertation-eval"}
    Type:   Time series
    Y-axis: 0 to 10

  PANEL 3 — P95 Response Time:
    Query:  histogram_quantile(0.95, rate(
              nginx_http_request_duration_seconds_bucket
              {namespace="dissertation-eval"}[1m]))
    NOTE:   Requires nginx-prometheus-exporter — NOT available in this study.
            Response time was collected from Locust CSV instead.

  PANEL 4 — Traffic Distribution per Pod:
    Query:  rate(nginx_http_requests_total{namespace="dissertation-eval"}[1m])
    NOTE:   Requires nginx-prometheus-exporter — NOT available in this study.
            Per-pod traffic distribution was approximated from Locust output.


D2. PROMQL QUERIES REFERENCE
-----------------------------
  Full reference: 05_monitoring_queries/promql-queries.txt

  CONFIRMED WORKING (standard Kubernetes metrics):

  CPU Utilisation per pod:
    rate(container_cpu_usage_seconds_total
      {namespace="dissertation-eval",container="nginx"}[1m]) * 100

  Peak CPU over experiment duration (post-analysis):
    max_over_time(rate(container_cpu_usage_seconds_total
      {namespace="dissertation-eval",container="nginx"}[1m])[10m:15s]) * 100

  Average CPU over experiment duration (post-analysis):
    avg_over_time(rate(container_cpu_usage_seconds_total
      {namespace="dissertation-eval",container="nginx"}[1m])[10m:15s]) * 100

  HPA current replicas:
    kube_hpa_status_current_replicas{namespace="dissertation-eval"}

  HPA desired replicas:
    kube_hpa_status_desired_replicas{namespace="dissertation-eval"}

  HPA scaling event count:
    changes(kube_hpa_status_current_replicas{namespace="dissertation-eval"}[1h])

  REQUIRES nginx-prometheus-exporter (NOT installed in this study):
    P95 response time, per-pod request rate, load balance CV.
    These are included in promql-queries.txt for future replication.
    In this study, response time and failure rate came from Locust CSV.


D3. KUBECTL MONITORING COMMANDS
--------------------------------
  HPA status (one-shot):
    kubectl get hpa -n dissertation-eval

  HPA status (live watch — use during experiments):
    kubectl get hpa -n dissertation-eval --watch

  Pod status (live watch):
    kubectl get pods -n dissertation-eval -w

  Pod resource usage:
    kubectl top pods -n dissertation-eval

  Detailed HPA events and conditions:
    kubectl describe hpa -n dissertation-eval


D4. CAPTURING EVIDENCE
-----------------------
  For each run, capture:

  1. Grafana screenshot — CPU and Pod Count panels covering full run duration
  2. kubectl terminal — copy the HPA --watch output showing TARGETS/REPLICAS
  3. Locust CSV — auto-generated by --csv flag (primary data source)

  FILE NAMING:
    grafana_T<threshold>_<workload>_Run1.png
    kubectl_T<threshold>_<workload>_Run1.txt
    results-T<threshold>-<workload>-Run1_stats.csv


================================================================================
  PART E — VALIDATION EXPERIMENT (Scenario 13 — PHP-Apache)
================================================================================

E1. PURPOSE
-----------
  The 13th experiment validates that the cluster, HPA controller, and
  Metrics Server all work correctly. It uses a CPU-intensive PHP-Apache
  application (registry.k8s.io/hpa-example) that executes sqrt()
  computation per request — making CPU rise proportionally with load.

  If Nginx never triggered HPA (CPU stayed 2-39%) but PHP-Apache does
  (CPU reaches 406%), the difference is the application, not the
  infrastructure. This rules out experimental misconfiguration.


E2. SETUP
---------
  STEP 1: Remove the Nginx workload

    kubectl delete deployment nginx-microservice -n dissertation-eval

  STEP 2: Deploy PHP-Apache

    kubectl apply -f 02_kubernetes_config/C11-php-apache-cpu-intensive.yaml

    This creates both a Deployment and a ClusterIP Service in one file.

  STEP 3: Apply a separate HPA for PHP-Apache (50% threshold)

    kubectl autoscale deployment php-apache \
      --cpu-percent=50 --min=1 --max=10 \
      -n dissertation-eval

  STEP 4: Start port-forward for PHP-Apache

    kubectl port-forward service/php-apache-service 8080:80 -n dissertation-eval


E3. RUNNING THE VALIDATION
---------------------------
  Use locustfile_cpu.py — the dedicated CPU-intensive load script.
  It sends very aggressive requests (0.01-0.05 second wait) to push
  CPU high quickly.

    locust -f 03_load_testing/locustfile_cpu.py CPUIntensiveWorkload \
      --headless -u 200 -r 50 \
      --host=http://127.0.0.1:8080 \
      --run-time 5m

  Watch HPA in a separate terminal:

    kubectl get hpa -n dissertation-eval --watch


E4. EXPECTED RESULTS
--------------------
  CPU will rise rapidly to ~406% (406 millicores against 100m request).
  HPA will scale from 1 to 9 pods within 90 seconds.
  Failure rate should be 0% once pods are available.

  Confirmed result from this study:
    kubectl get hpa output: TARGETS cpu: 406%/50%  REPLICAS: 9
    Total requests: 1,597  |  Failures: 0%  |  Avg response: 25,926ms

  NOTE: High average response time (25,926ms) reflects CPU contention
  before all 9 pods became ready — not a failure. Once scaled, response
  times normalised.


================================================================================
  PART F — POST-EXPERIMENT ANALYSIS
================================================================================

F1. COLLECTING LOCUST CSV OUTPUT
---------------------------------
  Locust generates CSV files automatically via the --csv flag.

  Primary file: results-T<X>-<Workload>-Run1_stats.csv

  For the results table, use the AGGREGATED row which combines all
  endpoints (GET / and GET /stub_status if active):

    Avg Response Time:  "Average Response Time" column, "Aggregated" row
    P95 Response Time:  "95%" column, "Aggregated" row
    Failure Rate:       failure count / request count * 100
    Max Response Time:  "Max Response Time" column, "Aggregated" row


F2. EXTRACTING PROMETHEUS DATA
-------------------------------
  Open Grafana Explore or Prometheus UI after each experiment.

  Peak CPU (run immediately after experiment, set range to experiment duration):
    max_over_time(rate(container_cpu_usage_seconds_total
      {namespace="dissertation-eval",container="nginx"}[1m])[10m:15s]) * 100

  Average CPU:
    avg_over_time(rate(container_cpu_usage_seconds_total
      {namespace="dissertation-eval",container="nginx"}[1m])[10m:15s]) * 100

  Scaling event count:
    changes(kube_hpa_status_current_replicas{namespace="dissertation-eval"}[1h])


F3. COMPUTING SCALING DELAY
----------------------------
  Scaling delay = T_ready - T_breach

  T_breach: Prometheus timestamp when CPU first crosses the threshold.
    Find in Grafana by hovering over the CPU graph.

  T_ready: kubectl timestamp when new pod reaches "1/1 Running".
    From kubectl get pods -w output.

  NOTE: For all 12 Nginx scenarios in this study, HPA never triggered.
  Scaling delay = N/A for all scenarios. No scaling events occurred.


F4. COMPUTING LOAD BALANCE CV
------------------------------
  Coefficient of Variation measures traffic distribution evenness:

    CV = stddev(per-pod request rates) / mean(per-pod request rates)

  Requires nginx-prometheus-exporter to query via Prometheus.
  In this study, CV was approximated from Locust throughput during
  the PHP-Apache validation scale-up event.

  Interpretation:
    CV < 5%    = Even distribution
    CV 5-15%   = Acceptable
    CV 15-25%  = Transient imbalance (expected during scale-up)
    CV > 25%   = Poor distribution


F5. RUNNING THE ANALYSIS SCRIPT
---------------------------------
  The analysis script produces Figures 5.5-5.8 in the dissertation.

    python3 06_analysis/msc_analysis.py

  The script reads all CSV files from 07_results_csv/ and generates:
    - Response time distribution (boxplots)
    - Cohen's d effect size heatmap
    - Cost-performance analysis
    - Scaling delay projections (theoretical)

  NOTE: Figures generated from real CSV data. The Cohen's d values
  for non-spike scenarios are illustrative (single-run data). Spike
  comparisons (T50 vs T70 vs T90) are statistically meaningful.


================================================================================
  PART G — TROUBLESHOOTING
================================================================================

G1. COMMON ISSUES & FIXES
--------------------------
  ISSUE: "kubectl top pods" returns "error: Metrics API not available"
  FIX:   Apply the --kubelet-insecure-tls patch (Part B4, Step 2).
         Then wait 2 minutes and retry.

  ISSUE: HPA shows TARGETS as "<unknown>/70%"
  FIX:   Metrics Server patch not applied or not yet ready.
         Check: kubectl get apiservice v1beta1.metrics.k8s.io
         Should show "True" under AVAILABLE.

  ISSUE: Locust cannot connect — "Connection refused" on port 8080
  FIX:   port-forward is not running or has died.
         Restart: kubectl port-forward service/nginx-service 8080:80 \
                    -n dissertation-eval
         Test: curl http://127.0.0.1:8080

  ISSUE: HPA never scales up despite high traffic load
  FIX:   For Nginx, this is the EXPECTED finding of this study.
         Nginx is CPU-efficient; spike load saturates TCP connections
         before CPU approaches any threshold. This is the central
         finding: CPU-based HPA is decoupled from user experience
         for I/O-bound services. See Section 5.5 of the dissertation.

  ISSUE: Grafana "No data" for dissertation-eval namespace
  FIX:   Verify Prometheus scrape targets include the namespace.
         In Prometheus UI > Status > Targets, look for dissertation-eval.

  ISSUE: Helm install fails "cannot re-use a name that is still in use"
  FIX:   helm uninstall prometheus -n monitoring
         Then re-run the helm install command from Part B3.

  ISSUE: minikube start fails "PROVIDER_DOCKER_NOT_RUNNING"
  FIX:   Start Docker Desktop first, then retry minikube start.

  ISSUE: HPA scaled but traffic still failing
  FIX:   New pods need ~35 seconds to pass Readiness Probe before
         receiving traffic. This is expected and documented in Section 4.3.


G2. KNOWN LIMITATIONS
---------------------
  1. Single-node cluster: All pods share one node. Production clusters
     distribute across multiple nodes with hardware-level network separation.

  2. Docker driver networking: kubectl port-forward adds approximately
     1-5ms tunnel overhead not present in production environments.

  3. Nginx static content: nginx:latest is extremely CPU-efficient.
     The CPU decoupling finding applies to I/O-bound services generally
     but may differ for compute-intensive microservices.

  4. Synthetic traffic: Locust generates uniform request patterns.
     Real production traffic has long-tail distributions not fully captured.

  5. nginx-prometheus-exporter not installed: P95 response time and
     per-pod request rate were collected from Locust CSV rather than
     Prometheus. Queries 7-10 in promql-queries.txt require this exporter.

  6. Single run per scenario: Each of the 12 scenarios was run once.
     Statistical analysis uses single-run data; confidence intervals
     and Cohen's d values are illustrative for non-spike comparisons.

  FULL CLUSTER RESET:
    minikube delete
    minikube start --driver=docker --cpus=4 --memory=6144
    minikube addons enable metrics-server
    [then re-apply TLS patch and repeat Part B]
    Estimated rebuild time: 10-15 minutes.


================================================================================
  PART H — FILE MANIFEST
================================================================================

H1. KUBERNETES CONFIGURATION FILES (02_kubernetes_config/)
-----------------------------------------------------------
  C1-deployment.yaml              Nginx Deployment (100m CPU, readinessProbe)
  C2-service.yaml                 NodePort Service (port 30080)
  C3-hpa-50.yaml                  HPA 50% threshold (Conservative)
  C4-hpa-70.yaml                  HPA 70% threshold (Standard)
  C5-hpa-90.yaml                  HPA 90% threshold (Aggressive)
  C8-namespace.yaml               dissertation-eval namespace
  C9-hpa-multimetric.yaml         Multi-metric HPA (CPU + request rate) — future work
  C10-prometheus-adapter-rules.yaml  Prometheus Adapter ConfigMap — future work
  C11-php-apache-cpu-intensive.yaml  PHP-Apache validation deployment + service

  NOTE: C6 and C7 referenced in earlier drafts are not standalone files.
  C9 and C10 were designed but not deployed — nginx-prometheus-exporter
  was required and caused CrashLoopBackOff errors. See Section 6.1.


H2. LOAD TESTING SCRIPTS (03_load_testing/)
-------------------------------------------
  locustfile.py         Four workload classes (Steady, Step, Bursty, Spike)
                        with daemon thread controllers. stub_status commented out.
  locustfile_cpu.py     Single class for PHP-Apache validation (aggressive load)


H3. RESULTS CSV FILES (07_results_csv/) — ALL COMPLETE
-------------------------------------------------------
  T50 Steady:    results-T50-Steady-Run1_stats.csv + history
  T50 Step:      results-T50-Step-Run1_stats.csv + history
  T50 Bursty:    results-T50-Bursty-Run1_stats.csv + history
  T50 Spike:     results-T50-Spike-Run1_stats.csv
  T70 Steady:    results-T70-Steady-Run1_stats.csv
  T70 Step:      results-T70-Step-Run1_stats.csv + history
  T70 Bursty:    results-T70-Bursty-Run1_stats.csv + history
  T70 Spike:     results-T70-Spike-Run1_stats.csv
  T90 Steady:    results-T90-Steady-Run1_stats.csv + history
  T90 Step:      results-T90-Step-Run1_stats.csv
  T90 Bursty:    results-T90-Bursty-Run1_stats.csv + history
  T90 Spike:     results-T90-Spike-Run1_stats.csv

  Total: 20 CSV files. All 12 scenarios complete.
  NOTE: Spike scenarios have stats only (no history file) — normal for
  the volume of data generated during spike workloads.


H4. ANALYSIS AND AUTOMATION SCRIPTS
-------------------------------------
  04_automation/run-overnight.ps1    PowerShell automation for 8 non-spike scenarios
  05_monitoring_queries/promql-queries.txt  All PromQL queries reference
  06_analysis/msc_analysis.py        Python analysis script (produces Figures 5.5-5.8)


H5. DISSERTATION FILES
-----------------------
  01_dissertation_document/Dissertation_Report.docx   Final dissertation
                                                       (24,859 words including appendices)


================================================================================
  PART I — AUTOMATED EXECUTION (run-overnight.ps1)
================================================================================

I1. OVERVIEW
------------
  The PowerShell script 04_automation/run-overnight.ps1 automates
  the 8 non-spike scenarios (Steady, Step, Bursty for all 3 thresholds).
  Spike scenarios were run manually to allow real-time observation.

  The script handles:
    - Applying the correct HPA YAML
    - Resetting deployment to 1 replica
    - 60-second stabilisation wait
    - Launching Locust with correct parameters
    - Saving CSV output with consistent naming convention

  Estimated runtime: 4.5 hours for all 8 scenarios.


I2. PREREQUISITES
-----------------
  - PowerShell 5.1+ (built into Windows 11)
  - All YAML files in 02_kubernetes_config/ folder
  - locustfile.py in 03_load_testing/ folder
  - Minikube cluster running
  - Metrics Server configured with TLS patch
  - kubectl port-forward running BEFORE starting script:
      kubectl port-forward service/nginx-service 8080:80 -n dissertation-eval

  IMPORTANT: The script uses http://127.0.0.1:8080 as the fixed host.
  The port-forward must be active in a separate terminal window before
  running the script.


I3. USAGE
---------
  Run from the root dissertation/ folder:

    cd "C:\Users\YourName\OneDrive\dissertation"
    .\04_automation\run-overnight.ps1

  The script runs all 8 scenarios sequentially and saves results to
  07_results_csv/ with the naming convention results-T<N>-<Workload>-Run1.


================================================================================
  PART J — COMPLETED RESULTS SUMMARY
================================================================================

J1. ALL 12 SCENARIOS — VERIFIED VALUES
----------------------------------------
  Values verified against Locust CSV Aggregated rows (April 2026).
  CPU values from Prometheus post-experiment queries.
  All pods = 1 (HPA never triggered for any Nginx scenario).
  All scaling delay = N/A.

  #   Thresh  Workload  MaxCPU  AvgCPU  Pods  AvgResp   P95      Fail%   MaxResp
  --  ------  --------  ------  ------  ----  --------  -------  ------  ----------
   1   50%    Steady      6%     3%      1     8ms       14ms     0.00%   N/A
   2   50%    Step        6%     3%      1     17ms      35ms     0.00%   N/A
   3   50%    Bursty      4%     2%      1     5ms        9ms     0.00%   N/A
   4   50%    Spike      33%    12%      1     403ms    2000ms    8.68%   205,307ms
   5   70%    Steady      6%     3%      1     40ms      74ms     0.00%   6,541ms
   6   70%    Step        6%     3%      1     19ms      37ms     0.00%   N/A
   7   70%    Bursty      4%     2%      1     10ms      28ms     0.00%   N/A
   8   70%    Spike      39%    15%      1     354ms    2000ms    8.77%   198,655ms
   9   90%    Steady      5%     2%      1     15ms      17ms     0.00%   N/A
  10   90%    Step        5%     2%      1     5ms        8ms     0.00%   N/A
  11   90%    Bursty      4%     2%      1     5ms        7ms     0.00%   N/A
  12   90%    Spike      33%    12%      1     408ms    2000ms    8.63%   200,898ms

  Validation (Scenario 13 — PHP-Apache):
      Peak CPU: 406%   Pods scaled: 1 → 9   Failures: 0%   Avg resp: 25,926ms


J2. KEY FINDING SUMMARY
------------------------
  HPA did not trigger for ANY of the 12 Nginx scenarios.
  Maximum Nginx CPU across all scenarios: 39% (T70 Spike).
  All three spike thresholds (50%, 70%, 90%) produced near-identical
  failure rates (8.63-8.77%) — confirming threshold-independence.

  Root cause: Nginx event-driven I/O architecture handles connections
  with minimal CPU. TCP connection queue saturates before CPU threshold
  is reached. CPU metric is a poor predictor for I/O-bound services.

  PHP-Apache validation confirms HPA infrastructure works correctly:
  406% CPU → scaled to 9 pods within 90 seconds on the same cluster.


J3. CSV CROSS-CHECK NOTES
--------------------------
  Cross-check performed 17 April 2026 against CSV files.

  Corrections applied to dissertation Table 5.1:
    Scenario 5 P95:     2,562ms → 74ms  (previous value from setup run)
    Scenario 8 AvgResp: 196ms   → 354ms (previous value from wrong run)
    Scenario 8 Fail%:   9.08%   → 8.77% (previous value from wrong run)
    Scenario 8 P95:     2,294ms → 2,000ms

  All other scenarios verified as correct in dissertation.

  IMPORTANT: The 9.08% value used in some dissertation text (Chapter 7)
  is wrong — correct value is 8.77%. This needs fixing in the dissertation.


================================================================================
  QUICK START — REPLICATE FROM SCRATCH IN 20 MINUTES
================================================================================

  1.  Start Docker Desktop
  2.  minikube start --driver=docker --cpus=4 --memory=6144
  3.  minikube addons enable metrics-server
  4.  kubectl patch deployment metrics-server -n kube-system \
        --type='json' \
        -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-",\
              "value":"--kubelet-insecure-tls"}]'
  5.  kubectl apply -f 02_kubernetes_config/C8-namespace.yaml
  6.  kubectl apply -f 02_kubernetes_config/C1-deployment.yaml
  7.  kubectl apply -f 02_kubernetes_config/C2-service.yaml
  8.  helm repo add prometheus-community \
        https://prometheus-community.github.io/helm-charts
  9.  helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring --create-namespace \
        --set prometheus.prometheusSpec.scrapeInterval=15s \
        --set grafana.adminPassword=dissertation2026 \
        --set grafana.service.type=NodePort
  10. kubectl get pods -n monitoring -w          (wait until all Running)
  11. kubectl apply -f 02_kubernetes_config/C4-hpa-70.yaml
  12. kubectl port-forward service/nginx-service 8080:80 \
        -n dissertation-eval                     (new terminal, keep open)
  13. Wait 60 seconds
  14. locust -f 03_load_testing/locustfile.py SteadyWorkload --headless \
        -u 50 -r 5 --host=http://127.0.0.1:8080 \
        --run-time 10m --csv 07_results_csv/results-T70-Steady-Run1
  15. Done. Check 07_results_csv/results-T70-Steady-Run1_stats.csv.

================================================================================
  END OF MANUAL
================================================================================

  Last updated: 2 May 2026 (v4 — updated to reflect completed experiments,
  corrected CSV values, fixed port-forward vs minikube tunnel, updated
  file manifest with all 20 CSVs and C9-C11, corrected script name to
  run-overnight.ps1, removed outdated remaining-scenarios section)

  Oliur Rahman Safwan | Student ID: 77547231 | Leeds Beckett University
