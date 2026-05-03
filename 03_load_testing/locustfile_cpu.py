"""
locustfile_cpu.py — CPU-Intensive Validation Experiment
Tests HPA scaling with a compute-bound application (PHP sqrt loop)
Oliur Rahman Safwan | Leeds Beckett University | 2026
"""

from locust import HttpUser, task, between


class CPUIntensiveWorkload(HttpUser):
    """Generates load against php-apache which does CPU-heavy sqrt() loops.
    This WILL trigger HPA scaling, validating the experimental setup.
    """
    wait_time = between(0.01, 0.05)  # Very fast requests to push CPU

    @task
    def generate_cpu_load(self):
        self.client.get("/")
