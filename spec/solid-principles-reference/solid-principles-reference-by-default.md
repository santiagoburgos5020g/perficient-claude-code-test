# SOLID Principles Reference — Skill Specification (Default Model)

## Overview

A strict, language-agnostic reference skill containing all 5 SOLID principles of object-oriented design. Agents and subagents consult this skill as the authoritative source of truth during any code creation, modification, or review. The skill defines **when** each principle applies, **how** to follow it, and **what to watch for** when auditing code.

This skill is **not user-invocable**. It is automatically loaded by Claude and its agents whenever coding tasks are performed.

## Purpose

- Serve as the **single source of truth** for SOLID principles knowledge across all agents
- Guide agents to follow the correct principle during code creation and modification
- Enable agents to **audit user-written code** — identify violations, misapplications, and improvement opportunities
- Ensure design consistency across all code structures: functions, classes, components, pages, utilities, services, and modules

## Trigger Conditions

- **Auto-invoked by model**: Yes
- **User-invocable**: No
- Agents load this skill whenever they:
  - Create new code (files, functions, classes, components, utils, pages, services)
  - Modify existing code
  - Review or audit code written by the user
  - Evaluate architectural decisions or code structure

## Scope

- **Language-agnostic**: Applies to all programming languages and technology stacks
- **General software development**: Not tied to any specific framework, library, or project
- Covers all **5 SOLID principles**:
  - **S** — Single Responsibility Principle (SRP)
  - **O** — Open/Closed Principle (OCP)
  - **L** — Liskov Substitution Principle (LSP)
  - **I** — Interface Segregation Principle (ISP)
  - **D** — Dependency Inversion Principle (DIP)

## Agent Decision Process

When agents encounter a coding task, they follow this process:

1. **Identify the problem** — What is the code trying to solve?
2. **Check for code smells** — Are there indicators that a SOLID principle is being violated? (see per-principle "Code Smells" below)
3. **Match to a principle** — Consult the "When It Applies" section of candidate principles
4. **Evaluate trade-offs** — Review pros/cons; do not refactor toward a principle if the cost outweighs the benefit
5. **Apply or flag** — If creating/modifying code, follow the principle. If reviewing, flag the violation with a reference to the specific principle

### Severity Levels for Audits

When reviewing code, agents categorize findings as:

- **Critical** — A principle is clearly violated and its absence causes maintainability, scalability, or correctness problems
- **Recommended** — Following the principle would improve the code but the current approach is functional
- **Informational** — A principle could apply but the current code is simple enough that refactoring toward it would be over-engineering

### Key Principle: Do Not Over-Engineer

Agents must **never force a principle** where the problem is too simple to warrant it. A three-line class does not need an extracted interface for ISP. The simplest correct solution is always preferred. SOLID principles are tools for managing complexity — they should not introduce it.

---

## THE 5 SOLID PRINCIPLES

### S — Single Responsibility Principle (SRP)

**Statement:** A class should have only one reason to change — meaning it should have only one job or responsibility.

**When It Applies:**
- A class handles multiple unrelated concerns (e.g., data access AND formatting AND validation)
- Changes to one feature regularly require modifying a class that also handles other features
- A class is difficult to name because it does too many things

**Code Smells That Signal a Violation:**
- Classes with many methods that serve different purposes
- Classes that import/depend on many unrelated modules
- Methods in a class that don't use the same subset of fields
- Class names that include "And" or "Manager" or "Handler" with broad scope
- A change in one business requirement forces changes across multiple methods in the same class

**How to Apply:**
1. Identify the distinct responsibilities a class currently handles
2. Extract each responsibility into its own class
3. Each new class should be cohesive — its methods and fields should all relate to a single concern
4. Use composition or dependency injection to reconnect the separated classes where needed
5. Name each class clearly after its single responsibility

**Pros:**
- Easier to understand — each class has a clear, focused purpose
- Easier to test — small, focused classes are simpler to unit test
- Reduces the impact of changes — modifying one responsibility doesn't risk breaking another
- Improves reusability — focused classes are easier to reuse in other contexts

**Cons:**
- Can lead to many small classes if applied too aggressively
- May increase complexity if responsibilities are over-separated for trivial code

