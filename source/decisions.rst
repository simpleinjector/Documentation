.. _decisions:

================
Design Decisions
================

Our :doc:`design principles <principles>` have influenced the direction of the development of features in Simple Injector. In this section we would like to explain some of the design decisions.

* :ref:`The container is locked after the first call to resolve <Container-is-locked>`
* :ref:`The API clearly separates registration of collections from other registrations <Separate-collections>`
* :ref:`No support for  XML based configuration <No-support-for-XML>`
* :ref:`Never force users to release what they resolve <Never-force-release>`
* :ref:`Don’t allow resolving scoped instances outside an active scope <Dont-allow-resolving-outside-an-active-scope>`
* :ref:`No out-of-the-box support for property injection <No-property-injection>`
* :ref:`No out-of-the-box support for interception <No-interception>`
* :ref:`Limited batch-registration API <Limited-batch-registration>`
* :ref:`No per-thread lifestyle <No-per-thread-lifestyle>`

.. _Container-is-locked:

The container is locked after the first call to resolve
=======================================================

When an application makes its first call to **GetInstance**, **GetAllIntances** or **Verify**, the container locks itself to prevent any future changes being made by explicit registrations. This strictly separates the configuration of the container from its use and forces the user to configure the container in one single place. This design decision is inspired by the following two design principles:

* :ref:`Push developers into best practices <Push-developers-into-best-practices>`
* :ref:`Fast by default <Fast-by-default>`

In most situations it makes little sense to change the configuration once the application is running. This would make the application much more complex, whereas dependency injection as a pattern is meant to lower the total complexity of a system. By strictly separating the registration/startup phase from the phase where the application is in a running state, it is much easier to determine how the container will behave and it is much easier to verify the container’s configuration. The locking behavior of Simple Injector exists to protect the user from defining invalid and/or confusing combinations of registrations.

Allowing the ability to alter the DI configuration while the application is running could easily cause strange, hard to debug, and hard to verify behavior. This may also mean the application has numerous hard references to the container –and this is something we work hard to prevent. Attempting to alter the configuration when running a multi-threaded application would lead to very un-deterministic behavior, even if the container itself is thread-safe.

Imagine the scenario where you want to replace some *FileLogger* component for a different implementation with the same *ILogger* interface. If there’s a different registration that directly or indirectly depends on this registration, replacing the *ILogger* might not work as you would expect. If the depending registration is registered as singleton, for example, the container should guarantee that only one instance will be created. When you are allowed to change the implementation of *ILogger* after a singleton instance already holds a reference to the “old” registered implementation the container has 2 choices – neither of which are correct:

#. Return the cached instance of the registration that has a reference to the "wrong" *ILogger*.
#. Create and cache a new instance of that registration and, in doing so, break the promise of the type being registered as a singleton and the guarantee that the container will always return the same instance.

The description above is a simple to grasp example of dealing with the runtime replacement of services. But adding new registrations can also cause things to go wrong in unexpected ways. A simple example would be where the container has previously supplied the object graph with a default implementation resolved through unregistered type resolution.

Problems with thread-safety can easily emerge when the user changes a registration during a web request. If the container allowed such registration changes during a request, other requests could directly be impacted by those changes (since in general there should only be one *Container* instance per AppDomain). Depending on things such as the lifestyle of the registration; the use of factories and how the object graph is structured, it could be a real possibility that another request gets both the old and the new registration. Take for instance a transient registration that is replaced with a different one. If this is done while an object graph for a different thread is being resolved while the service is injected into multiple points within the graph - the graph would contain different instance of that abstraction with different lifetimes at the same time in the same request – and this is bad.

Since we consider it good practice to lock the container, we were able to greatly optimize performance of the container and adhere to the :ref:`Fast by default <Fast-by-default>` principle.

Do note that container lock-down still allows runtime registrations. A few common ways to add registrations to the container are:

#. Resolving an unregistered concrete type from the container. The container will auto-register that type for you as transient registration.
#. Using :ref:`unregistered type resolution <Unregistered-Type-Resolution>` the container will be able to at a later time resolve new types.
#. The `Lifestyle.CreateProducer <https://simpleinjector.org/ReferenceLibrary/?topic=html/Overload_SimpleInjector_Lifestyle_CreateProducer.htm>`_ overloads can be called at any point in time to create new **InstanceProducer** instances that allow building new registrations.

