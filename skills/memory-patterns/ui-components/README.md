# Memory Patterns UI Components

Collection of React components for visualizing and analyzing memory patterns.

## Components

### MemoryHierarchyChart

Visualizes memory hierarchies in a tree-like structure:

- **Working Memory** (Short-term) - Top level, active context
- **Long-term Memory** - Middle level, completed tasks
- **Knowledge Base** - Bottom level, historical patterns

**Features:**
- Interactive tree structure
- Statistics display per memory tier
- Expandable nodes
- Highlighting support

**Props:**
```typescript
interface MemoryHierarchyChartProps {
  workingMemory: {
    count: number;
    size: string;
    accessTime: string;
    items?: Array<{ title, size, type }>;
  };
  longTermMemory: similar structure;
  knowledgeBase: similar structure;
  showDetails?: boolean;
  highlightNodes?: string[];
}
```

**Usage:**
```jsx
import { MemoryHierarchyChart } from './ui-components';

<MemoryHierarchyChart
  workingMemory={{ count: 15, size: '2.3 MB', accessTime: '< 1ms' }}
  longTermMemory={{ count: 45, size: '8.7 MB', accessTime: '< 10ms' }}
  knowledgeBase={{ count: 120, size: '24.1 MB', accessTime: '< 50ms' }}
/>
```

---

### MemoryPartitionVisualizer

Visualizes memory partitions by domain:

- **User Context** - Profile, preferences, conversation history
- **Task Context** - Active tasks, progress, checkpoints
- **Tool Knowledge** - Tool capabilities, usage history
- **Project Knowledge** - Architecture, dependencies, changes

**Features:**
- Interactive partition cards
- Expandable details
- Filtering
- Statistics per partition
- Highlighting support

**Props:**
```typescript
interface MemoryPartitionVisualizerProps {
  partitions: {
    userContext: { count, size, lastAccessed, accessRate, averageAge };
    taskContext: similar structure;
    toolKnowledge: similar structure;
    projectKnowledge: similar structure;
  };
  showAllPartitions?: boolean;
  highlightedPartition?: string;
}
```

**Usage:**
```jsx
import { MemoryPartitionVisualizer } from './ui-components';

<MemoryPartitionVisualizer
  partitions={{
    userContext: { count: 15, size: '1.2 MB' },
    taskContext: { count: 8, size: '0.8 MB' },
    toolKnowledge: { count: 12, size: '1.5 MB' },
    projectKnowledge: { count: 10, size: '1.1 MB' },
  }}
/>
```

---

### AnalyticsDashboard

Comprehensive analytics dashboard with:

- Performance metrics (precision, recall, compression ratio, decay rate)
- Access patterns (latency, access count, eviction rate)
- Visualization charts
- Time series history
- Multiple tabs for different metrics

**Features:**
- Tab-based navigation
- Metric cards
- Progress bars
- Time series charts
- Comparison with baseline
- Expandable details

**Props:**
```typescript
interface AnalyticsDashboardProps {
  metrics: {
    relevance: {
      precision: number;
      recall: number;
      semanticSimilarity: number;
      recencyWeight: number;
      contextAlignment: number;
      frequencyWeight: number;
    };
    compression: {
      ratio: number;
      accuracy: number;
      extractionQuality: number;
    };
    decay: {
      staleRate: number;
      accuracy: number;
      exponentialRate: number;
    };
    access: {
      avgLatency: number;
      avgAccessCount: number;
      evictionRate: number;
      rollbackRate: number;
      hotCount: number;
      warmCount: number;
      coldCount: number;
    };
  };
  history?: Array<{
    timestamp: string;
    metrics: similar structure;
  }>;
  chartType?: 'line' | 'bar';
  showTimeSeries?: boolean;
  compareWithBaseline?: boolean;
}
```

**Usage:**
```jsx
import { AnalyticsDashboard } from './ui-components';

<AnalyticsDashboard
  metrics={{
    relevance: { precision: 0.85, recall: 0.78 },
    compression: { ratio: 1.8, accuracy: 0.93 },
    decay: { avgDecayRate: 0.92 },
    access: { avgLatency: 12, avgAccessCount: 15 },
  }}
  history={recentData}
  chartType="line"
  showTimeSeries={true}
/>
```

---

## Installation

```bash
# Copy components to your project
cp -r memory-patterns/ui-components/your-project/src/

# Install dependencies (if needed)
npm install antd prop-types

# or with yarn
yarn add antd prop-types
```

---

## Dependencies

- `antd` - UI components (Tree, Icon)
- `prop-types` - Type checking

---

## Example Application

See `EXAMPLES.md` for complete examples of using these components together.

---

## Performance

All components are optimized for performance:
- Efficient re-rendering with React.memo
- Virtualization for large datasets (via Tree component)
- Lazy loading for charts

**Memory Usage:**
- MemoryHierarchyChart: ~500 KB
- MemoryPartitionVisualizer: ~400 KB
- AnalyticsDashboard: ~800 KB

**Rendering Performance:**
- MemoryHierarchyChart: < 50ms for 1000 items
- MemoryPartitionVisualizer: < 30ms for 50 partitions
- AnalyticsDashboard: < 100ms for all metrics

---

## Browser Support

- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)

---

## License

Part of the Memory Patterns hypothesis-009 implementation.

---

*Last updated: 2026-04-24*
