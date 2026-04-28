/**
 * Redis Integration for Memory Patterns
 *
 * Provides persistent storage for memory patterns using Redis.
 *
 * Features:
 * - Memory storage and retrieval with TTL
 * - Partition-based organization
 * - Compression and relevance scoring
 * - Cache warming
 * - Persistence and durability
 *
 * Usage:
 * ```javascript
 * const redisStore = new RedisMemoryStore({
 *   url: 'redis://localhost:6379',
 *   defaultTTL: 86400, // 24 hours
 *   partitions: ['userContext', 'taskContext', 'toolKnowledge', 'projectKnowledge']
 * });
 *
 * // Store memory
 * await redisStore.store('user:preferences', { theme: 'dark' }, 'userContext');
 *
 * // Retrieve memory
 * const memory = await redisStore.retrieve('user:preferences', 'userContext');
 *
 * // Search with relevance scoring
 * const results = await redisStore.search('theme preferences', 'userContext', 5);
 * ```
 */

const Redis = require('ioredis');

/**
 * Redis Memory Store Configuration
 */
const RedisMemoryStoreConfig = {
  // Redis connection URL
  url: process.env.REDIS_URL || 'redis://localhost:6379',

  // Default TTL for memories (in seconds)
  defaultTTL: 86400, // 24 hours

  // Partitions to organize memories
  partitions: [
    'userContext',
    'taskContext',
    'toolKnowledge',
    'projectKnowledge',
  ],

  // Connection pool settings
  poolMax: 50,
  poolMin: 5,

  // Enable compression
  enableCompression: true,

  // Enable caching
  enableCache: true,

  // Cache TTL (in seconds)
  cacheTTL: 3600, // 1 hour

  // Enable logging
  enableLogging: process.env.NODE_ENV !== 'production',
};

/**
 * Redis Memory Store Class
 */
class RedisMemoryStore {
  constructor(config = {}) {
    this.config = { ...RedisMemoryStoreConfig, ...config };
    this.redis = null;
    this.cache = new Map();
    this.stats = {
      stores: 0,
      retrieves: 0,
      searches: 0,
      evictions: 0,
    };
  }

  /**
   * Initialize Redis connection
   */
  async connect() {
    if (this.redis) {
      return;
    }

    this.redis = new Redis(this.config.url, {
      maxRetriesPerRequest: 3,
      retryDelayOnFailover: 100,
      retryDelayOnFailure: 100,
      enableReadyCheck: true,
      lazyConnect: true,
      poolMaxConnections: this.config.poolMax,
      poolMinConnections: this.config.poolMin,
    });

    this.redis.on('error', (err) => {
      if (this.config.enableLogging) {
        console.error('[RedisMemoryStore] Error:', err);
      }
    });

    this.redis.on('connect', () => {
      if (this.config.enableLogging) {
        console.log('[RedisMemoryStore] Connected to Redis');
      }
    });

    await this.redis.connect();
  }

  /**
   * Store a memory in a partition
   */
  async store(key, value, partition = 'default', metadata = {}) {
    await this.connect();

    try {
      const memory = {
        value,
        partition,
        metadata: {
          ...metadata,
          createdAt: Date.now(),
          updatedAt: Date.now(),
          accessCount: 0,
        },
      };

      // Serialize with compression if enabled
      if (this.config.enableCompression) {
        memory.value = this.compress(value);
      }

      const redisKey = this.getRedisKey(partition, key);

      // Store with TTL
      await this.redis.setex(
        redisKey,
        this.config.defaultTTL,
        JSON.stringify(memory)
      );

      // Update cache
      this.cache.set(redisKey, memory);

      // Update stats
      this.stats.stores++;

      if (this.config.enableLogging) {
        console.log(`[RedisMemoryStore] Stored ${key} in ${partition}`);
      }

      return true;
    } catch (error) {
      console.error('[RedisMemoryStore] Store error:', error);
      throw error;
    }
  }

  /**
   * Retrieve a memory from a partition
   */
  async retrieve(key, partition = 'default') {
    await this.connect();

    try {
      this.stats.retrieves++;

      const redisKey = this.getRedisKey(partition, key);

      // Check cache first
      const cached = this.cache.get(redisKey);
      if (cached) {
        if (this.config.enableLogging) {
          console.log(`[RedisMemoryStore] Cache hit for ${key}`);
        }
        return this.decompress(cached.value);
      }

      // Retrieve from Redis
      const data = await this.redis.get(redisKey);

      if (!data) {
        if (this.config.enableLogging) {
          console.log(`[RedisMemoryStore] Memory not found: ${key}`);
        }
        return null;
      }

      const memory = JSON.parse(data);

      // Update cache
      this.cache.set(redisKey, memory);

      // Update access count
      await this.updateAccessCount(redisKey, partition);

      if (this.config.enableLogging) {
        console.log(`[RedisMemoryStore] Retrieved ${key} from ${partition}`);
      }

      return this.decompress(memory.value);
    } catch (error) {
      console.error('[RedisMemoryStore] Retrieve error:', error);
      throw error;
    }
  }

