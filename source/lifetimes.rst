==========================
Object Lifetime Management
==========================

Object Lifetime Management is the concept of controlling the number of instances a configured service will have and the duration of the lifetime of those instances. In other words, it allows you to determine how returned instances are cached. Most DI libraries have sophisticated mechanisms for lifestyle management, and Simple Injector is no exception with built-in support for the most common lifestyles. The three default lifestyles (transient, scoped and singleton) are part of the core library. Implementations for the scoped lifestyle can be found within some of the extension and integration packages. The built-in lifestyles will suit about 99% of cases. For anything else custom lifestyles can be used.

Below is a list of the most common lifestyles with code examples of how to configure them using Simple Injector:

+------------------------------+-----------------------------------------------------------------------+----------------------------+
| Lifestyle                    | Description                                                           | Disposal                   |
+==============================+=======================================================================+============================+
| :ref:`Transient <Transient>` | A new instance of the component will be created each time the         | Never                      |
|                              | service is requested from the container. If multiple consumers depend |                            |
|                              | on the service within the same graph, each consumer will get its own  |                            |
|                              | new instance of the given service.                                    |                            |
+------------------------------+-----------------------------------------------------------------------+----------------------------+
| :ref:`Scoped <Scoped>`       | For every request within an implicitly or explicitly defined scope.   | Instances will be disposed | 
|                              |                                                                       | when their scope ends.     |
+------------------------------+-----------------------------------------------------------------------+----------------------------+
| :ref:`Singleton <Singleton>` | There will be at most one instance of the registered service type and | Instances will be disposed |
|                              | the container will hold on to that instance until the container is    | when the container is      |
|                              | disposed or goes out of scope. Clients will always receive that same  | disposed.                  |
|                              | instance from the container.                                          |                            |
+------------------------------+-----------------------------------------------------------------------+----------------------------+

Many different platform and framework-specific flavors are available for the *Scoped* lifestyle. Please see the :ref:`Scoped <Scoped>` section for more information.

Further reading:

* :ref:`Per Graph <PerGraph>`
* :ref:`Instance Per Dependency <InstancePerDependency>`
* :ref:`Per Thread <PerThread>`
* :ref:`Per HTTP Session <PerHttpSession>`
* :ref:`Hybrid <Hybrid>`
* :ref:`Developing a Custom Lifestyle <CustomLifestyles>`
* :ref:`Generics and lifetime management <Generics-and-lifetime-management>`
* :ref:`Collections and lifetime management <Collections-and-lifetime-management>`
* :ref:`Flowing scopes <flowing-scopes>`

.. _Transient:

Transient Lifestyle
===================

.. container:: Note
    
    A new instance of the service type will be created each time the service is requested from the container. If multiple consumers depend on the service within the same graph, each consumer will get its own new instance of the given service.

This example instantiates a new *IService* implementation for each call, while leveraging the power of :ref:`Auto-Wiring <Automatic-constructor-injection>`.

.. code-block:: c#

    container.Register<IService, RealService>(Lifestyle.Transient); 

    // Alternatively, you can use the following short cut
    container.Register<IService, RealService>();

The next example instantiates a new *RealService* instance on each call by using a delegate.

.. code-block:: c#

    container.Register<IService>(
        () => new RealService(new SqlRepository()),
        Lifestyle.Transient); 

.. container:: Note
    
    **Note**: It is recommended that registrations for your application components are made using the former Auto-Wiring overload, while registrations of components that are out of your control (e.g. framework or third-party components) are made using the latter delegate overload. This typically results in the most maintainable `Composition Root <https://mng.bz/K1qZ>`_.
    
Simple Injector considers Transient registrations to be *lasting for only a short time; temporary*, i.e. short lived and not reused. For that reason, Simple Injector prevents the injection of Transient components into Singleton consumers as they are expected to be longer lived, which would otherwise result in :doc:`Lifestyle Mismatches <LifestyleMismatches>`.
    
.. container:: Note

    **Warning**: Transient instances are not tracked by the container as tracking transient instances is a common source of memory leaks. This means that Simple Injector can't dispose transient instances as that would require tracking. Simple Injector detects disposable instances that are registered as transient when calling *container.Verify()*. Please view  :doc:`Diagnostic Warning - Disposable Transient Components <disposabletransientcomponent>` for more information.

.. _Singleton:

Singleton Lifestyle
===================

.. container:: Note
    
    There will be at most one instance of the registered service type and the container will hold on to that instance until the container is disposed or goes out of scope. Clients will always receive that same instance from the container.

There are multiple ways to register singletons. The most simple and common way to do this is by specifying both the service type and the implementation as generic type arguments. This allows the implementation type to be constructed using automatic constructor injection:

.. code-block:: c#

    container.Register<IService, RealService>(Lifestyle.Singleton);

You can also use the **RegisterInstance<T>(T)** method to assign a constructed instance manually:
 
