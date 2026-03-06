# iterative-refinement Skill

**Pattern:** Ralph Loop (Iterative Refinement)

**Purpose:** Enable agents to iteratively refine their work through self-correction loops before presenting final output.

**Author:** Klavdii R&D
**Version:** 1.0.0

---

## Overview

The Ralph Loop pattern enables agents to produce higher-quality work through intentional iteration. Instead of presenting an initial solution immediately, agents:
1. Generate an initial version
2. Perform a self-review against quality criteria
3. Identify improvements
4. Refine and re-submit
5. Finalize when all criteria met

This pattern is particularly valuable for:
- Complex problem solving where initial solutions are imperfect
- Code generation requiring multiple iterations
- Research tasks with evolving understanding
- Test suite generation needing refinement

---

## Core Concept

```
Generate Initial → Self-Review → Identify Gaps → Refine → Repeat → Finalize
```

Each iteration follows the same pattern:
1. **Generate**: Produce work based on requirements
2. **Review**: Evaluate against quality criteria
3. **Fix**: Apply corrections
4. **Report**: Show evidence of iteration

---

## Self-Review Checklist

After generating any significant piece of work, run through this 6-point self-review:

### 1. Functional Correctness ✅

- [ ] All requirements explicitly stated and addressed?
- [ ] Edge cases handled (null, empty, boundary values)?
- [ ] Error cases handled (invalid input, failures)?
- [ ] Business logic correct and consistent with requirements?
- [ ] No missing functionality?

**Quick Check:** Can I trace every requirement from the spec to the implementation?

### 2. Code Quality 🔍

- [ ] Follows project coding conventions (naming, structure, style)?
- [ ] No code smells (duplicate code, long methods, complex nesting)?
- [ ] Appropriate error handling (try-catch, validation, fallbacks)?
- [ ] Type safety respected (no implicit casts)?
- [ ] No TODOs or temporary workarounds?

**Quick Check:** Would I accept this code from another developer?

### 3. Integration 🧩

- [ ] Works with existing code in the codebase?
- [ ] Correctly imports and uses dependencies?
- [ ] No breaking changes to existing APIs?
- [ ] Configured correctly (env vars, settings, config files)?
- [ ] Compatible with other skills/workflows?

**Quick Check:** Will this integrate seamlessly with existing code?

### 4. Documentation 📚

- [ ] Code clearly documented (functions, classes, logic)?
- [ ] Examples provided (usage, integration, edge cases)?
- [ ] Comments explain *why*, not just *what*?
- [ ] README or inline docs clear and complete?
- [ ] Change log or migration guide if applicable?

**Quick Check:** Can a new developer understand this from documentation alone?

### 5. Performance ⚡

- [ ] No obvious inefficiencies (N+1 queries, unnecessary loops)?
- [ ] Appropriate data structures chosen?
- [ ] Caching used where beneficial?
- [ ] Async operations handled correctly?
- [ ] Resource cleanup proper (close streams, release locks)?

**Quick Check:** Can I identify performance improvements if needed?

### 6. Testing 🧪

- [ ] Unit tests pass (if applicable)?
- [ ] Integration tests pass (if applicable)?
- [ ] Edge cases covered (null, empty, boundary)?
- [ ] Error cases tested (exceptions, failures)?
- [ ] Manual testing performed (if no automated tests)?

**Quick Check:** Would I be confident deploying this without manual review?

---

## Implementation Workflow

### Phase 1: Generate Initial Work

```markdown
## Developer Workflow - Initial Generation

1. **Analyze Requirements**
   - Read requirements document
   - Identify constraints and dependencies
   - Ask clarifying questions if needed

2. **Generate Initial Solution**
   - Follow coding conventions
   - Include basic error handling
   - Add TODOs for known limitations

3. **Present Preview**
   - Show what you're building
   - Explain key decisions
   - Ask for early feedback
```

### Phase 2: Ralph Loop Self-Review

After generating code or design:

