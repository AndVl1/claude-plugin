/**
 * Memory Hierarchy Chart Component
 *
 * Visualizes memory hierarchies in a tree-like structure:
 * - Working Memory (Short-term) - Top level, active context
 * - Long-term Memory - Middle level, completed tasks
 * - Knowledge Base - Bottom level, historical patterns
 *
 * Usage:
 * ```jsx
 * <MemoryHierarchyChart
 *   workingMemory={{ count: 15, size: '2.3 MB' }}
 *   longTermMemory={{ count: 45, size: '8.7 MB' }}
 *   knowledgeBase={{ count: 120, size: '24.1 MB' }}
 * />
 * ```
 */

import React, { useState, useEffect } from 'react';
import PropTypes from 'prop-types';
import { Tree, Icon } from 'antd';

const { TreeNode } = Tree;

/**
 * Memory Hierarchy Chart Component
 */
const MemoryHierarchyChart = ({
  workingMemory,
  longTermMemory,
  knowledgeBase,
  showDetails = true,
  highlightNodes = null,
}) => {
  const [selectedNode, setSelectedNode] = useState(null);
  const [chartData, setChartData] = useState([]);

  useEffect(() => {
    setChartData([
      {
        title: 'Working Memory',
        key: 'working',
        icon: 'clock-circle',
        children: workingMemory?.items?.map((item, index) => ({
          title: item,
          key: `working-${index}`,
          size: item.size || 'Unknown',
          type: item.type || 'Context',
          isHighlighted: highlightNodes?.includes(`working-${index}`),
        })) || [],
        stats: {
          count: workingMemory?.count || 0,
          size: workingMemory?.size || '0 MB',
          accessTime: workingMemory?.accessTime || '< 1ms',
        },
      },
      {
        title: 'Long-term Memory',
        key: 'longterm',
        icon: 'database',
        children: longTermMemory?.items?.map((item, index) => ({
          title: item,
          key: `longterm-${index}`,
          size: item.size || 'Unknown',
          type: item.type || 'Task',
          isHighlighted: highlightNodes?.includes(`longterm-${index}`),
        })) || [],
        stats: {
          count: longTermMemory?.count || 0,
          size: longTermMemory?.size || '0 MB',
          accessTime: longTermMemory?.accessTime || '< 10ms',
        },
      },
      {
        title: 'Knowledge Base',
        key: 'knowledge',
        icon: 'book',
        children: knowledgeBase?.items?.map((item, index) => ({
          title: item,
          key: `knowledge-${index}`,
          size: item.size || 'Unknown',
          type: item.type || 'Pattern',
          isHighlighted: highlightNodes?.includes(`knowledge-${index}`),
        })) || [],
        stats: {
          count: knowledgeBase?.count || 0,
          size: knowledgeBase?.size || '0 MB',
          accessTime: knowledgeBase?.accessTime || '< 50ms',
        },
      },
    ]);
  }, [workingMemory, longTermMemory, knowledgeBase, highlightNodes]);

  const renderStats = (stats, title) => {
    if (!showDetails || !stats) return null;

    return (
      <div className="memory-stats">
        <h4>{title}</h4>
        <div className="stats-grid">
          <div className="stat-item">
            <Icon type="number" />
            <span>Count: {stats.count}</span>
          </div>
          <div className="stat-item">
            <Icon type="container" />
            <span>Size: {stats.size}</span>
          </div>
          <div className="stat-item">
            <Icon type="clock-circle" />
            <span>Access: {stats.accessTime}</span>
          </div>
        </div>
      </div>
    );
  };

  const renderTreeNodes = (data) => {
    return data.map((node) => {
      const hasChildren = node.children && node.children.length > 0;

      return (
        <TreeNode
          key={node.key}
          title={
            <div
              className={`tree-node ${node.isHighlighted ? 'highlighted' : ''}`}
            >
              <Icon type={node.icon} />
              <span>{node.title}</span>
            </div>
          }
        >
          {hasChildren ? renderTreeNodes(node.children) : null}
        </TreeNode>
      );
    });
  };

  const handleSelect = (selectedKeys, info) => {
    setSelectedNode(selectedKeys[0]);
  };

  return (
    <div className="memory-hierarchy-chart">
      <h3>Memory Hierarchy</h3>

      {showDetails && (
        <div className="hierarchy-stats">
          {chartData.map((item, index) => (
            <div key={item.key} className="stat-card">
              {renderStats(item.stats, item.title)}
            </div>
          ))}
        </div>
      )}

      <Tree
        showIcon
        showLine
        defaultExpandAll
        onSelect={handleSelect}
        treeData={chartData}
      >
        {chartData.map((node) => renderTreeNodes(node))}
      </Tree>

      {selectedNode && (
        <div className="node-details">
          <h4>Selected Node: {selectedNode}</h4>
          {/* Node details would be shown here */}
        </div>
      )}

      <style jsx>{`
        .memory-hierarchy-chart {
          padding: 20px;
          font-family: 'Inter', sans-serif;
        }

        h3 {
          margin-bottom: 20px;
          color: #1a1a1a;
        }

        .hierarchy-stats {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
          gap: 15px;
          margin-bottom: 20px;
        }

        .stat-card {
          background: #f8f9fa;
          padding: 15px;
          border-radius: 8px;
          border: 1px solid #e0e0e0;
        }

        .stat-card h4 {
          margin: 0 0 10px 0;
          font-size: 14px;
          color: #666;
        }

        .stats-grid {
          display: grid;
          gap: 8px;
        }

        .stat-item {
          display: flex;
          align-items: center;
          gap: 8px;
          font-size: 13px;
          color: #333;
        }

        .tree-node {
          display: flex;
          align-items: center;
          gap: 8px;
          padding: 4px 0;
        }

        .tree-node.highlighted {
          background: #fff7e6;
          border-radius: 4px;
        }

        .node-details {
          margin-top: 20px;
          padding: 15px;
          background: #f8f9fa;
          border-radius: 8px;
          border: 1px solid #e0e0e0;
        }

        .node-details h4 {
          margin: 0 0 10px 0;
          color: #1a1a1a;
        }
      `}</style>
    </div>
  );
};

MemoryHierarchyChart.propTypes = {
  workingMemory: PropTypes.shape({
    count: PropTypes.number,
    size: PropTypes.string,
    accessTime: PropTypes.string,
    items: PropTypes.arrayOf(
      PropTypes.shape({
        title: PropTypes.string,
        size: PropTypes.string,
        type: PropTypes.string,
      })
    ),
  }),
  longTermMemory: PropTypes.shape({
    count: PropTypes.number,
    size: PropTypes.string,
    accessTime: PropTypes.string,
    items: PropTypes.arrayOf(
      PropTypes.shape({
        title: PropTypes.string,
        size: PropTypes.string,
        type: PropTypes.string,
      })
    ),
  }),
  knowledgeBase: PropTypes.shape({
    count: PropTypes.number,
    size: PropTypes.string,
    accessTime: PropTypes.string,
    items: PropTypes.arrayOf(
      PropTypes.shape({
        title: PropTypes.string,
        size: PropTypes.string,
        type: PropTypes.string,
      })
    ),
  }),
  showDetails: PropTypes.bool,
  highlightNodes: PropTypes.arrayOf(PropTypes.string),
};

export default MemoryHierarchyChart;
