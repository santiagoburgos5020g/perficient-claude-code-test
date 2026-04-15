# Design Patterns Reference — Skill Specification (Opus 4.6 Reviewed)

## Overview

A strict, language-agnostic reference skill containing all 22 Gang of Four (GoF) software design patterns. Agents and subagents consult this skill as the authoritative source of truth during any code creation, modification, or review. The skill defines **when** each pattern applies, **how** to implement it, and **what to watch for** when auditing code.

This skill is **not user-invocable**. It is automatically loaded by Claude and its agents whenever coding tasks are performed.

## Purpose

- Serve as the **single source of truth** for design pattern knowledge across all agents
- Guide agents to apply the correct pattern during code creation and modification
- Enable agents to **audit user-written code** — identify gaps, misapplications, and improvement opportunities
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
- Covers all **22 classic GoF design patterns** organized into three categories

## Agent Decision Process

When agents encounter a coding task, they follow this process:

1. **Identify the problem** — What is the code trying to solve?
2. **Check for code smells** — Are there indicators that a pattern is needed? (see per-pattern "Code Smells" below)
3. **Match to a pattern** — Consult the "When to Use" section of candidate patterns
4. **Evaluate trade-offs** — Review pros/cons; do not apply a pattern if the cost outweighs the benefit
5. **Apply or flag** — If creating/modifying code, apply the pattern. If reviewing, flag the gap with a reference to the specific pattern

### Severity Levels for Audits

When reviewing code, agents categorize findings as:

- **Critical** — A pattern is clearly needed and its absence causes maintainability, scalability, or correctness problems
- **Recommended** — A pattern would improve the code but the current approach is functional
- **Informational** — A pattern could apply but the current code is simple enough that adding it would be over-engineering

### Key Principle: Do Not Over-Engineer

Agents must **never force a pattern** where the problem is too simple to warrant one. A three-line function does not need the Strategy pattern. The simplest correct solution is always preferred. Patterns are tools for managing complexity — they should not introduce it.

---

## Pattern Classification

All patterns are organized into three groups by intent, following the Gang of Four classification:

- **Creational Patterns** — Object creation mechanisms that increase flexibility and reuse
- **Structural Patterns** — How to assemble objects and classes into larger structures while keeping them flexible and efficient
- **Behavioral Patterns** — Effective communication and assignment of responsibilities between objects

---

## CREATIONAL PATTERNS

### Singleton

**Intent:** Ensure a class has only one instance and provide a global access point to it.

**When to Use:**
- A single shared resource must be accessed across the application (database connection, configuration, logger)
- Creating multiple instances would cause conflicts or waste resources
- You need controlled access to a shared resource

**Code Smells That Signal This Pattern:**
- Global variables used to share a single resource
- Multiple instantiations of something that should exist only once
- Constructor calls scattered across the codebase for the same resource

**Structure:**
- **Singleton class** — stores the single instance as a private static field; provides a static creation method that returns the cached instance

**How to Apply:**
1. Add a private static field to the class for storing the singleton instance
2. Declare a public static creation/access method (e.g., `getInstance()`)
3. Implement lazy initialization inside the static method — create the instance on first call, return the cached instance on subsequent calls
4. Make the constructor private to prevent direct instantiation
5. In multithreaded environments, add synchronization to prevent race conditions

**Pros:**
- Guarantees a single instance
- Global access point to that instance
- Instance is created only when first needed (lazy initialization)

**Cons:**
- Violates Single Responsibility Principle (manages its own lifecycle and its core logic)
- Can mask bad design by making components overly dependent on global state
- Difficult to unit test (hard to mock or substitute)
- Requires special handling in multithreaded environments

**Common Misuses:**
- Using Singleton as a shortcut for global variables
- Applying it when dependency injection would be cleaner

**Related Patterns:** Facade (a single facade can also serve as a singleton), Abstract Factory / Builder / Prototype (can all be implemented as singletons)

---

### Factory Method

**Intent:** Define an interface for creating objects, but let subclasses decide which class to instantiate.

**When to Use:**
- You don't know ahead of time the exact types of objects your code will need to work with
- You want to provide a way to extend the internal components of a library or framework
- You want to reuse existing objects instead of rebuilding them each time

**Code Smells That Signal This Pattern:**
- Large `if/else` or `switch` blocks that instantiate different classes based on a condition
- Constructor calls with varying parameters scattered across the code
- Code that needs to create objects but shouldn't know the concrete class

**Structure:**
- **Product interface** — declares the interface common to all objects that the factory method creates
- **Concrete Products** — different implementations of the product interface
- **Creator (base class)** — declares the factory method that returns product objects
- **Concrete Creators** — override the factory method to return a specific concrete product

**How to Apply:**
1. Define a common interface or base class for all products
2. Create concrete product classes implementing the interface
3. Declare the factory method in the creator class — return type should be the product interface
4. In each concrete creator, override the factory method to return the appropriate concrete product
5. Replace direct constructor calls in client code with calls to the factory method

**Pros:**
- Avoids tight coupling between creator and concrete products
- Single Responsibility: product creation code is centralized
- Open/Closed: new product types can be introduced without breaking existing code

**Cons:**
- Code can become more complex with many subclasses
- Requires a creator subclass for each product type

**Common Misuses:**
- Creating a factory for a single product type with no expected variation
- Overcomplicating simple object creation