**Common Misapplications:**
- Splitting a simple class with 2-3 related methods into multiple classes prematurely
- Interpreting SRP as "one method per class" — SRP is about one *reason to change*, not one method
- Creating excessive indirection by separating responsibilities that are tightly coupled and always change together

**Related Principles:** OCP (a class with a single responsibility is easier to extend without modification), ISP (SRP for classes parallels ISP for interfaces)

---

### O — Open/Closed Principle (OCP)

**Statement:** Software entities (classes, modules, functions) should be open for extension but closed for modification.

**When It Applies:**
- Existing code needs new behavior without risking breakage of current functionality
- You anticipate new variants or types being added over time
- A module is stable and relied upon by other parts of the system

**Code Smells That Signal a Violation:**
- Adding a new feature requires modifying existing, tested code
- Growing `if/else` or `switch` blocks that check types or conditions to vary behavior
- A change in requirements forces edits across multiple files that shouldn't need changing
- Methods that use type-checking (instanceof, typeof) to decide behavior

**How to Apply:**
1. Identify the behavior that varies or is likely to change
2. Define an abstraction (interface or abstract class) for that behavior
3. Implement each variant as a concrete class implementing the abstraction
4. Use polymorphism, composition, or dependency injection to plug in the correct variant
5. Existing code references the abstraction, not concrete implementations

**Pros:**
- Existing code remains stable and tested when new features are added
- Encourages use of abstractions and polymorphism
- Reduces the risk of introducing bugs in existing functionality

**Cons:**
- Requires anticipating which aspects will change — incorrect predictions add unnecessary abstraction
- Can introduce complexity if applied to parts of the code that are unlikely to change

**Common Misapplications:**
- Creating abstractions for every class "just in case" — OCP should target known or likely change points
- Interpreting OCP as "never modify any code" — it's about design, not a ban on editing files
- Adding extension points to code that has only one implementation and no foreseeable variation

**Related Principles:** SRP (focused classes are easier to extend), LSP (extensions must be substitutable), DIP (depend on abstractions to enable extension)

---

### L — Liskov Substitution Principle (LSP)

**Statement:** Objects of a superclass should be replaceable with objects of its subclasses without altering the correctness of the program.

**When It Applies:**
- You are using inheritance (class hierarchies, interface implementations)
- Subclasses override methods from a parent class
- Client code works with base class or interface references

**Code Smells That Signal a Violation:**
- A subclass throws exceptions for methods it doesn't support (e.g., `throw new NotImplementedException()`)
- A subclass overrides a method and changes its expected behavior or side effects
- Client code checks the concrete type before calling a method (instanceof/type guards)
- A subclass ignores or empties out inherited methods
- Tests for the base class fail when run against a subclass

**How to Apply:**
1. Ensure subclasses honor the contract of the parent class — preconditions, postconditions, and invariants
2. Subclasses must not strengthen preconditions (require more than the parent)
3. Subclasses must not weaken postconditions (deliver less than the parent promises)
4. Subclasses must preserve the invariants of the parent class
5. If a subclass can't fully satisfy the parent's contract, it should not inherit from it — use composition instead
6. Design by contract: define what each method promises and verify subclasses maintain those promises

**Pros:**
- Ensures polymorphism works correctly — client code can trust the base class contract
- Makes code more predictable and easier to reason about
- Prevents subtle bugs caused by subclasses violating assumptions

**Cons:**
- Can be restrictive — some natural-seeming hierarchies violate LSP (e.g., Square extends Rectangle)
- Requires careful contract design upfront

**Common Misapplications:**
- Avoiding all inheritance — LSP doesn't forbid inheritance, it defines when inheritance is correct
- Forcing unrelated classes into a hierarchy just because they share some methods
- Ignoring LSP for "internal" code — violations cause bugs regardless of visibility

**Related Principles:** OCP (LSP enables safe extension through substitution), ISP (smaller interfaces make it easier to satisfy contracts)

---

### I — Interface Segregation Principle (ISP)

**Statement:** No client should be forced to depend on interfaces it does not use. Prefer many small, specific interfaces over one large, general-purpose interface.

**When It Applies:**
- An interface has methods that some implementations don't need
- Classes implement an interface but leave some methods empty or throw exceptions
- Client code depends on an interface but only uses a subset of its methods

