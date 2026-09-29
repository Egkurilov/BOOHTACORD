package watchconnectedparticipants

import "testing"

func TestNotifierWakesEveryWatcherAndRemovesClosedWatchers(t *testing.T) {
	notifier := NewNotifier()
	first, closeFirst := notifier.Subscribe()
	second, closeSecond := notifier.Subscribe()
	notifier.Notify()
	for _, watcher := range []<-chan struct{}{first, second} {
		select {
		case <-watcher:
		default:
			t.Fatal("watcher missed roster change")
		}
	}
	closeFirst()
	closeSecond()
	notifier.Notify()
}
