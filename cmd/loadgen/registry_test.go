package main

import (
	"fmt"
	"reflect"
	"sync"
	"testing"
)

func TestRegistryAddRemove(t *testing.T) {
	r := newRegistry[string](4)
	for _, c := range []string{"a", "b", "c", "d"} {
		if !r.add(c) {
			t.Fatalf("add %s refused", c)
		}
	}
	if r.add("b") {
		t.Error("adding a stored connection twice must be refused")
	}
	if r.len() != 4 {
		t.Fatalf("len = %d, want 4", r.len())
	}

	// Removing from the middle swaps the last connection into the hole.
	if !r.remove("b") {
		t.Error("remove of a stored connection returned false")
	}
	if r.remove("b") {
		t.Error("second remove of the same connection returned true")
	}
	got, _ := r.batch(nil, 0, 10)
	if !reflect.DeepEqual(got, []string{"a", "d", "c"}) {
		t.Errorf("after removing b, batch = %v", got)
	}
	// The moved connection must still be removable through its new slot.
	if !r.remove("d") || !r.remove("c") || !r.remove("a") {
		t.Error("removing the remaining connections failed")
	}
	if r.len() != 0 {
		t.Errorf("len = %d after removing everything", r.len())
	}
}

// A connection can be reported closed before the dialer has added it. It must
// not be stored, or the load generator would count it as open forever.
func TestRegistryClosedBeforeAdd(t *testing.T) {
	r := newRegistry[string](2)
	if r.remove("late") {
		t.Error("remove of an unknown connection returned true")
	}
	if r.add("late") {
		t.Error("add of a connection that was already closed must be refused")
	}
	if r.len() != 0 {
		t.Errorf("len = %d, want 0", r.len())
	}
	// The record is consumed: the same key can be used again afterwards.
	if !r.add("late") {
		t.Error("a later, genuine add of the same key was refused")
	}
}

func TestRegistryBatchWraps(t *testing.T) {
	r := newRegistry[int](5)
	for i := 0; i < 5; i++ {
		r.add(i)
	}
	got, cur := r.batch(nil, 0, 3)
	if !reflect.DeepEqual(got, []int{0, 1, 2}) || cur != 3 {
		t.Errorf("first batch = %v, cursor %d", got, cur)
	}
	got, cur = r.batch(got, cur, 3)
	if !reflect.DeepEqual(got, []int{3, 4, 0}) || cur != 1 {
		t.Errorf("wrapping batch = %v, cursor %d", got, cur)
	}
	got, _ = r.batch(got, 0, 99)
	if len(got) != 5 {
		t.Errorf("a batch larger than the list returned %d items", len(got))
	}
	empty := newRegistry[int](0)
	if got, cur := empty.batch(nil, 7, 3); len(got) != 0 || cur != 0 {
		t.Errorf("empty registry batch = %v, cursor %d", got, cur)
	}
}

// Adds and removes from many goroutines, in either order per connection, must
// leave exactly the connections that were added and never removed.
func TestRegistryConcurrent(t *testing.T) {
	r := newRegistry[string](1000)
	var wg sync.WaitGroup
	for i := 0; i < 1000; i++ {
		c := fmt.Sprintf("c%d", i)
		wg.Add(2)
		go func() { defer wg.Done(); r.add(c) }()
		if i%2 == 0 { // every even connection is also closed, racing with its add
			go func() { defer wg.Done(); r.remove(c) }()
		} else {
			wg.Done()
		}
	}
	wg.Wait()
	// Odd connections were never closed. Even ones are either stored-then-removed
	// or refused, so none of them may remain.
	if r.len() != 500 {
		t.Errorf("len = %d, want 500", r.len())
	}
	got, _ := r.batch(nil, 0, 1000)
	for _, c := range got {
		var n int
		fmt.Sscanf(c, "c%d", &n)
		if n%2 == 0 {
			t.Errorf("closed connection %s is still stored", c)
		}
	}
}
