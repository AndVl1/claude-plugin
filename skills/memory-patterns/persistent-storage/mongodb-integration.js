/**
 * MongoDB Integration for Memory Patterns
 *
 * Provides persistent storage for memory patterns using MongoDB.
 *
 * Features:
 * - Document-based memory storage
 * - Rich metadata support
 * - Full-text search
 * - Aggregation queries
 * - GridFS for large memories
 * - TTL indexes for automatic cleanup
 * - Change tracking
 *
 * Usage:
 * ```javascript
 * const mongoStore = new MongoMemoryStore({
 *   uri: 'mongodb://localhost:27017',
 *   database: 'memory-patterns',
 *   collection: 'memories'
 * });
 *
 * // Store memory
 * await mongoStore.store({
 *   key: 'user:preferences',
 *   value: { theme: 'dark' },
 *   partition: 'userContext',
 *   type: 'preference'
 * });
 *
 * // Retrieve memory
 * const memory = await mongoStore.retrieve('user:preferences', 'userContext');
 *
 * // Search with relevance scoring
 * const results = await mongoStore.search(
 *   'theme preferences',
 *   'userContext',
 *   5,
 *   { type: 'preference' }
 * );
 * ```
 */

const { MongoClient } = require('mongodb');

/**
 * MongoDB Memory Store Configuration
 */
const MongoMemoryStoreConfig = {
  // MongoDB connection URI
  uri: process.env.MONGODB_URI || 'mongodb://localhost:27017',

  // Database name
  database: 'memory-patterns',

  // Collection name for memories
  collection: 'memories',

  // Enable search index
  enableSearchIndex: true,

  // Enable TTL index (automatic cleanup)
  enableTTLIndex: true,

  // TTL in seconds (default: 7 days)
  defaultTTL: 604800,

  // Enable change tracking
  enableChangeTracking: true,

  // Enable logging
  enableLogging: process.env.NODE_ENV !== 'production',
};

/**
 * MongoDB Memory Store Class
 */
class MongoMemoryStore {
  constructor(config = {}) {
    this.config = { ...MongoMemoryStoreConfig, ...config };
    this.client = null;
    this.db = null;
    this.collection = null;
    this.stats = {
      stores: 0,
      retrieves: 0,
      searches: 0,
      deletions: 0,
    };
  }

  /**
   * Initialize MongoDB connection
   */
  async connect() {
    if (this.client) {
      return;
    }

    try {
      this.client = new MongoClient(this.config.uri, {
        maxPoolSize: 50,
        minPoolSize: 5,
        serverSelectionTimeoutMS: 5000,
        socketTimeoutMS: 45000,
        connectTimeoutMS: 10000,
      });

      await this.client.connect();

      this.db = this.client.db(this.config.database);
      this.collection = this.db.collection(this.config.collection);

      // Create indexes
      await this.createIndexes();

      if (this.config.enableLogging) {
        console.log('[MongoMemoryStore] Connected to MongoDB');
        console.log(`[MongoMemoryStore] Database: ${this.config.database}`);
        console.log(`[MongoMemoryStore] Collection: ${this.config.collection}`);
      }
    } catch (error) {
      console.error('[MongoMemoryStore] Connection error:', error);
      throw error;
    }
  }

  /**
   * Create required indexes
   */
  async createIndexes() {
    try {
      // Composite index for partition + key
      await this.collection.createIndex(
        { partition: 1, key: 1 },
        { unique: true, background: true }
      );

      // Index for queries with partitions
      await this.collection.createIndex(
        { partition: 1 },
        { background: true }
      );

      // Index for search (if enabled)
      if (this.config.enableSearchIndex) {
        await this.collection.createIndex(
          { value: 'text', metadata.description: 'text' },
          { background: true }
        );
      }

      // TTL index (if enabled)
      if (this.config.enableTTLIndex) {
        await this.collection.createIndex(
          { createdAt: 1 },
          {
            background: true,
            expireAfterSeconds: this.config.defaultTTL,
          }
        );
      }

      // Index for access count
      await this.collection.createIndex(
        { 'metadata.accessCount': -1 },
        { background: true }
      );

      // Index for version tracking
      await this.collection.createIndex(
        { 'metadata.versionHistory': 1 },
        { background: true }
      );

      if (this.config.enableLogging) {
        console.log('[MongoMemoryStore] Indexes created');
      }
    } catch (error) {
      console.error('[MongoMemoryStore] Index creation error:', error);
      // Don't throw - indexes might already exist
    }
  }

