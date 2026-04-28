/**
 * Memory Analytics Dashboard Component
 *
 * Provides analytics and metrics for memory patterns:
 * - Relevance scoring metrics
 * - Memory compression statistics
 * - Decay rates
 * - Access patterns
 * - Performance metrics
 *
 * Usage:
 * ```jsx
 * <AnalyticsDashboard
 *   metrics={{
 *     relevance: { precision: 0.85, recall: 0.78 },
 *     compression: { ratio: 1.8, accuracy: 0.93 },
 *     decay: { avgDecayRate: 0.92 },
 *     access: { avgLatency: 12, avgAccessCount: 15 },
 *   }}
 *   history={historyData}
 *   chartType="line"
 * />
 * ```
 */

import React, { useState } from 'react';
import PropTypes from 'prop-types';

/**
 * Memory Analytics Dashboard Component
 */
const AnalyticsDashboard = ({
  metrics = {},
  history = [],
  chartType = 'line',
  showTimeSeries = true,
  compareWithBaseline = true,
}) => {
  const [activeTab, setActiveTab] = useState('overview');
  const [showDetails, setShowDetails] = useState(false);

  const tabs = [
    { id: 'overview', label: 'Overview' },
    { id: 'relevance', label: 'Relevance' },
    { id: 'compression', label: 'Compression' },
    { id: 'decay', label: 'Decay' },
    { id: 'access', label: 'Access' },
  ];

  const renderOverview = () => {
    return (
      <div className="analytics-overview">
        <div className="metrics-grid">
          <MetricCard
            title="Memory Compression Ratio"
            value={metrics.compression?.ratio || 'N/A'}
            unit=":1"
            description="Size reduction achieved by compression"
            color="#52c41a"
          />
          <MetricCard
            title="Relevance Precision"
            value={metrics.relevance?.precision?.toFixed(2) || 'N/A'}
            unit=""
            description="Percentage of retrieved memories that are relevant"
            color="#1890ff"
          />
          <MetricCard
            title="Relevance Recall"
            value={metrics.relevance?.recall?.toFixed(2) || 'N/A'}
            unit=""
            description="Percentage of relevant memories retrieved"
            color="#722ed1"
          />
          <MetricCard
            title="Average Decay Rate"
            value={metrics.decay?.avgDecayRate?.toFixed(2) || 'N/A'}
            unit=""
            description="Memory staleness detection accuracy"
            color="#fa8c16"
          />
          <MetricCard
            title="Avg Retrieval Latency"
            value={metrics.access?.avgLatency?.toFixed(1) || 'N/A'}
            unit="ms"
            description="Average time to retrieve memory"
            color="#13c2c2"
          />
          <MetricCard
            title="Avg Access Count"
            value={metrics.access?.avgAccessCount?.toFixed(0) || 'N/A'}
            unit=""
            description="Average number of times memory is accessed"
            color="#eb2f96"
          />
        </div>
      </div>
    );
  };

  const renderRelevance = () => {
    return (
      <div className="analytics-relevance">
        <div className="score-display">
          <div className="score-card primary">
            <div className="score-label">Precision</div>
            <div className="score-value">
              {(metrics.relevance?.precision || 0).toFixed(2)}%
            </div>
            <div className="score-bar">
              <div
                className="score-bar-fill"
                style={{
                  width: `${(metrics.relevance?.precision || 0) * 100}%`,
                }}
              />
            </div>
          </div>
          <div className="score-card">
            <div className="score-label">Recall</div>
            <div className="score-value">
              {(metrics.relevance?.recall || 0).toFixed(2)}%
            </div>
            <div className="score-bar">
              <div
                className="score-bar-fill"
                style={{
                  width: `${(metrics.relevance?.recall || 0) * 100}%`,
                }}
              />
            </div>
          </div>
        </div>

        <div className="metrics-details">
          <MetricDetail
            title="Semantic Similarity"
            value={metrics.relevance?.semanticSimilarity?.toFixed(2) || 'N/A'}
            unit=""
          />
          <MetricDetail
            title="Recency Weight"
            value={metrics.relevance?.recencyWeight?.toFixed(2) || 'N/A'}
            unit=""
          />
          <MetricDetail
            title="Context Alignment"
            value={metrics.relevance?.contextAlignment?.toFixed(2) || 'N/A'}
            unit=""
          />
          <MetricDetail
            title="Frequency Weight"
            value={metrics.relevance?.frequencyWeight?.toFixed(2) || 'N/A'}
            unit=""
          />
        </div>
      </div>
    );
  };

  const renderCompression = () => {
    return (
      <div className="analytics-compression">
        <div className="compression-stats">
          <MetricCard
            title="Compression Ratio"
            value={metrics.compression?.ratio || 'N/A'}
            unit=":1"
            description="How much space is saved"
            color="#52c41a"
          />
          <MetricCard
            title="Summarization Accuracy"
            value={metrics.compression?.accuracy?.toFixed(2) || 'N/A'}
            unit="%"
            description="How well summary preserves meaning"
            color="#1890ff"
          />
          <MetricCard
            title="Extraction Quality"
            value={metrics.compression?.extractionQuality?.toFixed(2) || 'N/A'}
            unit="%"
            description="How well entities are extracted"
            color="#722ed1"
          />
        </div>

        <div className="compression-ratio-chart">
          <div className="chart-container">
            <div className="bar-group">
              <div className="bar-label">Raw Size</div>
              <div className="bar">
                <div
                  className="bar-fill"
                  style={{ width: '100%', backgroundColor: '#f5f5f5' }}
                />
                <span className="bar-value">100%</span>
              </div>
            </div>
            <div className="bar-group">
              <div className="bar-label">Compressed Size</div>
              <div className="bar">
                <div
                  className="bar-fill"
                  style={{
                    width: `${(1 / (metrics.compression?.ratio || 1)) * 100}%`,
                    backgroundColor: '#52c41a',
                  }}
                />
                <span className="bar-value">
                  {metrics.compression?.ratio || 0}:1
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  };

  const renderDecay = () => {
    return (
      <div className="analytics-decay">
        <div className="decay-stats">
          <MetricCard
            title="Staleness Detection"
            value={metrics.decay?.staleRate?.toFixed(2) || 'N/A'}
            unit="%"
            description="Rate of detected stale memories"
            color="#fa8c16"
          />
          <MetricCard
            title="Decay Accuracy"
            value={metrics.decay?.accuracy?.toFixed(2) || 'N/A'}
            unit="%"
            description="How accurate the decay model is"
            color="#f5222d"
          />
          <MetricCard
            title="Exponential Decay Rate"
            value={metrics.decay?.exponentialRate?.toFixed(3) || 'N/A'}
            unit=""
            description="Rate constant for exponential decay"
            color="#eb2f96"
          />
        </div>

        <div className="decay-curve-chart">
          <div className="chart-legend">
            <div className="legend-item">
              <span className="legend-color" style={{ backgroundColor: '#52c41a' }} />
              <span>Decayed</span>
            </div>
            <div className="legend-item">
              <span className="legend-color" style={{ backgroundColor: '#1890ff' }} />
              <span>Active</span>
            </div>
          </div>
          {/* Decay curve visualization would be rendered here */}
          <div className="chart-placeholder">
            <p>Decay curve visualization</p>
            <p className="small-text">
              Shows memory importance over time with exponential decay
            </p>
          </div>
        </div>
      </div>
    );
  };

  const renderAccess = () => {
    return (
      <div className="analytics-access">
        <div className="access-stats">
          <MetricCard
            title="Avg Retrieval Latency"
            value={metrics.access?.avgLatency?.toFixed(1) || 'N/A'}
            unit="ms"
            description="Time to retrieve memory"
            color="#13c2c2"
          />
          <MetricCard
            title="Avg Access Count"
            value={metrics.access?.avgAccessCount?.toFixed(0) || 'N/A'}
            unit=""
            description="How often memory is accessed"
            color="#13c2c2"
          />
          <MetricCard
            title="Eviction Success Rate"
            value={metrics.access?.evictionRate?.toFixed(2) || 'N/A'}
            unit="%"
            description="Rate of successful memory eviction"
            color="#36cfc9"
          />
          <MetricCard
            title="Rollback Success Rate"
            value={metrics.access?.rollbackRate?.toFixed(2) || 'N/A'}
            unit="%"
            description="Rate of successful rollback"
            color="#2f54eb"
          />
        </div>

        <div className="access-patterns">
          <h4>Access Patterns</h4>
          <div className="pattern-list">
            <PatternItem
              name="Hot Memory"
              description="Frequently accessed (count > 50)"
              count={metrics.access?.hotCount || 0}
              threshold="50"
            />
            <PatternItem
              name="Warm Memory"
              description="Moderately accessed (20-50)"
              count={metrics.access?.warmCount || 0}
              threshold="20-50"
            />
            <PatternItem
              name="Cold Memory"
              description="Rarely accessed (< 20)"
              count={metrics.access?.coldCount || 0}
              threshold="< 20"
            />
          </div>
        </div>
      </div>
    );
  };

  const renderTab = () => {
    switch (activeTab) {
      case 'overview':
        return renderOverview();
      case 'relevance':
        return renderRelevance();
      case 'compression':
        return renderCompression();
      case 'decay':
        return renderDecay();
      case 'access':
        return renderAccess();
      default:
        return renderOverview();
    }
  };

  return (
    <div className="analytics-dashboard">
      <div className="dashboard-header">
        <h3>Memory Analytics</h3>
        <div className="dashboard-controls">
          {showDetails && (
            <button
              onClick={() => setShowDetails(!showDetails)}
              className="toggle-details-btn"
            >
              {showDetails ? 'Hide Details' : 'Show Details'}
            </button>
          )}
        </div>
      </div>

      {/* Tabs */}
      <div className="analytics-tabs">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            className={`tab ${activeTab === tab.id ? 'active' : ''}`}
            onClick={() => setActiveTab(tab.id)}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Content */}
      <div className="analytics-content">
        {renderTab()}
      </div>

      {/* History */}
      {showTimeSeries && history.length > 0 && (
        <div className="analytics-history">
          <h4>Performance History</h4>
          {/* Time series chart would be rendered here */}
          <div className="history-placeholder">
            <p>Time series visualization</p>
            <p className="small-text">
              Shows performance metrics over time
            </p>
          </div>
        </div>
      )}

      <style jsx>{`
        .analytics-dashboard {
          padding: 20px;
          font-family: 'Inter', sans-serif;
        }

        .dashboard-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 20px;
        }

        .dashboard-header h3 {
          margin: 0;
          color: #1a1a1a;
        }

        .dashboard-controls {
          display: flex;
          gap: 10px;
        }

        .toggle-details-btn {
          padding: 8px 16px;
          border: 1px solid #d9d9d9;
          border-radius: 4px;
          background: white;
          cursor: pointer;
          font-size: 13px;
          transition: all 0.2s;
        }

        .toggle-details-btn:hover {
          border-color: #1890ff;
          color: #1890ff;
        }

        .analytics-tabs {
          display: flex;
          gap: 5px;
          margin-bottom: 20px;
          border-bottom: 1px solid #e0e0e0;
        }

        .tab {
          padding: 10px 20px;
          border: none;
          background: none;
          cursor: pointer;
          font-size: 14px;
          color: #666;
          border-bottom: 2px solid transparent;
          transition: all 0.2s;
        }

        .tab:hover {
          color: #1890ff;
        }

        .tab.active {
          color: #1890ff;
          border-bottom-color: #1890ff;
        }

        .analytics-content {
          background: #f8f9fa;
          border-radius: 8px;
          padding: 20px;
          min-height: 200px;
        }

        .metrics-grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
          gap: 15px;
        }

        .score-display {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
          gap: 15px;
          margin-bottom: 20px;
        }

        .score-card {
          background: white;
          padding: 20px;
          border-radius: 8px;
          text-align: center;
          box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }

        .score-card.primary {
          background: linear-gradient(135deg, #1890ff, #36cfc9);
          color: white;
        }

        .score-label {
          font-size: 12px;
          opacity: 0.9;
          margin-bottom: 8px;
        }

        .score-value {
          font-size: 32px;
          font-weight: 600;
          margin-bottom: 12px;
        }

        .score-bar {
          height: 6px;
          background: rgba(255, 255, 255, 0.3);
          border-radius: 3px;
          overflow: hidden;
        }

        .score-bar-fill {
          height: 100%;
          background: white;
          transition: width 0.5s ease;
        }

        .metrics-details {
          display: grid;
          gap: 10px;
        }

        .compression-ratio-chart {
          margin-top: 20px;
        }

        .bar-group {
          margin-bottom: 12px;
        }

        .bar-label {
          font-size: 12px;
          color: #666;
          margin-bottom: 4px;
        }

        .bar {
          display: flex;
          align-items: center;
          height: 24px;
          background: #f5f5f5;
          border-radius: 4px;
          overflow: hidden;
        }

        .bar-fill {
          height: 100%;
          transition: width 0.5s ease;
        }

        .bar-value {
          padding-left: 10px;
          font-size: 13px;
          font-weight: 600;
          color: #1a1a1a;
        }

        .decay-curve-chart {
          margin-top: 20px;
        }

        .chart-legend {
          display: flex;
          gap: 15px;
          margin-bottom: 15px;
        }

        .legend-item {
          display: flex;
          align-items: center;
          gap: 6px;
          font-size: 13px;
        }

        .legend-color {
          width: 12px;
          height: 12px;
          border-radius: 2px;
        }

        .chart-placeholder {
          background: white;
          padding: 30px;
          border-radius: 8px;
          text-align: center;
        }

        .chart-placeholder p {
          margin: 5px 0;
          color: #666;
        }

        .small-text {
          font-size: 12px;
        }

        .access-patterns {
          margin-top: 20px;
        }

        .access-patterns h4 {
          margin: 0 0 15px 0;
          font-size: 14px;
          color: #1a1a1a;
        }

        .pattern-list {
          display: flex;
          flex-direction: column;
          gap: 10px;
        }

        .analytics-history {
          margin-top: 20px;
        }

        .analytics-history h4 {
          margin: 0 0 10px 0;
          font-size: 14px;
          color: #1a1a1a;
        }

        .history-placeholder {
          background: white;
          padding: 30px;
          border-radius: 8px;
          text-align: center;
        }
      `}</style>
    </div>
  );
};