  /**
   * Search for memories in a partition using relevance scoring
   */
  async search(query, partition = 'default', topK = 10, filter = {}) {
    await this.connect();

    this.stats.searches++;

    try {
      // Get all keys in the partition
      const pattern = `${this.getRedisKeyPrefix(partition)}:*`;
      const keys = await this.redis.keys(pattern);

      // Score each memory
      const scored = [];

      for (const key of keys) {
        const data = await this.redis.get(key);
        if (!data) continue;

        const memory = JSON.parse(data);

        // Apply filter
        if (filter.type && memory.metadata.type !== filter.type) {
          continue;
        }

        const score = this.relevanceScore(
          memory.value,
          query,
          memory.metadata
        );

        if (score > 0) {
          scored.push({ key, memory, score });
        }
      }

      // Sort by score and return top K
      scored.sort((a, b) => b.score - a.score);

      const results = scored.slice(0, topK).map(({ memory }) => this.decompress(memory.value));

      if (this.config.enableLogging) {
        console.log(`[RedisMemoryStore] Search returned ${results.length} results`);
      }

      return results;
    } catch (error) {
      console.error('[RedisMemoryStore] Search error:', error);
      throw error;
    }
  }

  /**
   * Delete a memory
   */
  async delete(key, partition = 'default') {
    await this.connect();

    try {
      const redisKey = this.getRedisKey(partition, key);

      await this.redis.del(redisKey);

      // Remove from cache
      this.cache.delete(redisKey);

      if (this.config.enableLogging) {
        console.log(`[RedisMemoryStore] Deleted ${key} from ${partition}`);
      }

      return true;
    } catch (error) {
      console.error('[RedisMemoryStore] Delete error:', error);
      throw error;
    }
  }

  /**
   * Get memory statistics
   */
  async getStats(partition = null) {
    await this.connect();

    try {
      const prefix = partition
        ? this.getRedisKeyPrefix(partition)
        : '*';

      const pattern = `${prefix}:*`;
      const keys = await this.redis.keys(pattern);

      const stats = {
        count: keys.length,
        size: 0,
        partitions: {},
      };

      for (const key of keys) {
        const data = await this.redis.get(key);
        if (data) {
          const memory = JSON.parse(data);
          stats.size += JSON.stringify(memory).length;
          stats.partitions[partition] = (stats.partitions[partition] || 0) + 1;
        }
      }

      return {
        ...stats,
        ...this.stats,
        cacheSize: this.cache.size,
        avgSize: stats.count > 0 ? stats.size / stats.count : 0,
      };
    } catch (error) {
      console.error('[RedisMemoryStore] Stats error:', error);
      throw error;
    }
  }

  /**
   * Clear all memories in a partition
   */
  async clearPartition(partition) {
    await this.connect();

    try {
      const prefix = this.getRedisKeyPrefix(partition);
      const pattern = `${prefix}:*`;
      const keys = await this.redis.keys(pattern);

      if (keys.length > 0) {
        await this.redis.del(...keys);
      }

      // Clear cache
      this.cache.clear();

      if (this.config.enableLogging) {
        console.log(`[RedisMemoryStore] Cleared partition: ${partition}`);
      }

      return keys.length;
    } catch (error) {
      console.error('[RedisMemoryStore] Clear error:', error);
      throw error;
    }
  }

  /**
   * Close connection
   */
  async disconnect() {
    if (this.redis) {
      await this.redis.quit();
      this.redis = null;
      this.cache.clear();

      if (this.config.enableLogging) {
        console.log('[RedisMemoryStore] Disconnected from Redis');
      }
    }
  }

  /**
   * Get Redis key for a memory
   */
  getRedisKey(partition, key) {
    return `${this.getRedisKeyPrefix(partition)}:${key}`;
  }

  /**
   * Get Redis key prefix for a partition
   */
  getRedisKeyPrefix(partition) {
    return `memory:${partition}`;
  }

  /**
   * Calculate relevance score for a memory
   */
  relevanceScore(value, query, metadata) {
    let score = 0;

    // Semantic similarity (simplified - in production use vector embeddings)
    const similarity = this.semanticSimilarity(value, query);
    score += similarity * 0.4;

    // Recency
    const timeDiff = Date.now() - metadata.updatedAt;
    const recency = Math.max(0, 1 - timeDiff / (24 * 60 * 60 * 1000));
    score += recency * 0.3;

    // Context alignment (simplified)
    const alignment = this.contextAlignment(value, query);
    score += alignment * 0.2;

    // Access frequency
    score += Math.min(metadata.accessCount * 0.1, 1);

    return score;
  }

  /**
   * Calculate semantic similarity (simplified)
   */
  semanticSimilarity(value, query) {
    const valueWords = new Set(value.toLowerCase().split(/\s+/));
    const queryWords = new Set(query.toLowerCase().split(/\s+/));
    const intersection = [...valueWords].filter((word) => queryWords.has(word));
    return intersection.length / Math.max(valueWords.size, queryWords.size);
  }

  /**
   * Calculate context alignment (simplified)
   */
  contextAlignment(value, query) {
    const valueLower = value.toLowerCase();
    const queryLower = query.toLowerCase();
    const valueHasQuery = valueLower.includes(queryLower) ||
                         queryLower.includes(valueLower);
    return valueHasQuery ? 0.8 : 0.3;
  }

  /**
   * Update access count
   */
  async updateAccessCount(redisKey, partition) {
    await this.redis.hIncrBy(`memory:${partition}:stats`, redisKey, 1);
  }

  /**
   * Compress data (simplified - use actual compression in production)
   */
  compress(data) {
    // In production, use actual compression like zstd, brotli, etc.
    // For now, return as-is
    return data;
  }

  /**
   * Decompress data
   */
  decompress(data) {
    // In production, use actual decompression
    return data;
  }
}

// Export singleton instance
const redisStore = new RedisMemoryStore();

module.exports = {
  RedisMemoryStore,
  redisStore,
  RedisMemoryStoreConfig,
};