.. code-block:: c#

    var service = new RealService(new SqlRepository());
    container.RegisterInstance<IService>(service);

There is also a **RegisterSingleton<T>** overload that takes an *Func<T>* delegate. The container guarantees that this delegate is called only once:

.. code-block:: c#

    container.Register<IService>(
        () => new RealService(new SqlRepository()),
        Lifestyle.Singleton);

    // Or alternatively:
    container.RegisterSingleton<IService>(() => new RealService(new SqlRepository()));

Alternatively, when needing to register a concrete type as singleton, you can use the parameterless **RegisterSingleton<T>()** overload. This will inform the container to automatically construct that concrete type (at most) once, and return that instance on each request:

.. code-block:: c#

    container.RegisterSingleton<RealService>();

    // Which is a more convenient short cut for:
    container.Register<RealService, RealService>(Lifestyle.Singleton);

.. container:: Note
    
    **Warning**: Simple Injector guarantees that there is at most one instance of the registered **Singleton** inside that **Container** instance, but if multiple **Container** instances are created, each **Container** instance will get its own instance of the registered **Singleton**.

.. container:: Note

    **Note**: Simple Injector will cache a **Singleton** instance for the lifetime of the **Container** instance and will dispose any auto-wired instance (that implements *IDisposable*) when **Container.Dispose()** is called. This includes registrations using **RegisterSingleton<TService, TImplementation>()**, **RegisterSingleton<TConcrete>()** and **RegisterSingleton(Type, Type)**. Non-auto-wired instances that are created using factory delegates will be disposed as well. This includes **RegisterSingleton<TService>(Func<TService>)** and **RegisterSingleton(Type, Func<object>)**.

.. container:: Note
    
    **Warning**: Already existing instances that are supplied to the container using **RegisterInstance<TService>(TService)** and **RegisterInstance(Type, object)** will not be disposed by the container. They are considered to be 'externally owned'.
    
.. container:: Note

    **Note**: Simple Injector guarantees that instances are disposed in opposite order of creation. See: :ref:`Order of disposal <Order-of-disposal>` for more information.
    
.. _Scoped:

Scoped Lifestyle
================

.. container:: Note
    
    For every request within an implicitly or explicitly defined scope, a single instance of the service will be returned and that instance will be disposed when the scope ends.

The Scoped lifestyle behaves much like the Singleton lifestyle within a single, well-defined scope or request. A Scoped instance, however, isn't shared across scopes. Each scope has its own cache of associated dependencies.

The Scoped lifestyle is useful for applications where you run a single operation in an isolated manner. Web applications are a great example, as you want to run a request in isolation from other requests. The same can hold for desktop applications. A press of a button can be seen as a form of a request, and you might wish to isolate such request. This can be done with the use of the Scoped lifestyle.

In frameworks where Simple Injector supplies out-of-the-box integration for (see the :doc:`integration guide <integration>`), the integration package will typically wrap a scope around a request on your behalf. This is what we call an *implicitly defined scope*, as you are not responsible for defining the scope–the integration package is.

In other situations, where there is no integration package available or, alternatively, you wish to start an operation outside the facilities that the integration package provides, you should start your own scope. This can happen when you wish to run an operation on a background thread of a web application, or when you want start a new operation when running inside a Windows service. When you manage the scope yourself, we call this an *explicitly defined scope*, as you are directly responsible for the creation and disposing of that scope.
     
Simple Injector contains the following scoped lifestyles:

+-------------------------------------+-----------------------------------------------------------------------+----------------------------+
| Lifestyle                           | Description                                                           | Disposal                   |
+=====================================+=======================================================================+============================+
| :ref:`Thread Scoped <ThreadScoped>` | Within a certain (explicitly defined) scope, there will be only one   | Instance will be disposed  |
|                                     | instance of a given service type A created scope is specific to one   | when their scope gets      |
|                                     | particular thread, and can't be moved across threads.                 | disposed.                  |
+-------------------------------------+-----------------------------------------------------------------------+----------------------------+
| :ref:`Async Scoped <AsyncScoped>`   | There will be only one instance of a given service type within a      | Instance will be disposed  |
|                                     | certain (explicitly defined) scope. This scope will automatically     | when their scope gets      |
|                                     | flow with the logical flow of control of asynchronous methods.        | disposed.                  |
+-------------------------------------+-----------------------------------------------------------------------+----------------------------+
| :ref:`Web Request <WebRequest>`     | Only one instance will be created by the container per web request.   | Instances will be disposed | 
|                                     | Use this lifestyle in ASP.NET Web Forms and ASP.NET MVC applications. | when the web request ends. |
+-------------------------------------+-----------------------------------------------------------------------+----------------------------+
| :ref:`WCF Operation <WcfOperation>` | Only one instance will be created by the container during the lifetime| Instances will be disposed |
|                                     | of the WCF service class.                                             | when the WCF service class |
|                                     |                                                                       | is released.               |
+-------------------------------------+-----------------------------------------------------------------------+----------------------------+

