"""
locustfile.py — Dissertation Load Testing Script
Evaluating Kubernetes HPA Using Prometheus
Oliur Rahman Safwan | Leeds Beckett University | 2026

Four workload classes:
  SteadyWorkload  — 50 constant users, 10 minutes
  StepWorkload    — 10->150 users, +20 every 2 minutes
  BurstyWorkload  — 10-200 users varying randomly every 30 seconds
  SpikeWorkload   — 10 users -> 500 instant spike -> recovery

NOTE on /stub_status endpoint:
  The get_health task targeting /stub_status is retained below but
  commented out. Standard nginx:latest does not expose /stub_status
  without additional Nginx configuration (ngx_http_stub_status_module).
  All dissertation analysis uses GET / metrics only. The /stub_status
  requests appeared in experimental CSV files but were excluded from
  Table 5.1 failure rate calculations as they represent a configuration
  characteristic rather than service degradation under load.
"""

import time
import random
import threading
from locust import HttpUser, task, between, events


# ============================================================
# WORKLOAD 1: STEADY (50 constant users, 10 min)
# ============================================================
class SteadyWorkload(HttpUser):
    """50 constant users for 10 minutes.
    Simulates: Normal SaaS business hours traffic.
    Expected HPA: No scaling triggered (CPU stays at 2-6%).
    """
    wait_time = between(0.5, 2.0)

    @task(10)
    def get_homepage(self):
        self.client.get("/")

    # NOTE: /stub_status excluded from analysis - see module docstring
    # @task(2)
    # def get_health(self):
    #     self.client.get("/stub_status")


# ============================================================
# WORKLOAD 2: STEP (10->150 users, +20 every 2 min)
# ============================================================
class StepWorkload(HttpUser):
    """10 to 150 users, increasing by 20 every 2 minutes.
    Simulates: Morning traffic ramp-up.
    Expected HPA: Progressive scaling at each increment.
    """
    wait_time = between(0.5, 2.0)

    @task(10)
    def get_homepage(self):
        self.client.get("/")

    # NOTE: /stub_status excluded from analysis - see module docstring
    # @task(2)
    # def get_health(self):
    #     self.client.get("/stub_status")


class StepController:
    """Background thread to increment users every 2 minutes."""
    def __init__(self, runner):
        self.runner = runner
        self.thread = threading.Thread(target=self._run, daemon=True)

    def start(self):
        self.thread.start()

    def _run(self):
        users = 10
        while users < 150:
            time.sleep(120)
            users = min(users + 20, 150)
            self.runner.start(users, spawn_rate=2)


# ============================================================
# WORKLOAD 3: BURSTY (10-200 users, random every 30s)
# ============================================================
class BurstyWorkload(HttpUser):
    """10 to 200 users varying randomly every 30 seconds.
    Simulates: Viral social media traffic spikes.
    Expected HPA: Frequent scale events, potential oscillation.
    """
    wait_time = between(0.2, 1.0)

    @task(10)
    def get_homepage(self):
        self.client.get("/")

    # NOTE: /stub_status excluded from analysis - see module docstring
    # @task(2)
    # def get_health(self):
    #     self.client.get("/stub_status")


class BurstyController:
    """Background thread to vary users randomly every 30 seconds."""
    def __init__(self, runner):
        self.runner = runner
        self.thread = threading.Thread(target=self._run, daemon=True)

    def start(self):
        self.thread.start()

    def _run(self):
        random.seed(77547231)  # reproducibility — student ID as seed
        for _ in range(20):
            time.sleep(30)
            users = random.randint(10, 200)
            rate = random.randint(10, 50)
            self.runner.start(users, spawn_rate=rate)


# ============================================================
# WORKLOAD 4: SPIKE (10 -> 500 instant -> 10 recovery)
# ============================================================
class SpikeWorkload(HttpUser):
    """10 users baseline -> 500 users instant spike -> recovery.
    Simulates: Flash sale or breaking news event.
    Expected HPA: Worst-case test - CPU may not cross threshold
    for I/O-bound nginx due to metric-bottleneck mismatch.
    """
    wait_time = between(0.2, 1.0)

    @task(10)
    def get_homepage(self):
        self.client.get("/")

    # NOTE: /stub_status excluded from analysis - see module docstring
    # @task(2)
    # def get_health(self):
    #     self.client.get("/stub_status")


class SpikeController:
    """Background thread: 5 min baseline -> instant 500 spike -> recovery."""
    def __init__(self, runner):
        self.runner = runner
        self.thread = threading.Thread(target=self._run, daemon=True)

    def start(self):
        self.thread.start()

    def _run(self):
        time.sleep(300)
        self.runner.start(500, spawn_rate=500)
        time.sleep(180)
        self.runner.start(10, spawn_rate=10)


# ============================================================
# EVENT LISTENER: Auto-start controllers for dynamic workloads
# ============================================================
@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    runner = environment.runner
    user_classes = [cls.__name__ for cls in environment.user_classes]
    if "StepWorkload" in user_classes:
        StepController(runner).start()
    if "BurstyWorkload" in user_classes:
        BurstyController(runner).start()
    if "SpikeWorkload" in user_classes:
        SpikeController(runner).start()

