package admitconnection

import (
	"crypto/sha256"
	"sync"
	"testing"
)

func TestLimiterCapsDeploymentAccountAndSessionAndReleases(t *testing.T) {
	limiter, err := New(Config{GlobalLimit: 2, AccountLimit: 2, SessionLimit: 1})
	if err != nil {
		t.Fatal(err)
	}
	sessionA, sessionB := sha256.Sum256([]byte("A")), sha256.Sum256([]byte("B"))
	releaseA, ok := limiter.TryAcquire("account-1", sessionA)
	if !ok {
		t.Fatal("first connection rejected")
	}
	if _, ok := limiter.TryAcquire("account-1", sessionA); ok {
		t.Fatal("session limit exceeded")
	}
	releaseB, ok := limiter.TryAcquire("account-1", sessionB)
	if !ok {
		t.Fatal("account limit incorrectly applied to sibling session")
	}
	if _, ok := limiter.TryAcquire("account-2", sha256.Sum256([]byte("C"))); ok {
		t.Fatal("global limit exceeded")
	}
	releaseA()
	if _, ok := limiter.TryAcquire("account-1", sessionA); !ok {
		t.Fatal("released session slot remained occupied")
	}
	releaseB()
}

func TestLimiterConcurrentAcquisitionNeverExceedsGlobalLimit(t *testing.T) {
	limiter, err := New(Config{GlobalLimit: 3, AccountLimit: 8, SessionLimit: 8})
	if err != nil {
		t.Fatal(err)
	}
	var wait sync.WaitGroup
	var accepted int
	var mutex sync.Mutex
	var releases []func()
	for index := 0; index < 50; index++ {
		wait.Add(1)
		go func(index int) {
			defer wait.Done()
			if release, ok := limiter.TryAcquire("account", sha256.Sum256([]byte{byte(index)})); ok {
				mutex.Lock()
				accepted++
				releases = append(releases, release)
				mutex.Unlock()
			}
		}(index)
	}
	wait.Wait()
	if accepted != 3 {
		t.Fatalf("accepted %d connections, want global cap 3", accepted)
	}
	for _, release := range releases {
		release()
	}
}
