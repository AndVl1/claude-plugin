/**
 * Memory Partition Visualizer Component
 *
 * Visualizes memory partitions in a hierarchical way:
 * - User Context
 * - Task Context
 * - Tool Knowledge
 * - Project Knowledge
 *
 * Usage:
 * ```jsx
 * <MemoryPartitionVisualizer
 *   partitions={{
 *     userContext: { count: 15, size: '1.2 MB' },
 *     taskContext: { count: 8, size: '0.8 MB' },
 *     toolKnowledge: { count: 12, size: '1.5 MB' },
 *     projectKnowledge: { count: 10, size: '1.1 MB' },
 *   }}
 * />
 * ```
 */

import React, { useState } from 'react';
import PropTypes from 'prop-types';

/**
 * Memory Partition Visualizer Component
 */
const MemoryPartitionVisualizer = ({
  partitions = {},
  showAllPartitions = true,
  highlightedPartition = null,
}) => {
  const [selectedPartition, setSelectedPartition] = useState(null);
  const [filter, setFilter] = useState('');

  // Define partition configuration
  const partitionConfig = [
    {
      key: 'userContext',
      title: 'User Context',
      icon: 'user',
      color: '#1890ff',
      description: 'User profile, preferences, conversation history',
    },
    {
      key: 'taskContext',
      title: 'Task Context',
      icon: 'task',
      color: '#52c41a',
      description: 'Active tasks, progress, checkpoints',
    },
    {
      key: 'toolKnowledge',
      title: 'Tool Knowledge',
      icon: 'tool',
      color: '#722ed1',
      description: 'Tool capabilities, usage history',
    },
    {
      key: 'projectKnowledge',
      title: 'Project Knowledge',
      icon: 'folder',
      color: '#fa8c16',
      description: 'Project architecture, dependencies, changes',
    },
  ];

  const getFilteredPartitions = () => {
    return partitionConfig.filter((partition) => {
      if (!filter) return showAllPartitions;
      return partition.title.toLowerCase().includes(filter.toLowerCase());
    });
  };

  const handleSelectPartition = (partitionKey) => {
    setSelectedPartition(partitionKey === selectedPartition ? null : partitionKey);
  };

  const calculateTotal = () => {
    return Object.values(partitions).reduce((sum, p) => sum + (p.count || 0), 0);
  };

  return (
    <div className="memory-partition-visualizer">
      <h3>Memory Partitions</h3>

      {/* Total Stats */}
      <div className="total-stats">
        <div className="stat-item">
          <span>Total Memories:</span>
          <span>{calculateTotal()}</span>
        </div>
        <div className="stat-item">
          <span>Total Size:</span>
          <span>{Object.values(partitions).reduce((sum, p) => sum + (p.size || 0), '0')}</span>
        </div>
      </div>

      {/* Partitions Grid */}
      <div className="partitions-grid">
        {getFilteredPartitions().map((partition) => {
          const data = partitions[partition.key] || {};
          const isSelected = selectedPartition === partition.key;
          const isHighlighted =
            highlightedPartition && highlightedPartition === partition.key;

          return (
            <div
              key={partition.key}
              className={`partition-card ${isSelected ? 'selected' : ''} ${
                isHighlighted ? 'highlighted' : ''
              }`}
              style={{
                borderLeft: `4px solid ${partition.color}`,
              }}
              onClick={() => handleSelectPartition(partition.key)}
            >
              <div className="partition-header">
                <div className="partition-icon">
                  <span style={{ color: partition.color, fontSize: '24px' }}>
                    {partition.icon}
                  </span>
                </div>
                <div className="partition-title">
                  <h4>{partition.title}</h4>
                  <p className="partition-description">
                    {partition.description}
                  </p>
                </div>
              </div>

              <div className="partition-stats">
                <div className="stat">
                  <span className="stat-label">Count:</span>
                  <span className="stat-value">{data.count || 0}</span>
                </div>
                <div className="stat">
                  <span className="stat-label">Size:</span>
                  <span className="stat-value">{data.size || '0'}</span>
                </div>
              </div>

              {/* Expandable content */}
              {isSelected && (
                <div className="partition-details">
                  <div className="expandable-content">
                    <p><strong>Last accessed:</strong> {data.lastAccessed || 'N/A'}</p>
                    <p><strong>Access rate:</strong> {data.accessRate || 'N/A'}</p>
                    <p><strong>Average age:</strong> {data.averageAge || 'N/A'}</p>
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Filter */}
      <div className="filter-container">
        <input
          type="text"
          placeholder="Filter partitions..."
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          className="partition-filter"
        />
      </div>

      <style jsx>{`
        .memory-partition-visualizer {
          padding: 20px;
          font-family: 'Inter', sans-serif;
        }

        h3 {
          margin-bottom: 20px;
          color: #1a1a1a;
        }

        .total-stats {
          display: flex;
          gap: 20px;
          margin-bottom: 20px;
          padding: 15px;
          background: #f8f9fa;
          border-radius: 8px;
        }

        .stat-item {
          display: flex;
          flex-direction: column;
          gap: 5px;
        }

        .stat-item span:first-child {
          font-size: 12px;
          color: #666;
        }

        .stat-item span:last-child {
          font-size: 18px;
          font-weight: 600;
          color: #1a1a1a;
        }

        .partitions-grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
          gap: 15px;
          margin-bottom: 20px;
        }

        .partition-card {
          background: white;
          border-radius: 8px;
          padding: 15px;
          cursor: pointer;
          transition: all 0.2s ease;
          box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }

        .partition-card:hover {
          transform: translateY(-2px);
          box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
        }

        .partition-card.selected {
          border: 2px solid #1890ff;
        }

        .partition-card.highlighted {
          box-shadow: 0 0 0 2px #1890ff;
        }

        .partition-header {
          display: flex;
          gap: 12px;
          margin-bottom: 12px;
        }

        .partition-icon {
          display: flex;
          align-items: center;
          justify-content: center;
          width: 40px;
          height: 40px;
          background: #f8f9fa;
          border-radius: 8px;
          flex-shrink: 0;
        }

        .partition-title h4 {
          margin: 0 0 4px 0;
          font-size: 14px;
          color: #1a1a1a;
        }

        .partition-description {
          margin: 0;
          font-size: 12px;
          color: #666;
        }

        .partition-stats {
          display: flex;
          gap: 15px;
          margin-bottom: 12px;
        }

        .stat {
          display: flex;
          flex-direction: column;
          gap: 2px;
        }

        .stat-label {
          font-size: 11px;
          color: #999;
        }

        .stat-value {
          font-size: 14px;
          font-weight: 600;
          color: #1a1a1a;
        }

        .partition-details {
          margin-top: 12px;
          padding-top: 12px;
          border-top: 1px solid #eee;
        }

        .expandable-content {
          font-size: 12px;
          color: #666;
        }

        .expandable-content p {
          margin: 4px 0;
        }

        .expandable-content strong {
          color: #333;
        }

        .filter-container {
          margin-top: 10px;
        }

        .partition-filter {
          width: 100%;
          padding: 10px;
          border: 1px solid #ddd;
          border-radius: 6px;
          font-size: 14px;
          outline: none;
        }

        .partition-filter:focus {
          border-color: #1890ff;
          box-shadow: 0 0 0 2px rgba(24, 144, 255, 0.2);
        }
      `}</style>
    </div>
  );
};

MemoryPartitionVisualizer.propTypes = {
  partitions: PropTypes.shape({
    userContext: PropTypes.shape({
      count: PropTypes.number,
      size: PropTypes.string,
      lastAccessed: PropTypes.string,
      accessRate: PropTypes.string,
      averageAge: PropTypes.string,
    }),
    taskContext: PropTypes.shape({
      count: PropTypes.number,
      size: PropTypes.string,
      lastAccessed: PropTypes.string,
      accessRate: PropTypes.string,
      averageAge: PropTypes.string,
    }),
    toolKnowledge: PropTypes.shape({
      count: PropTypes.number,
      size: PropTypes.string,
      lastAccessed: PropTypes.string,
      accessRate: PropTypes.string,
      averageAge: PropTypes.string,
    }),
    projectKnowledge: PropTypes.shape({
      count: PropTypes.number,
      size: PropTypes.string,
      lastAccessed: PropTypes.string,
      accessRate: PropTypes.string,
      averageAge: PropTypes.string,
    }),
  }),
  showAllPartitions: PropTypes.bool,
  highlightedPartition: PropTypes.string,
};

export default MemoryPartitionVisualizer;