.. _Separate-collections:

The API clearly differentiates the registration of collections
==============================================================

When designing Simple Injector, we made a very explicit design decision to define a separate **RegisterAll** method for registering a collection of services for an abstraction. This design adheres to the following principles:

* :ref:`Never fail silently <Never-fail-silently>`
* :ref:`Features should be intuitive <Features-should-be-intuitive>`

This design differentiates vastly from how other DI libraries work. Most libraries provide the same API for single registrations and collections. Registering a collection of some abstraction in that case means that you call the **Register** method multiple times with the same abstraction but with different implementations. There are some clear downsides to such an approach. 

* There’s a big difference between having a collection of services and a single service. For many of the services you register you will have one implementation and it doesn’t make sense for there to be multiple implementations. For other services you will always expect a collection of them (even if you have one or no implementations). In the majority (if not all) of cases you wouldn’t expect to switch dynamically between one and multiple implementations and it doesn’t make much sense to create an API that makes it possible.
* An API that mixes these concepts will be unable to warn you if you accidentally add a second registration for the same service. Those APIs will ‘fail silently’ and simply return one of the items you registered. Simple Injector will throw an exception when you call **Register<T>** for the same T and will describe that collections should be registered using **RegisterAll**.
* None of the APIs that mix these concepts make it clear which of the registered services is returned if you resolve one of them. Some libraries will return the first registered element, while others return the last. Although all of them describe this behavior in their documentation it’s not clear from the API itself i.e. it is not discoverable. An API design like this is unintuitive. A design that separates **Register** from **RegisterAll** makes the intention of the code very clear to anyone who reads it.

In general, your services should not depend on an *IEnumerable<ISomeService>*, especially when your application has multiple services that need to work with *ISomeService*. The problem with injecting *IEnumerable* into multiple consumers is that you will have to iterate that collection in multiple places. This forces the consumers to know about having multiple implementations and how to iterate and process that collection. As far as the consumer is concerned this should be an implementation detail. If you ever need to change the way a collection is processed you will have to go through the application, since this logic will have be duplicated throughout the system.

Instead of injecting an *IEnumerable* a consumer should instead depend on a single abstraction and you can achieve this using a `Composite <https://en.wikipedia.org/wiki/Composite_pattern>`_ Implementation that wraps the actual collection and contains the logic of processing the collection. Registering composite implementation is so much easier with Simple Injector because of the clear separation between a single implementation and a collection of implementations. Take the following configuration for example, where we register a collection of *ILogger* implementations and a single composite implementation for use in the rest of our code:

.. code-block:: c#

    container.RegisterAll<ILogger>(
        typeof(FileLogger), 
        typeof(SqlLogger),
        typeof(EventLogLogger));
    
	container.Register<ILogger, CompositeLogger>();

.. _No-support-for-XML:

No support for XML based configuration
======================================

While designing Simple Injector, we decided to *not* provide an XML based configuration API, since we want to:

* :ref:`Push developers into best practices <Push-developers-into-best-practices>` and having a XML centered configuration is *not* best practice

XML based configuration is brittle, error prone and always provides a subset of what you can achieve with code based configuration. General consensus is to use code based configuration as much as possible and only fall back to file based configuration for the parts of the configuration that really need to be customizable after deployment. These are normally just a few registrations since the majority of changes would still require developer interaction (write unit tests or recompiling for instance). Even for those few lines that do need to be configurable, it's a bad idea to require the fully qualified type name in a configuration file. A configuration switch (true/false or simple enum) is more than enough. You can read the configured value in your code based configuration and this allows you to keep the type names in your code. This allows you to refactor easily and gives you compile-time support.

.. _Never-force-release:

Never force users to release what they resolve
==============================================

The `Register Resolve Release <http://blog.ploeh.dk/2010/09/29/TheRegisterResolveReleasepattern/>`_ (RRR) pattern is a common pattern that DI containers implement. In general terms the pattern describes that you should tell the container how to build each object  graph (Register) during application start-up, ask the container for an object graph (Resolve) at the beginning of a request, and tell the container when you’re done with that object graph (Release) after the request.

