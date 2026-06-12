---
name: go-microservices
description: Go microservices — gRPC, REST, cloud-native patterns, service discovery, circuit breakers, observability, health checks, graceful shutdown.
---

# Go Microservices Patterns

## gRPC Service Implementation

### Protocol Definition

```protobuf
// proto/service.proto
syntax = "proto3";

package myservice.v1;

option go_package = "github.com/user/project/proto";

service MyService {
  rpc Create(CreateRequest) returns (CreateResponse);
  rpc Get(GetRequest) returns (GetResponse);
  rpc List(ListRequest) returns (stream ListResponse);
}

message CreateRequest {
  string name = 1;
  string description = 2;
}

message CreateResponse {
  string id = 1;
  int64 created_at = 2;
}

message GetRequest {
  string id = 1;
}

message GetResponse {
  string id = 1;
  string name = 2;
  string description = 3;
}

message ListRequest {
  int32 page_size = 1;
  string page_token = 2;
}

message ListResponse {
  repeated Item items = 1;
  string next_page_token = 2;
}
```

### Server Implementation

```go
package server

import (
   "context"
    "log/slog"

    "google.golang.org/grpc"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
)

type server struct {
    pb.UnimplementedMyServiceServer
    svc  Service
    log  *slog.Logger
}

func NewServer(svc Service, log *slog.Logger) *grpc.Server {
    s := grpc.NewServer(
        grpc.ChainUnaryInterceptor(
            loggingInterceptor(log),
            recoveryInterceptor(),
            validationInterceptor(),
        ),
    )

    pb.RegisterMyServiceServer(s, &server{
        svc: svc,
        log: log,
    })

    return s
}

func (s *server) Create(ctx context.Context, req *pb.CreateRequest) (*pb.CreateResponse, error) {
    if err := validateCreateRequest(req); err != nil {
        return nil, status.Error(codes.InvalidArgument, err.Error())
    }

    result, err := s.svc.Create(ctx, CreateRequest{
        Name:        req.Name,
        Description: req.Description,
    })
    if err != nil {
        return nil, handleError(err)
    }

    return &pb.CreateResponse{
        Id:        result.ID,
        CreatedAt: result.CreatedAt,
    }, nil
}

func (s *server) Get(ctx context.Context, req *pb.GetRequest) (*pb.GetResponse, error) {
    result, err := s.svc.Get(ctx, req.Id)
    if err != nil {
        if errors.Is(err, ErrNotFound) {
            return nil, status.Error(codes.NotFound, "item not found")
        }
        return nil, status.Error(codes.Internal, err.Error())
    }

    return toProtoResponse(result), nil
}

func (s *server) List(req *pb.ListRequest, stream pb.MyService_ListServer) error {
    for {
        resp, err := s.svc.List(stream.Context(), ListRequest{
            PageSize:  req.PageSize,
            PageToken: req.PageToken,
        })
        if err != nil {
            return err
        }

        for _, item := range resp.Items {
            if err := stream.Send(&pb.ListResponse{Items: item}); err != nil {
                return err
            }
        }

        if resp.NextPageToken == "" {
            return nil
        }
        req.PageToken = resp.NextPageToken
    }
}
```

### Unary Interceptors

```go
func loggingInterceptor(log *slog.Logger) grpc.UnaryServerInterceptor {
    return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
        start := time.Now()

        resp, err := handler(ctx, req)

        duration := time.Since(start)
        log.Info("gRPC request",
            "method", info.FullMethod,
            "duration", duration,
            "error", err,
        )

        return resp, err
    }
}

func recoveryInterceptor() grpc.UnaryServerInterceptor {
    return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (resp interface{}, err error) {
        defer func() {
            if r := recover(); r != nil {
                err = status.Error(codes.Internal, "internal server error")
                slog.Error("panic recovered", "panic", r)
            }
        }()
        return handler(ctx, req)
    }
}
```

## REST API with Middleware

### Chi Router Pattern

