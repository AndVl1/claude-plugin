---
name: go-concurrency
description: Go concurrency mastery — goroutines, channels, context, sync primitives, patterns, performance.
---

# Go Concurrency Patterns

## Goroutine Lifecycle

### Basic Goroutine

```go
// Simple goroutine
go func() {
    fmt.Println("running in background")
}()

// With parameters
go func(msg string) {
    fmt.Println(msg)
}("hello")

// Anonymous goroutine with defer
go func() {
    defer cleanup()
    doWork()
}()
```

### Goroutine Leaks - How to Avoid

```go
// ❌ BAD - goroutine leak
func process() {
    ch := make(chan int)
    go func() {
        for val := range ch {  // Never exits if channel closes
            fmt.Println(val)
        }
    }()
    // If we return here, goroutine leaks forever
}

// ✅ GOOD - explicit cancellation
func process(ctx context.Context) error {
    ch := make(chan int)
    done := make(chan struct{})

    go func() {
        defer close(done)
        for {
            select {
            case val, ok := <-ch:
                if !ok {
                    return
                }
                fmt.Println(val)
            case <-ctx.Done():
                return
            }
        }
    }()

    // ... use ch
    close(ch)
    <-done
    return nil
}
```

## Channel Patterns

### Buffered vs Unbuffered

```go
// Unbuffered - synchronous
unbuf := make(chan int)
// Sender blocks until receiver ready

// Buffered - async capacity
buf := make(chan int, 100)
// Sender blocks only when buffer full
```

### Fan-in Pattern

```go
// Merge multiple channels into one
func fanIn[T any](ctx context.Context, channels ...<-chan T) <-chan T {
    out := make(chan T)

    var wg sync.WaitGroup
    for _, ch := range channels {
        wg.Add(1)
        go func(c <-chan T) {
            defer wg.Done()
            for {
                select {
                case v, ok := <-c:
                    if !ok {
                        return
                    }
                    select {
                    case out <- v:
                    case <-ctx.Done():
                        return
                    }
                case <-ctx.Done():
                    return
                }
            }
        }(ch)
    }

    go func() {
        wg.Wait()
        close(out)
    }()

    return out
}
```

### Fan-out Pattern

```go
// Distribute work to multiple workers
func fanOut[T any, R any](ctx context.Context, workers int, input <-chan T, work func(T) R) <-chan R {
    out := make(chan R)

    var wg sync.WaitGroup
    for i := 0; i < workers; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for item := range input {
                result := work(item)
                select {
                case out <- result:
                case <-ctx.Done():
                    return
                }
            }
        }()
    }

    go func() {
        wg.Wait()
        close(out)
    }()

    return out
}
```

### Pipeline Pattern

```go
// Stage 1: Generate
func generate(ctx context.Context, nums ...int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for _, n := range nums {
            select {
            case out <- n:
            case <-ctx.Done():
                return
            }
        }
    }()
    return out
}

// Stage 2: Transform
func square(ctx context.Context, in <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for n := range in {
            result := n * n
            select {
            case out <- result:
            case <-ctx.Done():
                return
            }
        }
    }()
    return out
}

// Stage 3: Consume
func consume(ctx context.Context, in <-chan int) []int {
    var results []int
    for n := range in {
        results = append(results, n)
    }
    return results
}

// Pipeline
func pipeline(ctx context.Context) []int {
    nums := generate(ctx, 1, 2, 3, 4, 5)
    squared := square(ctx, nums)
    return consume(ctx, squared)
}
```

## Worker Pool Pattern

```go
type Job struct {
    ID   int
    Data string
}

type Result struct {
    JobID int
    Value string
    Err   error
}

func workerPool(ctx context.Context, jobs <-chan Job, workers int) <-chan Result {
    results := make(chan Result)

    var wg sync.WaitGroup
    for i := 0; i < workers; i++ {
        wg.Add(1)
        go func(workerID int) {
            defer wg.Done()
            for job := range jobs {
                result := processJob(job)
                select {
                case results <- result:
                case <-ctx.Done():
                    return
                }
            }
        }(i)
    }

    go func() {
        wg.Wait()
        close(results)
    }()

    return results
}

func processJob(job Job) Result {
    // Simulate work
    time.Sleep(100 * time.Millisecond)
    return Result{
        JobID: job.ID,
        Value: "processed: " + job.Data,
    }
}

// Usage
func main() {
    ctx := context.Background()
    jobs := make(chan Job, 100)

    // Feed jobs
    go func() {
        for i := 0; i < 50; i++ {
            jobs <- Job{ID: i, Data: fmt.Sprintf("item-%d", i)}
        }
        close(jobs)
    }()

    // Start workers
    results := workerPool(ctx, jobs, 5)

    // Collect results
    for result := range results {
        fmt.Printf("Job %d: %s\n", result.JobID, result.Value)
    }
}
```

