package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"sync"
	"time"
)

const defaultTimeout = 120 * time.Second

type pending struct {
	meta  Request
	reply chan Reply // capacity 1; written exactly once
}

// Server holds the in-memory pending-request map and the set of active
// event subscribers. All public methods are safe for concurrent use.
type Server struct {
	instance string
	mu       sync.Mutex
	pending  map[string]*pending
	subs     map[*subscriber]struct{}
}

// subscriber is a subscriber's wire-bound event channel. The handler
// goroutine reads from ch and writes JSON lines to the connection;
// broadcast sends to ch with a non-blocking select so a slow subscriber
// can't stall the server.
type subscriber struct {
	ch chan any // any of: Snapshot, Added, Removed
}

func NewServer(instance string) *Server {
	return &Server{
		instance: instance,
		pending:  make(map[string]*pending),
		subs:     make(map[*subscriber]struct{}),
	}
}

// register creates a pending entry, broadcasts an "added" event, and returns
// the request ID plus the reply channel. Caller waits on the channel and
// calls unregister when done (which broadcasts "removed").
func (s *Server) register(req Request) (string, *pending) {
	id := newID()
	p := &pending{meta: req, reply: make(chan Reply, 1)}
	s.mu.Lock()
	s.pending[id] = p
	s.mu.Unlock()
	s.broadcast(Added{
		Op:       "added",
		Instance: s.instance,
		Request:  pendingEntryOf(id, req),
	})
	return id, p
}

func (s *Server) unregister(id string) {
	s.mu.Lock()
	_, existed := s.pending[id]
	delete(s.pending, id)
	s.mu.Unlock()
	if existed {
		s.broadcast(Removed{Op: "removed", Instance: s.instance, RequestID: id})
	}
}

func pendingEntryOf(id string, r Request) PendingEntry {
	return PendingEntry{
		RequestID:   id,
		Skill:       r.Skill,
		Profile:     r.Profile,
		Field:       r.Field,
		Description: r.Description,
		Secret:      r.Secret,
	}
}

// list returns a snapshot of all pending requests. Order is unspecified.
func (s *Server) list() []PendingEntry {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.snapshotLocked()
}

// snapshotLocked builds a PendingEntry slice. Must be called with s.mu held.
func (s *Server) snapshotLocked() []PendingEntry {
	out := make([]PendingEntry, 0, len(s.pending))
	for id, p := range s.pending {
		out = append(out, pendingEntryOf(id, p.meta))
	}
	return out
}

// addSubscriber registers a new event channel and returns it along with the
// initial snapshot. The snapshot and the registration happen under the same
// lock so a subscriber never misses an event between snapshot and stream.
func (s *Server) addSubscriber() (*subscriber, Snapshot) {
	sub := &subscriber{ch: make(chan any, 32)}
	s.mu.Lock()
	s.subs[sub] = struct{}{}
	snap := Snapshot{
		Op:       "snapshot",
		Instance: s.instance,
		Requests: s.snapshotLocked(),
	}
	s.mu.Unlock()
	return sub, snap
}

func (s *Server) removeSubscriber(sub *subscriber) {
	s.mu.Lock()
	if _, ok := s.subs[sub]; ok {
		delete(s.subs, sub)
		close(sub.ch)
	}
	s.mu.Unlock()
}

// broadcast sends ev to every subscriber. Slow subscribers (whose channel is
// full) miss the event rather than blocking the server. The plugin can
// reconnect to get a fresh snapshot if it suspects drift.
func (s *Server) broadcast(ev any) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for sub := range s.subs {
		select {
		case sub.ch <- ev:
		default:
			// drop
		}
	}
}

// submit looks up the pending request and sends the value to its reply
// channel. Returns an error if the request_id is unknown or the channel
// has already been written.
func (s *Server) submit(id, value string) error {
	s.mu.Lock()
	p, ok := s.pending[id]
	s.mu.Unlock()
	if !ok {
		return errors.New("unknown request_id")
	}
	select {
	case p.reply <- Reply{Op: "submitted", Value: value}:
		return nil
	default:
		return errors.New("request already completed")
	}
}

// cancel signals dismissal to the waiting CLI.
func (s *Server) cancel(id string) error {
	s.mu.Lock()
	p, ok := s.pending[id]
	s.mu.Unlock()
	if !ok {
		return errors.New("unknown request_id")
	}
	select {
	case p.reply <- Reply{Op: "cancelled"}:
		return nil
	default:
		return errors.New("request already completed")
	}
}

// waitReply blocks until the request receives a Reply, the timeout fires,
// or the CLI's context is cancelled (peer disconnect).
func (p *pending) waitReply(ctx context.Context, timeoutSecs int) Reply {
	timeout := defaultTimeout
	if timeoutSecs > 0 {
		timeout = time.Duration(timeoutSecs) * time.Second
	}
	t := time.NewTimer(timeout)
	defer t.Stop()
	select {
	case rep := <-p.reply:
		return rep
	case <-t.C:
		return Reply{Op: "timeout"}
	case <-ctx.Done():
		// CLI disconnected. The reply we return won't reach anyone;
		// it's purely a sentinel for the handler to clean up.
		return Reply{Op: "cancelled"}
	}
}

func newID() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	return fmt.Sprintf(
		"%s-%s-%s-%s-%s",
		hex.EncodeToString(b[0:4]),
		hex.EncodeToString(b[4:6]),
		hex.EncodeToString(b[6:8]),
		hex.EncodeToString(b[8:10]),
		hex.EncodeToString(b[10:16]),
	)
}