```go
package api

import (
    "github.com/go-chi/chi/v5"
    "github.com/go-chi/chi/v5/middleware"
    "github.com/go-chi/cors"
)

type Server struct {
    router *chi.Mux
    svc    Service
    log    *slog.Logger
}

func NewServer(svc Service, log *slog.Logger) *Server {
    r := chi.NewRouter()

    // Middleware
    r.Use(middleware.RequestID)
    r.Use(middleware.RealIP)
    r.Use(middleware.Logger)
    r.Use(middleware.Recoverer)
    r.Use(middleware.Timeout(60 * time.Second))
    r.Use(middleware.SetHeader("Content-Type", "application/json"))

    // CORS
    r.Use(cors.Handler(cors.Options{
        AllowedOrigins:   []string{"https://*", "http://*"},
        AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
        AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
        ExposedHeaders:   []string{"Link"},
        AllowCredentials: true,
        MaxAge:           300,
    }))

    s := &Server{router: r, svc: svc, log: log}

    // Routes
    r.Route("/api/v1", func(r chi.Router) {
        r.Post("/items", s.createItem)
        r.Get("/items/{id}", s.getItem)
        r.Get("/items", s.listItems)
        r.Put("/items/{id}", s.updateItem)
        r.Delete("/items/{id}", s.deleteItem)
    })

    return s
}

func (s *Server) createItem(w http.ResponseWriter, r *http.Request) {
    var req CreateRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid request", http.StatusBadRequest)
        return
    }

    result, err := s.svc.Create(r.Context(), req)
    if err != nil {
        handleError(w, err)
        return
    }

    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(result)
}

func handleError(w http.ResponseWriter, err error) {
    switch {
    case errors.Is(err, ErrNotFound):
        http.Error(w, "not found", http.StatusNotFound)
    case errors.Is(err, ErrValidation):
        http.Error(w, err.Error(), http.StatusBadRequest)
    default:
        http.Error(w, "internal error", http.StatusInternalServerError)
    }
}
```

## Service Discovery Integration

### Consul Registration

```go
package discovery

import (
    "github.com/hashicorp/consul/api"
)

type Registrar struct {
    client *api.Client
    id     string
}

func NewRegistrar(consulAddr, serviceName, serviceID string) (*Registrar, error) {
    config := api.DefaultConfig()
    config.Address = consulAddr

    client, err := api.NewClient(config)
    if err != nil {
        return nil, err
    }

    return &Registrar{
        client: client,
        id:     serviceID,
    }, nil
}

func (r *Registrar) Register(addr string, port int) error {
    registration := &api.AgentServiceRegistration{
        ID:      r.id,
        Name:    "my-service",
        Port:    port,
        Address: addr,
        Check: &api.AgentServiceCheck{
            GRPC:     fmt.Sprintf("%s:%d", addr, port),
            Interval: "10s",
            Timeout:  "3s",
        },
        Tags: []string{"go", "microservice"},
    }

    return r.client.Agent().ServiceRegister(registration)
}

func (r *Registrar) Deregister() error {
    return r.client.Agent().ServiceDeregister(r.id)
}
```

## Circuit Breaker Pattern

```go
package circuitbreaker

import (
    "github.com/sony/gobreaker"
)

type CircuitBreaker struct {
    breaker *gobreaker.CircuitBreaker
}

func NewCircuitBreaker() *CircuitBreaker {
    settings := gobreaker.Settings{
        Name:        "my-service",
        MaxRequests: 100,
        Interval:    10 * time.Second,
        Timeout:     30 * time.Second,
        ReadyToTrip: func(counts gobreaker.Counts) bool {
            return counts.ConsecutiveFailures > 5
        },
        OnStateChange: func(name string, from, to gobreaker.State) {
            slog.Info("circuit breaker state changed",
                "name", name,
                "from", from,
                "to", to,
            )
        },
    }

    return &CircuitBreaker{
        breaker: gobreaker.NewCircuitBreaker(settings),
    }
}

func (cb *CircuitBreaker) Execute(fn func() (interface{}, error)) (interface{}, error) {
    return cb.breaker.Execute(fn)
}

// Usage in service
func (s *Service) CallExternal(ctx context.Context, req Request) (Response, error) {
    result, err := s.cb.Execute(func() (interface{}, error) {
        return s.externalAPI.Call(ctx, req)
    })

    if err != nil {
        return Response{}, fmt.Errorf("circuit breaker: %w", err)
    }

    return result.(Response), nil
}
```

## Health Checks

```go
package health

import (
    "google.golang.org/grpc/health"
    "google.golang.org/grpc/health/grpc_health_v1"
)

type Checker struct {
    healthServer *health.Server
    db           *sql.DB
    redis        *redis.Client
}

func NewChecker(db *sql.DB, redis *redis.Client) *Checker {
    hc := health.NewServer()
    return &Checker{
        healthServer: hc,
        db:          db,
        redis:       redis,
    }
}

func (c *Checker) Start() {
    c.healthServer.SetServingStatus("", grpc_health_v1.HealthCheckResponse_SERVING)

    // Start background checks
    go c.checkDatabase()
    go c.checkRedis()
}

func (c *Checker) checkDatabase() {
    ticker := time.NewTicker(30 * time.Second)
    defer ticker.Stop()

    for range ticker.C {
        if err := c.db.Ping(); err != nil {
            c.healthServer.SetServingStatus("db", grpc_health_v1.HealthCheckResponse_NOT_SERVING)
        } else {
            c.healthServer.SetServingStatus("db", grpc_health_v1.HealthCheckResponse_SERVING)
        }
    }
}

func (c *Checker) checkRedis() {
    ticker := time.NewTicker(30 * time.Second)
    defer ticker.Stop()

    for range ticker.C {
        if err := c.redis.Ping(context.Background()).Err(); err != nil {
            c.healthServer.SetServingStatus("redis", grpc_health_v1.HealthCheckResponse_NOT_SERVING)
        } else {
            c.healthServer.SetServingStatus("redis", grpc_health_v1.HealthCheckResponse_SERVING)
        }
    }
}
```

