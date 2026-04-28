# Persistent Storage Integration Examples

Examples of using Redis and MongoDB for memory pattern persistence.

---

## Redis Examples

### Basic Usage

```javascript
const { redisStore } = require('./redis-integration');

// Connect to Redis
await redisStore.connect();

// Store a memory
await redisStore.store(
  'user:preferences',
  { theme: 'dark', language: 'en' },
  'userContext'
);

// Retrieve a memory
const preferences = await redisStore.retrieve('user:preferences', 'userContext');
console.log(preferences); // { theme: 'dark', language: 'en' }

// Delete a memory
await redisStore.delete('user:preferences', 'userContext');
```

### Partitioned Storage

```javascript
// Store memories in different partitions
await redisStore.store(
  'task:123:progress',
  { status: 'in-progress', progress: 75, checkpoints: ['done', 'in-progress'] },
  'taskContext'
);

await redisStore.store(
  'tool:api-client',
  { capabilities: ['fetch', 'post'], version: '2.0.0' },
  'toolKnowledge'
);

await redisStore.store(
  'project:main-app:dependencies',
  { react: '^18.0.0', typescript: '^5.0.0' },
  'projectKnowledge'
);

// Get statistics for each partition
const stats = await redisStore.getStats();
console.log(stats);
// {
//   partitions: {
//     userContext: { count: 1, size: 1234 },
//     taskContext: { count: 1, size: 2345 },
//     toolKnowledge: { count: 1, size: 3456 },
//     projectKnowledge: { count: 1, size: 4567 }
//   },
//   total: { count: 4, size: 11622 }
// }
```

### Relevance Scoring Search

```javascript
// Search for relevant memories
const results = await redisStore.search(
  'theme preferences dark mode',
  'userContext',
  5
);

console.log(results);
// [
//   { theme: 'dark', language: 'en', ... },
//   { theme: 'dark', accentColor: 'blue', ... },
//   // ... top 5 most relevant
// ]
```

### Cache Warming

```javascript
// Pre-warm frequently accessed memories
async function warmCache() {
  const keys = ['user:preferences', 'task:123:progress', 'tool:api-client'];

  for (const key of keys) {
    await redisStore.retrieve(key);
  }

  console.log('Cache warmed');
}

await warmCache();
```

### Custom Configuration

```javascript
const { RedisMemoryStore } = require('./redis-integration');

const customStore = new RedisMemoryStore({
  url: 'redis://custom-host:6379',
  defaultTTL: 86400, // 24 hours
  poolMax: 100,
  poolMin: 10,
  enableCompression: true,
  enableCache: true,
  cacheTTL: 7200, // 2 hours
  enableLogging: true,
});

await customStore.connect();
```

---

## MongoDB Examples

### Basic Usage

```javascript
const { mongoStore } = require('./mongodb-integration');

// Connect to MongoDB
await mongoStore.connect();

// Store a memory
await mongoStore.store({
  key: 'user:preferences',
  value: { theme: 'dark', language: 'en' },
  partition: 'userContext',
  type: 'preference',
  metadata: { userId: '123', lastAccessed: new Date() }
});

// Retrieve a memory
const preferences = await mongoStore.retrieve('user:preferences', 'userContext');
console.log(preferences); // { theme: 'dark', language: 'en' }
```

### Version Tracking

```javascript
// Get version history
const history = await mongoStore.getVersionHistory('user:preferences', 'userContext');

console.log(history);
// [
//   {
//     version: 1,
//     changedBy: 'system',
//     changedAt: '2026-04-24T02:00:00.000Z',
//     changes: 'Initial creation',
//     previousValue: null
//   },
//   {
//     version: 2,
//     changedBy: 'system',
//     changedAt: '2026-04-24T02:01:00.000Z',
//     changes: 'Update',
//     previousValue: { theme: 'dark', language: 'en' }
//   }
// ]
```

### Using Update Function

```javascript
// Update a memory with version tracking
await mongoStore.update(
  'user:preferences',
  'userContext',
  (currentValue, currentMetadata) => {
    return {
      ...currentValue,
      theme: currentValue.theme === 'light' ? 'dark' : 'light',
      lastModified: new Date(),
    };
  }
);

// Get a specific version
const version2 = await mongoStore.getByVersion('user:preferences', 'userContext', 2);
console.log(version2); // Value at version 2
```

### Full-Text Search