**Code Smells That Signal a Violation:**
- Classes that implement an interface with empty method bodies or `NotImplementedException`
- "Fat" interfaces with many methods that serve different client needs
- Changes to an interface method force recompilation or modification of classes that don't use that method
- Client code receives an object with many methods but only calls one or two

**How to Apply:**
1. Identify which clients use which methods of the interface
2. Group methods by client need — each group becomes a separate interface
3. Split the fat interface into smaller, role-specific interfaces
4. Classes implement only the interfaces relevant to them
5. Client code depends on the smallest interface that provides what it needs

**Pros:**
- Reduces coupling — clients only depend on what they use
- Easier to implement — classes don't need to provide unused methods
- Easier to change — modifying one interface doesn't affect unrelated clients
- Improves clarity — each interface has a clear, focused purpose

**Cons:**
- Can lead to many small interfaces if applied too aggressively
- Requires good understanding of client needs upfront

**Common Misapplications:**
- Creating a separate interface for every single method — ISP is about client needs, not minimalism
- Applying ISP to interfaces with only 2-3 cohesive methods that are always used together
- Splitting interfaces that are genuinely cohesive and always consumed as a whole

**Related Principles:** SRP (ISP is the interface equivalent of SRP), LSP (smaller interfaces make it easier to satisfy the full contract)

---

### D — Dependency Inversion Principle (DIP)

**Statement:** High-level modules should not depend on low-level modules. Both should depend on abstractions. Abstractions should not depend on details. Details should depend on abstractions.

**When It Applies:**
- High-level business logic directly instantiates or references low-level implementation details (database, file system, external APIs)
- Changing a low-level module forces changes in high-level modules
- Code is difficult to test because dependencies can't be substituted

**Code Smells That Signal a Violation:**
- `new` keyword or direct instantiation of concrete dependencies inside business logic classes
- Import statements for concrete implementations in high-level modules
- Business logic classes that can't be tested without a database, network, or file system
- Changes to a data access layer requiring changes to business logic

**How to Apply:**
1. Identify where high-level modules depend on low-level concrete classes
2. Define an abstraction (interface or abstract class) for each dependency
3. High-level modules reference the abstraction, not the concrete implementation
4. Low-level modules implement the abstraction
5. Use dependency injection (constructor, method, or property injection) to provide the concrete implementation at runtime
6. The composition root (application entry point or DI container) wires everything together

**Pros:**
- High-level business logic is decoupled from low-level implementation details
- Easier to test — dependencies can be mocked or stubbed
- Easier to swap implementations (e.g., switch databases, replace an API client)
- Promotes modular, pluggable architecture

**Cons:**
- Adds indirection — abstractions and injection wiring increase initial complexity
- Overhead is not justified for simple applications with no variation in dependencies

**Common Misapplications:**
- Creating abstractions for everything, including stable, unlikely-to-change dependencies (e.g., wrapping standard library string utilities)
- Using DIP as a justification for a heavy DI framework when manual injection suffices
- Applying DIP to leaf classes with no dependents

**Related Principles:** OCP (abstractions enable extension without modification), LSP (implementations must be substitutable for their abstractions), ISP (narrow abstractions are easier to implement and depend on)

---

## Principle Selection Quick Reference

When an agent encounters a design problem, use this guide to identify which SOLID principle is relevant:

| Problem | Consider |
|---|---|
| Class does too many things / has too many reasons to change | SRP |
| Adding features requires modifying existing stable code | OCP |
| Subclass doesn't honor parent class contract | LSP |
| Interface forces implementations to provide unused methods | ISP |
| High-level code depends on low-level implementation details | DIP |
| Growing if/else or switch blocks for varying behavior | OCP, Strategy pattern |
| Subclass throws NotImplementedException for inherited methods | LSP, ISP |
| Can't unit test a class without external systems | DIP |
| Fat interface with methods not all clients use | ISP |
| Change in one area cascades into unrelated areas | SRP, DIP |

---

## Frontmatter Settings

```yaml
name: solid-principles-reference
description: Strict reference for SOLID principles — agents consult this during code creation, modification, and review to enforce correct principle adherence
user-invocable: false
disable-model-invocation: false
```