**Related Patterns:** Abstract Factory (often implemented with Factory Methods), Template Method (Factory Method is a specialization of Template Method), Prototype (doesn't require subclassing but needs an initialization step)

---

### Abstract Factory

**Intent:** Produce families of related objects without specifying their concrete classes.

**When to Use:**
- Code needs to work with various families of related products (e.g., UI elements for different operating systems)
- You want to ensure products from the same family are used together
- You want to provide a library of products exposing only interfaces, not implementations

**Code Smells That Signal This Pattern:**
- Multiple Factory Methods that are logically related and always used together
- Code that creates families of objects but hard-codes the concrete types
- Platform- or theme-specific object creation scattered throughout the codebase

**Structure:**
- **Abstract Factory interface** — declares creation methods for each distinct product type
- **Concrete Factories** — implement creation methods for a specific product family
- **Abstract Product interfaces** — one per distinct product type
- **Concrete Products** — implementations specific to each factory/family
- **Client** — works with factories and products through abstract interfaces only

**How to Apply:**
1. Map out distinct product types and their variants (families)
2. Declare abstract product interfaces for each product type
3. Declare the abstract factory interface with creation methods for all product types
4. Implement a concrete factory class for each product family
5. Create factory initialization code somewhere in the app — select the concrete factory based on configuration or environment
6. Replace all direct product constructor calls with calls to the factory

**Pros:**
- Guarantees compatibility between products of the same family
- Avoids tight coupling between client code and concrete products
- Single Responsibility: product creation is centralized
- Open/Closed: new families can be introduced without modifying existing code

**Cons:**
- High complexity — introduces many interfaces and classes
- Adding a new product type requires changing the abstract factory interface and all concrete factories

**Common Misuses:**
- Using Abstract Factory when there's only one product family
- Creating abstract factories for products that aren't logically related

**Related Patterns:** Factory Method (Abstract Factory classes are often built with Factory Methods), Builder (focuses on step-by-step construction; Abstract Factory on families of products), Prototype (alternative when families aren't fixed at compile time)

---

### Builder

**Intent:** Construct complex objects step by step, allowing different types and representations of the object using the same construction process.

**When to Use:**
- Object construction involves many steps or parameters
- You want to create different representations of the same product
- You need to construct composite objects (trees or other complex structures)

**Code Smells That Signal This Pattern:**
- Constructors with many parameters (telescoping constructor anti-pattern)
- Multiple constructor overloads for different configurations
- Complex object initialization logic duplicated across the codebase

**Structure:**
- **Builder interface** — declares the construction steps common to all builders
- **Concrete Builders** — provide different implementations of the construction steps
- **Product** — the resulting complex object (products from different builders don't need a common interface)
- **Director** (optional) — defines the order in which construction steps are called

**How to Apply:**
1. Identify the construction steps common to building all product representations
2. Declare these steps in the builder interface
3. Create a concrete builder class for each product representation
4. Optionally create a director class that encapsulates specific construction sequences
5. Client code creates a builder, optionally passes it to a director, triggers construction, and retrieves the result from the builder

**Pros:**
- Construct objects step by step, defer steps, or run steps recursively
- Reuse the same construction code for different product representations
- Single Responsibility: isolates complex construction logic from business logic

**Cons:**
- Increases overall code complexity with multiple new classes
- Client must be aware of different builder implementations (unless using a director)

**Common Misuses:**
- Using Builder for simple objects with few parameters
- Creating a Builder when a constructor with named/optional parameters suffices

**Related Patterns:** Factory Method / Abstract Factory (can use Builder internally for complex product construction), Composite (builders often construct Composite trees), Singleton (builders can be implemented as singletons)

---

### Prototype

**Intent:** Create new objects by copying (cloning) existing ones, without depending on their concrete classes.

**When to Use:**
- Creating an object is expensive and a similar object already exists
- You want to reduce the number of subclasses that only differ in initialization
- You need to create objects at runtime without knowing their concrete types

**Code Smells That Signal This Pattern:**
- Repetitive initialization code creating similar objects with slight variations
- Large switch/if blocks creating objects that share most of their configuration
- Code that needs to copy objects but can't access their private fields

**Structure:**
- **Prototype interface** — declares the cloning method (typically `clone()`)
- **Concrete Prototypes** — implement the cloning method, handling deep vs. shallow copy
- **Client** — produces a copy by calling the clone method on a prototype
- **Prototype Registry** (optional) — stores frequently used prototypes for easy access

**How to Apply:**
1. Declare the prototype interface with a `clone()` method
2. Implement `clone()` in each concrete class — handle deep copying of mutable fields
3. Optionally create a registry class that stores pre-configured prototypes
4. Replace `new` calls with calls to `clone()` on an existing prototype

**Pros:**
- Clone objects without coupling to their concrete classes
- Eliminate repeated initialization code
- Produce complex objects more conveniently
- Alternative to inheritance for presets

**Cons:**
- Cloning objects with circular references can be tricky
- Deep cloning complex objects requires careful implementation

**Common Misuses:**
- Using Prototype for simple objects that are cheap to construct
- Implementing shallow copy when deep copy is required (causing shared state bugs)

**Related Patterns:** Factory Method (alternative — no subclassing needed but requires initialization), Abstract Factory (can use Prototype internally), Memento (Prototype can simplify saving object snapshots)

---

## STRUCTURAL PATTERNS

### Adapter

**Intent:** Allow objects with incompatible interfaces to work together by wrapping one object to make it compatible with another.

**When to Use:**
- You want to use an existing class, but its interface doesn't match what you need
- You want to create a reusable class that cooperates with unrelated or unforeseen classes
- You need to use several existing subclasses but it's impractical to adapt each by subclassing

**Code Smells That Signal This Pattern:**
- Wrapper code that translates calls from one interface to another, duplicated in multiple places
- Code that directly manipulates third-party library objects to make them fit
- Data transformation logic scattered across the codebase

**Structure:**
- **Client interface (Target)** — the interface the client expects
- **Adapter** — implements the client interface and wraps the adaptee
- **Adaptee** — the existing class with an incompatible interface
- **Client** — interacts with the adapter through the target interface

**How to Apply:**
1. Identify the two incompatible interfaces (what you have vs. what you need)
2. Create the adapter class implementing the target interface
3. Add a reference to the adaptee object inside the adapter
4. Implement all target interface methods by delegating to the adaptee (translating as needed)
5. Client code uses the adapter through the target interface

**Pros:**
- Single Responsibility: separates interface conversion from business logic
- Open/Closed: new adapters can be introduced without changing existing code

**Cons:**
- Adds complexity — sometimes it's simpler to change the existing class directly
- Two types (class adapter via inheritance, object adapter via composition) — choose appropriately

**Common Misuses:**
- Using Adapter when you control both interfaces and can simply change one
- Creating adapters for interfaces that are almost identical

**Related Patterns:** Bridge (designed up front for abstraction/implementation separation; Adapter is a retrofit), Decorator (changes behavior without changing interface; Adapter changes the interface), Facade (defines a new interface for a subsystem; Adapter makes an existing interface usable), Proxy (same interface, controlled access)

---

### Bridge

**Intent:** Separate an abstraction from its implementation so that both can vary independently.

**When to Use:**
- You want to divide and organize a monolithic class that has multiple variants of some functionality
- You need to extend a class in several orthogonal (independent) dimensions
- You need to switch implementations at runtime

**Code Smells That Signal This Pattern:**
- Class hierarchy growing exponentially due to combinations of variants (e.g., Shape + Color = RedCircle, BlueCircle, RedSquare, etc.)
- Platform-specific code mixed with business logic
- Conditional logic selecting different implementations throughout a class

**Structure:**
- **Abstraction** — provides high-level control logic; delegates work to the implementation
- **Refined Abstraction** — extends the abstraction with additional operations
- **Implementation interface** — declares the interface common to all concrete implementations
- **Concrete Implementations** — platform- or variant-specific code

**How to Apply:**
1. Identify the orthogonal dimensions in your classes (e.g., shape and rendering, or UI and platform)
2. Define the operations the client needs in the abstraction class
3. Define the operations available on all platforms/variants in the implementation interface
4. Create concrete implementation classes for each variant
5. Add a reference field in the abstraction for the implementation object
6. The client passes the desired implementation to the abstraction's constructor

**Pros:**
- Platform-independent abstraction code
- Client code works with high-level abstractions — not exposed to implementation details
- Open/Closed: new abstractions and implementations can be introduced independently
- Single Responsibility: abstraction handles high-level logic, implementation handles low-level work

**Cons:**
- Can overcomplicate code when applied to a class that's already cohesive
- Initial setup requires more classes and interfaces

**Common Misuses:**
- Using Bridge when there's only one dimension of variation
- Applying it to simple classes that don't have independent axes of change

**Related Patterns:** Adapter (retrofit; Bridge is designed up front), Abstract Factory (can create the bridge objects), Strategy (similar structure but different intent — Strategy is about behavior, Bridge is about structure)

---

### Composite

**Intent:** Compose objects into tree structures to represent part-whole hierarchies, letting clients treat individual objects and compositions uniformly.

**When to Use:**
- You need to implement a tree-like object structure
- You want client code to treat simple and complex elements uniformly
- You have recursive structures where a container holds items and other containers

**Code Smells That Signal This Pattern:**
- Separate handling logic for individual items vs. groups of items
- Recursive data structures where containers and leaves are treated differently
- Type-checking code to distinguish between simple and compound objects

**Structure:**
- **Component interface** — declares operations common to both simple and complex elements
- **Leaf** — a basic element that has no sub-elements
- **Composite** — a container that stores child components and delegates work to them
- **Client** — works with all elements through the component interface

**How to Apply:**
1. Ensure the core model can be represented as a tree (with simple elements and containers)
2. Declare the component interface with methods that make sense for both leaves and composites
3. Create leaf classes representing simple elements
4. Create composite classes that store a collection of child components
5. In the composite, delegate operations to children (iterate and aggregate results)
6. Define methods for adding/removing children in the composite

**Pros:**
- Work with complex tree structures using polymorphism and recursion
- Open/Closed: new element types can be introduced without changing existing code
- Client code is simplified — uniform interface for all elements

**Cons:**
- It can be hard to provide a common interface for classes whose functionality differs too much
- The component interface may become too general, making it harder to comprehend

**Common Misuses:**
- Using Composite when the structure is flat (no hierarchy)
- Forcing a tree structure on data that doesn't naturally form one

**Related Patterns:** Builder (can be used to construct Composite trees), Iterator (to traverse Composites), Visitor (to execute operations over a Composite tree), Chain of Responsibility (often composed with Composite — leaf components pass requests up through parent containers)

---

### Decorator

**Intent:** Attach new behaviors to objects dynamically by wrapping them in decorator objects, providing a flexible alternative to subclassing.

**When to Use:**
- You need to add responsibilities to objects at runtime without affecting other objects
- It's awkward or impossible to extend behavior through inheritance
- You need to combine several behaviors by stacking wrappers

**Code Smells That Signal This Pattern:**
- Subclass explosion from combining optional features (e.g., NotifierWithSMS, NotifierWithSMSAndEmail, etc.)
- Conditional logic in a class to enable/disable optional behaviors
- Code that modifies or extends behavior by creating many small subclasses

**Structure:**
- **Component interface** — declares the common interface for wrappers and wrapped objects
- **Concrete Component** — the base object being wrapped
- **Base Decorator** — wraps a component and delegates all operations to it
- **Concrete Decorators** — extend the base decorator and add behavior before or after delegating

**How to Apply:**
1. Identify the core component interface and its base implementation
2. Create a base decorator class that implements the component interface and wraps a component
3. Create concrete decorator classes that add behavior before/after delegating to the wrapped object
4. Client code composes decorators by wrapping the core component in one or more decorators
5. Ensure decorator stacking order doesn't cause unexpected behavior

**Pros:**
- Extend behavior without making new subclasses
- Add or remove responsibilities at runtime
- Combine behaviors by stacking multiple decorators
- Single Responsibility: each decorator handles one behavior

**Cons:**
- Hard to remove a specific wrapper from the middle of a stack
- Behavior depends on stacking order — can be confusing
- Initial configuration code can look complex

**Common Misuses:**
- Using Decorator when inheritance is simpler and the behavior is fixed at compile time
- Creating decorators for behaviors that should be part of the core component

**Related Patterns:** Adapter (changes interface; Decorator changes behavior but keeps interface), Composite (similar recursive structure but different intent — Composite sums children, Decorator adds behavior), Strategy (changes the guts of an object; Decorator changes the skin), Proxy (same interface — Proxy controls lifecycle, Decorator adds behavior)

---

### Facade

**Intent:** Provide a simplified, unified interface to a complex subsystem, making it easier to use.

**When to Use:**
- You need a simple interface to a complex subsystem
- You want to structure a subsystem into layers
- You want to decouple client code from the subsystem's internals

**Code Smells That Signal This Pattern:**
- Client code directly interacts with many classes from a subsystem
- Initialization sequences that involve configuring and connecting multiple subsystem objects
- Business logic mixed with subsystem orchestration code

**Structure:**
- **Facade** — provides a simple interface to the subsystem's functionality; knows which subsystem classes handle which requests
- **Subsystem classes** — implement the subsystem's functionality; unaware of the facade
- **Additional Facade** (optional) — prevents a single facade from becoming bloated
- **Client** — uses the facade instead of calling subsystem objects directly

**How to Apply:**
1. Identify whether a simpler interface to the subsystem is possible
2. Create the facade class that provides the simplified methods clients need
3. Inside the facade, initialize and manage subsystem objects
4. Route client calls to the appropriate subsystem objects
5. Client code works through the facade; subsystem code is hidden behind it
6. If the facade grows too large, extract additional facades

**Pros:**
- Isolates client code from subsystem complexity
- Promotes loose coupling between client and subsystem
- Can serve as a starting point for layered architecture

**Cons:**
- The facade can become a "god object" coupled to everything in the subsystem
- Clients may still need to use subsystem classes for advanced operations

**Common Misuses:**
- Creating a facade that just mirrors the subsystem's methods without simplification
- Making the facade the only way to access the subsystem when direct access is needed

**Related Patterns:** Adapter (wraps one object to change interface; Facade wraps an entire subsystem), Abstract Factory (can be used as an alternative to Facade to hide subsystem creation), Mediator (similar to Facade but with bidirectional communication), Singleton (a facade is often a singleton)

---

### Flyweight

**Intent:** Share common parts of state between multiple objects to reduce memory consumption.

**When to Use:**
- Application needs a huge number of similar objects
- Objects contain duplicate state that can be extracted and shared
- Many groups of objects can be replaced by a few shared objects once extrinsic state is extracted

**Code Smells That Signal This Pattern:**
- Memory exhaustion from creating a large number of similar objects
- Objects that carry duplicate immutable data
- Repeated object creation for data that could be cached

**Structure:**
- **Flyweight** — contains the shared (intrinsic) state; immutable
- **Context** — contains the extrinsic state unique to each object
- **Flyweight Factory** — manages a pool of existing flyweights and returns shared instances
- **Client** — calculates or stores extrinsic state and passes it to flyweight methods

**How to Apply:**
1. Split the object's fields into intrinsic (shared, immutable) and extrinsic (unique, contextual) state
2. Keep intrinsic state in the flyweight class; make it immutable
3. Move extrinsic state out — methods that use it should accept it as parameters
4. Create a factory that manages a pool of flyweights, returning existing ones or creating new ones
5. Client code stores/computes extrinsic state and passes it when calling flyweight methods

**Pros:**
- Saves large amounts of RAM when many similar objects exist
- Centralizes shared data

**Cons:**
- Trades RAM for CPU (extrinsic state must be recalculated or passed around)
- Code becomes more complex with split state
- Can be premature optimization if memory isn't actually a bottleneck

**Common Misuses:**
- Applying Flyweight when there aren't enough objects to justify it
- Including mutable state in the flyweight (breaks sharing)

**Related Patterns:** Composite (Flyweight often stores shared leaf nodes of a Composite tree), Singleton (Flyweight may resemble Singleton but Flyweight can have multiple instances with different intrinsic state)

---

### Proxy

**Intent:** Provide a surrogate or placeholder for another object to control access to it.

**When to Use:**
- You need lazy initialization of a heavyweight object (virtual proxy)
- You need access control to an object (protection proxy)
- You need to execute something before/after the main logic of an object (logging, caching proxy)
- You need a local representative of a remote object (remote proxy)

**Code Smells That Signal This Pattern:**
- Repeated access control checks before calling an object's methods
- Objects that are expensive to create but not always used
- Logging/caching logic duplicated around calls to the same object

**Structure:**
- **Service interface** — declares the interface shared by proxy and real service
- **Service** — the real object that the proxy represents
- **Proxy** — wraps the service and controls access; delegates to the service
- **Client** — works with the proxy through the service interface (unaware of the proxy)

**How to Apply:**
1. Define the service interface if one doesn't exist
2. Create the proxy class implementing the service interface
3. Add a reference to the real service object inside the proxy
4. Implement proxy methods — add the control logic (lazy init, caching, access check, logging), then delegate to the real service
5. Optionally add a creation method that decides whether client gets a proxy or the real service

**Pros:**
- Control access to the service without clients knowing
- Manage the lifecycle of the service object
- Works even if the service isn't ready or isn't available
- Open/Closed: new proxies can be introduced without changing service or client

**Cons:**
- Code becomes more complex
- Response time may increase due to the extra layer

**Common Misuses:**
- Using Proxy when direct access is fine and there's no access control or lifecycle concern
- Creating proxies that add no meaningful behavior

**Related Patterns:** Adapter (provides a different interface; Proxy provides the same interface), Facade (Proxy represents one object; Facade represents a subsystem), Decorator (similar structure but different intent — Decorator adds behavior, Proxy controls access)

---

## BEHAVIORAL PATTERNS

### Chain of Responsibility

**Intent:** Pass a request along a chain of handlers, where each handler either processes the request or passes it to the next handler.

**When to Use:**
- Multiple objects may handle a request and the handler isn't known in advance
- You want to process a request through several handlers in sequence
- The set of handlers and their order should be configurable at runtime

**Code Smells That Signal This Pattern:**
- Nested if/else or switch chains checking conditions to decide who handles a request
- A single class responsible for routing requests to different handlers
- Handler logic that manually checks "should I handle this?" before processing

**Structure:**
- **Handler interface** — declares the method for handling requests and optionally setting the next handler
- **Base Handler** (optional) — boilerplate code common to all handlers; stores the next handler reference
- **Concrete Handlers** — contain the actual processing logic; decide whether to handle or pass along
- **Client** — composes the chain and initiates requests

**How to Apply:**
1. Declare the handler interface with a handle method
2. Create a base handler class with a "next handler" field and default forwarding behavior
3. Create concrete handler classes — implement the handle logic; call next handler if not processed
4. Client assembles the chain by linking handlers and sends requests to the first handler
5. The client may trigger any handler in the chain, not just the first

**Pros:**
- Control the order of request handling
- Single Responsibility: each handler focuses on one concern
- Open/Closed: new handlers can be introduced without breaking existing code
- Decouples senders from receivers

**Cons:**
- Some requests may go unhandled if no handler processes them
- Debugging can be tricky — hard to track which handler processed a request

**Common Misuses:**
- Using a chain when a simple conditional would suffice
- Creating chains where every request always goes through all handlers (consider Pipeline instead)

**Related Patterns:** Composite (often used together — leaf components pass requests through parent containers), Command (loosely couples senders to receivers; Chain does the same with sequential processing), Mediator (centralizes communication; Chain distributes it), Observer (notifies all subscribers; Chain passes to one handler at a time)

---

### Command

**Intent:** Turn a request into a stand-alone object that contains all information about the request, allowing parameterization, queuing, logging, and undo operations.

**When to Use:**
- You want to parameterize objects with operations
- You want to queue, schedule, or execute operations remotely
- You need to implement reversible (undo/redo) operations

**Code Smells That Signal This Pattern:**
- UI code directly calling business logic methods
- Duplicate action logic in multiple places (e.g., "save" triggered from menu, toolbar, and shortcut)
- No way to undo or replay actions

**Structure:**
- **Command interface** — declares the execute method (and optionally undo)
- **Concrete Commands** — implement execute by calling methods on the receiver; store parameters
- **Receiver** — the object that does the actual work
- **Invoker** — stores and triggers commands; doesn't know what the command does
- **Client** — creates concrete commands and associates them with receivers

**How to Apply:**
1. Declare the command interface with an `execute()` method
2. Create concrete command classes that store a reference to the receiver and the operation parameters
3. Implement `execute()` by delegating to the receiver's method
4. If undo is needed, implement an `undo()` method that reverses the action and store state before execution
5. The invoker stores the command and calls `execute()` when needed
6. Client creates commands, sets their receivers, and associates them with invokers

**Pros:**
- Single Responsibility: decouples invocation from execution
- Open/Closed: new commands can be added without changing existing code
- Enables undo/redo, deferred execution, and command queuing
- Commands can be composed into composite commands

**Cons:**
- Code becomes more complex with an additional layer between senders and receivers

**Common Misuses:**
- Using Command for simple operations that don't need queuing, undo, or decoupling
- Creating command objects that just pass through to a receiver with no added value

**Related Patterns:** Chain of Responsibility (links handlers), Mediator (eliminates direct connections), Observer (subscription-based notification), Memento (can be used alongside Command for undo), Strategy (both encapsulate behavior — Strategy replaces algorithms, Command encapsulates operations)

---

### Iterator

**Intent:** Provide a way to access the elements of a collection sequentially without exposing its underlying representation.

**When to Use:**
- The collection has a complex data structure internally but you want to hide this from clients
- You need to traverse the same collection in multiple ways
- You want a uniform interface for traversing different data structures

**Code Smells That Signal This Pattern:**
- Client code that accesses internal data structure details (indices, nodes, pointers)
- Traversal logic duplicated across multiple parts of the codebase
- Tight coupling between client code and the collection's storage format

**Structure:**
- **Iterator interface** — declares operations for traversal (next, hasNext, current, reset)
- **Concrete Iterators** — implement the traversal algorithm for a specific collection
- **Collection interface** — declares method(s) to create iterators
- **Concrete Collections** — return appropriate concrete iterator instances

**How to Apply:**
1. Declare the iterator interface with traversal methods
2. Declare the collection interface with a method to create iterators
3. Implement concrete iterator classes for each collection type
4. Implement the iterator creation method in each concrete collection
5. Client code uses the iterator interface — no dependence on concrete collection types

**Pros:**
- Single Responsibility: traversal logic is extracted from the collection
- Open/Closed: new collection types and iterators can be added independently
- Multiple iterators can traverse the same collection in parallel
- Iteration can be paused and resumed

**Cons:**
- Overkill for simple collections
- May be less efficient than direct access for some specialized collections

**Common Misuses:**
- Creating custom iterators when the language's built-in iteration protocol suffices
- Using Iterator for single-traversal scenarios on simple lists

**Related Patterns:** Composite (iterators traverse Composite trees), Factory Method (collection's iterator creation method is a factory method), Memento (can capture iteration state), Visitor (can be used with Iterator to traverse and apply operations)

---

### Mediator

**Intent:** Reduce chaotic dependencies between objects by forcing them to communicate only through a mediator object.

**When to Use:**
- Many classes are tightly coupled and changes to one require changes to many others
- Components can't be reused in other contexts because they depend on too many other components
- You find yourself creating many subclasses just to reuse behavior in slightly different contexts

**Code Smells That Signal This Pattern:**
- Classes that reference many other classes directly
- Circular dependencies between components
- Changes to one component cascade into changes in multiple other components
- Complex dialog or form logic where fields depend on each other

**Structure:**
- **Mediator interface** — declares the notification method used by components
- **Concrete Mediator** — encapsulates the relationships and coordination logic between components
- **Components** — contain business logic; communicate by notifying the mediator (not other components)

**How to Apply:**
1. Identify tightly coupled components that would benefit from more independence
2. Declare the mediator interface with a notification method
3. Implement the concrete mediator that coordinates interactions between components
4. Components store a reference to the mediator, not to each other
5. Components call the mediator's notification method instead of directly calling other components

**Pros:**
- Single Responsibility: communication logic centralized in the mediator
- Open/Closed: new mediators can be introduced without changing components
- Reduces coupling between components
- Components become more reusable

**Cons:**
- The mediator can evolve into a "god object" if it accumulates too much logic
- Centralized control can become a bottleneck

**Common Misuses:**
- Using Mediator when direct communication between two objects is clearer
- Putting business logic in the mediator instead of the components

**Related Patterns:** Chain of Responsibility (passes sequentially), Command (indirect connection between sender and receiver), Facade (simplifies a subsystem — Mediator centralizes communication; Facade is unidirectional, Mediator is bidirectional), Observer (Mediator is often implemented using Observer)

---

### Memento

**Intent:** Save and restore the previous state of an object without revealing the details of its implementation.

**When to Use:**
- You need to produce snapshots of an object's state to restore it later (undo)
- Direct access to the object's fields violates encapsulation

**Code Smells That Signal This Pattern:**
- Undo/redo logic that copies object fields manually
- State-saving code that accesses private fields through reflection or getters
- Snapshot logic tightly coupled to the internal structure of the object

**Structure:**
- **Originator** — creates a memento of its current state and restores state from a memento
- **Memento** — acts as a snapshot of the originator's state; immutable
- **Caretaker** — knows when and why to capture/restore the originator's state; stores mementos

**How to Apply:**
1. Determine which class will be the originator (the object whose state needs saving)
2. Create the memento class — its fields should mirror the originator's state fields
3. Make the memento immutable — set values only through the constructor
4. Implement `save()` in the originator — returns a new memento with current state
5. Implement `restore(memento)` in the originator — sets its state from the memento
6. The caretaker stores mementos and triggers save/restore at appropriate times

**Pros:**
- Produce snapshots without violating encapsulation
- Simplifies the originator by letting the caretaker manage history

**Cons:**
- Frequent memento creation can consume a lot of memory
- Caretakers must track the originator's lifecycle to clean up obsolete mementos
- Dynamic languages can't guarantee memento immutability

**Common Misuses:**
- Creating mementos for objects whose state rarely needs restoring
- Storing too much state in mementos when only partial state needs saving

**Related Patterns:** Command (Command + Memento for undo — command stores the operation, memento stores the state), Iterator (memento can save iteration state), Prototype (simpler alternative if the originator is easy to clone)

---

### Observer

**Intent:** Define a subscription mechanism to notify multiple objects about any events that happen to the object they're observing.

**When to Use:**
- Changes to one object should trigger updates in other objects, and you don't know how many objects need updating
- Some objects need to observe others for a limited time or in specific cases
- You need a one-to-many dependency between objects

**Code Smells That Signal This Pattern:**
- Code that manually calls update methods on multiple objects after a state change
- Tight coupling between a data source and its consumers
- Polling logic where objects check for changes periodically

**Structure:**
- **Publisher (Subject)** — maintains a list of subscribers and notifies them of events
- **Subscriber (Observer) interface** — declares the update/notification method
- **Concrete Subscribers** — implement the update method to react to the publisher's notifications
- **Client** — creates publishers and subscribers and registers subscriptions

**How to Apply:**
1. Identify the publisher (data source) and subscriber (consumer) roles
2. Declare the subscriber interface with an `update()` method
3. Declare a subscription interface in the publisher (subscribe, unsubscribe, notify methods)
4. Implement the notification mechanism — iterate over subscribers and call their update method
5. Concrete subscribers implement the update method with their specific reaction logic
6. Client registers subscribers with the publisher

**Pros:**
- Open/Closed: new subscribers can be added without modifying the publisher
- Establishes relationships between objects at runtime
- Loosely coupled — publisher doesn't need to know subscriber details

**Cons:**
- Subscribers are notified in an unpredictable order
- Memory leaks if subscribers are not properly unsubscribed
- Can cascade unexpected updates if observers trigger further events

**Common Misuses:**
- Using Observer for a single subscriber that could just be called directly
- Not handling unsubscription properly, leading to memory leaks or ghost notifications

**Related Patterns:** Chain of Responsibility (chain passes to one handler; Observer notifies all), Mediator (centralizes Observer-like communication), Command (Commands can be used as subscription messages)

---

### State

**Intent:** Let an object alter its behavior when its internal state changes, appearing as if the object changed its class.

**When to Use:**
- An object behaves differently depending on its current state
- There are many conditionals that check the object's state and change behavior accordingly
- You have a large number of states and the state-specific behavior changes frequently

**Code Smells That Signal This Pattern:**
- Large `if/else` or `switch` blocks based on state
- Methods with multiple code paths depending on the current state
- State-dependent behavior duplicated across multiple methods

**Structure:**
- **Context** — stores a reference to the current state object and delegates behavior to it
- **State interface** — declares the methods that all concrete states must implement
- **Concrete States** — implement the behavior for a specific state; may trigger transitions by changing the context's state

**How to Apply:**
1. Identify the class whose behavior changes based on state — this becomes the context
2. Declare the state interface with all state-specific methods
3. Create concrete state classes for each state, implementing the appropriate behavior
4. Add a field in the context for the current state object
5. Replace state conditionals in the context with delegation to the current state object
6. Implement state transitions — either in the context or in the concrete state classes

**Pros:**
- Single Responsibility: each state's behavior is in its own class
- Open/Closed: new states can be added without changing existing states or context
- Simplifies complex conditional logic

**Cons:**
- Overkill if there are few states or state changes are rare
- Increases the number of classes

**Common Misuses:**
- Using State when a simple boolean flag or enum suffices
- Creating states for objects that don't actually change behavior

**Related Patterns:** Strategy (similar structure — State allows transitions between states; Strategy objects are independent and unaware of each other), Bridge (similar structure — Bridge separates abstraction from implementation; State is about behavior based on internal state)

---

### Strategy

**Intent:** Define a family of algorithms, put each in a separate class, and make their objects interchangeable.

**When to Use:**
- You have multiple algorithms for a task and want to switch between them at runtime
- You have many similar classes that only differ in how they execute some behavior
- You want to isolate the business logic of a class from algorithm implementation details

**Code Smells That Signal This Pattern:**
- Large `if/else` or `switch` blocks selecting between different algorithms
- Duplicate classes that differ only in one method or behavior
- Algorithm logic mixed into the class that uses it

**Structure:**
- **Context** — maintains a reference to the current strategy and delegates work to it
- **Strategy interface** — declares the method(s) common to all algorithms
- **Concrete Strategies** — implement different algorithm variants
- **Client** — creates a concrete strategy and passes it to the context

**How to Apply:**
1. Identify the algorithm that varies and declare the strategy interface for it
2. Extract each algorithm variant into a concrete strategy class
3. Add a field in the context to store a strategy reference
4. The context delegates the algorithmic work to the strategy object
5. Client code selects the appropriate strategy and passes it to the context

**Pros:**
- Swap algorithms at runtime
- Isolates algorithm implementation from code that uses it
- Open/Closed: new strategies can be added without changing context
- Replaces inheritance with composition

**Cons:**
- Overkill if there are only a couple of algorithms that rarely change
- Clients must know the differences between strategies to select the right one
- Many modern languages support functional alternatives (lambdas/closures)

**Common Misuses:**
- Using Strategy for a single algorithm that won't change
- Creating a Strategy hierarchy when a simple function parameter would suffice

**Related Patterns:** State (similar structure — Strategy makes objects independent; State allows transitions), Template Method (Template Method uses inheritance to vary part of an algorithm; Strategy uses composition to vary the whole algorithm), Command (both encapsulate behavior — Strategy is about algorithms, Command about operations), Decorator (changes the skin; Strategy changes the guts)

---

### Template Method

**Intent:** Define the skeleton of an algorithm in a base class, letting subclasses override specific steps without changing the overall structure.

**When to Use:**
- Subclasses should extend only particular steps of an algorithm, not the whole algorithm
- You have several classes with nearly identical algorithms and only minor differences
- You want to let clients extend only particular steps, not the whole algorithm

**Code Smells That Signal This Pattern:**
- Multiple classes with algorithms that are almost identical except for a few steps
- Copy-pasted code across subclasses with slight variations
- An algorithm that must always follow the same sequence of steps

**Structure:**
- **Abstract Class** — declares the template method (the algorithm skeleton) and abstract/hook methods for the variable steps
- **Concrete Classes** — implement the abstract steps and optionally override hook methods

**How to Apply:**
1. Analyze the algorithm and identify which steps are common and which vary
2. Create the abstract class with the template method that calls the steps in order
3. Make common steps concrete methods in the abstract class
4. Make variable steps abstract methods that subclasses must implement
5. Optionally add hook methods (with default empty implementations) for optional extension points
6. Concrete classes implement abstract steps and optionally override hooks

**Pros:**
- Clients override only certain steps without changing the overall structure
- Common code is pulled into the base class, reducing duplication
- Hook methods provide optional extension points

**Cons:**
- Clients are limited by the provided algorithm skeleton
- Template methods with many steps become hard to maintain
- Violates Liskov Substitution Principle if a subclass suppresses a step

**Common Misuses:**
- Using Template Method when the algorithm steps vary too much (use Strategy instead)
- Making too many steps abstract, forcing subclasses to implement things they don't care about

**Related Patterns:** Factory Method (a specialization of Template Method — the factory method is a step in the template), Strategy (Template Method varies part of an algorithm via inheritance; Strategy varies the whole algorithm via composition)

---

### Visitor

**Intent:** Separate algorithms from the objects on which they operate, allowing new operations to be added without modifying the classes.

**When to Use:**
- You need to perform operations across elements of a complex object structure (like a Composite tree)
- You want to add new operations to existing classes without modifying them
- You want to clean up the business logic by extracting auxiliary behaviors into visitor classes

**Code Smells That Signal This Pattern:**
- Operations on a class hierarchy that don't belong to the classes themselves
- New operations frequently added to a class hierarchy, causing frequent modifications
- Type-checking or casting to perform different operations on different element types

**Structure:**
- **Visitor interface** — declares visit methods for each concrete element type
- **Concrete Visitors** — implement the operation for each element type
- **Element interface** — declares the `accept(visitor)` method
- **Concrete Elements** — implement `accept()` by calling the appropriate visit method on the visitor
- **Client** — iterates over elements and passes the visitor to each

**How to Apply:**
1. Declare the visitor interface with a `visit` method for each concrete element class
2. Declare the `accept(visitor)` method in the element interface
3. Implement `accept()` in each concrete element — it should call the visitor method corresponding to its type
4. Create concrete visitor classes implementing the operation for each element type
5. Client creates a visitor and passes it to each element's `accept()` method

**Pros:**
- Open/Closed for operations: new operations (visitors) can be added without changing element classes
- Single Responsibility: related behaviors are grouped in one visitor class
- A visitor can accumulate state while traversing a structure

**Cons:**
- Must update all visitors when a new element class is added
- Visitors may lack access to the private fields of elements
- Not well-suited for hierarchies that change frequently

**Common Misuses:**
- Using Visitor on a hierarchy that changes frequently (adding new element types is painful)
- Creating visitors for operations that only apply to one element type

**Related Patterns:** Composite (Visitor is often used to traverse a Composite tree), Iterator (can be used with Visitor to traverse elements), Command (both encapsulate operations — Visitor applies to elements, Command to requests)

---

## Pattern Selection Quick Reference

When an agent encounters a design problem, use this guide to narrow down the pattern:

| Problem | Consider |
|---|---|
| Need to create objects without specifying exact class | Factory Method, Abstract Factory |
| Object construction is complex with many parameters | Builder |
| Need exactly one instance of a class | Singleton |
| Need to copy existing objects | Prototype |
| Incompatible interfaces | Adapter |
| Need to separate abstraction from implementation | Bridge |
| Tree/hierarchy structure | Composite |
| Add behavior dynamically to objects | Decorator |
| Simplify a complex subsystem | Facade |
| Too many similar objects consuming memory | Flyweight |
| Control access to an object | Proxy |
| Pass request through a pipeline of handlers | Chain of Responsibility |
| Encapsulate operations for undo/queue/logging | Command |
| Traverse a collection without exposing internals | Iterator |
| Reduce coupling between many interdependent objects | Mediator |
| Save/restore object state | Memento |
| Notify multiple objects of changes | Observer |
| Object behavior depends on its state | State |
| Swap algorithms at runtime | Strategy |
| Same algorithm structure, different step implementations | Template Method |
| Add operations to classes without modifying them | Visitor |

---

## Frontmatter Settings

```yaml
name: design-patterns-reference
description: Strict reference for GoF design patterns — agents consult this during code creation, modification, and review to enforce correct pattern usage
user-invocable: false
disable-model-invocation: false
```
