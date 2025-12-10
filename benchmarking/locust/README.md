# Locust Load Testing Guide

This directory contains files for running Locust load tests in Kubernetes using the Locust Operator.

## 1. Writing a test

Edit or replace:

```
benchmarking/locust/locustfile.py
```

Example:

```python
from locust import HttpUser, task

class PingUser(HttpUser):
    @task
    def ping(self):
        self.client.get("/ping")
```

Use meaningful class names and task names.
Each test script should contain only the logic for one test scenario.

If creating multiple tests, name them clearly:

```
locustfile_login.py
locustfile_ping.py
locustfile_checkout.py
```

Only one is used at a time; update `locusttest.yaml` accordingly.

## 2. Number of workers

Workers are defined in:

```
locusttest.yaml
```

Example:

```yaml
spec:
  workers: 5
```

Workers determine parallelism and throughput.
Guidelines:

* Start low (1–5) for functional validation.
* Increase gradually for load or stress tests.
* Ensure resource limits are appropriate if running many workers.

Changing worker count requires reapplying:

```
kubectl apply -k benchmarking/locust
```

## 3. Deploy the test

```
kubectl apply -k benchmarking/locust
```

Check test status:

```
kubectl get locusttests -n locusttests
```

## 4. Check pods and logs

List pods:

```
kubectl get pods -n locusttests
```

Master logs:

```
kubectl logs -n locusttests deploy/load-test-v2-master -f
```

Worker logs:

```
kubectl logs -n locusttests deploy/load-test-v2-worker -f
```

## 5. Accessing the Locust web UI

### LoadBalancer service

```
kubectl get svc -n locusttests
```

Open:

```
http://<external-ip>:8089
```

### Port forwarding (works in all clusters)

```
kubectl port-forward -n locusttests svc/load-test-v2-master 8089:8089
```

Open:

```
http://localhost:8089
```

## 6. Updating and redeploying the test

After modifying `locustfile.py`, redeploy:

```
kubectl apply -k benchmarking/locust
```

Pods will restart with the new test code.

## 7. Naming conventions

Use consistent names for test resources:

* Namespace: `locusttests`
* Test name: `load-test-<purpose>`
* ConfigMap: `locustfile`
* Test scripts: `locustfile_<purpose>.py`

Examples:

```
load-test-login
load-test-ping
load-test-orders
```

This keeps test artifacts organized.

## 8. Storing test results in the repository

Locust UI allows exporting:

* CSV statistics
* charts
* failure logs

Suggested storage layout:

```
benchmarking/results/<test-name>/<timestamp>/
```

Example:

```
benchmarking/results/load-test-ping/2025-12-10/
    stats.csv
    failures.csv
    distribution.csv
    summary.txt
```

Do not store raw logs unless necessary.
Commit only summary results or charts that are useful for comparison.

## 9. Removing all test resources

```
kubectl delete -k benchmarking/locust
```