```markdown
## Self-Review Phase

1. **Review Against Checklist**
   - Go through all 6 categories above
   - Mark each item as ✅ or ❌
   - Note any ❌ items

2. **Identify Improvements**
   - For each ❌ item, identify:
     - What needs fixing
     - How to fix it
     - Impact on rest of code

3. **Refine Implementation**
   - Apply fixes to identified issues
   - Update related code
   - Re-test if needed

4. **Report Iteration**
   - Document what was fixed
   - Show evidence of iteration
   - Present improved version
```

### Phase 3: Finalize Work

```markdown
## Finalization Phase

1. **Confirm All Criteria Met**
   - All 6 checklist items ✅
   - No TODOs remaining
   - All requirements satisfied

2. **Complete Documentation**
   - Update README
   - Add usage examples
   - Document any decisions made

3. **Create Handoff**
   - Prepare context for next skill
   - Include self-review results
   - Flag any known limitations

4. **Present Final Version**
   - Show complete, refined work
   - Document iteration history
   - Ready for QA/Review
```

---

## Integration Examples

### Example 1: Code Generation with Ralph Loop

```markdown
## Feature: User Authentication

### Iteration 1 (Initial)
- Generated login endpoint with basic validation
- Used simple password comparison
- No rate limiting
- No password hashing

### Ralph Loop Review (Iteration 1)
1. ✅ Functional Correctness - Basic requirements met
2. ❌ Code Quality - No password hashing (security issue)
3. ❌ Integration - No rate limiting (could be abused)
4. ❌ Performance - Simple comparison is vulnerable
5. ✅ Documentation - Basic comments
6. ❌ Testing - No test cases

### Iteration 2 (Refined)
- Implemented bcrypt password hashing
- Added rate limiting (5 requests/minute per user)
- Updated documentation with security considerations
- Added unit tests for authentication
- Added integration test with rate limiting

### Ralph Loop Review (Iteration 2)
1. ✅ Functional Correctness - All requirements met
2. ✅ Code Quality - Uses secure hashing, proper error handling
3. ✅ Integration - Compatible with existing user service
4. ✅ Documentation - Comprehensive security docs
5. ✅ Performance - Bcrypt is appropriately slow, rate limiting prevents brute force
6. ✅ Testing - Unit tests + integration tests

### Final Output
- Authentication fully functional
- Passwords securely hashed
- Rate limiting active
- Comprehensive documentation
- All tests passing
```

### Example 2: Research Task with Iteration

```markdown
## Research: Impact of AI on Software Development

### Iteration 1 (Initial)
- Gathered 10 articles from search
- Read first 5
- Extracted basic themes

### Ralph Loop Review (Iteration 1)
1. ✅ Functional - Basic themes identified
2. ❌ Code - Not applicable
3. ❌ Integration - Not applicable
4. ❌ Documentation - Basic summary only
5. ❌ Performance - Limited depth
6. ❌ Testing - No validation of findings

### Iteration 2 (Refined)
- Expanded to 30 articles
- Read 25 articles in depth
- Categorized findings into 5 themes
- Identified 3 contradictory findings
- Analyzed trends over time
- Created detailed analysis with citations

### Ralph Loop Review (Iteration 2)
1. ✅ Functional - Comprehensive analysis complete
2. ✅ Code - Not applicable
3. ✅ Integration - Not applicable
4. ✅ Documentation - Full analysis with references
5. ✅ Performance - In-depth research
6. ✅ Testing - Validated findings through multiple sources

### Final Output
- 5 themes with evidence from multiple sources
- Contradictory findings noted and analyzed
- Trends over time identified
- Citations provided for all claims
- Ready for report
```

---

## Ralph Loop in Complex Workflows

### Combined with Workflow Orchestrator

```markdown
## Example: Feature Development Workflow

1. **Planning Phase** (systematic-planning skill)
   - Break down feature into tasks
   - Create plan with dependencies

2. **Design Phase** (workflow-orchestrator skill)
   - Analyze architecture requirements
   - Design component structure
   - Identify potential issues

3. **Implementation Phase** (iterative-refinement + developer skill)
   - Generate initial implementation
   - Run Ralph Loop self-review
   - Identify improvements
   - Refine implementation
   - Repeat until all criteria met
   - Generate final code

4. **Review Phase** (qa skill)
   - QA reviews self-review results
   - QA may request additional refinement
   - Developer applies corrections if needed
   - Final version ready for merge
```