Although this pattern applies to Simple Injector, we never force users to have to explicitly release any service once they have finished with it. With Simple Injector your components are automatically released when the web request finishes, or when you dispose of your :ref:`Lifetime Scope <PerLifetimeScope>` or :ref:`Execution Context Scope <PerExecutionContextScope>`. By not forcing users to release what they resolve, we adhere to the following design principles:

* :ref:`Never fail silently <Never-fail-silently>`
* :ref:`Features should be intuitive <Features-should-be-intuitive>`

A container that expects the user to release the instances they resolve will fail silently when a user forgets to release, because forgetting to release is a failure and the container doesn’t know when the user is done with the object graph. Forgetting to release can sometimes leads to out of memory exceptions that are often hard to trace back and are therefore costly to fix. The need to release explicitly is far from intuitive and is therefore not needed when working with Simple Injector.

.. _Dont-allow-resolving-outside-an-active-scope:

Don’t allow resolving scoped instances outside an active scope
==============================================================

When you register a component in Simple Injector with a :ref:`scoped lifestyle <Scoped>`, you can only resolve an instance when there is an active instance of that specified scope. For instance, when you register your *DbContext* per Web Request Lifestyle, resolving that instance on a background thread will fail in Simple Injector. This design is chosen because we want to:

* :ref:`Never fail silently <Never-fail-silently>`

The reason is simple - resolving an instance outside of the context of a scope is a bug. The container could decide to return a singleton or transient for you (as other DI libraries do), but neither of these cases is usually what you would expect. Take a look at the *DbContext* example for instance, the class is normally registered as Per Web Request lifestyle for a reason, probably because you want to reuse one instance for the whole request. Not reusing an instance, but instead injecting a new instance (transient) would most likely not give the expected results. Returning a single instance (singleton) when outside of a scope, i.e. reusing a single *DbContext* over multiple requests/threads will sooner or later lead you down the path of failure.

Because there is not a standard logical default for Simple Injector to return when you request an instance outside of the context of an active scope, the right thing to do is throwing an exception. Returning a transient or singleton is a form of failing silently.

That doesn’t mean that you’re lost when you really need the option of per request and transient or singleton, you are required to configure such a scope explicitly by defining a :ref:`Hybrid <Hybrid>` lifestyle. We :ref:`Make simple use cases easy, and complex use cases possible <Make-simple-use-cases-easy>`.

.. _No-property-injection:

No out-of-the-box support for property injection
================================================

Simple Injector has no out-of-the-box support for property injection, to adhere to the following principles:

* :ref:`Don't force vendor lock-in <Vendor-lock-in>`
* :ref:`Never fail silently <Never-fail-silently>`

In general there are two ways of implementing property injection: Implicit and Explicit property injection.
With implicit property injection, the container injects any public writable property by default for any instance you resolve. This is done by mapping those properties to configured types. When no such registration exists, or when the property doesn’t have a public setter, the property will be skipped. Simple Injector does not do implicit property injection, and for good reason. We think that implicit property injection is simply too uuhh... implicit :-). There are many reasons for a container to skip a property, but in none of the cases the container doesn’t know if skipping the property is really what the user wants, or whether it was a bug. In other words, the container is forced to fail silently.

With explicit property injection, the container is forced to inject a property and the process will fail immediately when a property can't be mapped or injected. The common way containers allow you to specify whether a property should be injected or not is by the use of library-defined attributes. As previously discussed, this would force the application to take a dependency on the library, which causes a vendor lock-in.

The use of property injection should be non-standard; constructor injection should be used in the majority of cases. If a constructor gets too many parameters (the constructor over-injection anti-pattern), it is an indication of a violation of the `Single Responsibility Principle <https://en.wikipedia.org/wiki/Single_responsibility_principle>`_ (SRP). SRP violations often lead to maintainability issues. Instead of fixing constructor over-injection with property injection the root cause should be analyzed and the type should be refactored, probably with `Facade Services <http://blog.ploeh.dk/2010/02/02/RefactoringtoAggregateServices/>`_. Another common reason to use properties is because the dependencies are optional. But instead of using optional property dependencies, the best practice is to inject empty implementations (a.k.a. `Null Object pattern <https://en.wikipedia.org/wiki/Null_Object_pattern>`_) into the constructor; Dependencies should rarely be optional.