```javascript
// Search with MongoDB text index
const results = await mongoStore.search(
  'theme preferences dark mode',
  'userContext',
  5,
  { type: 'preference' }
);

console.log(results);
// Returns top 5 matching preferences
```

### Aggregation Queries

```javascript
// Get statistics across all partitions
const stats = await mongoStore.getStats();

console.log(stats);
// {
//   partitions: {
//     userContext: { count: 150, size: 150000 },
//     taskContext: { count: 80, size: 80000 },
//     toolKnowledge: { count: 45, size: 45000 },
//     projectKnowledge: { count: 95, size: 95000 }
//   },
//   total: { count: 370, size: 370000 }
// }
```

### Memory Cleanup with TTL

```javascript
// Memories older than 7 days (default TTL) will be automatically deleted
// by the TTL index
// MongoDB handles this automatically when the TTL index expires

// Check TTL settings
// Can be configured via MongoMemoryStoreConfig.defaultTTL
```

---

## Integration with Memory Patterns

### Using Redis with MemoryManager

```javascript
const { RedisMemoryStore } = require('./redis-integration');
const { MemoryManager } = require('./memory-patterns/skill');

// Initialize Redis store
const redisStore = new RedisMemoryStore();
await redisStore.connect();

// Create memory manager with Redis backend
const memoryManager = new MemoryManager(redisStore);

// Use memory manager as normal
await memoryManager.store('user:theme', 'dark', 'UserContext');
const theme = await memoryManager.retrieve('user:theme', 'UserContext');
```

### Using MongoDB with MemoryAgent

```javascript
const { MongoMemoryStore } = require('./mongodb-integration');
const { MemoryAgent } = require('./memory-patterns/skill');

// Initialize MongoDB store
const mongoStore = new MongoMemoryStore();
await mongoStore.connect();

// Create memory agent with MongoDB backend
const memoryAgent = new MemoryAgent({
  store: mongoStore,
  partitions: ['userContext', 'taskContext', 'toolKnowledge', 'projectKnowledge'],
});

// Use memory agent
const context = await memoryAgent.onUserMessage('I like dark mode');
```

---

## Best Practices

### Redis

1. **Use appropriate TTL**: Set TTL based on memory type
   - Short-term: 1 hour
   - Long-term: 24 hours
   - Knowledge: 7 days

2. **Leverage partitions**: Organize memories by context
   - `userContext`, `taskContext`, `toolKnowledge`, `projectKnowledge`

3. **Enable caching**: Use in-memory cache for hot data
   ```javascript
   customStore.config.enableCache = true;
   customStore.config.cacheTTL = 3600;
   ```

4. **Monitor cache size**: Redis memory usage can grow
   ```javascript
   const stats = await redisStore.getStats();
   console.log('Cache size:', stats.cacheSize);
   ```

5. **Connection pooling**: Configure pool size for high load
   ```javascript
   poolMax: 100,
   poolMin: 10,
   ```

### MongoDB

1. **Use indexes**: Leverage composite indexes for performance
   ```javascript
   await collection.createIndex({ partition: 1, key: 1 }, { unique: true });
   ```

2. **Enable TTL**: Automatic cleanup of old memories
   ```javascript
   defaultTTL: 604800, // 7 days
   enableTTLIndex: true
   ```

3. **Use version tracking**: Track memory evolution
   ```javascript
   enableChangeTracking: true
   ```

4. **Select specific partitions**: Query only needed data
   ```javascript
   const stats = await mongoStore.getStats('userContext');
   ```

5. **Monitor size**: MongoDB storage can grow large
   ```javascript
   const stats = await mongoStore.getStats();
   console.log('Total size:', stats.total.size);
   ```

---

## Performance Considerations

### Redis
- **Memory usage**: ~100-500 bytes per memory
- **Latency**: < 5ms for most operations
- **Throughput**: 50,000+ ops/second
- **Best for**: Cache, temporary storage, high-speed access

### MongoDB
- **Memory usage**: ~500-1000 bytes per memory (with metadata)
- **Latency**: < 20ms for most operations
- **Throughput**: 10,000+ ops/second
- **Best for**: Persistent storage, complex queries, version tracking

---

## Error Handling

```javascript
try {
  await redisStore.store(key, value, partition);
} catch (error) {
  console.error('Store failed:', error);
  // Retry logic or fallback to other store
}

try {
  await mongoStore.retrieve(key, partition);
} catch (error) {
  console.error('Retrieve failed:', error);
  // Return default value
  return defaultValue;
}
```

---

*Last updated: 2026-04-24*
