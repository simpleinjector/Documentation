=========================================
Diagnostic Warning - Lifestyle Mismatches
=========================================

Severity
========

Warning

Cause
=====

The component depends on a service with a lifestyle that is shorter than that of the component.

Warning Description
===================

In general, components should only depend on other components that are configured to live at least as long. In other words, it is safe for a transient component to depend on a singleton, but not the other way around. Because components store a reference to their dependencies in (private) instance fields, those dependencies are kept alive for the lifetime of that component. This means that dependencies that are configured with a shorter lifetime than their consumer, accidentally live longer than intended. This can lead to all sorts of bugs, such as hard to debug multi-threading issues.

The Diagnostic Services detect this kind of misconfiguration and report it. The container will be able to compare all built-in lifestyles (and sometimes even custom lifestyles). Here is an overview of the built-in lifestyles ordered by their length:

* :ref:`Transient <Transient>`
* :ref:`Scoped <Scoped>`
* :ref:`Singleton <Singleton>`

.. container:: Note

    **Note**: This kind of error is also known as `Captive Dependency <https://blog.ploeh.dk/2014/06/02/captive-dependency/>`_.
    
.. container:: Note

    **Note**: Lifestyle mismatches are such a common source of bugs, that the container always checks for mismatches the first time a component is resolved, no matter whether you call *Container.Verify()* or not. This behavior can be suppressed by setting the **Container.Options.SuppressLifestyleMismatchVerification** property, but you are advised to keep the default settings.


How to Fix Violations
=====================

There are multiple ways to fix this violation:

* Change the lifestyle of the component to a lifestyle that is as short as or shorter than that of the dependency.
* Change the lifestyle of the dependency to a lifestyle as long as or longer than that of the component.
* Instead of injecting the dependency, inject a factory for the creation of that dependency and call that factory every time an instance is required.

When to Ignore Warnings
=======================

Do not ignore these warnings. False positives for this warning are rare and even when they occur, the registration or the application design can always be changed in a way that the warning disappears.

Example
=======

The following example shows a configuration that will trigger the warning:

.. code-block:: c#

    var container = new Container();

    container.Register<IUserRepository, InMemoryUserRepository>(Lifestyle.Transient);

    // RealUserService depends on IUserRepository
    container.Register<RealUserService>(Lifestyle.Singleton);

    // FakeUserService depends on IUserRepository
    container.Register<FakeUserService>(Lifestyle.Singleton);

    container.Verify();

The *RealUserService* component is registered as **Singleton** but it depends on *IUserRepository* which is configured with the shorter **Transient** lifestyle. Below is an image that shows the output for this configuration in a watch window. The watch window shows two mismatches and one of the warnings is unfolded.

.. image:: images/lifestylemismatch.png 
   :alt: Diagnostics debugger view watch window with lifestyle mismatches

The following example shows how to query the Diagnostic API for Lifetime Mismatches:

.. code-block:: c#

    // using SimpleInjector.Diagnostics;

    var container = /* get verified container */;

    var results = Analyzer.Analyze(container)
        .OfType<LifestyleMismatchDiagnosticResult>();
        
    foreach (var result in results) {
        Console.WriteLine(result.Description);
        Console.WriteLine("Lifestyle of service: " + 
            result.Relationship.Lifestyle.Name);

        Console.WriteLine("Lifestyle of service's dependency: " +
            result.Relationship.Dependency.Lifestyle.Name);
    }

Working with Scoped components
==============================

Simple Injector's Lifestyle Mismatch verification is strict and will warn about injecting :ref:`Transient <Transient>` dependencies into :ref:`Scoped <Scoped>` components. This is because **Transient**, in the context of Simple Injector, means *short lived*. A **Scoped** component, however, could live for quite a long time, depending on the time you decide to keep the `Scope` alive. Simple Injector does not know how your application handles scoping.

This, however, can be a quite restrictive model. Especially for applications where the lifetime of a scope equals that of a web request. In that case the `Scope` lives very short, and in that case the difference in lifetime between the **Transient** and **Scoped** lifestyle might be non-existing. It can, therefore, make sense in these types of applications to loosen the restriction and allow **Transient** dependencies to be injected into **Scoped** consumers. Especially because Simple Injector does track **Scoped** dependencies and allows them to be disposed, while **Transient** components are not tracked. See the :doc:`Disposable Transient Components diagnostic warning <disposabletransientcomponent>` for more information on this behavior.

To allow **Transient** dependencies to be injected into **Scoped** consumers without causing verification warnings, you can configure **Options.UseLoosenedLifestyleMismatchBehavior** as follows:

.. code-block:: c#

    var container = new Container();

    container.Options.UseLoosenedLifestyleMismatchBehavior = true;

.. container:: Note

    **Note** the **Options.UseLoosenedLifestyleMismatchBehavior** setting requires Simple Injector v4.9 or newer.


What about Hybrid lifestyles?
=============================

