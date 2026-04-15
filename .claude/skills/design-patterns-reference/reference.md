# Design Patterns — Detailed Pattern Reference

Complete details for all 23 GoF design patterns. This file is the detailed companion to `SKILL.md`.

---

## CREATIONAL PATTERNS

### Singleton

**Intent:** Ensure a class has only one instance and provide a global access point to it.

**When to Use:**
- A single shared resource must be accessed across the application (database connection, configuration, logger)
- Creating multiple instances would cause conflicts or waste resources

**Code Smells:** Global variables sharing a single resource; multiple instantiations of what should exist once; constructor calls for the same resource scattered across the codebase.

**Structure:** Singleton class stores the single instance as a private static field; provides a public static method (`getInstance()`) that returns the cached instance.

**How to Apply:**
1. Add a private static field to store the singleton instance
2. Declare a public static creation method
3. Implement lazy initialization — create on first call, return cached on subsequent calls
4. Make the constructor private
5. Handle thread safety in multithreaded environments

**Pros:** Guarantees single instance; global access point; lazy initialization.
**Cons:** Violates Single Responsibility Principle; masks bad design via global state; hard to unit test; requires thread-safety handling.

**Common Misuses:** Using as a shortcut for global variables; applying when dependency injection would be cleaner.

**Related:** Facade, Abstract Factory, Builder, Prototype (all can be singletons).

---

### Factory Method

**Intent:** Define an interface for creating objects, but let subclasses decide which class to instantiate.

**When to Use:**
- You don't know ahead of time the exact types your code needs
- You want to extend creation logic without modifying existing code

**Code Smells:** Large if/else or switch blocks instantiating different classes by condition; constructor calls with varying parameters scattered across code.

**Structure:** Product interface + Concrete Products + Creator (declares factory method) + Concrete Creators (override factory method).

**How to Apply:**
1. Define a common product interface
2. Create concrete product classes
3. Declare the factory method in the creator class (return type = product interface)
4. Override the factory method in each concrete creator
5. Replace direct constructor calls with factory method calls

**Pros:** Avoids tight coupling; Single Responsibility (centralized creation); Open/Closed (new products without breaking code).
**Cons:** More subclasses; requires a creator subclass per product type.

**Common Misuses:** Factory for a single product type with no variation; overcomplicating simple creation.

**Related:** Abstract Factory (often uses Factory Methods), Template Method (Factory Method is a specialization), Prototype.

---

### Abstract Factory

**Intent:** Produce families of related objects without specifying their concrete classes.

**When to Use:**
- Code needs to work with families of related products (e.g., UI elements per OS)
- Products from the same family must be used together

**Code Smells:** Multiple related Factory Methods always used together; hard-coded concrete types for product families; platform-specific creation scattered across codebase.

**Structure:** Abstract Factory interface + Concrete Factories (per family) + Abstract Product interfaces + Concrete Products + Client (uses abstract interfaces only).

**How to Apply:**
1. Map out product types and their family variants
2. Declare abstract product interfaces
3. Declare the abstract factory interface with creation methods for all product types
4. Implement a concrete factory per product family
5. Select concrete factory based on configuration/environment
6. Replace direct constructor calls with factory calls

**Pros:** Guarantees product family compatibility; loose coupling; Open/Closed.
**Cons:** High complexity; adding a new product type changes all factories.

**Common Misuses:** Using with only one product family; creating factories for unrelated products.

**Related:** Factory Method, Builder, Prototype.

---

### Builder

**Intent:** Construct complex objects step by step, allowing different representations using the same construction process.

**When to Use:**
- Object construction involves many steps or parameters
- You want different representations of the same product
- You need to construct composite or deeply nested objects

**Code Smells:** Telescoping constructors (many parameters); multiple constructor overloads; complex initialization logic duplicated.

**Structure:** Builder interface + Concrete Builders + Product + Director (optional, defines build order).

