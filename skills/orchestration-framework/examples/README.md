# Orchestration Framework Examples

This directory contains examples demonstrating different use cases of the orchestration framework.

## Available Examples

### 1. Basic Orchestrator

**File:** `example-basic-orchestration.md`

Demonstrates the basic usage of the orchestrator with a simple skill chain.

**What you'll learn:**
- Creating a chain of beads
- Setting up the orchestrator
- Handling success and failure cases
- Configuring error recovery

**Key concepts:**
- Bead interfaces
- Context passing
- Result handling
- Basic configuration

---

### 2. ReAct Pattern Reasoning

**File:** `example-react-reasoning.md`

Demonstrates the ReAct pattern for explicit reasoning before action.

**What you'll learn:**
- Implementing a reasoner function
- Defining executor functions
- Evaluating reasoning quality
- Iterative refinement

**Key concepts:**
- ReActThought structure
- Thought-process-driven workflows
- Action-observation cycles
- Quality evaluation

---

### 3. Tree-of-Thoughts Exploration

**File:** `example-tree-of-thoughts.md`

Demonstrates the Tree-of-Thoughts pattern for exploring multiple solutions.

**What you'll learn:**
- Building thought trees
- Configuring branching factors
- Evaluating paths
- Selecting the best solution

**Key concepts:**
- ThoughtNode hierarchy
- Branching and depth control
- Path evaluation
- Best path selection

---

### 4. Error Recovery

**File:** `example-error-recovery.md`

Demonstrates error handling and recovery strategies.

**What you'll learn:**
- Configuring recovery strategies
- Defining recoverable errors
- Implementing retry logic
- Fallback mechanisms

**Key concepts:**
- RecoveryConfig
- Fallback strategies
- Error classification
- Retry mechanisms

---

### 5. Complete Workflow

**File:** `example-complete-workflow.md`

Demonstrates a complete real-world workflow combining all patterns.

**What you'll learn:**
- Integrating multiple patterns
- Real-world scenario
- Performance optimization
- Production considerations

**Key concepts:**
- Pattern combination
- Real-world application
- Performance tuning
- Production readiness

---

## Getting Started

### Step 1: Read the Concept

Start with `example-basic-orchestration.md` to understand the fundamentals.

### Step 2: Try the Examples

Follow along with the examples in the SKILL.md file.

### Step 3: Build Your Own

Use the patterns as a foundation to build your own workflows.

## Code Reference

For complete API reference, see:
- SKILL.md - Main documentation
- README.md - Overview and quick start
- src/main/kotlin/ - Source code (when available)

## Questions?

See the SKILL.md for detailed explanations and troubleshooting.
