---
name: go-patterns
description: Effective Go patterns — idiomatic code, testing, benchmarks, project layout. Always use Go 1.21+ patterns.
---

# Go Patterns - Effective Go

## Current Versions

| Component | Version | Notes |
|---|---|---|
| Go | **1.21+** | Minimum for this skill. New features: `slog`, `slices`, `maps`, `cmp` packages. |
| Go modules | Latest | Use `go mod` for dependency management. |

## Project Layout

### Standard Go Project

```
myproject/
├── cmd/
│   └── myapp/
│       └── main.go          # Entry point
├── internal/
│   ├── service/
│   ├── repository/
│   └── model/
├── pkg/
│   └── publicapi/           # Public libraries
├── api/
│   ├── proto/               # Protobuf definitions
│   └── openapi/             # OpenAPI specs
├── go.mod
├── go.sum
├── Makefile
└── Dockerfile
```

### Microservice Layout

```
myservice/
├── cmd/
│   └── server/
│       └── main.go
├── internal/
│   ├── handler/
│   ├── service/
│   ├── repository/
│   └── domain/
├── pkg/
│   └── protocol/            # Shared protocol buffers
├── configs/
│   └── config.yaml
└── migrations/
```

## Effective Go Guidelines

### Accept Interfaces, Return Structs

```go
// Good - accept interface
func ProcessData(w io.Writer, data []byte) error {
    // ...
}

// Good - return struct
type Processor struct {
    config Config
}

func NewProcessor(cfg Config) *Processor {
    return &Processor{config: cfg}
}
```

### Error Handling

```go
// Always check errors
if err != nil {
    return fmt.Errorf("context: %w", err)
}

// Custom error types
type ValidationError struct {
    Field string
    Msg   string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("%s: %s", e.Field, e.Msg)
}

// Error wrapping
if err != nil {
    return &ValidationError{Field: "email", Msg: "invalid"}
}
```

### Context Propagation

```go
// All public APIs accept context
func (s *Service) DoWork(ctx context.Context, req Request) (Response, error) {
    // Pass context to all downstream calls
    result, err := s.repo.Query(ctx, req.ID)
    if err != nil {
        return Response{}, fmt.Errorf("query failed: %w", err)
    }
    return Response{Data: result}, nil
}
```

## Testing Patterns

### Table-Driven Tests

```go
func TestParse(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    Result
        wantErr bool
        errMsg  string
    }{
        {
            name:  "valid input",
            input: "valid",
            want:  Result{Value: "valid"},
        },
        {
            name:    "empty input",
            input:   "",
            wantErr: true,
            errMsg:  "input cannot be empty",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := Parse(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("Parse() error = %v, wantErr %v", err, tt.wantErr)
                return
            }
            if err != nil && tt.errMsg != "" && err.Error() != tt.errMsg {
                t.Errorf("Parse() error message = %v, want %v", err, tt.errMsg)
            }
            if !reflect.DeepEqual(got, tt.want) {
                t.Errorf("Parse() = %v, want %v", got, tt.want)
            }
        })
    }
}
```

### Test Helpers

```go
// setup_test.go
func setupTest(t *testing.T) *Service {
    t.Helper()
    return NewService(&testRepository{})
}

// teardown with cleanup
func withTestServer(t *testing.T, handler http.Handler) *httptest.Server {
    t.Helper()
    srv := httptest.NewServer(handler)
    t.Cleanup(func() { srv.Close() })
    return srv
}
```

### Golden Files

```go
func TestRender(t *testing.T) {
    got := renderTemplate(input)

    golden := filepath.Join("testdata", t.Name()+".golden")
    if *updateGolden {
        os.WriteFile(golden, []byte(got), 0644)
        return
    }

    want, _ := os.ReadFile(golden)
    if diff := cmp.Diff(want, got); diff != "" {
        t.Errorf("render mismatch (-want +got):\n%s", diff)
    }
}
```

## Benchmarking

```go
func BenchmarkProcess(b *testing.B) {
    data := generateTestData(1000)

    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        Process(data)
    }
}

// Parallel benchmark
func BenchmarkParallel(b *testing.B) {
    b.RunParallel(func(pb *testing.PB) {
        for pb.Next() {
            Process(data)
        }
    })
}
```

## Makefile Conventions

```makefile
.PHONY: test build clean lint run

# Build
build:
    go build -o bin/myapp ./cmd/myapp

# Run tests
test:
    go test -v -race ./...

# Run tests with coverage
test-coverage:
    go test -coverprofile=coverage.out ./...
    go tool cover -html=coverage.out

# Lint
lint:
    go vet ./...
    staticcheck ./...
    golangci-lint run

# Format
fmt:
    gofmt -w .

# Run
run:
    go run ./cmd/myapp

# Clean
clean:
    rm -rf bin/

# Install tools
tools:
    go install golang.org/x/tools/cmd/...@latest
    go install honnef.co/go/tools/cmd/staticcheck@latest
```