## Graceful Shutdown

```go
package server

import (
    "context"
    "net"
    "net/http"
    "time"

    "google.golang.org/grpc"
)

type Server struct {
    httpServer *http.Server
    grpcServer *grpc.Server
    log        *slog.Logger
}

func NewServer(httpAddr, grpcAddr string, handlers http.Handler) *Server {
    return &Server{
        httpServer: &http.Server{
            Addr:           httpAddr,
            Handler:        handlers,
            ReadTimeout:    15 * time.Second,
            WriteTimeout:   15 * time.Second,
            IdleTimeout:    60 * time.Second,
            MaxHeaderBytes: 1 << 20, // 1MB
        },
        grpcServer: grpc.NewServer(),
        log:        slog.Default(),
    }
}

func (s *Server) Start() error {
    // Start HTTP
    go func() {
        s.log.Info("starting HTTP server", "addr", s.httpServer.Addr)
        if err := s.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            s.log.Error("HTTP server error", "error", err)
        }
    }()

    // Start gRPC
    lis, err := net.Listen("tcp", s.grpcServerAddr)
    if err != nil {
        return err
    }

    go func() {
        s.log.Info("starting gRPC server", "addr", s.grpcServerAddr)
        if err := s.grpcServer.Serve(lis); err != nil {
            s.log.Error("gRPC server error", "error", err)
        }
    }()

    return nil
}

func (s *Server) Shutdown(ctx context.Context) error {
    var wg sync.WaitGroup
    errs := make(chan error, 2)

    // Shutdown HTTP
    wg.Add(1)
    go func() {
        defer wg.Done()
        errs <- s.httpServer.Shutdown(ctx)
    }()

    // Shutdown gRPC
    wg.Add(1)
    go func() {
        defer wg.Done()
        s.grpcServer.GracefulStop()
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

// Main with signal handling
func main() {
    srv := NewServer(":8080", ":9090", handlers)

    if err := srv.Start(); err != nil {
        log.Fatal(err)
    }

    // Wait for interrupt signal
    sigChan := make(chan os.Signal, 1)
    signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
    <-sigChan

    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        log.Fatal(err)
    }

    log.Println("server shutdown complete")
}
```

## Configuration Management

### Environment-based Configuration

```go
package config

import (
    "github.com/kelseyhightower/envconfig"
)

type Config struct {
    // Server
    HTTPPort int    `env:"HTTP_PORT" envDefault:"8080"`
    GRPCPort int    `env:"GRPC_PORT" envDefault:"9090"`

    // Database
    DatabaseURL string `env:"DATABASE_URL" envDefault:"postgres://localhost:5432/mydb"`
    DBPoolSize  int    `env:"DB_POOL_SIZE" envDefault:"10"`

    // Redis
    RedisURL string `env:"REDIS_URL" envDefault:"redis://localhost:6379"`

    // Service Discovery
    ConsulAddr string `env:"CONSUL_ADDR" envDefault:"localhost:8500"`

    // Observability
    LogLevel      string `env:"LOG_LEVEL" envDefault:"info"`
    MetricsPort   int    `env:"METRICS_PORT" envDefault:"9091"`
    TracingAddr   string `env:"TRACING_ADDR" envDefault:"localhost:4318"`
    ServiceName   string `env:"SERVICE_NAME" envDefault:"my-service"`
    ServiceVersion string `env:"SERVICE_VERSION" envDefault:"1.0.0"`
}

func Load() (*Config, error) {
    var cfg Config
    if err := envconfig.Process("", &cfg); err != nil {
        return nil, err
    }
    return &cfg, nil
}
```

## Observability Setup

### Structured Logging