// Helper components
const MetricCard = ({ title, value, unit, description, color }) => (
  <div className="metric-card" style={{ borderLeft: `4px solid ${color}` }}>
    <div className="metric-title">{title}</div>
    <div className="metric-value">
      {value}
      <span className="metric-unit">{unit}</span>
    </div>
    <div className="metric-description">{description}</div>
  </div>
);

const MetricDetail = ({ title, value, unit }) => (
  <div className="metric-detail">
    <span className="metric-detail-title">{title}:</span>
    <span className="metric-detail-value">
      {value}
      <span className="metric-detail-unit">{unit}</span>
    </span>
  </div>
);

const PatternItem = ({ name, description, count, threshold }) => (
  <div className="pattern-item">
    <div className="pattern-name">{name}</div>
    <div className="pattern-description">{description}</div>
    <div className="pattern-stats">
      <span>Count: {count}</span>
      <span>Threshold: {threshold}</span>
    </div>
  </div>
);

AnalyticsDashboard.propTypes = {
  metrics: PropTypes.shape({
    relevance: PropTypes.shape({
      precision: PropTypes.number,
      recall: PropTypes.number,
      semanticSimilarity: PropTypes.number,
      recencyWeight: PropTypes.number,
      contextAlignment: PropTypes.number,
      frequencyWeight: PropTypes.number,
    }),
    compression: PropTypes.shape({
      ratio: PropTypes.number,
      accuracy: PropTypes.number,
      extractionQuality: PropTypes.number,
    }),
    decay: PropTypes.shape({
      staleRate: PropTypes.number,
      accuracy: PropTypes.number,
      exponentialRate: PropTypes.number,
    }),
    access: PropTypes.shape({
      avgLatency: PropTypes.number,
      avgAccessCount: PropTypes.number,
      evictionRate: PropTypes.number,
      rollbackRate: PropTypes.number,
      hotCount: PropTypes.number,
      warmCount: PropTypes.number,
      coldCount: PropTypes.number,
    }),
  }),
  history: PropTypes.array,
  chartType: PropTypes.string,
  showTimeSeries: PropTypes.bool,
  compareWithBaseline: PropTypes.bool,
};

export default AnalyticsDashboard;
