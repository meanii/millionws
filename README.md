# MillionWS
MillionWS is a high-performance WebSocket server written in Go.
The project is focused on measuring, understanding, and reducing the resource cost of large-scale WebSocket concurrency while maintaining predictable performance and observability.

## Project Goal
The primary goal of MillionWS is to support up to 1,000,000 concurrent WebSocket connections while minimizing per-connection resource usage and maintaining stable throughput.

### **Key Objectives**
- Reduce memory usage per connection
- Reduce CPU overhead per connection
- Minimize goroutine count per connection
- Minimize file descriptor overhead
- Maintain low and predictable message latency
- Provide accurate, real-time observability via metrics

### **Non-Goals**
- Feature-rich application logic
- Business-level WebSocket protocols
- Client authentication or authorization
- Message persistence or durability guarantees

MillionWS is intentionally minimal and exists solely to study scalability characteristics.

### **Architecture Overview**
| **Components** | **Technology** |
| --- | --- |
| Language | Go |
| WebSocket | gorilla/websocket (baseline) |
| Metrics | Prometheus |
| Monitoring | Grafana |
| Distributed Load Testing | Locust |
| Orchestration | Kubernetes (EKS) |
| Infrastructure | Terraform |

### **Server Responsibilities**
- Accept WebSocket connections
- Track connection lifecycle metrics
- Echo messages back to clients
- Expose health and metrics endpoints

### **Exposed Endpoints**
| **Endpoint** | **Description** |
| --- | --- |
| `/echo` | WebSocket echo handler |
| `/health` | Returns a simple health check response |
| `/metrics` | Exposes Prometheus metrics for monitoring |

### **Observability**
The server exposes Prometheus metrics to measure connection scale and resource usage.

#### **Core Metrics**
- Total WebSocket connections accepted
- Current active WebSocket connections
- Total WebSocket disconnections
- Process memory usage
- Goroutine count
- Open file descriptors

---
### **Baseline Measurements**
Initial testing was performed with 5,000 concurrent WebSocket connections.
#### Resource Usage
| **Metric** | **Value** |
| --- | --- |
| Active Connections | 5,000 |
| Memory Usage | 192 MiB |
| Goroutines | 5,010 |
| Open File Descriptors | 5,010 |

Approximate memory usage: **~38 KB per connection**

### Repository Structure
```
.
├── deploy
│   ├── local
│   │   ├── compose.yml
│   │   ├── dashboard.json
│   │   ├── datasource.yml
│   │   └── prometheus.yml
│   └── millionws
│       ├── deployment.yaml
│       ├── hpa.yaml
│       ├── namespace.yaml
│       ├── pdb.yaml
│       └── service.yaml
├── Dockerfile
├── go.mod
├── go.sum
├── infra
│   └── terraform
│       ├── clusters
│       └── modules
├── justfile
├── LICENSE
├── locust
│   ├── kustomization.yaml
│   ├── locustfile.py
│   ├── locusttest.yaml
│   ├── namespace.yaml
│   ├── README.md
│   ├── requirements.txt
│   └── run.sh
├── main.go
└── README.md

9 directories, 23 files

### References
- https://dyte.io/blog/scaling-websockets-to-millions/
- https://www.freecodecamp.org/news/million-websockets-and-go-cc58418460bb/
- https://github.com/gobwas/ws-examples/blob/master/src/chat/main.go#L135

```
