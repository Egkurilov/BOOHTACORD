package watchconnectedparticipants

import "sync"

// Notifier carries only invalidation hints. Each watcher loads its own
// server-authorized roster, so notification fanout cannot reveal room data.
type Notifier struct {
	mu       sync.Mutex
	watchers map[chan struct{}]struct{}
}

func NewNotifier() *Notifier { return &Notifier{watchers: make(map[chan struct{}]struct{})} }

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
	notifier.mu.Lock()
	defer notifier.mu.Unlock()
	for watcher := range notifier.watchers {
		select {
		case watcher <- struct{}{}:
		default:
		}
	}
}