```go
package logging

import (
    "log/slog"
    "os"
)

func NewLogger(level string, service, version string) *slog.Logger {
    var logLevel slog.Level
    switch level {
    case "debug":
        logLevel = slog.LevelDebug
    case "info":
        logLevel = slog.LevelInfo
    case "warn":
        logLevel = slog.LevelWarn
    case "error":
        logLevel = slog.LevelError
    default:
        logLevel = slog.LevelInfo
    }

    opts := &slog.HandlerOptions{
        Level: logLevel,
    }

    handler := slog.NewJSONHandler(os.Stdout, opts)
    logger := slog.New(handler)

    return logger.With(
        "service", service,
        "version", version,
    )
}
```

### Prometheus Metrics

```go
package metrics

import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    requestsTotal = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "my_service_requests_total",
            Help: "Total number of requests",
        },
        []string{"method", "endpoint", "status"},
    )

    requestDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "my_service_request_duration_seconds",
            Help:    "Request duration in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "endpoint"},
    )

    activeConnections = promauto.NewGauge(
        prometheus.GaugeOpts{
            Name: "my_service_active_connections",
            Help: "Number of active connections",
        },
    )
)

func RecordRequest(method, endpoint, status string, duration float64) {
    requestsTotal.WithLabelValues(method, endpoint, status).Inc()
    requestDuration.WithLabelValues(method, endpoint).Observe(duration)
}

func IncrementConnections() {
    activeConnections.Inc()
}

func DecrementConnections() {
    activeConnections.Dec()
}
```

### Distributed Tracing with OpenTelemetry

```go
package tracing

import (
    "context"
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.4.0"
)

func InitTracer(ctx context.Context, addr, service, version string) (func(context.Context) error, error) {
    res, err := resource.New(ctx,
        resource.WithAttributes(
            semconv.ServiceNameKey.String(service),
            semconv.ServiceVersionKey.String(version),
        ),
    )
    if err != nil {
        return nil, err
    }

    exporter, err := otlptracegrpc.New(ctx,
        otlptracegrpc.WithInsecure(),
        otlptracegrpc.WithEndpoint(addr),
    )
    if err != nil {
        return nil, err
    }

    tp := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(exporter),
        sdktrace.WithResource(res),
        sdktrace.WithSampler(sdktrace.TraceIDRatioBased(1.0)),
    )

    otel.SetTracerProvider(tp)

    return tp.Shutdown, nil
}
```

## Middleware Chain for Observability

```go
package middleware

import (
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

func ObservabilityMiddleware(service, version string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            start := time.Now()

            // Wrap writer to capture status
            ww := &responseWriter{ResponseWriter: w}
            next.ServeHTTP(ww, r)

            // Record metrics
            duration := time.Since(start).Seconds()
            metrics.RecordRequest(
                r.Method,
                r.URL.Path,
                fmt.Sprintf("%d", ww.status),
                duration,
            )

            // Log request
            slog.Info("request",
                "method", r.Method,
                "path", r.URL.Path,
                "status", ww.status,
                "duration", duration,
                "user_agent", r.UserAgent(),
            )
        })
    }
}

type responseWriter struct {
    http.ResponseWriter
    status int
}

func (w *responseWriter) WriteHeader(status int) {
    w.status = status
    w.ResponseWriter.WriteHeader(status)
}

// Metrics endpoint
func MetricsHandler() http.Handler {
    return promhttp.Handler()
}
```

## Docker Compose for Development

```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8080:8080"
      - "9090:9090"
      - "9091:9091"
    environment:
      - DATABASE_URL=postgres://postgres:password@db:5432/mydb
      - REDIS_URL=redis://redis:6379
      - CONSUL_ADDR=consul:8500
      - TRACING_ADDR=jaeger:4317
    depends_on:
      - db
      - redis
      - consul
      - jaeger

  db:
    image: postgres:16
    environment:
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=mydb
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7
    volumes:
      - redis_data:/data

  consul:
    image: consul:latest
    ports:
      - "8500:8500"
    command: consul agent -server -ui -bootstrap-expect=1 -client=0.0.0.0

  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "5775:5775/udp"
      - "6831:6831/udp"
      - "6832:6832/udp"
      - "5778:5778"
      - "16686:16686"
      - "14268:14268"
      - "14250:14250"
      - "9411:9411"

volumes:
  postgres_data:
  redis_data:
```

## Best Practices Summary

1. **Always implement health checks** - For readiness/liveness probes
2. **Use circuit breakers** - Prevent cascade failures
3. **Register with service discovery** - Enable dynamic routing
4. **Implement graceful shutdown** - Handle SIGTERM properly
5. **Add observability** - Logging, metrics, tracing from day one
6. **Use structured logging** - JSON format with contextual fields
7. **Set reasonable timeouts** - Prevent resource leaks
8. **Implement backpressure** - Rate limiting and throttling
9. **Secure inter-service communication** - mTLS where needed
10. **Design for failure** - Assume dependencies will fail
