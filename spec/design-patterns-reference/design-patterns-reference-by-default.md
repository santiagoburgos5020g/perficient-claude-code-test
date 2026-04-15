# Design Patterns Reference — Skill Specification

## Overview

A strict, language-agnostic reference skill for software design patterns that agents and subagents consult during any code creation or modification. This skill is **not user-invocable** — it is automatically loaded by Claude and its agents when performing coding tasks to ensure all code follows established design pattern best practices.

## Purpose

- Serve as the **source of truth** for when and how to apply software design patterns
- Guide agents during code creation, modification, and review
- Enable agents to **audit user code** to identify gaps or incorrect pattern usage
- Ensure consistency and correctness across all code — functions, components, pages, utils, and any other code structures

## Trigger Conditions

- **Auto-invoked by model**: Yes — Claude and agents load this skill automatically when relevant to coding tasks
- **User-invocable**: No — this skill is not available in the `/` menu
- This skill is referenced whenever agents:
  - Create new code (files, functions, classes, components, utils, pages)
  - Modify existing code
  - Review or audit code written by the user
  - Evaluate whether the right design pattern has been applied

## Scope

- **Language-agnostic**: Applies to all programming languages and stacks
- **General software development**: Not tied to any specific framework or project
- Covers all **22 classic Gang of Four (GoF) design patterns**

## Pattern Classification

All patterns are organized into three groups by intent (following Refactoring.Guru's classification):

### 1. Creational Patterns

Provide object creation mechanisms that increase flexibility and reuse of existing code.

- **Singleton** — Ensures a class has only one instance and provides a global access point to it
- **Factory Method** — Defines an interface for creating objects but lets subclasses decide which class to instantiate
- **Abstract Factory** — Produces families of related objects without specifying their concrete classes
- **Builder** — Constructs complex objects step by step, allowing different representations
- **Prototype** — Creates new objects by copying existing ones

### 2. Structural Patterns

Explain how to assemble objects and classes into larger structures, while keeping these structures flexible and efficient.

- **Adapter** — Allows objects with incompatible interfaces to work together
- **Bridge** — Separates an abstraction from its implementation so they can vary independently
- **Composite** — Composes objects into tree structures to represent part-whole hierarchies
- **Decorator** — Attaches new behaviors to objects by wrapping them
- **Facade** — Provides a simplified interface to a complex subsystem
- **Flyweight** — Shares common state between multiple objects to reduce memory usage
- **Proxy** — Provides a substitute or placeholder for another object to control access

### 3. Behavioral Patterns

Take care of effective communication and the assignment of responsibilities between objects.

- **Chain of Responsibility** — Passes requests along a chain of handlers until one handles it
- **Command** — Turns a request into a stand-alone object containing all request information
- **Iterator** — Traverses elements of a collection without exposing its underlying representation
- **Mediator** — Reduces chaotic dependencies between objects by centralizing communication
- **Memento** — Saves and restores previous state of an object without exposing its internals
- **Observer** — Defines a subscription mechanism to notify multiple objects about events
- **State** — Lets an object alter its behavior when its internal state changes
- **Strategy** — Defines a family of algorithms, encapsulates each one, and makes them interchangeable
- **Template Method** — Defines the skeleton of an algorithm, deferring some steps to subclasses
- **Visitor** — Separates algorithms from the objects on which they operate

## Pattern Entry Structure

Each pattern in the skill reference should follow this structure (based on Refactoring.Guru):

1. **Intent** — One-sentence definition of what the pattern does
2. **When to Use** — Specific scenarios and problem indicators that signal this pattern is the right fit
3. **Structure** — Key components/participants involved in the pattern and their roles
4. **How to Apply** — Step-by-step implementation guidance applicable across languages
5. **Pros and Cons** — Trade-offs to consider
6. **Related Patterns** — Cross-references to patterns that are commonly confused, combined, or used as alternatives

## How Agents Use This Skill

### During Code Creation
- Before writing new code, agents check which pattern (if any) is appropriate for the structure being created
- Apply the pattern correctly following the "How to Apply" steps

### During Code Modification
- Before modifying code, agents identify if an existing pattern is in place
- Ensure modifications maintain the pattern's integrity
- If a modification would break a pattern, flag it and suggest the correct approach

### During Code Review / Audit
- Agents review user-written code against this reference
- Identify where a pattern should have been applied but wasn't (gaps)
- Identify where a pattern was applied incorrectly
- Suggest corrections with reference to the specific pattern's guidelines

## Rules and Constraints

- This skill is a **strict reference** — agents must align code with these patterns, not deviate from them
- The reference is **language-agnostic** — pattern guidance applies regardless of the programming language
- Agents should **not force patterns** where they don't fit — only apply patterns when the problem genuinely calls for one
- When multiple patterns could apply, agents should consider the pros/cons and related patterns sections to choose the best fit
- Agents should **not over-engineer** — the simplest correct pattern is preferred

## Frontmatter Settings

```yaml
name: design-patterns-reference
description: Strict reference for GoF design patterns — agents consult this during code creation, modification, and review to enforce correct pattern usage
user-invocable: false
disable-model-invocation: false
```

## Primary Reference

- **Refactoring.Guru** (https://refactoring.guru/design-patterns) — classification, structure, and pattern details
- **SourceMaking** (https://sourcemaking.com/design_patterns) — supplementary reference for rules of thumb and additional patterns
