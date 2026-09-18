# From Big Ball of Mud to Fitness Functions: How to Keep Architecture Alive

> *Inspired by "Fundamentals of Software Architecture" by Mark Richards & Neal Ford*

---

I have been building distributed systems for over a decade — from monoliths that quietly became unmanageable, to event-driven Elixir services processing hundreds of thousands of operations per day. And if there is one honest confession every senior engineer eventually makes, it is this: **architecture does not rot suddenly. It rots quietly, one compromise at a time.**

This article is about that rot, how to detect it, and — more importantly — how to build the automated guardrails that prevent it from coming back.

---

## The System That Was Never Designed to Be a Mess

Every codebase that became a nightmare was once someone's clean starting point. No engineer woke up and decided to write a Big Ball of Mud. Yet here is how Richards and Ford describe what eventually emerges in codebases that lack structural discipline:

> *"A Big Ball of Mud is a haphazardly structured, sloppy, duct-tape-and-baling-wire, spaghetti-code jungle."*
> — Brian Foote & Joseph Yoder, 1997 (cited in *Fundamentals of Software Architecture*)

The term is brutal, but accurate. When architecture has no perceivable structure, every new feature becomes an act of archaeology. Developers spend more time understanding what exists than building what is needed. Coupling creeps in because the path of least resistance is always to reach across whatever boundary feels inconvenient that afternoon.

I have seen this pattern up close. At one company, a monolith that started clean had, over three years, grown into a system where changing a billing rule required touching seven different modules — none of which were obviously related to billing. No one planned it that way. It just happened, incrementally, under deadline pressure.

The Big Ball of Mud is not a technical problem. It is the consequence of architecture being treated as a starting condition rather than an ongoing discipline.

---

## Seeing the Rot: JDepend and Dependency Cycles

Before you can fix structural problems, you need to see them. And they are often invisible to the human eye inside large codebases.

This is where static analysis tools become essential. Richards and Ford describe one concrete approach:

> *"In code, an architect uses the JDepend metric tool to verify dependencies between packages. The tool understands the structure of Java packages and fails the build if any cycle exists."*
> — *Fundamentals of Software Architecture*

Dependency cycles are one of the clearest signals that your architecture has been compromised. A cycle means Module A depends on Module B, which depends on Module C, which depends back on Module A. You can no longer reason about any of them in isolation. You can no longer test them independently. You can no longer evolve them without coordinating changes across all three.

JDepend exposes cycles automatically and, critically, fails the build when one is detected. This is the key move: turning an architectural rule into a mechanical constraint enforced by the CI pipeline.

The underlying principle applies regardless of language. In Elixir projects I have worked on, the equivalent is being deliberate about which contexts are allowed to call which — and writing tests that assert those boundaries are respected. The tool is different, but the intent is identical: **make architectural violations visible and automatically rejected.**

---

## Enforcing Architecture: ArchUnit and Fitness Functions

Detecting problems after they have been introduced is useful. Preventing them from being introduced is better.

This is the idea behind fitness functions — a concept Richards and Ford develop extensively throughout *Fundamentals of Software Architecture*. A fitness function is an automated test that verifies an architectural characteristic. Not a business rule. Not a unit behavior. A structural property of the system itself.

ArchUnit makes this practical for JVM projects:

> *"ArchUnit allows architects to handle the problem via fitness function... the architect defines the desired relationship between layers and writes a verification fitness function to control it."*
> — *Fundamentals of Software Architecture*

Consider a layered architecture where the rule is: the `domain` layer must never import anything from the `infrastructure` layer. This is a reasonable rule. It keeps business logic portable and testable. But it is a rule that lives only in documentation — until someone writes an ArchUnit test that enforces it automatically.

```java
@Test
void domain_should_not_depend_on_infrastructure() {
    noClasses()
        .that().resideInAPackage("..domain..")
        .should().dependOnClassesThat()
        .resideInAPackage("..infrastructure..")
        .check(importedClasses);
}
```

That test runs in CI. Every pull request. Every deployment. The architecture is now *executable* — not aspirational.

This is the mental shift that matters: architectural rules are not policies for people to follow. They are constraints for machines to enforce. The moment you rely only on human discipline to maintain structure, you have accepted that the structure will eventually erode.

---

## Distributed Systems: The Cost of Chatty Services

There is a second dimension to architectural discipline that becomes critical the moment you move beyond a single process: **how much data travels between your services.**

Richards and Ford address this directly when discussing the fallacies of distributed computing:

> *"Regardless of the technique used, ensuring that the minimum amount of data is passed between services or systems in a distributed architecture is the best way to deal with this fallacy."*
> — *Fundamentals of Software Architecture*

The fallacy in question is the assumption that the network is reliable and fast. It is neither — or at least, you cannot depend on it being either. Latency is real. Serialization has cost. Payloads that feel negligible in development become bottlenecks under production load.

I experienced this at Zubale, processing roughly one million records per ingestion cycle. The original implementation moved large, denormalized payloads between services and took close to five hours to complete. The fix was not a faster machine or a different database. It was rethinking what data actually needed to cross service boundaries at each step — and moving only that. The same pipeline then completed in under ten minutes.

The principle is simple to state but difficult to follow under pressure: **pass the minimum. Compute locally when you can. Cross boundaries only when you must.**

This applies whether you are designing REST APIs, Kafka event schemas, or GraphQL queries. Every byte you add to a cross-service payload is a byte that must be serialized, transmitted, deserialized, and — often — ignored by the consumer.

---

## The Thread Connecting All of This

What Richards and Ford are pointing at, across all of these topics, is a single underlying idea: **architecture must be actively maintained, not passively assumed.**

A Big Ball of Mud forms when no one is watching the structure. Dependency cycles accumulate when no tool is checking for them. Layer violations creep in when tests only cover behavior, not boundaries. Distributed services grow bloated payloads when engineers optimize for convenience rather than coupling.

The antidote to all of it is the same: make the rules explicit, automate their verification, and run that verification continuously.

Fitness functions — whether implemented with ArchUnit, JDepend, custom boundary tests in Elixir, or any other mechanism — are how you turn architectural intent into architectural reality. They are the difference between a system that was designed well at the start and a system that is kept well over time.

And that distinction, in production, is everything.

---

*Gustavo Oliveira is a Senior Elixir Engineer with 11+ years of experience designing and operating distributed systems across logistics, fintech, and SaaS. He writes about software architecture, AI-assisted development, and engineering craft at [alchemistdrops.com](https://www.alchemistdrops.com).*
