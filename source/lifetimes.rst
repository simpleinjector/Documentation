==========================
Object Lifetime Management
==========================

Object Lifetime Management is the concept of controlling the number of instances a configured service will have and the duration of the lifetime of those instances. In other words, it allows you to determine how returned instances are cached. Most DI libraries have sophisticated mechanisms for lifestyle management, and Simple Injector is no exception with built-in support for the most common lifestyles. The three default lifestyles (transient, scoped and singleton) are part of the core library. Implementations for the scoped lifestyle can be found within some of the extension and integration packages. The built-in lifestyles will suit about 99% of cases. For anything else custom lifestyles can be used.

Below is a list of the most common lifestyles with code examples of how to configure them using Simple Injector:

+-----------------------------------------------+-----------------------------------------------------------------------+----------------------------+
| Lifestyle                                     | Description                                                           | Disposal                   |
+===============================================+=======================================================================+============================+
| :ref:`Transient <Transient>`                  | A new instance of the component will be created each time the         | Never                      |
|                                               | service is requested from the container. If multiple consumers depend |                            |
|                                               | on the service within the same graph, each consumer will get its own  |                            |
|                                               | new instance of the given service.                                    |                            |
+-----------------------------------------------+-----------------------------------------------------------------------+----------------------------+
| :ref:`Scoped <Scoped>`                        | For every request within an implicitly or explicitly defined scope.   | Instances will be disposed | 
|                                               |                                                                       | when their scope ends.     |
+-----------------------------------------------+-----------------------------------------------------------------------+----------------------------+
| :ref:`Singleton <Singleton>`                  | There will be at most one instance of the registered service type and | Instances will be disposed |
|                                               | the container will hold on to that instance until the container is    | when the container is      |
|                                               | disposed or goes out of scope. Clients will always receive that same  | disposed.                  |
|                                               | instance from the container.                                          |                            |
+-----------------------------------------------+-----------------------------------------------------------------------+----------------------------+

Many different platform and framework specific flavors are available for the *Scoped* lifestyle. Please see the :ref:`Scoped <Scoped>` section for more information.

Further reading:

* :ref:`Per Graph <PerGraph>`
* :ref:`Instance Per Dependency <InstancePerDependency>`
* :ref:`Per Thread <PerThread>`
* :ref:`Per HTTP Session <PerHttpSession>`
* :ref:`Hybrid <Hybrid>`
* :ref:`Developing a Custom Lifestyle <CustomLifestyles>`

.. _Transient:

Transient
=========

.. container:: Note
    
    A new instance of the service type will be created each time the service is requested from the container. If multiple consumers depend on the service within the same graph, each consumer will get its own new instance of the given service.

This example instantiates a new *IService* implementation for each call, while leveraging the power of :ref:`automatic constructor injection <Automatic-constructor-injection>`.

.. code-block:: c#

    container.Register<IService, RealService>(Lifestyle.Transient); 

    // Alternatively, you can use the following short cut
    container.Register<IService, RealService>();

The next example instantiates a new *RealService* instance on each call by using a delegate.

.. code-block:: c#

    container.Register<IService>(() => new RealService(new SqlRepository()),
        Lifestyle.Transient); 

.. container:: Note
    
    **Note**: It is normally recommended that registrations are made using **Register<TService, TImplementation>()**. It is easier, leads to less fragile configuration, and results in faster retrieval than registrations using a *Func<T>* delegate. Always try the former approach before resorting to using delegates.
    
.. container:: Note

    **Warning**: Transient instances are not tracked by the container. This means that Simple Injector will not dispose transient instances. Simple Injector will detect disposable instances that are registered as transient when calling *container.Verify()*. Please view  :doc:`Diagnostic Warning - Disposable Transient Components <disposabletransientcomponent>` for more information.

.. _Singleton:

Singleton
=========

.. container:: Note
    
    There will be at most one instance of the registered service type and the container will hold on to that instance until the container is disposed or goes out of scope. Clients will always receive that same instance from the container.

There are multiple ways to register singletons. The most simple and common way to do this is by specifying both the service type and the implementation as generic type arguments. This allows the implementation type to be constructed using automatic constructor injection:

