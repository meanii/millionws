package main

import (
	"net"
	"net/http"
	"os"
	"path/filepath"
	"reflect"
	"strconv"
	"testing"
	"time"

	"github.com/lesismal/nbio/nbhttp"
	"github.com/lesismal/nbio/nbhttp/websocket"
)

func TestParsePorts(t *testing.T) {
	tests := []struct {
		in      string
		want    []int
		wantErr bool
	}{
		{in: "", want: nil},
		{in: " , ,", want: nil},
		{in: "8081", want: []int{8081}},
		{in: "8081, 8090-8092", want: []int{8081, 8090, 8091, 8092}},
		{in: "8080-8080", want: []int{8080}},
		{in: "1-2,65535", want: []int{1, 2, 65535}},
		{in: "abc", wantErr: true},
		{in: "8081-abc", wantErr: true},
		{in: "8095-8090", wantErr: true},
		{in: "0", wantErr: true},
		{in: "65536", wantErr: true},
		{in: "8080-70000", wantErr: true},
	}
	for _, tt := range tests {
		got, err := parsePorts(tt.in)
		if (err != nil) != tt.wantErr {
			t.Errorf("parsePorts(%q) error = %v, wantErr %v", tt.in, err, tt.wantErr)
			continue
		}
		if !reflect.DeepEqual(got, tt.want) {
			t.Errorf("parsePorts(%q) = %v, want %v", tt.in, got, tt.want)
		}
	}
}

// The AWS compose file once passed -ports=8080-8095 with the default
// -port=8080, which listed 8080 twice and left the server listening on nothing.
func TestListenAddrsDropsRepeats(t *testing.T) {
	got, err := listenAddrs("0.0.0.0", 8080, "8080-8082")
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"0.0.0.0:8080", "0.0.0.0:8081", "0.0.0.0:8082"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("listenAddrs = %v, want %v", got, want)
	}

	got, err = listenAddrs("127.0.0.1", 9000, "")
	if err != nil || !reflect.DeepEqual(got, []string{"127.0.0.1:9000"}) {
		t.Errorf("single port: got %v, %v", got, err)
	}

	if _, err := listenAddrs("0.0.0.0", 8080, "nope"); err == nil {
		t.Error("expected an error for a bad -ports value")
	}
}

func freePort(t *testing.T) int {
	t.Helper()
	l, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port
}

func TestCheckListening(t *testing.T) {
	l, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	open := l.Addr().String()

	if err := checkListening([]string{open}); err != nil {
		t.Errorf("open port reported as closed: %v", err)
	}
	closed := net.JoinHostPort("127.0.0.1", strconv.Itoa(freePort(t)))
	if err := checkListening([]string{open, closed}); err == nil {
		t.Error("closed port not reported")
	}
}

func TestReadCgroupInt(t *testing.T) {
	dir := t.TempDir()
	write := func(name, content string) string {
		p := filepath.Join(dir, name)
		if err := os.WriteFile(p, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
		return p
	}
	tests := []struct {
		name   string
		path   string
		want   int64
		wantOK bool
	}{
		{"number", write("a", "1073741824\n"), 1073741824, true},
		{"unlimited", write("b", "max\n"), 0, false},
		{"zero", write("c", "0\n"), 0, false},
		{"empty", write("d", ""), 0, false},
		{"missing", filepath.Join(dir, "nope"), 0, false},
	}
	for _, tt := range tests {
		got, ok := readCgroupInt(tt.path)
		if got != tt.want || ok != tt.wantOK {
			t.Errorf("%s: readCgroupInt = (%d, %v), want (%d, %v)", tt.name, got, ok, tt.want, tt.wantOK)
		}
	}
}

// TestServerEndToEnd starts the real handler on two ports and checks that a
// message is echoed on each, that /health answers, and that the memory guard
// turns new /ws requests away with 503.
func TestServerEndToEnd(t *testing.T) {
	ports := []int{freePort(t), freePort(t)}
	addrs := make([]string, len(ports))
	for i, p := range ports {
		addrs[i] = net.JoinHostPort("127.0.0.1", strconv.Itoa(p))
	}

	engine := nbhttp.NewEngine(nbhttp.Config{
		Network: "tcp4",
		Addrs:   addrs,
		Handler: newMux(newUpgrader(0), false),
	})
	if err := engine.Start(); err != nil {
		t.Fatal(err)
	}
	defer engine.Stop()
	if err := checkListening(addrs); err != nil {
		t.Fatal(err)
	}

	clientEngine := nbhttp.NewEngine(nbhttp.Config{Name: "test-client"})
	if err := clientEngine.Start(); err != nil {
		t.Fatal(err)
	}
	defer clientEngine.Stop()

	for _, addr := range addrs {
		echoed := make(chan string, 1)
		up := websocket.NewUpgrader()
		up.OnMessage(func(c *websocket.Conn, _ websocket.MessageType, data []byte) {
			echoed <- string(data)
		})
		d := &websocket.Dialer{Engine: clientEngine, Upgrader: up, DialTimeout: 3 * time.Second}
		c, _, err := d.Dial("ws://"+addr+"/ws", nil)
		if err != nil {
			t.Fatalf("dial %s: %v", addr, err)
		}
		if err := c.WriteMessage(websocket.TextMessage, []byte("hello "+addr)); err != nil {
			t.Fatalf("write %s: %v", addr, err)
		}
		select {
		case got := <-echoed:
			if got != "hello "+addr {
				t.Errorf("%s echoed %q", addr, got)
			}
		case <-time.After(3 * time.Second):
			t.Fatalf("%s: no echo", addr)
		}
		c.Close()

		resp, err := http.Get("http://" + addr + "/health")
		if err != nil {
			t.Fatalf("health %s: %v", addr, err)
		}
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Errorf("%s /health = %d", addr, resp.StatusCode)
		}
	}

	overloaded.Store(true)
	defer overloaded.Store(false)
	resp, err := http.Get("http://" + addrs[0] + "/ws")
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusServiceUnavailable {
		t.Errorf("/ws while overloaded = %d, want 503", resp.StatusCode)
	}
}
