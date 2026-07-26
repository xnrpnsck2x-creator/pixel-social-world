package minigame

import (
	"context"
	"sync"
)

const defaultPackageReviewWorkers = 4
const defaultPackageReviewQueueSize = 128

type packageReviewTask struct {
	key string
	run func()
}

type packageReviewExecutor struct {
	tasks   chan packageReviewTask
	mu      sync.Mutex
	pending map[string]struct{}
	wg      sync.WaitGroup
}

func newPackageReviewExecutor(workers int, queueSize int) *packageReviewExecutor {
	if workers < 1 {
		workers = 1
	}
	if queueSize < 1 {
		queueSize = 1
	}
	executor := &packageReviewExecutor{
		tasks:   make(chan packageReviewTask, queueSize),
		pending: map[string]struct{}{},
	}
	executor.wg.Add(workers)
	for range workers {
		go executor.worker()
	}
	return executor
}

func (e *packageReviewExecutor) Submit(
	ctx context.Context,
	key string,
	task func(),
) bool {
	if key == "" || task == nil {
		return false
	}
	e.mu.Lock()
	if _, exists := e.pending[key]; exists {
		e.mu.Unlock()
		return true
	}
	e.pending[key] = struct{}{}
	e.mu.Unlock()

	select {
	case e.tasks <- packageReviewTask{key: key, run: task}:
		return true
	case <-ctx.Done():
		e.removePending(key)
		return false
	}
}

func (e *packageReviewExecutor) TrySubmit(key string, task func()) bool {
	if key == "" || task == nil {
		return false
	}
	e.mu.Lock()
	if _, exists := e.pending[key]; exists {
		e.mu.Unlock()
		return true
	}
	e.pending[key] = struct{}{}
	e.mu.Unlock()

	select {
	case e.tasks <- packageReviewTask{key: key, run: task}:
		return true
	default:
		e.removePending(key)
		return false
	}
}

func (e *packageReviewExecutor) Close() {
	close(e.tasks)
	e.wg.Wait()
}

func (e *packageReviewExecutor) worker() {
	defer e.wg.Done()
	for task := range e.tasks {
		func() {
			defer e.removePending(task.key)
			task.run()
		}()
	}
}

func (e *packageReviewExecutor) removePending(key string) {
	e.mu.Lock()
	delete(e.pending, key)
	e.mu.Unlock()
}

var creatorPackageReviewExecutor = newPackageReviewExecutor(
	defaultPackageReviewWorkers,
	defaultPackageReviewQueueSize,
)