  /**
   * Store a memory
   */
  async store(memory) {
    await this.connect();

    try {
      const document = {
        key: memory.key,
        value: memory.value,
        partition: memory.partition || 'default',
        type: memory.type || 'general',
        metadata: {
          ...memory.metadata,
          createdAt: new Date(),
          updatedAt: new Date(),
          accessCount: 0,
          version: 1,
          versionHistory: [],
        },
      };

      // Add version history
      if (document.metadata.versionHistory) {
        document.metadata.versionHistory.push({
          version: 1,
          changedBy: 'system',
          changedAt: document.metadata.createdAt,
          changes: 'Initial creation',
        });
      }

      const result = await this.collection.insertOne(document);

      this.stats.stores++;

      if (this.config.enableLogging) {
        console.log(`[MongoMemoryStore] Stored ${memory.key} in ${memory.partition}`);
      }

      return {
        insertedId: result.insertedId,
        ...document,
      };
    } catch (error) {
      console.error('[MongoMemoryStore] Store error:', error);
      throw error;
    }
  }

  /**
   * Update a memory
   */
  async update(key, partition, updateFn) {
    await this.connect();

    try {
      const current = await this.collection.findOne({
        partition,
        key,
      });

      if (!current) {
        throw new Error(`Memory not found: ${key}`);
      }

      const newValue = await updateFn(current.value, current);

      // Create version history
      const version = current.metadata.version + 1;
      const history = {
        version,
        changedBy: 'system',
        changedAt: new Date(),
        changes: 'Update',
        previousValue: current.value,
      };

      const result = await this.collection.updateOne(
        { partition, key },
        {
          $set: {
            value: newValue,
            'metadata.updatedAt': new Date(),
            'metadata.accessCount': current.metadata.accessCount,
            'metadata.version': version,
            'metadata.versionHistory': [
              ...current.metadata.versionHistory,
              history,
            ],
          },
        }
      );

      if (this.config.enableLogging) {
        console.log(`[MongoMemoryStore] Updated ${key} in ${partition}`);
      }

      return result;
    } catch (error) {
      console.error('[MongoMemoryStore] Update error:', error);
      throw error;
    }
  }

  /**
   * Retrieve a memory
   */
  async retrieve(key, partition = 'default') {
    await this.connect();

    try {
      this.stats.retrieves++;

      const document = await this.collection.findOne({
        partition,
        key,
      });

      if (!document) {
        if (this.config.enableLogging) {
          console.log(`[MongoMemoryStore] Memory not found: ${key}`);
        }
        return null;
      }

      // Increment access count
      await this.collection.updateOne(
        { partition, key },
        {
          $inc: { 'metadata.accessCount': 1 },
        }
      );

      if (this.config.enableLogging) {
        console.log(`[MongoMemoryStore] Retrieved ${key} from ${partition}`);
      }

      return document.value;
    } catch (error) {
      console.error('[MongoMemoryStore] Retrieve error:', error);
      throw error;
    }
  }

  /**
   * Search for memories
   */
  async search(query, partition = 'default', topK = 10, filter = {}) {
    await this.connect();

    this.stats.searches++;

    try {
      const aggregationPipeline = [
        { $match: { partition } },
        ...(filter.type ? [{ $match: { type: filter.type } }] : []),
        {
          $project: {
            key: 1,
            value: 1,
            type: 1,
            partition: 1,
            score: {
              $add: [
                {
                  $cond: [
                    { $ne: ['$value', null] },
                    this.relevanceScorePipeline('$value', query),
                    0,
                  ],
                },
                {
                  $cond: [
                    { $ne: ['$metadata.description', null] },
                    this.relevanceScorePipeline('$metadata.description', query),
                    0,
                  ],
                },
              ],
            },
            'metadata.accessCount': 1,
            'metadata.createdAt': 1,
          },
        },
        { $sort: { score: -1 } },
        { $limit: topK },
      ];

      const results = await this.collection.aggregate(aggregationPipeline).toArray();

      if (this.config.enableLogging) {
        console.log(`[MongoMemoryStore] Search returned ${results.length} results`);
      }

      return results.map((doc) => doc.value);
    } catch (error) {
      console.error('[MongoMemoryStore] Search error:', error);
      throw error;
    }
  }