### Combined with Handoff Protocol

```markdown
## Handoff with Self-Review Results

```markdown
## HANDOFF: Developer → QA

**Self-Review Results:**
- Functional Correctness: ✅ All requirements met
- Code Quality: ✅ No issues found
- Integration: ✅ Compatible with existing code
- Documentation: ⚠️ 2 improvements needed
- Performance: ✅ No obvious issues
- Testing: ⚠️ 1 improvement needed

**Improvements Applied:**
1. Added inline documentation for complex logic
2. Added unit test for edge case X

**Known Limitations:**
- Performance may degrade with >1000 users (noted in docs)

**QA Recommendations:**
- Focus testing on the two improvements above
- Check performance with load test
```

---

## Benefits

### Quality Improvements
- **40-60% reduction** in review iterations through early self-correction
- **Fewer bugs** in production due to early issue detection
- **Higher quality output** through deliberate iteration

### Developer Experience
- **Clear guidance** on what to improve
- **Evidence of effort** - reviewers see iteration
- **Reduced surprises** - issues caught early

### Process Benefits
- **Standardized review** - same checklist for everyone
- **Traceable history** - iteration evidence in changelog
- **Better communication** - self-review results shared with QA

---

## Using This Skill

### When to Use

**Always use Ralph Loop for:**
- Complex features requiring careful consideration
- Security-sensitive code (authentication, data handling)
- Performance-critical components
- Research or analysis tasks with evolving understanding
- First-time implementation of new patterns

**Optional for:**
- Simple bug fixes
- Documentation updates
- Minor refactoring

### How to Invoke

```markdown
## In Your Workflow

1. **Start Iteration**
   "I'll implement feature X using the Ralph Loop pattern:
   - Generate initial version
   - Perform self-review
   - Refine based on findings
   - Present final version"

2. **Generate Initial**
   - Implement feature following conventions
   - Include basic error handling
   - Mark any TODOs or limitations

3. **Perform Self-Review**
   - Go through checklist
   - Identify issues
   - Note what's working

4. **Refine**
   - Apply fixes
   - Re-test if needed
   - Document changes

5. **Present Final**
   - Show complete version
   - Include self-review results
   - Show what improved
```

---

## Best Practices

### 1. Don't Iterate Too Many Times

**Good:**
- 1-2 iterations for simple features
- 3-5 iterations for complex features
- Stop when all criteria met

**Avoid:**
- >5 iterations for same work (code should be clear enough)
- Iterating without evidence of progress (document what changed)

### 2. Document Every Iteration

**Good:**
```
### Iteration 1
- Basic implementation

### Iteration 2
- Added error handling
- Improved performance
- Added tests
```

**Avoid:**
- Only showing final version
- No documentation of changes

### 3. Be Honest About Limitations

**Good:**
```
**Known Limitations:**
- Performance with 10k+ concurrent users not tested
- Integration with legacy system pending feedback
```

**Avoid:**
- Hiding issues in code
- Pretending everything is perfect

### 4. Share Review Results with Team

**Good:**
```
## Self-Review Results
- Functional: ✅ 10/10
- Code Quality: ✅ 9/10
- Integration: ⚠️ 7/10
  - Issue: API signature doesn't match expected format
  - Fix: Updated API to match contract
```

**Avoid:**
- Keeping self-review secret
- Surprising team with issues during review

---

## Common Pitfalls

### Pitfall 1: Skipping Self-Review

**Problem:** Presenting initial solution without review

**Impact:** Bugs and issues found late in review process

**Fix:** Always run through checklist before presenting

### Pitfall 2: Cherry-Picking Good Results

**Problem:** Only reporting successful items in self-review

**Impact:** Misleading reviewers, issues caught late

**Fix:** Report all items honestly, both ✅ and ❌

### Pitfall 3: Iterating Without Progress

**Problem:** Making small cosmetic changes without addressing core issues

**Impact:** Wasted time, frustrated reviewers

**Fix:** Each iteration should address real issues, not just "polishing"

### Pitfall 4: Over-Engineering

**Problem:** Creating overly complex solutions

**Impact:** Maintenance burden, performance issues

**Fix:** Balance quality with simplicity, use constraints as guidance

---

## Integration with Other Skills

### With Workflow Orchestrator

```markdown
## Multi-Phase Workflow with Iteration

