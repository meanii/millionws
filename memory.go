package main

import (
	"log"
	"os"
	"runtime/debug"
	"runtime/metrics"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var goMemoryLimit = promauto.NewGauge(prometheus.GaugeOpts{
	Name: "millionws_go_memory_limit_bytes",
	Help: "Soft memory limit given to the Go runtime; 0 when not managed by the server",
})

// memoryHeadroom is kept free below the cgroup limit for bursts between two
// adjustments: new connections allocate kernel memory before the next tick.
const memoryHeadroom = 0.05

// manageMemoryLimit keeps the Go soft memory limit equal to what the cgroup
// has left after kernel memory.
//
// Each idle connection costs about 4 KiB of kernel memory (socket, inode,
// epoll entry) and about 1 KiB of Go heap, and both are charged to the same
// cgroup. The Go GC only knows about its own heap: with the default GOGC=100
// it lets the heap grow to twice the live data before collecting, and the
// kernel OOM-kills the process while that garbage is still mapped. A fixed
// GOMEMLIMIT does not help either, because the kernel's share grows with the
// connection count.
//
// Once a second this reads memory.current, subtracts the memory the Go runtime
// holds, and sets the Go limit to what remains under memory.max minus 5%.
// When the limit binds, the GC runs more often, which costs CPU (the runtime
// caps GC at about 50% of CPU time in that state) instead of the process.
//
// It does nothing if GOMEMLIMIT is set or the cgroup has no memory limit.
func manageMemoryLimit() {
	if os.Getenv("GOMEMLIMIT") != "" {
		log.Printf("memory limit: GOMEMLIMIT is set, not managing the Go memory limit")
		return
	}
	cgroupMax, ok := readCgroupInt("/sys/fs/cgroup/memory.max")
	if !ok {
		log.Printf("memory limit: no cgroup v2 memory limit found, not managing the Go memory limit")
		return
	}
	log.Printf("memory limit: cgroup limit %d MiB, adjusting the Go memory limit every second", cgroupMax>>20)

	samples := []metrics.Sample{
		{Name: "/memory/classes/total:bytes"},
		{Name: "/memory/classes/heap/released:bytes"},
	}
	headroom := int64(float64(cgroupMax) * memoryHeadroom)
	var last int64

	for range time.Tick(time.Second) {
		current, ok := readCgroupInt("/sys/fs/cgroup/memory.current")
		if !ok {
			continue
		}
		metrics.Read(samples)
		goMapped := int64(samples[0].Value.Uint64() - samples[1].Value.Uint64())
		other := max(current-goMapped, 0) // kernel memory and page cache
		limit := cgroupMax - other - headroom
		if limit < headroom {
			limit = headroom
		}
		// Skip changes under 1% so the runtime is not reconfigured every tick.
		if d := limit - last; d > last/100 || -d > last/100 {
			debug.SetMemoryLimit(limit)
			goMemoryLimit.Set(float64(limit))
			last = limit
		}
	}
}

// Admission control thresholds, as a share of the cgroup memory limit.
const (
	rejectAbove = 0.90
	acceptBelow = 0.85
)

var (
	overloaded = atomic.Bool{}

	rejectedConnections = promauto.NewCounter(prometheus.CounterOpts{
		Name: "millionws_connections_rejected_total",
		Help: "WebSocket requests answered with 503 because container memory was above the admission threshold",
	})
)

// guardMemory sets overloaded when container memory passes 90% of the cgroup
// limit and clears it below 85%. While it is set, /ws answers 503 instead of
// upgrading. Without it, the next connections past the limit trigger the OOM
// killer, which drops every open connection at once; with it, existing
// connections stay up and only new clients are turned away.
func guardMemory() {
	cgroupMax, ok := readCgroupInt("/sys/fs/cgroup/memory.max")
	if !ok {
		return
	}
	high := int64(float64(cgroupMax) * rejectAbove)
	low := int64(float64(cgroupMax) * acceptBelow)
	for range time.Tick(250 * time.Millisecond) {
		current, ok := readCgroupInt("/sys/fs/cgroup/memory.current")
		if !ok {
			continue
		}
		switch {
		case current > high && !overloaded.Load():
			overloaded.Store(true)
			log.Printf("memory guard: %d MiB of %d MiB used, rejecting new connections", current>>20, cgroupMax>>20)
		case current < low && overloaded.Load():
			overloaded.Store(false)
			log.Printf("memory guard: %d MiB of %d MiB used, accepting new connections", current>>20, cgroupMax>>20)
		}
	}
}

func readCgroupInt(path string) (int64, bool) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return 0, false
	}
	n, err := strconv.ParseInt(strings.TrimSpace(string(raw)), 10, 64)
	return n, err == nil && n > 0
}
