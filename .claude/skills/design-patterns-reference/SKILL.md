---
name: design-patterns-reference
description: Strict GoF design patterns reference — agents consult this during code creation, modification, and review to enforce correct pattern usage across all languages
when_to_use: "TRIGGER when: code has growing if/else or switch blocks; class hierarchy issues; tight coupling between components; repetitive object creation; need to simplify complex subsystem interfaces; reviewing structural or behavioral code design. SKIP when: code is simple enough that no pattern is warranted"
effort: high
user-invocable: true
---

# Design Patterns Reference

This skill is the authoritative reference for Gang of Four (GoF) software design patterns. All agents and subagents must consult this reference when creating, modifying, or reviewing code to ensure design pattern best practices are followed.

## How Agents Use This Reference

### Decision Process

1. **Identify the problem** — What is the code trying to solve?
2. **Check for code smells** — Are there indicators that a pattern is needed? (see per-pattern "Code Smells" in [reference.md](reference.md))
3. **Match to a pattern** — Consult the "When to Use" section of candidate patterns; use the Quick Reference table below to narrow candidates
4. **Evaluate trade-offs** — Review pros/cons; do not apply a pattern if the cost outweighs the benefit
5. **Apply or flag** — If creating/modifying code, apply the pattern. If reviewing, flag the gap with a reference to the specific pattern

### During Code Creation

- Before writing new code, check which pattern (if any) is appropriate for the structure being created
- Apply the pattern correctly following the "How to Apply" steps

### During Code Modification

- Before modifying code, identify if an existing pattern is in place
- Ensure modifications maintain the pattern's integrity
- If a modification would break a pattern, flag it and suggest the correct approach

### During Code Review / Audit

- Review user-written code against this reference
- Identify where a pattern should have been applied but wasn't (gaps)
- Identify where a pattern was applied incorrectly
- Categorize findings by severity:
  - **Critical** — Pattern absence causes maintainability, scalability, or correctness problems
  - **Recommended** — A pattern would improve the code but the current approach is functional
  - **Informational** — A pattern could apply but the code is simple enough that adding it would be over-engineering

### Key Principle: Do Not Over-Engineer

Never force a pattern where the problem is too simple to warrant one. The simplest correct solution is always preferred. Patterns are tools for managing complexity — they should not introduce it.

---

## Pattern Classification

All 23 patterns organized by intent:

### Creational — Object creation mechanisms
- Singleton, Factory Method, Abstract Factory, Builder, Prototype

### Structural — Assembling objects into larger structures
- Adapter, Bridge, Composite, Decorator, Facade, Flyweight, Proxy

### Behavioral — Communication and responsibility assignment
- Chain of Responsibility, Command, Iterator, Mediator, Memento, Observer, State, Strategy, Template Method, Visitor

For complete details (intent, when to use, code smells, how to apply, pros/cons, related patterns) on each pattern, see [reference.md](reference.md).

---

## Pattern Selection Quick Reference

| Problem | Consider |
|---|---|
| Create objects without specifying exact class | Factory Method, Abstract Factory |
| Complex object construction with many parameters | Builder |
| Exactly one instance of a class | Singleton |
| Copy existing objects | Prototype |
| Incompatible interfaces | Adapter |
| Separate abstraction from implementation | Bridge |
| Tree / hierarchy structure | Composite |
| Add behavior dynamically | Decorator |
| Simplify a complex subsystem | Facade |
| Too many similar objects consuming memory | Flyweight |
| Control access to an object | Proxy |
| Pipeline of request handlers | Chain of Responsibility |
| Encapsulate operations for undo / queue / log | Command |
| Traverse collection without exposing internals | Iterator |
| Reduce coupling between interdependent objects | Mediator |
| Save / restore object state | Memento |
| Notify multiple objects of changes | Observer |
| Behavior depends on internal state | State |
| Swap algorithms at runtime | Strategy |
| Same algorithm structure, different steps | Template Method |
| Add operations without modifying classes | Visitor |
