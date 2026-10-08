package watchconnectedparticipants

import "sync"

// Notifier carries only invalidation hints. Each watcher loads its own
// server-authorized roster, so notification fanout cannot reveal room data.
type Notifier struct {
	mu         sync.Mutex
	watchers   map[chan struct{}]struct{}
	invalidate func()
}

func NewNotifier(invalidators ...func()) *Notifier {
	n := &Notifier{watchers: make(map[chan struct{}]struct{})}
	if len(invalidators) > 0 {
		n.invalidate = invalidators[0]
	}
	return n
}

func (notifier *Notifier) Subscribe() (<-chan struct{}, func()) {
	changes := make(chan struct{}, 1)
	notifier.mu.Lock()
	notifier.watchers[changes] = struct{}{}
	notifier.mu.Unlock()
	return changes, func() {
		notifier.mu.Lock()
		delete(notifier.watchers, changes)
		notifier.mu.Unlock()
	}
}

func (notifier *Notifier) Notify() {
	if notifier.invalidate != nil {
		notifier.invalidate()
	}
	notifier.mu.Lock()
	defer notifier.mu.Unlock()
	for watcher := range notifier.watchers {
		select {
		case watcher <- struct{}{}:
		default:
		}
	}
}