## Configuration Management

### Functional Options Pattern

```go
type Server struct {
    host     string
    port     int
    logger   *slog.Logger
    shutdownTimeout time.Duration
}

type Option func(*Server)

func WithHost(host string) Option {
    return func(s *Server) { s.host = host }
}

func WithPort(port int) Option {
    return func(s *Server) { s.port = port }
}

func WithLogger(logger *slog.Logger) Option {
    return func(s *Server) { s.logger = logger }
}

func WithShutdownTimeout(d time.Duration) Option {
    return func(s *Server) { s.shutdownTimeout = d }
}

func NewServer(opts ...Option) *Server {
    s := &Server{
        host:     "0.0.0.0",
        port:     8080,
        logger:   slog.Default(),
        shutdownTimeout: 30 * time.Second,
    }
    for _, opt := range opts {
        opt(s)
    }
    return s
}

// Usage
srv := NewServer(
    WithHost("localhost"),
    WithPort(9090),
    WithLogger(slog.New(os.Stdout)),
)
```

### Environment Variables

```go
import "github.com/sethvargo/go-envconfig"

type Config struct {
    DatabaseURL string `env:"DATABASE_URL,required"`
    Port        int    `env:"PORT,default=8080"`
    Debug       bool   `env:"DEBUG,default=false"`
}

func LoadConfig(ctx context.Context) (*Config, error) {
    var cfg Config
    if err := envconfig.Process(ctx, &cfg); err != nil {
        return nil, err
    }
    return &cfg, nil
}
```

## Structured Logging with slog

```go
import "log/slog"

// Structured logging
slog.Info("user logged in",
    "user_id", userID,
    "ip", req.RemoteAddr,
    "user_agent", req.UserAgent(),
)

// Error logging with context
slog.Error("failed to process request",
    "error", err,
    "request_id", reqID,
    "path", req.URL.Path,
)

// Debug levels
slog.Debug("processing item", "item_id", id)
slog.Warn("rate limit approaching", "current", rate, "limit", max)
```

## Dependency Injection

### Interface-based DI

```go
// Define interface
type Repository interface {
    Get(ctx context.Context, id string) (Item, error)
    Save(ctx context.Context, item Item) error
}

// Service depends on interface
type Service struct {
    repo Repository
    log  *slog.Logger
}

func NewService(repo Repository, log *slog.Logger) *Service {
    return &Service{repo: repo, log: log}
}

// Concrete implementation
type MemoryRepository struct {
    mu   sync.RWMutex
    data map[string]Item
}

func (r *MemoryRepository) Get(ctx context.Context, id string) (Item, error) {
    r.mu.RLock()
    defer r.mu.RUnlock()
    item, ok := r.data[id]
    if !ok {
        return Item{}, ErrNotFound
    }
    return item, nil
}
```

## Performance Tips

```go
// Pre-allocate slices when size is known
items := make([]Item, 0, expectedSize)

// Use strings.Builder for concatenation
var b strings.Builder
b.Grow(len(s1) + len(s2))
b.WriteString(s1)
b.WriteString(s2)

// Reuse buffers with sync.Pool
var bufferPool = sync.Pool{
    New: func() interface{} {
        return new(bytes.Buffer)
    },
}

func process(data []byte) {
    buf := bufferPool.Get().(*bytes.Buffer)
    defer func() {
        buf.Reset()
        bufferPool.Put(buf)
    }()
    // ... use buf
}

// Zero-copy techniques
// Use []byte instead of string for binary data
// Use unsafe.Slice for FFI (with caution)
```

## Build Tags

```go
//go:build !windows
// +build !windows

package main

import "syscall"

func getSignal() <-chan os.Signal {
    return syscallOnly
}
```

```go
//go:build cgo
// +build cgo

package main

/*
#include <stdio.h>
*/
import "C"

func printC() {
    C.puts(C.CString("Hello from C"))
}
```

## Go Module Management

```bash
# Initialize module
go mod init github.com/user/project

# Add dependency
go get github.com/pkg/errors

# Upgrade all
go get -u ./...

# Tidy dependencies
go mod tidy

# Verify dependencies
go mod verify

# Work with workspace
go work init
go work use ./module1 ./module2
```

## Docker Multi-stage Build

```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o main ./cmd/server

# Runtime stage
FROM alpine:latest
COPY --from=builder /app/main /usr/local/bin/server
EXPOSE 8080
CMD ["server"]
```