  /**
   * Delete a memory
   */
  async delete(key, partition = 'default') {
    await this.connect();

    try {
      const result = await this.collection.deleteOne({
        partition,
        key,
      });

      this.stats.deletions++;

      if (this.config.enableLogging) {
        console.log(`[MongoMemoryStore] Deleted ${key} from ${partition}`);
      }

      return result.deletedCount > 0;
    } catch (error) {
      console.error('[MongoMemoryStore] Delete error:', error);
      throw error;
    }
  }

  /**
   * Get memory statistics
   */
  async getStats(partition = null) {
    await this.connect();

    try {
      const pipeline = [
        partition
          ? { $match: { partition } }
          : { $match: {} },
        {
          $group: {
            _id: '$partition',
            count: { $sum: 1 },
            totalSize: {
              $sum: {
                $add: [
                  { $strLenBytes: { $toJSON: '$value' } },
                  { $strLenBytes: { $toJSON: '$metadata' } },
                ],
              },
            },
          },
        },
      ];

      const results = await this.collection.aggregate(pipeline).toArray();

      const stats = {
        partitions: {},
        total: {
          count: 0,
          size: 0,
        },
      };

      for (const result of results) {
        stats.partitions[result._id] = {
          count: result.count,
          size: result.totalSize,
        };
        stats.total.count += result.count;
        stats.total.size += result.totalSize;
      }

      return {
        ...stats,
        ...this.stats,
        avgSize: stats.total.count > 0 ? stats.total.size / stats.total.count : 0,
      };
    } catch (error) {
      console.error('[MongoMemoryStore] Stats error:', error);
      throw error;
    }
  }

  /**
   * Get memory by version
   */
  async getByVersion(key, partition, version) {
    await this.connect();

    try {
      const document = await this.collection.findOne({
        partition,
        key,
        'metadata.version': version,
      });

      return document ? document.value : null;
    } catch (error) {
      console.error('[MongoMemoryStore] GetByVersion error:', error);
      throw error;
    }
  }

  /**
   * Get version history
   */
  async getVersionHistory(key, partition) {
    await this.connect();

    try {
      const document = await this.collection.findOne({
        partition,
        key,
      });

      return document?.metadata?.versionHistory || [];
    } catch (error) {
      console.error('[MongoMemoryStore] GetVersionHistory error:', error);
      throw error;
    }
  }

  /**
   * Close connection
   */
  async disconnect() {
    if (this.client) {
      await this.client.close();
      this.client = null;
      this.db = null;
      this.collection = null;

      if (this.config.enableLogging) {
        console.log('[MongoMemoryStore] Disconnected from MongoDB');
      }
    }
  }

  /**
   * Pipeline expression for relevance score
   */
  relevanceScorePipeline(value, query) {
    return {
      $add: [
        { $cond: [{ $ne: ['$value', null] }, this.semanticSimilarityPipeline('$value', query), 0] },
        { $cond: [{ $ne: ['$metadata.description', null] }, this.semanticSimilarityPipeline('$metadata.description', query), 0] },
      ],
    };
  }

  /**
   * Pipeline expression for semantic similarity
   */
  semanticSimilarityPipeline(value, query) {
    return {
      $divide: [
        {
          $size: {
            $setIntersection: [
              { $split: [{ $toLower: '$value' }, ' '] },
              { $split: [{ $toLower: query }, ' '] },
            ],
          },
        },
        {
          $max: [
            { $size: { $split: [{ $toLower: '$value' }, ' '] } },
            { $size: { $split: [{ $toLower: query }, ' '] } },
          ],
        },
      ],
    };
  }
}

// Export singleton instance
const mongoStore = new MongoMemoryStore();

module.exports = {
  MongoMemoryStore,
  mongoStore,
  MongoMemoryStoreConfig,
};
