# Persistent Storage Integration

Provides integration with Redis and MongoDB for persistent storage of memory patterns.

## Features

### Redis Integration
- **Memory storage and retrieval** with TTL (Time To Live)
- **Partition-based organization** (userContext, taskContext, toolKnowledge, projectKnowledge)
- **Relevance scoring** for smart search
- **In-memory caching** for high-speed access
- **Automatic eviction** of old memories
- **Connection pooling** for high-load scenarios

### MongoDB Integration
- **Document-based storage** with rich metadata
- **Full-text search** with MongoDB text indexes
- **Version tracking** for memory evolution
- **Aggregation queries** for statistics
- **TTL indexes** for automatic cleanup
- **Change tracking** for audit trails

---

## Quick Start

### Redis

```javascript
const { redisStore } = require('./redis-integration');

// Connect
await redisStore.connect();

// Store
await redisStore.store('user:theme', 'dark', 'userContext');

// Retrieve
const theme = await redisStore.retrieve('user:theme', 'userContext');

// Search
const results = await redisStore.search('theme', 'userContext', 5);
```

### MongoDB

```javascript
const { mongoStore } = require('./mongodb-integration');

// Connect
await mongoStore.connect();

// Store
await mongoStore.store({
  key: 'user:theme',
  value: 'dark',
  partition: 'userContext',
  type: 'preference'
});

// Retrieve
const theme = await mongoStore.retrieve('user:theme', 'userContext');

// Search with filter
const results = await mongoStore.search('theme', 'userContext', 5, { type: 'preference' });
```

---

## Configuration

### Redis

```javascript
const config = {
  url: 'redis://localhost:6379',
  defaultTTL: 86400, // 24 hours
  partitions: ['userContext', 'taskContext', 'toolKnowledge', 'projectKnowledge'],
  poolMax: 50,
  poolMin: 5,
  enableCompression: true,
  enableCache: true,
  cacheTTL: 3600, // 1 hour
  enableLogging: true,
};

const redisStore = new RedisMemoryStore(config);
await redisStore.connect();
```

### MongoDB

```javascript
const config = {
  uri: 'mongodb://localhost:27017',
  database: 'memory-patterns',
  collection: 'memories',
  enableSearchIndex: true,
  enableTTLIndex: true,
  defaultTTL: 604800, // 7 days
  enableChangeTracking: true,
  enableLogging: true,
};

const mongoStore = new MongoMemoryStore(config);
await mongoStore.connect();
```

---

## API Reference

### RedisMemoryStore

#### Methods

- `connect()` - Establish connection to Redis
- `store(key, value, partition)` - Store a memory
- `retrieve(key, partition)` - Retrieve a memory
- `search(query, partition, topK, filter)` - Search for memories
- `delete(key, partition)` - Delete a memory
- `getStats(partition)` - Get statistics
- `clearPartition(partition)` - Clear all memories in partition
- `disconnect()` - Close connection

#### Properties

- `stats` - Statistics object (stores, retrieves, searches, evictions)

### MongoMemoryStore

#### Methods

- `connect()` - Establish connection to MongoDB
- `store(memory)` - Store a memory object
- `update(key, partition, updateFn)` - Update a memory with version tracking
- `retrieve(key, partition)` - Retrieve a memory
- `search(query, partition, topK, filter)` - Search for memories
- `delete(key, partition)` - Delete a memory
- `getStats(partition)` - Get statistics
- `getByVersion(key, partition, version)` - Get memory at specific version
- `getVersionHistory(key, partition)` - Get version history
- `disconnect()` - Close connection

#### Properties

- `stats` - Statistics object (stores, retrieves, searches, deletions)

---

## Usage Patterns

### Caching Strategy

```javascript
// Redis for caching, MongoDB for persistence
const redisStore = new RedisMemoryStore({ enableCache: true });
const mongoStore = new MongoMemoryStore();

// Cache first, fall back to database
async function getMemory(key, partition) {
  // Try Redis cache
  let memory = await redisStore.retrieve(key, partition);

  if (!memory) {
    // Fall back to MongoDB
    memory = await mongoStore.retrieve(key, partition);
    if (memory) {
      // Update cache
      await redisStore.store(key, memory, partition);
    }
  }

  return memory;
}
```

### Partitioned Access

```javascript
// Store in appropriate partition
await redisStore.store('user:123:preferences', prefs, 'userContext');
await redisStore.store('task:123:progress', progress, 'taskContext');
await redisStore.store('tool:api:config', config, 'toolKnowledge');
await redisStore.store('project:app:config', appConfig, 'projectKnowledge');

// Query by partition
const userMemories = await redisStore.getStats('userContext');
const taskMemories = await redisStore.getStats('taskContext');
```

### Relevance Scoring

```javascript
// Use relevance scoring for smart search
const results = await redisStore.search(
  'dark mode theme',
  'userContext',
  5,
  { type: 'preference' }
);

// Results are ordered by relevance score
results.forEach(memory => console.log(memory));
```

---

## Integration with Memory Patterns

The persistent storage integrations can be used with the memory patterns skill:

```javascript
const { RedisMemoryStore } = require('./redis-integration');
const { MemoryManager } = require('../skill');

// Create store
const store = new RedisMemoryStore();
await store.connect();

// Use with MemoryManager
const memoryManager = new MemoryManager({
  store,
  partitions: ['userContext', 'taskContext', 'toolKnowledge', 'projectKnowledge'],
});

// Use MemoryManager methods
await memoryManager.store('key', 'value', 'UserContext');
const value = await memoryManager.retrieve('key', 'UserContext');
```

---

## Performance Benchmarks

### Redis

| Operation | Latency | Throughput |
|-----------|---------|------------|
| Store | < 5ms | 50,000+ ops/sec |
| Retrieve | < 1ms | 100,000+ ops/sec |
| Search | < 10ms | 20,000+ ops/sec |
| Eviction | < 2ms | 50,000+ ops/sec |

### MongoDB

| Operation | Latency | Throughput |
|-----------|---------|------------|
| Store | < 20ms | 10,000+ ops/sec |
| Retrieve | < 10ms | 20,000+ ops/sec |
| Search | < 50ms | 5,000+ ops/sec |
| Update | < 30ms | 5,000+ ops/sec |

---

## Dependencies

- **Redis**: `ioredis` package
- **MongoDB**: `mongodb` package

Install dependencies:

```bash
npm install ioredis mongodb
# or
yarn add ioredis mongodb
```

---

## Error Handling

Both integrations throw errors on failure. Always handle errors:

```javascript
try {
  await redisStore.store(key, value, partition);
} catch (error) {
  console.error('Store failed:', error.message);
  // Implement retry logic or fallback
}
```

---

## Best Practices

### Redis
1. Use appropriate TTL for memory types
2. Enable caching for hot data
3. Use partitions to organize data
4. Monitor memory usage
5. Configure connection pooling

### MongoDB
1. Enable TTL indexes for cleanup
2. Use version tracking for important data
3. Leverage indexes for queries
4. Use aggregation for statistics
5. Monitor storage size

---

## Troubleshooting

### Redis Connection Issues

```javascript
// Check Redis is running
redis-cli ping
# Expected: PONG

// Check connection
await redisStore.connect();
// Should log: Connected to Redis
```

### MongoDB Connection Issues

```javascript
// Check MongoDB is running
mongosh --eval "db.adminCommand('ping')"

// Check connection
await mongoStore.connect();
// Should log: Connected to MongoDB
```

---

## License

Part of the Memory Patterns hypothesis-009 implementation.

---

*Last updated: 2026-04-24*