*Web Request* and *WCF Operation* implement scoping implicitly, which means that the user does not have to start or finish the scope to allow the lifestyle to end and to dispose cached instances. The *Container* does this for you. With the *Thread Scoped* and *Async Scoped* lifestyles on the other hand, you explicitly define a scope (just like you would do with .NET's `TransactionScope` class).

Most of the time, you will only use one particular scoped lifestyle per application. To simplify this, Simple Injector allows configuring the default scoped lifestyle in the container. After configuring the default scoped lifestyle, the rest of the configuration can access this lifestyle by calling **Lifestyle.Scoped**, as can be seen in the following example:
    
.. code-block:: c#
        
    var container = new Container();
    // Set the scoped lifestyle one directly after creating the container
    container.Options.DefaultScopedLifestyle = new AsyncScopedLifestyle();
    
    // Use the Lifestyle.Scoped everywhere in your configuration.
    container.Register<IUserContext, AspNetUserContext>(Lifestyle.Scoped);
    container.Register<MyAppUnitOfWork>(() => new MyAppUnitOfWork("constr"),
        Lifestyle.Scoped);
    
Just like *Singleton* registrations, instances of scoped registrations that are created by the container will be disposed when the their scope ends. Scoped lifestyles are especially useful for implementing patterns such as the `Unit of Work <https://martinfowler.com/eaaCatalog/unitOfWork.html>`_.


.. _Disposing-a-scope:

Disposing a Scope
-----------------

The managing of Scoped instances is done using the **Scope** class. A **Scope** keeps references to any created Scoped components to ensure the same instance is returned within the context of the same **Scope** and it allows the **Scope** to deterministically dispose off all disposable Scoped instances.

The following example shows how to manually create and dispose a **Scope** instance. The example uses the **AsyncScopedLifestyle** which is the most common Scoped lifestyle to use:

.. code-block:: c#

    using (Scope scope = AsyncScopedLifestyle.BeginScope(container))
    {
        var service = container.GetInstance<IOrderShipmentProcessor>();
        
        service.ProcessShipment();
    }

At the end of the using block, the **Scope** instances is automatically disposed off, and with it, all its cached disposable components.

.. _Async-disposal:

Asynchronous disposal
---------------------

With the introduction of Simple Injector v5.2 all its builds have support for asynchronous disposal of both **Scope** and **Container** instances. This means that components that implement `IAsyncDisposable <https://docs.microsoft.com/en-us/dotnet/api/system.iasyncdisposable>`_ can be disposed asynchronously by Simple Injector. This, however, does require you to call one of Simple Injector's methods for asynchronous disposal.

.. container:: Note

    **Tip**: Simple Injector v5.2 even supports asynchronous disposal on the older .NET 4.5, .NET Standard 1.0, and Standard 1.3 platforms. This is done using duck typing which will be explained below.

Depending on what C# and framework version you are using, there are multiple methods for asynchronous disposal. When using C# 8 in combination with .NET Core 3 or .NET 5, you can use C#'s new `await using` syntax, as seen in the following code:

.. code-block:: c#

    await using (AsyncScopedLifestyle.BeginScope(container))
    {
        var service = container.GetInstance<IOrderShipmentProcessor>();
        
        await service.ProcessShipmentAsync();
    }

.. container:: Note

    The `async using` keyword is only available for Simple Injector's `netstandard2.1` build, hence the requirement of running .NET Core 3 or .NET 5.

For older platforms and C# versions, disposal of a **Scope** can be done by calling **DisposeScopeAsync** inside a `finally` block.

.. code-block:: c#

    var scope = AsyncScopedLifestyle.BeginScope(container);
    
    try
    {
        var service = container.GetInstance<IOrderShipmentProcessor>();
        
        await service.ProcessShipmentAsync();
    }
    finally
    {
        await scope.DisposeScopeAsync();
    }
    
.. container:: Note

    Calling **DisposeAsync**, **DisposeScopeAsync** or **DisposeContainerAsync** ensures that all cached disposable instances are disposed of—both `IDisposable` and `IAsyncDisposable` implementations will be disposed. A class that implements both `IDisposable` and `IAsyncDisposable`, however, will only have its `DisposeAsync` method invoked.

Likewise, you can asynchronously dispose of a **Container** instance. This will dispose all disposable cached Singletons:

.. code-block:: c#

    await container.DisposeContainerAsync();

When running an application on .NET 4 or .NET Core 2, the `IAsyncDisposable` interface is not available by default. To support asynchronous disposal on these platform versions you have two options:

1. Use the `Microsoft.Bcl.AsyncInterfaces <https://nuget.org/packages/Microsoft.Bcl.AsyncInterfaces>`_ NuGet package. This package contains the `IAsyncDisposable` interface. Simple Injector will recognize this interface when placed on your application components.
2. Define a System.IAsyncDisposable interface in application code. Simple Injector will still recognize this custom interface by making use of duck typing.

Which option to pick depends on several factors:

* Microsoft.Bcl.AsyncInterfaces only supports .NET 4.6.1 and .NET Standard 2.0. If you're running .NET 4.5 or creating a reusable library that supports versions below .NET Standard 2.0, using the second option is your only option.
* You should go for option 1 in case your application is already depending on Microsoft.Bcl.AsyncInterfaces through third-party packages. Simple Injector only supports asynchronous disposal on a single interface. Having multiple interfaces name "System.IAsyncDisposable" can break your application.
* You should go for options 2 if you're trying to prevent binding redirect issues caused by Microsoft.Bcl.AsyncInterfaces or one of its dependencies. Microsoft.Bcl.AsyncInterfaces is a common source of binding direct issues for developers, which is the sole reason Simple Injector v5.2 switched to using duck typing, compared to taking a dependency on Microsoft.Bcl.AsyncInterfaces. You can read more about our reasoning `on our blog <https://blog.simpleinjector.org/2020/12/the-tale-of-the-async-interfaces/>`_.

In case you go for option 2, you need to add the following code to your application:

.. code-block:: c#

    namespace System
    {
        public interface IAsyncDisposable
        {
            Task DisposeAsync();
        }
    }

The signature of this self-defined interface is similar to the built-in version with the sole difference that this interface returns `Task` rather than `ValueTask`. That's because, just like `IAsyncDisposable`, `ValueTask` is not a built-in type prior to .NET Core 3. 
    
.. container:: Note

    **Warning:** Because this interface has a different signature compared to the built-in version, upgrading your application to .NET Core 3 later on does require you to change the classes implementing this interface.


.. _Order-of-disposal:

Order of disposal
-----------------

.. container:: Note

    Simple Injector guarantees that instances are disposed in opposite order of their creation.

When a component *A* depends on component *B*, *B* will be created before *A*. This means that *A* will be disposed before *B* (assuming both implement *IDisposable*). This allows *A* to use *B* while *A* is being disposed.

The following example demonstrates this:

.. code-block:: c#

    class A : IDisposable
    {
        public A(B b) => Console.WriteLine("Creating A");
        public void Dispose() => Console.WriteLine("Disposing A");
    }

    class B : IDisposable
    {
        public B() => Console.WriteLine("Creating B");
        public void Dispose() => Console.WriteLine("Disposing B");
    }
    
    // Registrations
    container.Register<A>(Lifestyle.Scoped);
    container.Register<B>(Lifestyle.Scoped);
    
    // Usage
    using (AsyncScopedLifestyle.BeginScope(container))
    {
        container.GetInstance<A>();
        Console.WriteLine("Using A");
    }

Execution of the above code example results in the following output:
    
.. code-block:: c#

    Creating B
    Creating A
    Using A
    Disposing A
    Disposing B


.. _PerLifetimeScope:
.. _ThreadScoped:

Thread Scoped Lifestyle
=======================

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

    using (ThreadScopedLifestyle.BeginScope(container))
    {
        var uow1 = container.GetInstance<IUnitOfWork>();
        var uow2 = container.GetInstance<IUnitOfWork>();

        Assert.AreSame(uow1, uow2);
    }

.. container:: Note

    **Warning**: The `ThreadScopedLifestyle` is *thread-specific*. A single scope should **not** be used over multiple threads. Do not pass a scope between threads and do not wrap an ASP.NET HTTP request with a `ThreadScopedLifestyle`, since ASP.NET can finish a web request on different thread to the thread the request is started on. Use :ref:`Web Request Lifestyle <WebRequest>` scoping for ASP.NET Web Forms and MVC web applications while running inside a web request. Use :ref:`Async Scoped Lifestyle <AsyncScoped>` when using ASP.NET Web API or ASP.NET Core. `ThreadScopedLifestyle` however, can still be used in web applications on background threads that are created by web requests or when processing commands in a Windows Service (where each command gets its own scope). For developing multi-threaded applications, take :ref:`these guidelines <Multi-Threaded-Applications>` into consideration.

Outside the context of a thread scoped lifestyle, i.e. `using (ThreadScopedLifestyle.BeginScope(container))` no instances can be created. An exception is thrown when a thread scoped registration is requested outside of a scope instance.

Scopes can be nested and each scope will get its own set of instances:

.. code-block:: c#

    using (ThreadScopedLifestyle.BeginScope(container))
    {
        var outer1 = container.GetInstance<IUnitOfWork>();
        var outer2 = container.GetInstance<IUnitOfWork>();

        Assert.AreSame(outer1, outer2);

        using (ThreadScopedLifestyle.BeginScope(container))
        {
            var inner1 = container.GetInstance<IUnitOfWork>();
            var inner2 = container.GetInstance<IUnitOfWork>();

            Assert.AreSame(inner1, inner2);

            Assert.AreNotSame(outer1, inner1);
        }
    }

.. _PerExecutionContextScope:
.. _PerWebAPIRequest:
.. _AsyncScoped:

Async Scoped Lifestyle (async/await)
====================================

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

    using (AsyncScopedLifestyle.BeginScope(container))
    {
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

    using (AsyncScopedLifestyle.BeginScope(container))
    {
        var outer1 = container.GetInstance<IUnitOfWork>();
        await SomeAsyncOperation();
        var outer2 = container.GetInstance<IUnitOfWork>();

        Assert.AreSame(outer1, outer2);

        using (AsyncScopedLifestyle.BeginScope(container))
        {
            var inner1 = container.GetInstance<IUnitOfWork>();
            
            await SomeOtherAsyncOperation();
            
            var inner2 = container.GetInstance<IUnitOfWork>();

            Assert.AreSame(inner1, inner2);

            Assert.AreNotSame(outer1, inner1);
        }
    }

.. _PerWebRequest:
.. _WebRequest:

Web Request Lifestyle
=====================

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

Async Scoped lifestyle vs. Web Request lifestyle
================================================

The lifestyles and scope implementations **Web Request** and **Async Scoped** in Simple Injector are based on different technologies. **AsyncScopedLifestyle** works well both inside and outside of IIS. i.e. It can function in a self-hosted Web API project where there is no *HttpContext.Current*. As the name implies, an async scope registers itself and flows with *async* operations across threads (e.g. a continuation after *await* on a different thread still has access to the scope regardless of whether *ConfigureAwait()* was used with *true* or *false*).

In contrast, the **Scope** of the **WebRequestLifestyle** is stored within the *HttpContext.Items* dictionary. The *HttpContext* can be used with Web API when it is hosted in IIS but care must be taken because it will not always flow with the async operation, because the current *HttpContext* is stored in the *IllogicalCallContext* (see `Understanding SynchronizationContext in ASP.NET <https://blogs.msdn.com/b/pfxteam/archive/2012/06/15/executioncontext-vs-synchronizationcontext.aspx>`_). If you use *await* with *ConfigureAwait(false)* the continuation may lose track of the original *HttpContext* whenever the async operation does not execute synchronously. A direct effect of this is that it would no longer be possible to resolve the instance of a previously created service with **WebRequestLifestyle** from the container (e.g. in a factory that has access to the container) - and an exception would be thrown because *HttpContext.Current* would be null.

The recommendation is to use **AsyncScopedLifestyle** in applications that solely consist of a Web API (or other asynchronous technologies such as ASP.NET Core) and use **WebRequestLifestyle** for applications that contain a mixture of Web API and MVC.

**AsyncScopedLifestyle** offers the following benefits when used in Web API:

* The Web API controller can be used outside of IIS (e.g. in a self-hosted project)
* The Web API controller can execute *free-threaded* (or *multi-threaded*) *async* methods because it is not limited to the ASP.NET *SynchronizationContext*.

For more information, check out the blog entry of Stephen Toub regarding the `difference between ExecutionContext and 
SynchronizationContext <https://vegetarianprogrammer.blogspot.de/2012/12/understanding-synchronizationcontext-in.html>`_.

.. _PerWcfOperation:
.. _WcfOperation:

WCF Operation Lifestyle
=======================

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

Per Graph Lifestyle
===================

.. container:: Note
    
    For each explicit call to **Container.GetInstance<T>** a new instance of the service type will be created, but the instance will be reused within the object graph that gets constructed.

Compared to **Transient**, there will be just a single instance per explicit call to the container, while **Transient** services can have multiple new instances per explicit call to the container. This lifestyle is not supported by Simple Injector but can be simulated by using one of the :ref:`Scoped <Scoped>` lifestyles.

.. _InstancePerDependency:

Instance Per Dependency Lifestyle
=================================

.. container:: Note
    
    Each consumer will get a new instance of the given service type and that dependency is expected to get live as long as its consuming type.

This lifestyle behaves the same as the built-in **Transient** lifestyle, but the intend is completely different. A **Transient** instance is expected to have a very short lifestyle and injecting it into a consumer with a longer lifestyle (such as **Singleton**) is an error. Simple Injector will prevent this from happening by checking for :doc:`lifestyle mismatches <LifestyleMismatches>`. With the *Instance Per Dependency* lifestyle on the other hand, the created component is expected to stay alive as long as the consuming component does. So when the *Instance Per Dependency* component is injected into a **Singleton** component, we intend it to be kept alive by its consumer.

This lifestyle is deliberately left out of Simple Injector, because its usefulness is very limited compared to the **Transient** lifestyle. It ignores :doc:`lifestyle mismatch checks <LifestyleMismatches>` and this can easily lead to errors, and it ignores the fact that application components should be immutable. In case a component is immutable, it's very unlikely that each consumer requires its own instance of the injected dependency.

.. _PerThread:

Per Thread Lifestyle
====================

.. container:: Note
    
    There will be one instance of the registered service type per thread.

This lifestyle is deliberately left out of Simple Injector because :ref:`it is considered to be harmful <No-per-thread-lifestyle>`. Instead of using Per-Thread lifestyle, you will usually be better of using the :ref:`Thread Scoped Lifestyle <ThreadScoped>`.

.. _PerHttpSession:

Per HTTP Session Lifestyle
==========================

.. container:: Note
    
    There will be one instance of the registered service per (user) session in a ASP.NET web application.

This lifestyle is deliberately left out of Simple Injector because `it is be used with care <https://stackoverflow.com/questions/17702546>`_. Instead of using Per HTTP Session lifestyle, you will usually be better of by writing a stateless service that can be registered as singleton and let it communicate with the ASP.NET Session cache to handle cached user-specific data.

.. _Hybrid:

Hybrid Lifestyle
================

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
        lifestyleApplierFactory: instanceCreator =>
        {
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
        lifestyleApplierFactory: instanceCreator =>
        {
            TimeSpan timeout = TimeSpan.FromMinutes(10);
            var syncRoot = new object();
            var expirationTime = DateTime.MinValue;
            object instance = null;

            return () =>
            {
                lock (syncRoot)
                {
                    if (expirationTime < DateTime.UtcNow)
                    {
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
    
    In case you wish to develop a custom lifestyle, we strongly advise posting a question on `our Forum <https://simpleinjector.org/forum>`_. We will be able to guide you through this process.



.. _Generics-and-lifetime-management:

Generics and Lifetime Management
================================

Just as with any other registration, lifestyles can be applied to open-generic registrations. The following registration demonstrates this:

.. code-block:: c#

    container.Register(typeof(IValidator<>), typeof(DefaultValidator<>),
        Lifestyle.Singleton);

This registers the open-generic *DefaultValidator<T>* class as **Singleton** for the *IValidator<T>* service. One might think, though, that there will only be a single instance of *DefaultValidator<T>* returned by the Container, but this is not the case.

At runtime, it is impossible to create an instance of an open-generic type, such as *DefaultValidator<T>*. Only closed versions can be created. An instance of *DefaultValidator<Customer>*, for instance, can be created, just as you can create a new *DefaultValidator<Order>* instance. But what the .NET runtime is concerned, these are two completely unrelated types. You can't replace one for the other. For instance, if some class requires an *IValidator<Customer>*, Simple Injector can't inject an *IValidator<Order>* implementation instead. The runtime doesn't allow this, and neither would the C# compiler if you coded this by hand.

So instead, you should consider a registration for an open-generic type, a complete list of its closed-generic types instead:

.. code-block:: c#

    container.RegisterSingleton<IValidator<Customer>, DefaultValidator<Customer>();
    container.RegisterSingleton<IValidator<Order>, DefaultValidator<Order>();
    container.RegisterSingleton<IValidator<Product>, DefaultValidator<Product>();
    container.RegisterSingleton<IValidator<Shipment>, DefaultValidator<Shipment>();
    // etc

This is what actually happens under the covers with your generic registration. Simple Injector will make a last-minute registration for the closed type when it is resolved for the first time. And as the above example shows, each closed registration will have its own lifestyle cache.    

.. container:: Note

    **NOTE**: While this text demonstrates this using the **Singleton** lifestyle, this holds for every lifestyle.


.. _Collections-and-lifetime-management:

Collections and Lifetime Management
===================================

Most applications that apply Dependency Injection need to work with collections of dependencies of some sort. In a typical situation, the dependencies that are part of the injected collection should all be part of the same scope. Without making any special adjustments to your code, this is the behavior you get out of the box. The following example demonstrates this:

.. code-block:: c#
    
    // Registration
    container.Register<IService, Service>();
    container.Collection.Append<ILogger, MailLogger>(Lifestyle.Transient);
    container.Collection.Append<ILogger, SqlLogger>(Lifestyle.Scoped);
    container.Collection.Append<ILogger, FileLogger>(Lifestyle.Singleton);
    container.Collection.AppendInstance<ILogger>(new ConsoleLogger(ConsoleColor.Gray));
        
    // Class depending on a collection of dependencies
    public class Service : IService
    {
        private readonly IEnumerable<ILogger> loggers;

        public Service(IEnumerable<ILogger> loggers)
        {
            this.loggers = loggers;
        }

        void IService.DoStuff()
        {
            foreach (var logger in this.loggers)
            {
                logger.Log("Some message");
            }
            
            // For sake of argument, this method iterates the loggers again.
            foreach (var logger in this.loggers)
            {
                logger.Log("Something else");
            }
        }
    }

    // Usage
    using (Scope scope = AsyncScopedLifstyle.BeginScope(container))
    {
        var service = container.GetInstance<IService>();
        service.DoStuff();
    }

In the example above, the `Service` class is injected with a collection of four different `ILogger` implementations, each with their own different lifestyle. The `Service` class's `DoStuff` method is invoked in the context of the scope of an **AsyncScopedLifstyle**. During the execution of that scope there will only be one instance of `SqlLogger`, as it is registered as **Scoped**. On the other hand, `MailLogger` is registered as **Transient**. This means multiple instance can be created and, in fact, in this example two instances are created, because each iteration of the `loggers` collection will create a new `MailLogger` instance. This happens because, in Simple Injector, collections are considered *streams*.

So far so good, but in more-specialized cases you might want to operate each collection dependency in its own scope. This allows running each dependency in its own isolated bubble, for instance with its own Entity Framework database context or similar Unit of Work implementation. Event handlers are a great example of when this might be beneficial. The following code shows how the `Publisher<TEvent>` class is used to dispatch a single event message to multiple handler implementations for that event:

.. code-block:: c#
    
    public class Publisher<TEvent> : IPublisher<TEvent>
    {
        private readonly IEnumerable<IEventHandler<TEvent>> handlers;

        public Publisher(IEnumerable<IEventHandler<TEvent>> handlers)
        {
            this.handlers = handlers;
        }

        public void Publish(TEvent e)
        {
            foreach (var handler in this.handlers)
            {
                handler.Handle(e);
            }
        }
    }

With the previous implementation all handlers (and their dependencies) will run in the same **Scope**, similar to the previous `Service` example. But since every handler is created lazily during iteration of the collection, the following change allows every handler to run in its own isolated **Scope**:

.. code-block:: c#
    
    public class Publisher<TEvent> : IPublisher<TEvent>
    {
        private readonly Container container;
        private readonly IEnumerable<IEventHandler<TEvent>> handlers;

        public Publisher(
            Container container, IEnumerable<IEventHandler<TEvent>> handlers)
        {
            this.container = container;
            this.handlers = handlers;
        }

        public void Publish(TEvent e)
        {
            using (var enumerator = this.handlers.GetEnumerator())
            {
                while (true)
                {
                    using (AsyncScopedLifestyle.BeginScope(this.container))
                    {
                        if (enumerator.MoveNext())
                        {
                            enumerator.Current.Handle(e);
                        }
                        else
                        {
                            break;
                        }
                    }
                }
            }
        }
    }

When iterating a collection, the `MoveNext()` of the enumerator delegates the call to the **GetInstance** method of the underlying **InstanceProducer** of the specific dependency. Because each element is wrapped in its own **Scope**, before `MoveNext` is called, it guarantees that each element lives in its own scope.

The previous example, however, is rather complicated and can be confusing to understand. Simple Injector v5's metadata feature, however, simplifies this use case considerably. Using the new `DependencyMetadata<T>` class, the previous example can be simplified to the following:

.. code-block:: c#
    
    public class Publisher<TEvent> : IPublisher<TEvent>
    {
        private readonly Container container;
        private readonly IEnumerable<DependencyMetadata<IEventHandler<TEvent>>> metadatas;

        public Publisher(
            Container container,
            IEnumerable<DependencyMetadata<IEventHandler<TEvent>>> metadatas)
        {
            this.container = container;
            this.metadatas = metadatas;
        }

        public void Publish(TEvent e)
        {
            foreach (var metadata in this.metadatas)
            {
                using (AsyncScopedLifestyle.BeginScope(this.container))
                {
                    metadata.GetInstance().Handle(e);
                }
            }
        }
    }

This this last code snippet, rather than being injected with a stream of `IEventHandler<TEvent>` instances, the `Publisher<TEvent>` is injected with a stream of `DependencyMetadata<IEventHandler<TEvent>>` instances. `DependencyMetadata<T>` is Simple Injector v5's new construct, which allows to access the dependency's metadata and allow resolving an instance of that dependency. In this case, its **GetInstance** method is used to resolve an instance within its own **Scope**.

.. _flowing-scopes:

Flowing scopes
==============

Simple Injector's default modus operandi is to store active scopes in ambient state. This is why, with Simple Injector, within the context of a scope you'd still resolve instances from the `Container`—not the `Scope`, as the following example demonstrates:

.. code-block:: c#

    var container = new Container();
    container.Options.DefaultScopedLifestyle = new AsyncScopedLifestyle();

    using (AsyncScopedLifestyle.BeginScope(container))
    {
        // Here you simply resolve from the Containe
        container.GetInstance<IMyService>();
    }

This model has several interesting advantages over resolving from a `Scope`, as some other DI Containers require:

* It simplifies the registration of delegates, as those delegates can directly resolve from the container, instead having to use a supplied scope.
* It removes the distinction between resolving from the `Container` vs. a `Scope`, where resolving from the `Container` would cause instances to be cached indefinitely, and cause memory leaks, as what happens with some other DI Containers.
* It simplifies resolving Scoped and Transient services from inside Singleton components, just by injecting the `Container` instance. Even inside the context of a Singleton class, the `Container` instance knows in which scope it is currently running.

Even though this ambient model has advantages, there are scenarios where it doesn't work, which is when you need to run multiple isolated scopes within the same ambient context. Within ASP.NET and ASP.NET Core, each web request gets its own ambient context from the framework. This means that when you start a `Scope` that scope will be automatically isolated for that request. With desktop technologies, on the other hand, such as WinForms and WPF, all the forms and views you create run in the same ambient context. This disallows running each page or view in their own isolated bubble—Simple Injector will automatically nest all created scopes because of the existence of that single ambient context. An isolated bubble per form/view is required when you want each form/view to have its own instance of a scoped service.

The most common scenario is when injecting `DbContext` instances into object graphs with forms/view (screens) as their root type. You might open multiple screens at the same time, and they might live for quite some time, but reusing the same `DbContext` throughout all screens in the system effectively means the `DbContext` becomes a Singleton, which leads to all kinds of problems. Instead, you can give each screen its own `DbContext` and dispose of that `DbContext` when the screen is closed. For this scenario, Simple Injector contains an alternative to its Ambient Scopes, which is Flowing Scopes. Flowing scopes are configured as follows:

.. code-block:: c#

    var container = new Container();
    container.Options.DefaultScopedLifestyle = ScopedLifestyle.Flowing;

When you configure Simple Injector to use Flowing scopes, the active scope will no longer be available ubiquously, and you won't be able to call `Container.GetInstance<T>` any longer to resolve object graphs that contain `Scoped` components. Instead, you will have to do the following:

.. code-block:: c#

    using (var scope = new Scope(container))
    {
        // You will have to resolve directly from the scope.
        scope.GetInstance<MainView>();
    }

Advantage of Flowing Scopes is that you can have as many isolated scopes running side by side, for instance:

.. code-block:: c#

    var scope1 = new Scope(container);
    var scope2 = new Scope(container);
    var scope3 = new Scope(container);
    
    scope1.GetInstance<MainView>();
    scope2.GetInstance<ProductsView>();
    scope2.Dispose();
    scope3.GetInstance<CustomersView>();
    
    scope1.Dispose();
    scope3.Dispose();

This change from resolving from the `Container` to resolving from a `Scope` might seem trivial, but it is important to understand that under the covers, things are changing quite drastically. There are several scenarios where Simple Injector internally expects the availability of an Ambient Scope in order to resolve instances—i.e. collections. When injecting collections while resolving through Flowing Scopes, that active scope needs to be stored inside the injected collection.

When running in Ambient-Scoping mode, collections in Simple Injector act as streams. This allows a collection of Scoped and Transient services to be injected in a Singleton consumer. When the collection is iterated, the Scoped services will automatically be resolved according to the active scope. For more information about this, see :ref:`collections and lifetime management <Collections-and-lifetime-management>`.

When running in Flowing Scoping, on the other hand, an injected collection of Transient and Scoped instances will no longer be injected into a Singleton consumer, because that would otherwise store a single Scope instance indefinitely. You will, in that case, must lower the lifetime of the consuming component to either Scoped or Transient. This could have consequences on the design of the application because it is not always easy to lower the lifetime of a component.

Another case where changes might be required is when working with :ref:`decoratee factories <Decorators-with-Func-factories>`. Simple Injector allows factory delegates to be injected into decorators, as the following example demonstrates:

.. code-block:: c#

    public class ServiceDecorator : IService
    {
        private readonly Container container;
        private readonly Func<Scope, IService> decorateeFactory;

        public ServiceDecorator(
            Container container, Func<Scope, IService> decorateeFactory)
        {
            this.container = container;
            this.decorateeFactory = decorateeFactory;
        }

        public void Do()
        {
            using (AsyncScopedLifestyle.BeginScope(this.container))
            {
                IService service = this.decorateeFactory.Invoke();
                service.Do();
            }
        }
    }

This technique allows the creation of the decorated instance to be postponed and run in their own isolated scope. When running with Flowing Scopes, however, the factory delegate needs to be supplied with a `Scope` instance, as follows:

.. code-block:: c#

    public class ServiceDecorator : IService
    {
        private readonly Container container;
        private readonly Func<Scope, IService> decorateeFactory;

        public ServiceDecorator(
            Container container, Func<Scope, IService> decorateeFactory)
        {
            this.container = container;
            this.decorateeFactory = decorateeFactory;
        }

        public void Do()
        {
            using (var scope = new Scope(this.container))
            {
                IService service = this.decorateeFactory.Invoke(scope);
                service.Do();
            }
        }
    }

Just like with the injection of `Func<T>` delegates, Simple Injector natively understands `Func<Scope, T>` delegates when injected into decorators.

The Flowing-Scoping model is a more recent concept to Simple Injector, compared to its original Ambient-Scoping model. It is added especially for the rare scenarios where Ambient Scoping doesn't work. Because of the newness of the Flowing model, you will likely stumble upon scenarios that are not easily supported with this model, compared to its original model. We, therefore, discourage the use of this model in cases where Ambient Scoping would do just fine.