**How to Apply:**
1. Identify construction steps common to all representations
2. Declare these steps in the builder interface
3. Create concrete builders for each representation
4. Optionally create a director for specific construction sequences
5. Client creates builder, optionally uses director, retrieves result

**Pros:** Step-by-step construction; reuse construction code; Single Responsibility.
**Cons:** More classes; client must know builder implementations.

**Common Misuses:** Builder for simple objects with few parameters; when named/optional parameters suffice.

**Related:** Abstract Factory, Composite (builders often build Composite trees), Singleton.

---

### Prototype

**Intent:** Create new objects by copying existing ones without depending on their concrete classes.

**When to Use:**
- Object creation is expensive and a similar object already exists
- You want to reduce subclasses that differ only in initialization
- You need runtime object creation without knowing concrete types

**Code Smells:** Repetitive initialization creating similar objects; large switch/if blocks creating objects sharing most configuration.

**Structure:** Prototype interface (`clone()`) + Concrete Prototypes + Prototype Registry (optional).

**How to Apply:**
1. Declare the prototype interface with `clone()`
2. Implement `clone()` in each class — handle deep vs. shallow copy
3. Optionally create a registry for pre-configured prototypes
4. Replace `new` calls with `clone()` on existing prototypes

**Pros:** Clone without coupling to concrete classes; eliminate repeated initialization; produce complex objects conveniently.
**Cons:** Circular references are tricky; deep cloning requires care.

**Common Misuses:** Prototyping cheap-to-construct objects; shallow copy when deep copy is needed.

**Related:** Factory Method, Abstract Factory, Memento.

---

## STRUCTURAL PATTERNS

### Adapter

**Intent:** Allow objects with incompatible interfaces to work together by wrapping one to match another.

**When to Use:**
- Existing class interface doesn't match what you need
- You want a reusable class that cooperates with unforeseen classes

**Code Smells:** Wrapper code translating between interfaces, duplicated in multiple places; direct manipulation of third-party objects to make them fit.

**Structure:** Target interface + Adapter (implements target, wraps adaptee) + Adaptee + Client.

**How to Apply:**
1. Identify the two incompatible interfaces
2. Create the adapter implementing the target interface
3. Add a reference to the adaptee inside the adapter
4. Implement target methods by delegating to the adaptee
5. Client uses the adapter through the target interface

**Pros:** Single Responsibility; Open/Closed.
**Cons:** Added complexity; sometimes simpler to change the existing class.

**Common Misuses:** Adapting when you control both interfaces; adapting nearly identical interfaces.

**Related:** Bridge (designed up front; Adapter is retrofit), Decorator (changes behavior; Adapter changes interface), Facade (new interface for subsystem), Proxy (same interface, controls access).

---

### Bridge

**Intent:** Separate an abstraction from its implementation so both can vary independently.

**When to Use:**
- A class has multiple orthogonal dimensions of variation
- You need to switch implementations at runtime
- Class hierarchy grows exponentially from variant combinations

**Code Smells:** Exponential class hierarchy (Shape + Color = RedCircle, BlueSquare, etc.); platform-specific code mixed with business logic.

**Structure:** Abstraction + Refined Abstraction + Implementation interface + Concrete Implementations.

**How to Apply:**
1. Identify orthogonal dimensions in your classes
2. Define client operations in the abstraction
3. Define platform/variant operations in the implementation interface
4. Create concrete implementations
5. Abstraction holds a reference to the implementation; client passes desired implementation via constructor

**Pros:** Platform-independent code; Open/Closed in both dimensions; Single Responsibility.
**Cons:** Overcomplicated for cohesive classes; more initial setup.

**Common Misuses:** Using with only one dimension of variation; applying to simple classes.