This doesn’t mean that you can’t do property injection with Simple Injector, but with Simple Injector this will have to be :ref:`explicitly configured <Overriding-Property-Injection-Behavior>`.

.. _No-interception:

No out-of-the-box support for interception
==========================================

Simple Injector does support interception out-of-the box, because we want to:

* :ref:`Push developers into best practices <Push-developers-into-best-practices>`
* :ref:`Fast by default <Fast-by-default>`
* :ref:`Don't force vendor lock-in <Vendor-lock-in>`

Simple Injector tries to push developers into good design, and the use of interception is often an indication of a suboptimal design. We prefer to promote the use of decorators. If you can't apply a decorator around a group of related types, you are probably missing a common (generic) abstraction.

Simple Injector is designed to be fast by default. Applying decorators in Simple Injector is just as fast as normal injection, while applying interceptors has a much higher cost, since it involves the use of reflection.

To be able to intercept, you will need to take a dependency on your interception library, since this library defines an *IInterceptor* interface or something similar (such as Castle’s *IInterceptor* or Unity's *ICallHandler*). Decorators on the other hand can be created without asking you to take a dependency on an external library. Since vendor lock-in should be avoided the Simple Injector library doesn't define any interfaces or attributes to be used at the application level.

.. _Limited-batch-registration:

Limited batch-registration API
==============================

Most DI libraries have a large and advanced batch-registration API that often allow specifying registrations in a fluent way. The downside of these APIs is that developers will struggle to use them correctly; they are often far from intuitive and the library’s documentation needs to be repeatedly consulted. 

Instead of creating our own API that would fall into the same trap as all the others, we decided not to have such elaborate API, because:

* :ref:`Features should be intuitive <Features-should-be-intuitive>`

In most cases we found it much easier to write batch registrations using LINQ; a language that many developers are already familiar with. Specifying your registrations in LINQ reduces the need to learn yet another (domain specific) language (with all its quirks).

When it comes to batch-registering generic-types things are different. Batch-registering generic types can be very complex without tool support. We have defined a clear API consisting of a single **RegisterManyForOpenGeneric** extension method that covers the majority of the cases. 

.. _No-per-thread-lifestyle:

No per-thread lifestyle
=======================

While designing Simple Injector, we explicitly decided not to include a Per Thread lifestyle out-of-the-box, because we want to:

* :ref:`Push developers into best practices <Push-developers-into-best-practices>`

The Per Thread lifestyle is very dangerous and in general you should not use it in your application, especially web applications.

This lifestyle should be considered dangerous, because it is very hard to predict what the actual lifespan of a thread is. When you create and start a thread using `new Thread().Start()`, you'll get a fresh block of thread-static memory, which means the container will create a new per-threaded instance for you. When starting threads from the thread pool using *ThreadPool.QueueUserWorkItem* however, you may get an existing thread from the pool. The same holds when running in ASP.NET (ASP.NET pools threads to increase performance).

All this means that a thread will almost certainly outlive a web request. ASP.NET can run requests asynchronously meaning that a web request can be finished on a different thread to the thread the request started executing on. These are some of the problems you can encounter when working with a Per Thread lifestyle.

A web request will typically begin with a call to **GetInstance** which will load the complete object graph including any services registered with the Per Thread lifestyle. At some point during the operation the call is postponed (due to the asynchronous nature of the ASP.NET framework). At some future moment in time ASP.NET will resume processing this call on a different thread and at this point we have a problem – some of the objects in our object graph are tied up on another thread, possibly doing something else for another operation. What a mess!

Since these instances are registered as Per Thread, they are probably not suited to be used in another thread. They are almost certainly not thread-safe (otherwise they would be registered as Singleton). Since the first thread that initially started the request is already free to pick up new requests, we can run into the situation where two threads access those Per Thread instances simultaneously. This will lead to race conditions and bugs that are hard to diagnose and find.

So in general, using Per Thread is a bad idea and that’s why Simple Injector does not support it. If you wish, you can always shoot yourself in the foot by implementing such a custom lifestyle, but don’t blame us :-)