package minigame

import (
	"context"
	"testing"
	"time"
)

func TestPackageReviewExecutorBoundsAndDeduplicatesWork(t *testing.T) {
	executor := newPackageReviewExecutor(1, 1)
	release := make(chan struct{})
	started := make(chan struct{})
	if !executor.Submit(context.Background(), "running", func() {
		close(started)
		<-release
	}) {
		t.Fatal("first task was not accepted")
	}
	<-started
	if !executor.TrySubmit("queued", func() {}) {
		t.Fatal("queued task was not accepted")
	}
	if !executor.TrySubmit("queued", func() {}) {
		t.Fatal("duplicate task should be treated as already scheduled")
	}
	if executor.TrySubmit("overflow", func() {}) {
		t.Fatal("executor accepted work beyond its bounded queue")
	}

	close(release)
	done := make(chan struct{})
	go func() {
		executor.Close()
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("executor did not drain")
	}
}