.. code-block:: c#

    container.Register<IService, RealService>(Lifestyle.Singleton);

You can also use the *RegisterSingleton<T>(T)* overload to assign a constructed instance manually:
 
.. code-block:: c#

    var service = new RealService(new SqlRepository());
    container.RegisterSingleton<IService>(service);

There is also an overload that takes an *Func<T>* delegate. The container guarantees that this delegate is called only once:

.. code-block:: c#

    container.Register<IService>(() => new RealService(new SqlRepository()),
        Lifestyle.Singleton);

    // Or alternatively:
    container.RegisterSingleton<IService>(() => new RealService(new SqlRepository()));

Alternatively, when needing to register a concrete type as singleton, you can use the parameterless **RegisterSingleton<T>()** overload. This will inform the container to automatically construct that concrete type (at most) once, and return that instance on each request:

.. code-block:: c#

    container.RegisterSingleton<RealService>();

    // Which is a more convenient short cut for:
    container.Register<RealService, RealService>(Lifestyle.Singleton);

Registration for concrete singletons is necessarily, because unregistered concrete types will be treated as transient.

.. container:: Note
    
    **Warning**: Simple Injector guarantees that there is at most one instance of the registered **Singleton** inside that **Container** instance, but if multiple **Container** instances are created, each **Container** instance will get its own instance of the registered **Singleton**.

.. container:: Note

    **Note**: Simple Injector will cache a **Singleton** instance for the lifetime of the **Container** instance and will dispose any auto-wired instance (that implements *IDisposable*) when **Container.Dispose()** is called. This includes registrations using **RegisterSingleton<TService, TImplementation>()**, **RegisterSingleton<TConcrete>()** and **RegisterSingleton(Type, Type)**. Non-auto-wired instances that are created using factory delegates will be disposed as well. This includes **RegisterSingleton<TService>(Func<TService>)** and **RegisterSingleton(Type, Func<object>)**.

.. container:: Note
    
    **Warning**: Already existing instances that are supplied to the container using **RegisterSingleton<TService>(TService)** and **RegisterSingleton(Type, object)** will not be disposed by the container. They are considered to be 'externally owned'.
    
.. container:: Note

    **Note**: Simple Injector guarantees that instances are disposed in opposite order of creation. See: :ref:`Order of disposal <Order-of-disposal>` for more information.
    
.. _Scoped:

Scoped
======

.. container:: Note
    
    For every request within an implicitly or explicitly defined scope, a single instance of the service will be returned and that instance will be disposed when the scope ends.

Simple Injector contains five scoped lifestyles:

+-----------------------------------------------+-----------------------------------------------------------------------+----------------------------+
| Lifestyle                                     | Description                                                           | Disposal                   |
+===============================================+=======================================================================+============================+
| :ref:`Thread Scoped <ThreadScoped>`           | Within a certain (explicitly defined) scope, there will be only one   | Instance will be disposed  |
|                                               | instance of a given service type A created scope is specific to one   | when their scope gets      |
|                                               | particular thread, and can't be moved across threads.                 | disposed.                  |
+-----------------------------------------------+-----------------------------------------------------------------------+----------------------------+
| :ref:`Async Scoped <AsyncScoped>`             | There will be only one instance of a given service type within a      | Instance will be disposed  |
|                                               | certain (explicitly defined) scope. This scope will automatically     | when their scope gets      |
|                                               | flow with the logical flow of control of asynchronous methods.        | disposed.                  |
+-----------------------------------------------+-----------------------------------------------------------------------+----------------------------+
| :ref:`Web Request <WebRequest>`               | Only one instance will be created by the container per web request.   | Instances will be disposed | 
|                                               | Use this lifestyle in ASP.NET Web Forms and ASP.NET MVC applications. | when the web request ends. |
+-----------------------------------------------+-----------------------------------------------------------------------+----------------------------+
| :ref:`WCF Operation <WcfOperation>`           | Only one instance will be created by the container during the lifetime| Instances will be disposed |
|                                               | of the WCF service class.                                             | when the WCF service class |
|                                               |                                                                       | is released.               |
+-----------------------------------------------+-----------------------------------------------------------------------+----------------------------+