## Context for Cancellation and Deadlines

### Context Hierarchy

```go
// Create context with timeout
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()

// Create derived context with deadline
d := time.Now().Add(10 * time.Second)
ctx, cancel := context.WithDeadline(context.Background(), d)
defer cancel()

// Create cancelable context
ctx, cancel := context.WithCancel(context.Background())
defer cancel()  // Always call cancel
```

### Propagation Pattern

```go
func (s *Service) ProcessOrder(ctx context.Context, orderID string) error {
    // Pass context to all downstream calls
    order, err := s.repo.GetOrder(ctx, orderID)
    if err != nil {
        return fmt.Errorf("get order: %w", err)
    }

    // Create derived context with timeout for external call
    apiCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
    defer cancel()

    result, err := s.externalAPI.Validate(apiCtx, order)
    if err != nil {
        return fmt.Errorf("validate: %w", err)
    }

    return nil
}
```

### Graceful Shutdown Pattern

```go
type Server struct {
    http     *http.Server
    grpc     *grpc.Server
    shutdown chan struct{}
}

func (s *Server) Start(ctx context.Context) error {
    // Start servers
    go func() {
        if err := s.http.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Printf("HTTP server error: %v", err)
        }
    }()

    go func() {
        if err := s.grpc.Serve(s.lis); err != nil {
            log.Printf("gRPC server error: %v", err)
        }
    }()

    // Wait for shutdown signal
    <-ctx.Done()
    return s.shutdown()
}

func (s *Server) shutdown() error {
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    var wg sync.WaitGroup
    errs := make(chan error, 2)

    // Shutdown HTTP
    wg.Add(1)
    go func() {
        defer wg.Done()
        errs <- s.http.Shutdown(ctx)
    }()

    // Shutdown gRPC
    wg.Add(1)
    go func() {
        defer wg.Done()
        s.grpc.GracefulStop()
        errs <- nil
    }()

    wg.Wait()
    close(errs)

    for err := range errs {
        if err != nil {
            return err
        }
    }
    return nil
}
```

## Select for Multiplexing

```go
// Select pattern for multiple channels
func multiplex(ctx context.Context, ch1, ch2 <-chan int) {
    for {
        select {
        case v, ok := <-ch1:
            if !ok {
                fmt.Println("ch1 closed")
                return
            }
            fmt.Printf("ch1: %d\n", v)

        case v, ok := <-ch2:
            if !ok {
                fmt.Println("ch2 closed")
                return
            }
            fmt.Printf("ch2: %d\n", v)

        case <-ctx.Done():
            fmt.Println("context cancelled")
            return

        case <-time.After(100 * time.Millisecond):
            fmt.Println("timeout - no data")
        }
    }
}
```

## Synchronization Primitives

### Mutex for State Protection

```go
type SafeCounter struct {
    mu    sync.RWMutex
    value int
}

func (c *SafeCounter) Increment() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.value++
}

func (c *SafeCounter) Value() int {
    c.mu.RLock()
    defer c.mu.RUnlock()
    return c.value
}
```

### Once for Initialization

```go
var (
    instance *Database
    once     sync.Once
)

func GetDatabase() *Database {
    once.Do(func() {
        instance = &Database{conn: connect()}
    })
    return instance
}
```

### WaitGroup for Coordination

```go
func processItems(items []Item) {
    var wg sync.WaitGroup
    semaphore := make(chan struct{}, 10) // Limit concurrency

    for _, item := range items {
        wg.Add(1)
        go func(i Item) {
            defer wg.Done()
            semaphore <- struct{}{}        // Acquire
            defer func() { <-semaphore }() // Release
            process(i)
        }(item)
    }

    wg.Wait()
}
```

### Cond for Waiting on Conditions