A :ref:`Hybrid lifestyle <Hybrid>` is a mix between two or more other lifestyles. Here is an example of a custom lifestyle that mixes the **Transient** and **Singleton** lifestyles together:

.. code-block:: c#

    var hybrid = Lifestyle.CreateHybrid(
        lifestyleSelector: () => someCondition,
        trueLifestyle: Lifestyle.Transient,
        falseLifestyle: Lifestyle.Singleton);

.. container:: Note

    **Note** that this example is quite bizarre, since it is a very unlikely combination of lifestyles to mix together, but it serves us well for the purpose of this explanation.

As explained, components should only depend on equal length or longer lived components. But how long does a component with this hybrid lifestyle live? For components that are configured with the lifestyle defined above, it depends on the implementation of `someCondition`. But without taking this condition into consideration, we can say that it will at most live as long as the longest wrapped lifestyle (Singleton in this case) and at least live as long as shortest wrapped lifestyle (in this case Transient).

From the Diagnostic Services' perspective, a component can only safely depend on a hybrid-lifestyled service if the consuming component's lifestyle is shorter than or equal the shortest lifestyle the hybrid is composed of. On the other hand, a hybrid-lifestyled component can only safely depend on another service when the longest lifestyle of the hybrid is shorter than or equal to the lifestyle of the dependency. Thus, when a relationship between a component and its dependency is evaluated by the Diagnostic Services, the **longest** lifestyle is used in the comparison when the hybrid is part of the consuming component, and the **shortest** lifestyle is used when the hybrid is part of the dependency.

This does imply that two components with the same hybrid lifestyle can't safely depend on each other. This is true since in theory the supplied predicate could change results in each call. In practice however, those components would usually be able safely relate, since it is normally unlikely that the predicate changes lifestyles within a single object graph. This is an exception the Diagnostic Services can make pretty safely. From the Diagnostic Services' perspective, components can safely be related when both share the exact same lifestyle instance and no warning will be displayed in this case. This does mean however, that you should be very careful using predicates that change the lifestyle during the object graph.

Iterating injected collections during construction can lead to warnings
=======================================================================

Simple Injector v4.5 improved the ability to find Lifestyle Mismatches by trying to detect when injected collections are iterated during object composition. This can lead to warnings similar to the following:

.. container:: Note

    {dependency} is part of the {collection} that is injected into {consumer}. The problem in {consumer} is that instead of storing the injected {collection} in a private field and iterating over it at the point its instances are required, {dependency} is being resolved (from the collection) during object construction. Resolving services from an injected collection during object construction (e.g. by calling {parameter name}.ToList() in the constructor) is not advised.

This warning is stating that the `collection` (e.g. an `IEnumerable<ILogger>`), which was injected into a class called `consumer`, was iterated during object construction—most likely inside the constructor.

The following code will reproduce the issue:

.. code-block:: c#

    public class Consumer
    {
        private readonly IEnumerable<ILogger> loggers;
        public Consumer(IEnumerable<ILogger> loggers)
        {
            // Calling ToArray will cause the warning
            this.loggers = loggers.ToArray();
        }
    }
    
    // Registrations
    var container = new Container();

    container.Collection.Append<ILogger, MyLogger>(Lifestyle.Transient);
    container.Register<Consumer>(Lifestyle.Singleton);

    container.Verify();

This warning will appear in case the following conditions hold:

* The consuming component is registered as **Singleton**. In this case, `Consumer` is registered as **Singleton**.
* The injected collection contains any components with a lifetime smaller than **Singleton**. In this case, the injected `IEnumerable<ILogger>` contains a component called `MyLogger` with the **Transient** lifestyle.
* The injected collection is iterated in a way that its instances are created and returned. In this case, the call to `.ToArray()` causes the `MyLogger` component to be marked as Lifestyle Mismatched.

All collection abstractions (i.e. `IEnumerable<T>`, `IList<T>`, `IReadOnlyList<T>`, `ICollection<T>`, and `IReadOnlyCollection<T>`) that Simple Injector injects behave as *streams*. This means that during injection no instances are created. Instead, instances are created according to their lifestyle every time the stream is iterated. This means that storing a copy of the injected stream, as the `Consumer` in the previous example did, can cause Lifestyle Mismatches, which is why Simple Injector warns about this.

Do note that it is impossible for Simple Injector to detect whether you store the original stream or its copy in its private instance field. This means that Simple Injector will report the warning, even when `Consumer` is written as follows:

.. code-block:: c#

    public class Consumer
    {
        private readonly IEnumerable<ILogger> loggers;
        public Consumer(IEnumerable<ILogger> loggers)
        {
            if (!loggers.ToArray().Any()) throw new ArgumentException();
            this.loggers = loggers;
        }
    }

In this case, Simple Injector will still report the Lifestyle Mismatch between `Consumer` and `MyLogger` even though this is a false positive.

.. container:: Note

    Even though false positives might occur, best practice is to prevent iterating the injected stream inside the constructor, as prescribed `here <https://blog.ploeh.dk/2011/03/03/InjectionConstructorsshouldbesimple/>`_.