*Web Request* and *WCF Operation* implement scoping implicitly, which means that the user does not have to start or finish the scope to allow the lifestyle to end and to dispose cached instances. The *Container* does this for you. With the *Thread Scoped* and *Async Scoped* lifestyles on the other hand, you explicitly define a scope (just like you would do with .NET's TransactionScope class).

Most of the time, you will only use one particular scoped lifestyle per application. To simplify this, Simple Injector allows configuring the default scoped lifestyle in the container. After configuring the default scoped lifestyle, the rest of the configuration can access this lifestyle by calling **Lifestyle.Scoped**, as can be seen in the following example:
    
.. code-block:: c#
        
    var container = new Container();
    // Set the scoped lifestyle one directly after creating the container
    container.Options.DefaultScopedLifestyle = new AsyncScopedLifestyle();
    
    // Use the Lifestyle.Scoped everywhere in your configuration.
    container.Register<IUserContext, AspNetUserContext>(Lifestyle.Scoped);
    container.Register<MyAppUnitOfWork>(() => new MyAppUnitOfWork("constr"),
        Lifestyle.Scoped);
    
Just like *Singleton* registrations, instances of scoped registrations that are created by the container will be disposed when the their scope ends. Scoped lifestyles are especially useful for implementing patterns such as the `Unit of Work <http://martinfowler.com/eaaCatalog/unitOfWork.html>`_.


.. _Order-of-disposal:

Order of disposal
-----------------

.. container:: Note

    Simple Injector guarantees that instances are disposed in opposite order of creation.

When a component *A* depends on component *B*, *B* will be created before *A*. This means that *A* will be disposed before *B* (assuming both implement *IDisposable*), since the guarantee of opposite order of creation. This allows *A* to use *B* while *A* is being disposed.


.. _PerLifetimeScope:
.. _ThreadScoped:

Thread Scoped
=============

.. container:: Note
    
    Within a certain (explicitly defined) scope, there will be only one instance of a given service type in that thread and the instance will be disposed when the scope ends. A created scope is specific to one particular thread, and can't be moved across threads.
    
.. container:: Note

    **Warning**: A thread scoped lifestyle can't be used for asynchronous operations (using the async/await keywords in C#).

**SimpleInjector.Lifestyles.ThreadScopedLifestyle** is part of the Simple Injector core library. The following examples shows its typical usage:

.. code-block:: c#

    var container = new Container();
    container.Options.DefaultScopedLifestyle = new ThreadScopedLifestyle();

    container.Register<IUnitOfWork, NorthwindContext>(Lifestyle.Scoped);

Within an explicitly defined scope, there will be only one instance of a service that is defined with the *Thread Scoped* lifestyle:

.. code-block:: c#

    using (ThreadScopedLifestyle.BeginScope(container)) {
        var uow1 = container.GetInstance<IUnitOfWork>();
        var uow2 = container.GetInstance<IUnitOfWork>();

        Assert.AreSame(uow1, uow2);
    }

.. container:: Note

    **Warning**: The `ThreadScopedLifestyle` is *thread-specific*. A single scope should **not** be used over multiple threads. Do not pass a scope between threads and do not wrap an ASP.NET HTTP request with a `ThreadScopedLifestyle`, since ASP.NET can finish a web request on different thread to the thread the request is started on. Use :ref:`Web Request Lifestyle <WebRequest>` scoping for ASP.NET Web Forms and MVC web applications while running inside a web request. Use :ref:`Async Scoped Lifestyle <AsyncScoped>` when using ASP.NET Web API or ASP.NET Core. `ThreadScopedLifestyle` however, can still be used in web applications on background threads that are created by web requests or when processing commands in a Windows Service (where each command gets its own scope). For developing multi-threaded applications, take :ref:`these guidelines <Multi-Threaded-Applications>` into consideration.

Outside the context of a thread scoped lifestyle, i.e. `using (ThreadScopedLifestyle.BeginScope(container))` no instances can be created. An exception is thrown when a thread scoped registration is requested outside of a scope instance.

Scopes can be nested and each scope will get its own set of instances:

.. code-block:: c#

    using (ThreadScopedLifestyle.BeginScope(container)) {
        var outer1 = container.GetInstance<IUnitOfWork>();
        var outer2 = container.GetInstance<IUnitOfWork>();

        Assert.AreSame(outer1, outer2);

        using (ThreadScopedLifestyle.BeginScope(container)) {
            var inner1 = container.GetInstance<IUnitOfWork>();
            var inner2 = container.GetInstance<IUnitOfWork>();

            Assert.AreSame(inner1, inner2);

            Assert.AreNotSame(outer1, inner1);
        }
    }

.. _PerExecutionContextScope:
.. _PerWebAPIRequest:
.. _AsyncScoped:

Async Scoped (async/await)
==========================

.. container:: Note
    
    There will be only one instance of a given service type within a certain (explicitly defined) scope and that instance will be disposed when the scope ends. This scope will automatically flow with the logical flow of control of asynchronous methods.

This lifestyle is meant for applications that work with the new asynchronous programming model.

**SimpleInjector.Lifestyles.AsyncScopedLifestyle** is part of the Simple Injector core library. The following examples shows its typical usage:

.. code-block:: c#

    var container = new Container();
    container.Options.DefaultScopedLifestyle = new AsyncScopedLifestyle();
    
    container.Register<IUnitOfWork, NorthwindContext>(Lifestyle.Scoped);

Within an explicitly defined scope, there will be only one instance of a service that is defined with the *Async Scoped* lifestyle:

.. code-block:: c#

    using (AsyncScopedLifestyle.BeginScope(container)) {
        var uow1 = container.GetInstance<IUnitOfWork>();
        await SomeAsyncOperation();
        var uow2 = container.GetInstance<IUnitOfWork>();
        await SomeOtherAsyncOperation();

        Assert.AreSame(uow1, uow2);
    }

.. container:: Note

    **Note**: A scope is specific to the asynchronous flow. A method call on a different (unrelated) thread, will get its own scope.

Outside the context of an active async scope no instances can be created. An exception is thrown when this happens.

Scopes can be nested and each scope will get its own set of instances:

.. code-block:: c#

    using (AsyncScopedLifestyle.BeginScope(container)) {
        var outer1 = container.GetInstance<IUnitOfWork>();
        await SomeAsyncOperation();
        var outer2 = container.GetInstance<IUnitOfWork>();

        Assert.AreSame(outer1, outer2);

        using (AsyncScopedLifestyle.BeginScope(container)) {
            var inner1 = container.GetInstance<IUnitOfWork>();
            
            await SomeOtherAsyncOperation();
            
            var inner2 = container.GetInstance<IUnitOfWork>();

            Assert.AreSame(inner1, inner2);

            Assert.AreNotSame(outer1, inner1);
        }
    }

.. _PerWebRequest:
.. _WebRequest:

Web Request
===========

.. container:: Note
    
    Only one instance will be created by the container per web request and the instance will be disposed when the web request ends.

The `ASP.NET Integration NuGet Package <https://nuget.org/packages/SimpleInjector.Integration.Web>`_ is available (and available as **SimpleInjector.Integration.Web.dll** in the default download) contains a **WebRequestLifestyle** class that enable easy *Per Web Request* registrations:

.. code-block:: c#

    var container = new Container();
    container.Options.DefaultScopedLifestyle = new WebRequestLifestyle();

    container.Register<IUserRepository, SqlUserRepository>(Lifestyle.Scoped);
    container.Register<IOrderRepository, SqlOrderRepository>(Lifestyle.Scoped);

.. container:: Note

    **Tip**: For ASP.NET MVC, there's a `Simple Injector MVC Integration Quick Start <https://nuget.org/packages/SimpleInjector.MVC3>`_ NuGet Package available that helps you get started with Simple Injector in MVC applications quickly.

.. _WebAPIRequest-vs-WebRequest:
.. _AsyncScoped-vs-WebRequest:

Web Async Scoped lifestyle vs. Web Request lifestyle
====================================================

The lifestyles and scope implementations **Web Request** and **Async Scoped** in Simple Injector are based on different technologies. **AsyncScopedLifestyle** works well both inside and outside of IIS. i.e. It can function in a self-hosted Web API project where there is no *HttpContext.Current*. As the name implies, an async scope registers itself flows with *async* operations across threads (e.g. a continuation after *await* on a different thread still has access to the scope regardless of whether *ConfigureAwait()* was used with *true* or *false*).

In contrast, the **Scope** of the **WebRequestLifestyle** is stored within the *HttpContext.Items* dictionary. The *HttpContext* can be used with Web API when it is hosted in IIS but care must be taken because it will not always flow with the async operation, because the current *HttpContext* is stored in the *IllogicalCallContext* (see `Understanding SynchronizationContext in ASP.NET <https://blogs.msdn.com/b/pfxteam/archive/2012/06/15/executioncontext-vs-synchronizationcontext.aspx>`_). If you use *await* with *ConfigureAwait(false)* the continuation may lose track of the original *HttpContext* whenever the async operation does not execute synchronously. A direct effect of this is that it would no longer be possible to resolve the instance of a previously created service with **WebRequestLifestyle** from the container (e.g. in a factory that has access to the container) - and an exception would be thrown because *HttpContext.Current* would be null.

The recommendation is to use **AsyncScopedLifestyle** in for applications that solely consist of a Web API (or other asynchronous technologies such as ASP.NET Core) and use **WebRequestLifestyle** for applications that contain a mixture of Web API and MVC.

**AsyncScopedLifestyle** offers the following benefits when used in Web API:

* The Web API controller can be used outside of IIS (e.g. in a self-hosted project)
* The Web API controller can execute *free-threaded* (or *multi-threaded*) *async* methods because it is not limited to the ASP.NET *SynchronizationContext*.

For more information, check out the blog entry of Stephen Toub regarding the `difference between ExecutionContext and 
SynchronizationContext <https://vegetarianprogrammer.blogspot.de/2012/12/understanding-synchronizationcontext-in.html>`_.

.. _PerWcfOperation:
.. _WcfOperation:

WCF Operation
=============

.. container:: Note
    
    Only one instance will be created by the container during the lifetime of the WCF service class and the instance will be disposed when the WCF service class is released.

The `WCF Integration NuGet Package <https://nuget.org/packages/SimpleInjector.Integration.Wcf>`_ is available (and available as **SimpleInjector.Integration.Wcf.dll** in the default download) contains a **WcfOperationLifestyle** class that enable easy *Per WCF Operation* registrations:

.. code-block:: c#

    var container = new Container();
    container.Options.DefaultScopedLifestyle = new WcfOperationLifestyle();

    container.Register<IUserRepository, SqlUserRepository>(Lifestyle.Scoped);
    container.Register<IOrderRepository, SqlOrderRepository>(Lifestyle.Scoped);

.. container:: Note

    **Warning**: Instead of what the name of the **WcfOperationLifestyle** class seems to imply, components that are registered with this lifestyle might actually outlive a single WCF operation. This behavior depends on how the WCF service class is configured. WCF is in control of the lifetime of the service class and contains three lifetime types as defined by the `InstanceContextMode enumeration <https://msdn.microsoft.com/en-us/library/system.servicemodel.instancecontextmode.aspx>`_. Components that are registered *PerWcfOperation* live as long as the WCF service class they are injected into.

For more information about integrating Simple Injector with WCF, please see the :doc:`WCF integration guide <wcfintegration>`.

.. _PerGraph:

Per Graph
=========

.. container:: Note
    
    For each explicit call to **Container.GetInstance<T>** a new instance of the service type will be created, but the instance will be reused within the object graph that gets constructed.

Compared to **Transient**, there will be just a single instance per explicit call to the container, while **Transient** services can have multiple new instances per explicit call to the container. This lifestyle is not supported by Simple Injector but can be simulated by using one of the :ref:`Scoped <Scoped>` lifestyles.

.. _InstancePerDependency:

Instance Per Dependency
=======================

.. container:: Note
    
    Each consumer will get a new instance of the given service type and that dependency is expected to get live as long as its consuming type.

This lifestyle behaves the same as the built-in **Transient** lifestyle, but the intend is completely different. A **Transient** instance is expected to have a very short lifestyle and injecting it into a consumer with a longer lifestyle (such as **Singleton**) is an error. Simple Injector will prevent this from happening by checking for :doc:`lifestyle mismatches <LifestyleMismatches>`. With the *Instance Per Dependency* lifestyle on the other hand, the created component is expected to stay alive as long as the consuming component does. So when the *Instance Per Dependency* component is injected into a **Singleton** component, we intend it to be kept alive by its consumer.

This lifestyle is deliberately left out of Simple Injector, because its usefulness is very limited compared to the **Transient** lifestyle. It ignores :doc:`lifestyle mismatch checks <LifestyleMismatches>` and this can easily lead to errors, and it ignores the fact that application components should be immutable. In case a component is immutable, it's very unlikely that each consumer requires its own instance of the injected dependency.

.. _PerThread:

Per Thread
==========

.. container:: Note
    
    There will be one instance of the registered service type per thread.

This lifestyle is deliberately left out of Simple Injector because :ref:`it is considered to be harmful <No-per-thread-lifestyle>`. Instead of using Per-Thread lifestyle, you will usually be better of using the :ref:`Thread Scoped Lifestyle <ThreadScoped>`.

.. _PerHttpSession:

Per HTTP Session
================

.. container:: Note
    
    There will be one instance of the registered session per (user) session in a ASP.NET web application.

This lifestyle is deliberately left out of Simple Injector because `it is be used with care <https://stackoverflow.com/questions/17702546>`_. Instead of using Per HTTP Session lifestyle, you will usually be better of by writing a stateless service that can be registered as singleton and let it communicate with the ASP.NET Session cache to handle cached user-specific data.

.. _Hybrid:

Hybrid
======

.. container:: Note
    
    A hybrid lifestyle is a mix between two or more lifestyles where the the developer defines the context for which the wrapped lifestyles hold.

Simple Injector has no built-in hybrid lifestyles, but has a simple mechanism for defining them:

.. code-block:: c#

    var container = new Container();
    
    container.Options.DefaultScopedLifestyle = Lifestyle.CreateHybrid(
        defaultLifestyle: new ThreadScopedLifestyle(),
        fallbackLifestyle: new WebRequestLifestyle());

    container.Register<IUserRepository, SqlUserRepository>(Lifestyle.Scoped);
    container.Register<ICustomerRepository, SqlCustomerRepository>(Lifestyle.Scoped);

In the example a hybrid lifestyle is defined wrapping the :ref:`Thread Scoped Lifestyle <ThreadScoped>` and the :ref:`Web Request Lifestyle <WebRequest>`. This hybrid lifestyle will use the `ThreadScopedLifestyle`, but will fall back to the `WebRequestLifestyle` in case there is no active thread scope.

A hybrid lifestyle is useful for registrations that need to be able to dynamically switch lifestyles throughout the lifetime of the application. The shown hybrid example might be useful in a web application, where some operations need to be run in isolation (with their own instances of scoped registrations such as unit of works) or run outside the context of an *HttpContext* (in a background thread for instance).

Please note though that when the lifestyle doesn't have to change throughout the lifetime of the application, a hybrid lifestyle is not needed. A normal lifestyle can be registered instead:

.. code-block:: c#

    bool runsOnWebServer = ReadConfigurationValue<bool>("RunsOnWebServer");

    var container = new Container();
    container.Options.DefaultScopedLifestyle = 
        runsOnWebServer ? new WebRequestLifestyle() : new ThreadScopedLifestyle();

    container.Register<IUserRepository, SqlUserRepository>(Lifestyle.Scoped);
    container.Register<ICustomerRepository, SqlCustomerRepository>(Lifestyle.Scoped);

.. _CustomLifestyles:

Developing a Custom Lifestyle
=============================

The lifestyles supplied by Simple Injector should be sufficient for most scenarios, but in rare circumstances defining a custom lifestyle might be useful. This can be done by creating a class that inherits from `Lifestyle <https://simpleinjector.org/ReferenceLibrary/?topic=html/T_SimpleInjector_Lifestyle.htm>`_ and let it return `Custom Registration <https://simpleinjector.org/ReferenceLibrary/?topic=html/T_SimpleInjector_Registration.htm>`_ instances. This however is a lot of work, and a shortcut is available in the form of the `Lifestyle.CreateCustom <https://simpleinjector.org/ReferenceLibrary/?topic=html/M_SimpleInjector_Lifestyle_CreateCustom.htm>`_.

A custom lifestyle can be created by calling the **Lifestyle.CreateCustom** factory method. This method takes two arguments: the name of the lifestyle to create (used mainly by the :doc:`Diagnostic Services <diagnostics>`) and a `CreateLifestyleApplier <https://simpleinjector.org/ReferenceLibrary/?topic=html/T_SimpleInjector_CreateLifestyleApplier.htm>`_ delegate:

.. code-block:: c#

    public delegate Func<object> CreateLifestyleApplier(
        Func<object> transientInstanceCreator)    

The **CreateLifestyleApplier** delegate accepts a *Func<object>* that allows the creation of a transient instance of the registered type. This *Func<object>* is created by Simple Injector supplied to the registered  **CreateLifestyleApplier** delegate for the registered type. When this *Func<object>* delegate is called, the creation of the type goes through the :doc:`Simple Injector pipeline <pipeline>`. This keeps the experience consistent with the rest of the library.

When Simple Injector calls the **CreateLifestyleApplier**, it is your job to return another *Func<object>* delegate that applies the caching based on the supplied *instanceCreator*. A simple example would be the following:

.. code-block:: c#

    var sillyTransientLifestyle = Lifestyle.CreateCustom(
        name: "Silly Transient",
        // instanceCreator is of type Func<object>
        lifestyleApplierFactory: instanceCreator => {
            // A Func<object> is returned that applies caching.
            return () => instanceCreator.Invoke();
        });

    var container = new Container();

    container.Register<IService, MyService>(sillyTransientLifestyle);

Here we create a custom lifestyle that applies no caching and simply returns a delegate that will on invocation always call the wrapped *instanceCreator*. Of course this would be rather useless and using the built-in **Lifestyle.Transient** would be much better in this case. It does however demonstrate its use.

The *Func<object>* delegate that you return from your **CreateLifestyleApplier** delegate will get cached by Simple Injector per registration. Simple Injector will call the delegate once per registration and stores the returned *Func<object>* for reuse. This means that each registration will get its own *Func<object>*.

Here's an example of the creation of a more useful custom lifestyle that caches an instance for 10 minutes:

.. code-block:: c#

    var tenMinuteLifestyle = Lifestyle.CreateCustom(
        name: "Absolute 10 Minute Expiration", 
        lifestyleApplierFactory: instanceCreator => {
            TimeSpan timeout = TimeSpan.FromMinutes(10);
            var syncRoot = new object();
            var expirationTime = DateTime.MinValue;
            object instance = null;

            return () => {
                lock (syncRoot) {
                    if (expirationTime < DateTime.UtcNow) {
                        instance = instanceCreator.Invoke();
                        expirationTime = DateTime.UtcNow.Add(timeout);
                    }
                    return instance;
                }
            };
        });

    var container = new Container();

    // We can reuse the created lifestyle for multiple registrations.
    container.Register<IService, MyService>(tenMinuteLifestyle);
    container.Register<AnotherService, MeTwoService>(tenMinuteLifestyle);

In this example the **Lifestyle.CreateCustom** method is called and supplied with a delegate that returns a delegate that applies the 10 minute cache. This example makes use of the fact that each registration gets its own delegate by using four closures (timeout, syncRoot, expirationTime and instance). Since each registration (in the example *IService* and *AnotherService*) will get its own *Func<object>* delegate, each registration gets its own set of closures. The closures are therefore static per registration.

One of the closure variables is the *instance* and this will contain the cached instance that will change after 10 minutes has passed. As long as the time hasn't passed, the same instance will be returned.

Since the constructed *Func<object>* delegate can be called from multiple threads, the code needs to do its own synchronization. Both the DateTime comparison and the DateTime assignment are not thread-safe and this code needs to handle this itself.

Do note that even though locking is used to synchronize access, this custom lifestyle might not work as expected, because when the expiration time passes while an object graph is being resolved, it might result in an object graph that contains two instances of the registered component, which might not be what you want. This example therefore is only for demonstration purposes.

.. container:: Note
    
    In case you wish to develop a custom lifestyle, we strongly advice posting a question on the Forum. We will be able to guide you through this process.
