# Stage reference: Quality Review

> Loaded on demand by the `/team` interpreter for the `review` stage.
> Governance (classification, interpreter loop, gates, DoD) lives in `commands/team.md`.
> This file holds only the prompt templates / criteria for running the stage.

---

### PHASE 6: QUALITY REVIEW (Parallel)

**Goal**: Ensure quality, find issues

**Actions**:
1. Launch **review agents IN PARALLEL** based on scope:

   **BACKEND REVIEW AGENTS:**
   ```
   Agent 1 (qa):
   "Review backend implementation for:
    - Test coverage (write tests if missing)
    - Functional correctness
    - Edge case handling
    Report issues with confidence score (0-100).
    Only report issues with confidence >= 80."

   Agent 2 (code-reviewer):
   "Review implementation for:
    - Code quality (simplicity, DRY, elegance)
    - Project conventions compliance
    - Maintainability
    Report issues with confidence score (0-100).
    Only report issues with confidence >= 80."

   Agent 3 (security-tester): [if auth/data/API involved]
   "Review implementation for:
    - Security vulnerabilities (OWASP Top 10)
    - Input validation
    - Authentication/authorization
    Report issues with confidence score (0-100).
    Only report issues with confidence >= 80."

   Agent 4 (devops): [if infrastructure changes]
   "Review implementation for:
    - Docker/Kubernetes configuration
    - CI/CD impacts
    - Environment variables
    Report issues."
   ```

   **FRONTEND REVIEW AGENTS (for Mini App changes):**
   ```
   Agent 5 (qa):
   "Review frontend implementation for:
    - Component testing
    - TypeScript type safety
    - State management correctness
    Report issues with confidence score (0-100)."

   Agent 6 (manual-qa):
   "Test Mini App UI at http://localhost:5173:
    - Navigate through new features
    - Verify API calls (read_network_requests)
    - Check for console errors (read_console_messages)
    - Take screenshots of key states
    - Report any UI/UX issues found."

   Agent 7 (security-tester):
   "Review frontend security:
    - XSS prevention (no dangerouslySetInnerHTML)
    - initData handling
    - Sensitive data exposure
    - Console logging of secrets
    Report issues with confidence score (0-100)."
   ```

   **MOBILE REVIEW AGENTS (for KMP Mobile App changes):**
   ```
   Agent (qa):
   "Review mobile implementation for:
    - Compose-arch compliance (Screen/View/Component layers)
    - Component state handling (Value<T>, not StateFlow)
    - UseCase patterns (Result<T> return)
    - Decompose navigation correctness
    Report issues with confidence score (0-100)."

   Agent (manual-qa):
   "Test KMP Mobile App on Android/iOS:
    - Launch app: launch_app(package: 'com.your-project.admin')
    - Navigate through new features: get_ui(), tap(), swipe()
    - Verify all screens render correctly: screenshot()
    - Check for crashes: get_logs(level: 'E')
    - Test state preservation on back navigation
    - Verify loading/error/empty states visible
    - Report any UI/UX issues found with screenshots."

   Agent (code-reviewer):
   "Review KMP implementation for:
    - One class per file rule
    - No logic in Screen/View layers
    - Proper DI with Metro
    - Platform-specific code isolation
    Report issues with confidence score (0-100)."
   ```

   **FULL-STACK REVIEW** (launch all applicable agents in parallel)

2. Consolidate findings by severity:
   - **CRITICAL** (confidence 90-100): Must fix
   - **HIGH** (confidence 80-89): Should fix
   - **MEDIUM** (confidence 70-79): Consider fixing

3. Present to user:
   ```
   Quality Review Results:

   CRITICAL ISSUES (must fix):
   1. [Issue] - [file:line] - Confidence: 95%

   HIGH PRIORITY (should fix):
   1. [Issue] - [file:line] - Confidence: 85%

   TESTS: [passed/failed count]

   What would you like to do?
   (A) Fix all issues now
   (B) Fix critical only, defer others
   (C) Proceed as-is
   ```

**Checkpoint**: ✋ WAIT for user decision

---