```go
type Queue struct {
    mu     sync.Mutex
    cond   *sync.Cond
    items  []Item
}

func NewQueue() *Queue {
    q := &Queue{
        items: make([]Item, 0),
    }
    q.cond = sync.NewCond(&q.mu)
    return q
}

func (q *Queue) Push(item Item) {
    q.mu.Lock()
    defer q.mu.Unlock()
    q.items = append(q.items, item)
    q.cond.Signal() // Wake one waiter
}

func (q *Queue) Pop() Item {
    q.mu.Lock()
    defer q.mu.Unlock()

    for len(q.items) == 0 {
        q.cond.Wait() // Wait for signal
    }

    item := q.items[0]
    q.items = q.items[1:]
    return item
}
```

### Atomic for Simple Counters

```go
type Metrics struct {
    requests atomic.Int64
    errors   atomic.Int64
}

func (m *Metrics) RecordRequest() {
    m.requests.Add(1)
}

func (m *Metrics) RecordError() {
    m.errors.Add(1)
}

func (m *Metrics) GetStats() (int64, int64) {
    return m.requests.Load(), m.errors.Load()
}
```

## ErrorGroup Pattern

```go
import "golang.org/x/sync/errgroup"

func processItems(ctx context.Context, items []Item) error {
    g, gctx := errgroup.WithContext(ctx)

    results := make(chan Result, len(items))

    for _, item := range items {
        item := item // Capture loop variable
        g.Go(func() error {
            result, err := processItem(gctx, item)
            if err != nil {
                return err
            }
            results <- result
            return nil
        })
    }

    // Wait for all goroutines
    if err := g.Wait(); err != nil {
        return err
    }

    close(results)
    return nil
}
```

## Rate Limiting Pattern

```go
import "golang.org/x/time/rate"

type RateLimiter struct {
    limiter *rate.Limiter
}

func NewRateLimiter(rps int) *RateLimiter {
    return &RateLimiter{
        limiter: rate.NewLimiter(rate.Limit(rps), rps),
    }
}

func (rl *RateLimiter) Allow() bool {
    return rl.limiter.Allow()
}

func (rl *RateLimiter) Wait(ctx context.Context) error {
    return rl.limiter.Wait(ctx)
}

// Usage in middleware
func (rl *RateLimiter) Middleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        if !rl.Allow() {
            http.Error(w, "rate limit exceeded", http.StatusTooManyRequests)
            return
        }
        next.ServeHTTP(w, r)
    })
}
```

## Backpressure Handling

```go
// Producer-consumer with backpressure
func backpressureProducer(ctx context.Context, out chan<- Item, rate int) <-chan Item {
    results := make(chan Item)

    go func() {
        defer close(results)
        ticker := time.NewTicker(time.Second / time.Duration(rate))
        defer ticker.Stop()

        for {
            select {
            case <-ctx.Done():
                return
            case <-ticker.C:
                item := produce()
                select {
                case out <- item:
                case <-ctx.Done():
                    return
                }
            }
        }
    }()

    return results
}
```

## Detecting Race Conditions

```bash
# Run tests with race detector
go test -race ./...

# Build with race detector
go run -race main.go

# Common race patterns
# - Shared state without mutex
# - Publishing reference during initialization
# - Data races on sync.Pool
```

```go
// ❌ RACE - shared state
var counter int

func increment() {
    counter++  // Data race!
}

// ✅ SAFE - protected state
var (
    counter int
    mu      sync.Mutex
)

func increment() {
    mu.Lock()
    counter++
    mu.Unlock()
}
```

## Performance Considerations

```go
// Goroutine overhead is small but not zero
// ~2KB stack, grows as needed
// ~1.5µs to spawn

// Channel operations cost
// Buffered channel send: ~50ns
// Unbuffered channel send: ~90ns (requires context switch)

// Mutex vs Channel
// Use mutex for state protection
// Use channels for orchestration and communication
```

## Best Practices Summary

1. **Always cancel contexts** - Use `defer cancel()`
2. **Never block goroutines indefinitely** - Use context or timeouts
3. **Prefer channels over mutex for orchestration**
4. **Prefer mutex over channels for state protection**
5. **Limit concurrency with worker pools or semaphores**
6. **Always check for race conditions in tests**
7. **Use errgroup for coordinated goroutines**
8. **Close channels from the sender side only**
9. **Never close a channel from the receiver**
10. **Use select for multiplexing and timeouts**