**Related:** Adapter (retrofit vs. Bridge's up-front design), Abstract Factory, Strategy (similar structure, different intent).

---

### Composite

**Intent:** Compose objects into tree structures for part-whole hierarchies; treat individual objects and compositions uniformly.

**When to Use:**
- Tree-like object structure
- Uniform treatment of simple and complex elements
- Recursive structures (containers holding items and other containers)

**Code Smells:** Separate handling for individual items vs. groups; type-checking to distinguish simple from compound objects.

**Structure:** Component interface + Leaf + Composite (stores children, delegates to them) + Client.

**How to Apply:**
1. Ensure the model can be a tree
2. Declare the component interface for both leaves and composites
3. Create leaf classes
4. Create composite classes with child collection and delegation logic
5. Define add/remove child methods

**Pros:** Polymorphism and recursion for tree structures; Open/Closed; simplified client code.
**Cons:** Hard to provide a common interface when functionality differs too much.

**Common Misuses:** Using for flat structures; forcing tree structure on non-hierarchical data.

**Related:** Builder, Iterator, Visitor, Chain of Responsibility.

---

### Decorator

**Intent:** Attach new behaviors to objects dynamically by wrapping them, as a flexible alternative to subclassing.

**When to Use:**
- Add responsibilities at runtime without affecting other objects
- Inheritance is awkward or impossible
- Combine behaviors by stacking wrappers

**Code Smells:** Subclass explosion from combining features; conditional logic enabling/disabling optional behaviors.

**Structure:** Component interface + Concrete Component + Base Decorator + Concrete Decorators.

**How to Apply:**
1. Identify the core component interface
2. Create a base decorator wrapping a component and delegating all operations
3. Create concrete decorators adding behavior before/after delegation
4. Client composes by wrapping core in one or more decorators

**Pros:** Extend without subclassing; runtime add/remove; stackable; Single Responsibility per decorator.
**Cons:** Hard to remove a specific wrapper mid-stack; order-dependent; complex configuration.

**Common Misuses:** Decorator when inheritance is simpler and behavior is compile-time; decorating core behaviors.

**Related:** Adapter (changes interface), Composite (similar structure), Strategy (changes guts; Decorator changes skin), Proxy (same interface — Proxy controls access, Decorator adds behavior).

---

### Facade

**Intent:** Provide a simplified, unified interface to a complex subsystem.

**When to Use:**
- Need a simple interface to a complex subsystem
- Want to structure a subsystem into layers
- Want to decouple client code from subsystem internals

**Code Smells:** Client code interacting with many subsystem classes directly; complex initialization sequences; business logic mixed with subsystem orchestration.

**Structure:** Facade + Subsystem classes + Additional Facade (optional) + Client.

**How to Apply:**
1. Identify whether a simpler interface is possible
2. Create the facade with simplified methods
3. Inside the facade, manage subsystem objects
4. Route client calls to appropriate subsystem objects
5. If the facade grows too large, extract additional facades

**Pros:** Isolates from complexity; promotes loose coupling; good for layered architecture.
**Cons:** Can become a god object; clients may still need direct subsystem access.

**Common Misuses:** Facade that mirrors subsystem methods without simplification; blocking all direct subsystem access.

**Related:** Adapter (wraps one object; Facade wraps subsystem), Abstract Factory, Mediator (bidirectional; Facade is unidirectional), Singleton (Facade is often a singleton).

---

### Flyweight

**Intent:** Share common state between multiple objects to reduce memory consumption.

**When to Use:**
- Huge number of similar objects
- Objects contain duplicate immutable state that can be shared
- Many object groups replaceable by few shared objects once extrinsic state is extracted

**Code Smells:** Memory exhaustion from many similar objects; duplicate immutable data across instances; repeated creation for cacheable data.

**Structure:** Flyweight (shared intrinsic state, immutable) + Context (unique extrinsic state) + Flyweight Factory + Client.

**How to Apply:**
1. Split fields into intrinsic (shared, immutable) and extrinsic (unique, contextual)
2. Keep intrinsic state in the flyweight; make it immutable
3. Methods accept extrinsic state as parameters
4. Create a factory managing a pool of flyweights
5. Client stores/computes extrinsic state and passes it to flyweight methods

**Pros:** Saves large amounts of RAM.
**Cons:** Trades RAM for CPU; split state adds complexity; premature optimization if memory isn't a bottleneck.

**Common Misuses:** Applying when not enough objects to justify; including mutable state in flyweight.

**Related:** Composite (shared Composite leaf nodes), Singleton (Flyweight can have multiple instances with different intrinsic state).

---

### Proxy

**Intent:** Provide a surrogate or placeholder for another object to control access.

**When to Use:**
- Lazy initialization of heavyweight objects (virtual proxy)
- Access control (protection proxy)
- Logging, caching before/after main logic (logging/caching proxy)
- Local representative of remote object (remote proxy)

**Code Smells:** Repeated access control checks before method calls; expensive objects not always used; duplicated logging/caching around same object.

**Structure:** Service interface + Service + Proxy (wraps service, controls access) + Client.

**How to Apply:**
1. Define the service interface
2. Create the proxy implementing the service interface
3. Add a reference to the real service
4. Implement proxy methods with control logic, then delegate to service
5. Optionally add a factory deciding whether client gets proxy or real service

**Pros:** Control access transparently; manage lifecycle; works when service isn't ready; Open/Closed.
**Cons:** More complexity; possible response delay.

**Common Misuses:** Proxy when direct access is fine; proxies adding no meaningful behavior.

**Related:** Adapter (different interface), Facade (wraps subsystem), Decorator (adds behavior; Proxy controls access).

---

## BEHAVIORAL PATTERNS

### Chain of Responsibility

**Intent:** Pass a request along a chain of handlers; each handler processes or passes it along.

**When to Use:**
- Multiple objects may handle a request; handler isn't known in advance
- Process requests through several handlers in sequence
- Handler set and order configurable at runtime

**Code Smells:** Nested if/else chains deciding who handles a request; a single class routing to different handlers.

**Structure:** Handler interface + Base Handler + Concrete Handlers + Client (assembles chain).

**How to Apply:**
1. Declare handler interface with a handle method
2. Create base handler with "next handler" field and forwarding
3. Concrete handlers implement logic; call next if not processed
4. Client assembles chain and sends requests to the first handler

**Pros:** Control handling order; Single Responsibility; Open/Closed; decouples senders from receivers.
**Cons:** Some requests may go unhandled; harder to debug.

**Common Misuses:** Chain when simple conditional suffices; chains where every request always passes through all handlers.

**Related:** Composite, Command, Mediator, Observer.

---

### Command

**Intent:** Turn a request into a stand-alone object with all request information, enabling parameterization, queuing, logging, and undo.

**When to Use:**
- Parameterize objects with operations
- Queue, schedule, or execute operations remotely
- Implement undo/redo

**Code Smells:** UI code directly calling business logic; duplicate action logic (save from menu, toolbar, shortcut); no way to undo/replay.

**Structure:** Command interface (`execute()`, optionally `undo()`) + Concrete Commands + Receiver + Invoker + Client.

**How to Apply:**
1. Declare command interface with `execute()`
2. Concrete commands store receiver reference and parameters
3. Implement `execute()` by delegating to receiver
4. For undo: implement `undo()`, store pre-execution state
5. Invoker stores and triggers commands
6. Client creates commands, sets receivers, associates with invokers

**Pros:** Single Responsibility; Open/Closed; undo/redo; queuing; composable.
**Cons:** More complexity with additional layer.

**Common Misuses:** Command for simple operations not needing queuing/undo; pass-through commands.

**Related:** Chain of Responsibility, Mediator, Observer, Memento (for undo), Strategy.

---

### Iterator

**Intent:** Access elements of a collection sequentially without exposing its underlying representation.

**When to Use:**
- Complex internal data structure hidden from clients
- Multiple traversal methods needed for the same collection
- Uniform traversal interface across different data structures

**Code Smells:** Client code accessing internal structure details (indices, nodes); duplicated traversal logic.

**Structure:** Iterator interface (next, hasNext, current, reset) + Concrete Iterators + Collection interface + Concrete Collections.

**How to Apply:**
1. Declare iterator interface with traversal methods
2. Declare collection interface with iterator creation method
3. Implement concrete iterators per collection type
4. Collections return appropriate iterator
5. Client uses iterator interface only

**Pros:** Single Responsibility; Open/Closed; parallel iteration; pause/resume.
**Cons:** Overkill for simple collections; may be less efficient than direct access.

**Common Misuses:** Custom iterators when language built-ins suffice; Iterator for single-traversal on simple lists.

**Related:** Composite, Factory Method, Memento, Visitor.

---

### Mediator

**Intent:** Reduce chaotic dependencies between objects by forcing communication through a mediator.

**When to Use:**
- Many tightly coupled classes; changes cascade
- Components can't be reused because of excessive dependencies
- Many subclasses needed just to reuse behavior in slightly different contexts

**Code Smells:** Classes referencing many other classes; circular dependencies; changes to one component cascading across many.

**Structure:** Mediator interface + Concrete Mediator + Components (notify mediator, not each other).

**How to Apply:**
1. Identify tightly coupled components
2. Declare mediator interface with notification method
3. Concrete mediator coordinates interactions
4. Components store mediator reference, not references to each other
5. Components call mediator instead of calling other components directly

**Pros:** Single Responsibility; Open/Closed; reduced coupling; reusable components.
**Cons:** Mediator can become a god object.

**Common Misuses:** Mediator when direct communication between two objects is clearer; business logic in the mediator.

**Related:** Chain of Responsibility, Command, Facade, Observer.

---

### Memento

**Intent:** Save and restore previous state of an object without revealing its implementation details.

**When to Use:**
- Need snapshots for undo/restore
- Direct field access violates encapsulation

**Code Smells:** Undo logic copying object fields manually; state-saving code accessing private fields; snapshot logic coupled to internal structure.

**Structure:** Originator (creates/restores from memento) + Memento (immutable snapshot) + Caretaker (stores mementos).

**How to Apply:**
1. Identify the originator
2. Create memento class mirroring originator's state fields
3. Make memento immutable
4. Originator's `save()` returns new memento; `restore(memento)` sets state
5. Caretaker stores mementos and triggers save/restore

**Pros:** Snapshots without violating encapsulation; history management separated from originator.
**Cons:** Frequent mementos consume memory; caretaker must manage lifecycle.

**Common Misuses:** Mementos for objects whose state rarely needs restoring; storing too much state.

**Related:** Command (for undo), Iterator, Prototype.

---

### Observer

**Intent:** Define a subscription mechanism to notify multiple objects about events on the object they observe.

**When to Use:**
- Changes to one object should trigger updates in others
- Unknown number of objects need updating
- One-to-many dependency between objects

**Code Smells:** Manual update calls to multiple objects after state changes; tight coupling between data source and consumers; polling for changes.

**Structure:** Publisher (Subject) + Subscriber (Observer) interface + Concrete Subscribers + Client.

**How to Apply:**
1. Identify publisher and subscriber roles
2. Declare subscriber interface with `update()`
3. Publisher declares subscribe/unsubscribe/notify methods
4. Notify iterates subscribers and calls `update()`
5. Concrete subscribers implement reaction logic
6. Client registers subscribers

**Pros:** Open/Closed; runtime relationships; loose coupling.
**Cons:** Unpredictable notification order; memory leaks from improper unsubscription; cascading updates.

**Common Misuses:** Observer for a single subscriber; not handling unsubscription (memory leaks).

**Related:** Chain of Responsibility, Mediator, Command.

---

### State

**Intent:** Let an object alter its behavior when its internal state changes, as if it changed its class.

**When to Use:**
- Object behaves differently per state
- Many conditionals check state to change behavior
- State-specific behavior changes frequently

**Code Smells:** Large if/else or switch blocks based on state; multiple code paths per method depending on state.

**Structure:** Context (delegates to current state) + State interface + Concrete States.

**How to Apply:**
1. Identify the context class
2. Declare state interface with all state-specific methods
3. Create concrete state classes per state
4. Context holds current state object reference
5. Replace conditionals with delegation to current state
6. State transitions change the context's state object

**Pros:** Single Responsibility; Open/Closed; eliminates complex conditionals.
**Cons:** Overkill for few states; more classes.

**Common Misuses:** State when a boolean/enum suffices; states for objects that don't change behavior.

**Related:** Strategy (similar structure; State allows transitions, Strategy objects are independent), Bridge.

---

### Strategy

**Intent:** Define a family of algorithms, encapsulate each one, and make them interchangeable.

**When to Use:**
- Multiple algorithms for a task, switchable at runtime
- Many similar classes differing only in one behavior
- Isolate algorithm implementation from the class that uses it

**Code Smells:** Large if/else or switch selecting between algorithms; duplicate classes differing in one method; algorithm logic mixed into business class.

**Structure:** Context + Strategy interface + Concrete Strategies + Client.

**How to Apply:**
1. Identify the varying algorithm; declare strategy interface
2. Extract each variant into a concrete strategy
3. Context holds strategy reference
4. Context delegates algorithmic work to strategy
5. Client selects and passes strategy to context

**Pros:** Runtime algorithm swap; isolated implementation; Open/Closed; composition over inheritance.
**Cons:** Overkill for few static algorithms; clients must know strategy differences; lambdas may suffice.

**Common Misuses:** Strategy for a single unchanging algorithm; Strategy when a function parameter suffices.

**Related:** State, Template Method, Command, Decorator.

---

### Template Method

**Intent:** Define the skeleton of an algorithm in a base class, letting subclasses override specific steps.

**When to Use:**
- Subclasses should extend particular steps, not the whole algorithm
- Several classes have nearly identical algorithms with minor differences

**Code Smells:** Multiple classes with almost identical algorithms except a few steps; copy-pasted code with slight variations.

**Structure:** Abstract Class (template method + abstract/hook steps) + Concrete Classes.

**How to Apply:**
1. Identify common vs. variable steps
2. Create abstract class with template method calling steps in order
3. Common steps as concrete methods
4. Variable steps as abstract methods
5. Optional hook methods with default empty implementations
6. Concrete classes implement abstract steps, optionally override hooks

**Pros:** Clients override only certain steps; reduced duplication; hook extension points.
**Cons:** Limited by algorithm skeleton; many steps = hard maintenance; may violate LSP.

**Common Misuses:** Template Method when steps vary too much (use Strategy); too many abstract steps.

**Related:** Factory Method (specialization of Template Method), Strategy (composition vs. inheritance).

---

### Visitor

**Intent:** Separate algorithms from the objects on which they operate, allowing new operations without modifying classes.

**When to Use:**
- Operations across a complex structure (like a Composite tree)
- Add operations without modifying classes
- Clean up business logic by extracting auxiliary behaviors

**Code Smells:** Operations on a hierarchy that don't belong to the classes; frequent new operations causing frequent class modifications; type-checking/casting for different operations.

**Structure:** Visitor interface (visit per element type) + Concrete Visitors + Element interface (`accept(visitor)`) + Concrete Elements + Client.

**How to Apply:**
1. Declare visitor interface with `visit` per concrete element
2. Declare `accept(visitor)` in element interface
3. Elements implement `accept()` calling the corresponding visit method
4. Concrete visitors implement operations per element type
5. Client creates visitor and passes to each element's `accept()`

**Pros:** Open/Closed for operations; Single Responsibility; visitor accumulates state while traversing.
**Cons:** Must update all visitors when new element types are added; limited access to private fields.

**Common Misuses:** Visitor on frequently changing hierarchies; visitors for single-element-type operations.

**Related:** Composite, Iterator, Command.