1. **Analysis** → Generate initial design
2. **Design Review** → Self-review design
3. **Implementation** → Generate code
4. **Implementation Review** → Self-review code
5. **Final Review** → QA reviews iteration results
6. **Merge** → Final decision
```

### With Handoff Protocol

```markdown
## Developer → QA Handoff with Self-Review

Handoff includes:
- Self-review results
- List of improvements made
- Known limitations
- Test coverage summary
- QA-specific recommendations
```

### With Systematic Planning

```markdown
## Planning with Iteration Considerations

1. **Break down** feature into components
2. **Identify** which components need iteration
3. **Plan** iterations for complex components
4. **Schedule** reviews for each component
5. **Track** iteration evidence in plan
```

---

## Metrics and Success Criteria

### Quality Metrics
- **Mean Iteration Count:** Target < 3 for most features
- **Self-Review Coverage:** 100% checklist completion
- **Bug Density:** Fewer bugs in production code
- **QA Pass Rate:** Higher pass rate due to early correction

### Process Metrics
- **Time to Fix:** Issues caught earlier = faster fixes
- **Review Time:** Faster reviews due to evidence of iteration
- **Change Request Rate:** Lower rate due to thorough review

---

## Examples by Category

### Code Generation
```markdown
## Example: API Endpoint

### Iteration 1
- Created endpoint with basic validation
- No input sanitization
- No rate limiting

### Iteration 2
- Added input validation
- Added rate limiting
- Added error responses

### Iteration 3
- Added input sanitization
- Added logging
- Added tests

### Final: All criteria met
```

### Database Schema
```markdown
## Example: User Table

### Iteration 1
- Basic columns: id, username, password_hash
- No indexes
- No constraints

### Iteration 2
- Added email column
- Added unique constraint on username
- Added unique constraint on email
- Added indexes

### Iteration 3
- Added soft delete flag
- Added audit columns
- Added appropriate constraints
- Added documentation

### Final: Complete and optimized
```

### Configuration
```markdown
## Example: Application Config

### Iteration 1
- Basic properties
- No validation
- No defaults

### Iteration 2
- Added validation rules
- Added defaults
- Added documentation

### Iteration 3
- Added type checking
- Added environment-specific configs
- Added secret management
- Added validation tests

### Final: Production-ready config
```

---

## Advanced Patterns

### Parallel Iterations

For complex features with multiple components:

```markdown
## Parallel Iteration Strategy

1. **Component 1**: Generate → Review → Refine → Final
2. **Component 2**: Generate → Review → Refine → Final
3. **Component 3**: Generate → Review → Refine → Final
4. **Integration**: Combine all components
5. **Overall Review**: Final iteration on integration

Benefits:
- Faster iteration per component
- Parallel work
- Component-level tracking
```

### Iteration Thresholds

```markdown
## When to Stop Iterating

**Stop when:**
- All 6 checklist items are ✅
- No TODOs remain
- All requirements satisfied
- Performance is acceptable
- Documentation is complete
- Tests cover critical paths

**Don't continue if:**
- Making only cosmetic changes
- Requirements are still unclear
- Performance is not a concern
- Time constraints prevent further iteration
```

---

## References

- **Ralph Loop Pattern**: Iterative refinement through self-correction
- **Code Review Best Practices**: Early detection, constructive feedback
- **Quality Assurance**: Prevention over detection

---

## Change Log

- **v1.0.0** (2026-03-07): Initial implementation
  - Complete Ralph Loop pattern
  - 6-point self-review checklist
  - Integration examples
  - Best practices and pitfalls

---

## Contributing

To improve this skill:

1. Add new checklist items based on experience
2. Provide additional integration examples
3. Share real-world usage patterns
4. Document common pitfalls and solutions
