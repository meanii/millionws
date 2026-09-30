package main

import "sync"

// registry holds open connections so the sender can walk them in order, with
// O(1) add and remove. Slots are tracked in a map rather than in the
// connection's session, so a removal never depends on state that add has not
// written yet.
//
// A connection can be reported closed before add is called: the dialer returns
// only after the handshake, and the server may close right away. remove then
// remembers it, and add refuses it, so it is neither stored nor counted as
// active.
type registry[C comparable] struct {
	mu     sync.Mutex
	conns  []C
	slot   map[C]int
	closed map[C]struct{} // closed before they were added
}

func newRegistry[C comparable](capacity int) *registry[C] {
	return &registry[C]{
		conns:  make([]C, 0, capacity),
		slot:   make(map[C]int, capacity),
		closed: make(map[C]struct{}),
	}
}

// add stores c and reports whether it did. It returns false if c was already
// closed or is already stored.
func (r *registry[C]) add(c C) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, was := r.closed[c]; was {
		delete(r.closed, c)
		return false
	}
	if _, dup := r.slot[c]; dup {
		return false
	}
	r.slot[c] = len(r.conns)
	r.conns = append(r.conns, c)
	return true
}

// remove deletes c and reports whether it was stored. A connection that is not
// stored yet is remembered as closed so that a later add can refuse it.
func (r *registry[C]) remove(c C) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	i, ok := r.slot[c]
	if !ok {
		r.closed[c] = struct{}{}
		return false
	}
	var zero C
	last := len(r.conns) - 1
	moved := r.conns[last]
	r.conns[i] = moved
	r.slot[moved] = i
	r.conns[last] = zero
	r.conns = r.conns[:last]
	delete(r.slot, c)
	return true
}

func (r *registry[C]) len() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.conns)
}

// batch copies up to n connections starting at cursor into dst and returns the
// next cursor. It wraps around the end of the list.
func (r *registry[C]) batch(dst []C, cursor, n int) ([]C, int) {
	r.mu.Lock()
	defer r.mu.Unlock()
	total := len(r.conns)
	if total == 0 {
		return dst[:0], 0
	}
	if n > total {
		n = total
	}
	dst = dst[:0]
	for i := 0; i < n; i++ {
		dst = append(dst, r.conns[(cursor+i)%total])
	}
	return dst, (cursor + n) % total
}
