==========================
Object Lifetime Management
==========================

Object Lifetime Management is the concept of controlling the number of instances a configured service will have and the duration of the lifetime of those instances. In other words, it allows you to determine how returned instances are cached. Most DI libraries have sophisticated mechanisms for lifestyle management, and Simple Injector is no exception with built-in support for the most common lifestyles. The two default lifestyles (transient and singleton) are part of the core library, while other lifestyles can be found within some of the extension and integration packages. The built-in lifestyles will suit about 99% of cases. For anything else custom lifestyles can be used.

Below is a list of the most common lifestyles with code examples of how to configure them using Simple Injector:

* :ref:`Transient <Transient>`
* :ref:`Singleton <Singleton>`
* :ref:`Scoped <Scoped>`
* :ref:`Per Web Request <PerWebRequest>`
* :ref:`Per Web API Request <PerWebAPIRequest>`
* :ref:`Per WCF Operation <PerWcfOperation>`
* :ref:`Per Lifetime Scope <PerLifetimeScope>`
* :ref:`Per Execution Context Scope (async/await) <PerExecutionContextScope>`
* :ref:`Per Graph <PerGraph>`
* :ref:`Per Thread <PerThread>`
* :ref:`Per HTTP Session <PerHttpSession>`
* :ref:`Hybrid <Hybrid>`
* :ref:`Developing a Custom Lifestyle <CustomLifestyles>`

.. _Transient:

Transient
=========

.. container:: Note
    
    A new instance of the service type will be created for each request (both for calls to **GetInstance<T>** and instances as part of an object graph).

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

This construct is only required for registering types by a base type or an interface. For concrete transient types, no formal registration is required as concrete types will be automatically registered on request:

.. code-block:: c#

    container.GetInstance<RealService>(); 

When you have a type that you want to be created using automatic constructor injection, but need some configuration that can't be done using constructor injection, you can use the **RegisterInitializer** method. It takes an *Action<T>* delegate:

.. code-block:: c#

    container.RegisterInitializer<ICommand>(commandToInitialize => {
        commandToInitialize.ExecuteAsynchronously = true;
    });

The given configuration calls the delegate after the creation of each type that implements *ICommand* and will set the *ExecuteAsynchroniously* property to *true*. This is a powerful mechanism that enables attribute-free property injection.

.. _Singleton:

Singleton
=========

.. container:: Note
    
    There will be only one instance of the registered service type during the lifetime of that container instance. Clients will always receive that same instance.

There are multiple ways to register singletons. The most simple and common way to do this is by specifying both the service type and the implementation as generic type arguments. This allows the implementation type to be constructed using automatic constructor injection:

.. code-block:: c#

    container.Register<IService, RealService>(Lifestyle.Singleton);

    // Alternatively, you can use the following short cut
    container.RegisterSingle<IService, RealService>();

You can also use the *RegisterSingle<T>(T)* overload to assign a constructed instance manually:
 
.. code-block:: c#

    var service = new RealService(new SqlRepository());
    container.RegisterSingle<IService>(service);

There is also an overload that takes an *Func<T>* delegate. The container guarantees that this delegate is called only once:

.. code-block:: c#

    container.Register<IService>(() => new RealService(new SqlRepository()),
        Lifestyle.Singleton);

    // Or alternatively:
    container.RegisterSingle<IService>(() => new RealService(new SqlRepository()));

Alternatively, when needing to register a concrete type as singleton, you can use the parameterless **RegisterSingle<T>()** overload. This will inform the container to automatically construct that concrete type (at most) once, and return that instance on each request:

.. code-block:: c#

    container.RegisterSingle<RealService>();

    // Which is a more convenient short cut for:
    container.Register<RealService, RealService>(Lifestyle.Singleton);

Registration for concrete singletons is necessarily, because unregistered concrete types will be treated as transient.

.. _Scoped:

Scoped
======

.. container:: Note
    
    For every request within an implicitly or explicitly defined scope, a single instance of the service will be returned and that instance will (optionally) be disposed when the scope ends.

Simple Injector contains five scoped lifestyles:

* :ref:`Per Web Request <PerWebRequest>`
* :ref:`Per Web API Request <PerWebAPIRequest>`
* :ref:`Per WCF Operation <PerWcfOperation>`
* :ref:`Per Lifetime Scope <PerLifetimeScope>`
* :ref:`Per Execution Context Scope <PerExecutionContextScope>`

Both *Per Web Request* and *Per WCF Operation* implement scoping implicitly, which means that the user does not have to start or finish the scope to allow the lifestyle to end and to dispose cached instances. The *Container* does this for you. With the *Per Lifetime Scope* lifestyle on the other hand, you explicitly define a scope (just like you would do with .NET's TransactionScope class).

The default behavior of Simple Injector is to **not** keep track of instances and to **not** dispose them. The scoped lifestyles on the other hand are the exceptions to this rule. Although most of your services should be registered either as :ref:`Transient <Transient>` or :ref:`Singleton <Singleton>`, scoped lifestyles are especially useful for implementing patterns such as the `Unit of Work <http://martinfowler.com/eaaCatalog/unitOfWork.html>`_.

.. _PerWebRequest:

Per Web Request
===============

.. container:: Note
    
    Only one instance will be created by the container per web request and the instance will be disposed when the web request ends (unless specified otherwise).

The `ASP.NET Integration NuGet Package <https://nuget.org/packages/SimpleInjector.Integration.Web>`_ is available (and available as **SimpleInjector.Integration.Web.dll** in the default download here on CodePlex) contains *RegisterPerWebRequest* extension methods and a **WebRequestLifestyle** class that enable easy *Per Web Request* registrations:

.. code-block:: c#

    container.RegisterPerWebRequest<IUserRepository, SqlUserRepository>();
    container.RegisterPerWebRequest<IOrderRepository, SqlOrderRepository>();

    // The same behavior can be achieved by using the WebRequestLifestyle class.
    var webLifestyle = new WebRequestLifestyle();
    container.Register<IUserRepository, SqlUserRepository>(webLifestyle);
    container.Register<IOrderRepository, SqlOrderRepository>(webLifestyle);

    // Alternatively, when cached instances that implement IDisposable, should NOT
    // be disposed, you can do the following
    var withoutDispose = new WebRequestLifestyle(false);
    container.Register<IUserRepository, SqlUserRepository>(withoutDispose);

In contrast to the default behavior of Simple Injector, these extension methods ensure the created service is disposed (when such an instance implements *IDisposable*). This disposal is done at the end of the web request. During startup an *HttpModule* is automatically registered for you that ensures all created instances are disposed when the web request ends.

.. container:: Note

    **Tip**: For ASP.NET MVC, there's a `Simple Injector MVC Integration Quick Start <https://nuget.org/packages/SimpleInjector.MVC3>`_ NuGet Package available that helps you get started with Simple Injector in MVC applications quickly.

Optionally you can register other services for disposal at the end of the web request:

.. code-block:: c#

    var scoped = new WebRequestLifestyle();
    container.Register<IService, ServiceImpl>();
    container.RegisterInitializer<ServiceImpl>(instance  =>
        scoped.RegisterForDisposal(container, instance));

This ensures that each time a *ServiceImpl* is created by the container, it is registered for disposal when the web request ends.

.. container:: Note

    **Note**: To be able to dispose an instance, the **RegisterForDisposal** will store the reference to that instance in the *HttpContext* Items cache. This means that the instance will be kept alive for the duration of that request.

.. container:: Note

    **Note**: Be careful to not register any services for disposal that will outlive the web request (such as services registered as singleton), since a service cannot be used once it has been disposed.

.. _PerWebAPIRequest:

Per Web API Request
===================

.. container:: Note
    
    Only one instance will be created by the container per request in a ASP.NET Web API application and the instance will be disposed when that request ends (unless specified otherwise).

The `ASP.NET Web API Integration NuGet Package <https://nuget.org/packages/SimpleInjector.Integration.WebApi>`_ is available (and available as **SimpleInjector.Integration.WebApi.dll** in the default download here on CodePlex) contains *RegisterWebApiRequest* extension methods and a **WebApiRequestLifestyle** class that enable easy *Per Web API Request* registrations:

.. code-block:: c#

    container.RegisterWebApiRequest<IUserRepository, SqlUserRepository>();
    container.RegisterWebApiRequest<IOrderRepository, SqlOrderRepository>();

    // The same behavior can be achieved by using the WebRequestLifestyle class.
    var webLifestyle = new WebApiRequestLifestyle();
    container.Register<IUserRepository, SqlUserRepository>(webLifestyle);
    container.Register<IOrderRepository, SqlOrderRepository>(webLifestyle);

    // Alternatively, when cached instances that implement IDisposable, should NOT
    // be disposed, you can do the following
    var withoutDispose = new WebApiRequestLifestyle(false);
    container.Register<IUserRepository, SqlUserRepository>(withoutDispose);

In contrast to the default behavior of Simple Injector, these extension methods ensure the created service is disposed (when such an instance implements *IDisposable*). This is done at the end of the Web API request. For this lifestyle to work, 

.. container:: Note

    **Tip**: There's a `Simple Injector Web API Integration Quick Start <https://nuget.org/packages/SimpleInjector.Integration.WebApi.WebHost.QuickStart>`_ NuGet Package available that helps you get started with Simple Injector in Web API applications quickly.

.. _WebAPIRequest-vs-WebRequest:

Web API Request lifestyle vs. Web Request lifestyle
===================================================

The lifestyles and scope implementations *Web Request* and *Web API Request* in SimpleInjector are based on different technologies.

**WebApiRequestLifestyle** is derived from **ExecutionContextScopeLifestyle** which works well both inside and outside of IIS. i.e. It can function in a self-hosted Web API project where there is no *HttpContext.Current*. The scope used by **WebApiRequestLifestyle** is the **ExecutionContextScope**. As the name implies, an execution context scope registers itself in the logical call context and flows with *async* operations across threads (e.g. a continuation after *await* on a different thread still has access to the scope regardless of whether *ConfigureAwait()* was used with *true* or *false*).

In contrast, the **Scope** of the **WebRequestLifestyle** is stored within the *HttpContext.Items* dictionary. The *HttpContext* can be used with Web API when it is hosted in IIS but care must be taken because it will not always flow with the execution context, because the current *HttpContext* is stored in the *IllogicalCallContext* (see `Understanding SynchronizationContext in ASP.NET <https://blogs.msdn.com/b/pfxteam/archive/2012/06/15/executioncontext-vs-synchronizationcontext.aspx>`_). If you use *await* with *ConfigureAwait(false)* the continuation may lose track of the original *HttpContext* whenever the async operation does not execute synchronously. A direct effect of this is that it would no longer be possible to resolve the instance of a previously created service with **WebRequestLifestyle** from the container (e.g. in a factory that has access to the container) - and an exception would be thrown because *HttpContext.Current* would be null.

The recommendation is therefore to use **WebApiRequestLifestyle** for services that should be 'per Web API request', the most obvious example being services that are injected into Web API controllers. **WebApiRequestLifestyle** offers the following benefits:

* The Web API controller can be used outside of IIS (e.g. in a self-hosted project)
* The Web API controller can execute *free-threaded* (or *multi-threaded*) *async* methods because it is not limited to the ASP.NET *SynchronizationContext*.

For more information, check out the blog entry of Stephen Toub regarding the `difference between ExecutionContext and 
SynchronizationContext <https://vegetarianprogrammer.blogspot.de/2012/12/understanding-synchronizationcontext-in.html>`_.

.. _PerWcfOperation:

Per WCF Operation
=================

.. container:: Note
    
    Only one instance will be created by the container during the lifetime of the WCF service class and the instance will be disposed when the WCF service class is released (unless specified otherwise).

The `WCF Integration NuGet Package <https://nuget.org/packages/SimpleInjector.Integration.Wcf>`_ is available (and available as **SimpleInjector.Integration.Wcf.dll** in the default download here on CodePlex) contains **RegisterPerWcfOperation** extension methods and a **WcfOperationLifestyle** class that enable easy *Per WCF Operation* registrations:

.. code-block:: c#

    container.RegisterPerWcfOperation<IUserRepository, SqlUserRepository>();
    container.RegisterPerWcfOperation<IOrderRepository, SqlOrderRepository>();

    // The same behavior can be achieved by using the WcfOperationLifestyle class.
    var wcfLifestyle = new WcfOperationLifestyle();
    container.Register<IUserRepository, SqlUserRepository>(wcfLifestyle);
    container.Register<IOrderRepository, SqlOrderRepository>(wcfLifestyle);

    // Alternatively, when cached instance that implement IDisposable, should NOT
    // be disposed, you can do the following
    var withoutDispose = new WcfOperationLifestyle(false);
    container.Register<IUserRepository, SqlUserRepository>(withoutDispose);

In contrast to the default behavior of Simple Injector, these extension methods ensure the created service is disposed (when such an instance implements *IDisposable*). This is done after the WCF service instance is released by WCF.

.. container:: Note

    **Warning**: Instead of what the name of the **WcfOperationLifestyle** class and the **RegisterPerWcfOperation** methods seem to imply, components that are registered with this lifestyle might actually outlive a single WCF operation. This behavior depends on how the WCF service class is configured. WCF is in control of the lifetime of the service class and contains three lifetime types as defined by the `InstanceContextMode enumeration <https://msdn.microsoft.com/en-us/library/system.servicemodel.instancecontextmode.aspx>`_. Components that are registered *PerWcfOperation* live as long as the WCF service class they are injected into.

For more information about integrating Simple Injector with WCF, please see the :doc:`WCF integration guide <wcfintegration>`.

You can optionally register other services for disposal at the end of the web request:

.. code-block:: c#

    var scoped = new WcfOperationLifestyle();
    container.Register<IService, ServiceImpl>();
    container.RegisterInitializer<ServiceImpl>(instance =>
        scoped.RegisterForDisposal(container, instance));

This ensures that each time a *ServiceImpl* is created by the container, it is registered for disposal when the WCF operation ends.

.. container:: Note

    **Note**: To be able to dispose an instance, the **RegisterForDisposal** will store a reference to that instance during the lifetime of the WCF operation. This means that the instance will be kept alive for the duration of that operation.

.. container:: Note

    **Note**: Be careful to not register any services for disposal that will outlive the WCF operation (such as services registered as singleton), since a service cannot be used once it has been disposed.

.. _PerLifetimeScope:

Per Lifetime Scope
==================

.. container:: Note
    
    Within a certain (explicitly defined) scope, there will be only one instance of a given service type and the instance will be disposed when the scope ends (unless specified otherwise).

Lifetime Scoping is supported as an extension package for Simple Injector. It is available as `Lifetime Scoping Extensions NuGet package <https://nuget.org/packages/SimpleInjector.Extensions.LifetimeScoping>`_ and is part of the default download on CodePlex as **SimpleInjector.Extensions.LifetimeScoping.dll**. The extension package adds multiple **RegisterLifetimeScope** extension method overloads and a **LifetimeScopeLifestyle** class, which allow to register services with the *Lifetime Scope* lifestyle:

.. code-block:: c#

    container.RegisterLifetimeScope<IUnitOfWork, NorthwindContext>();

    // Or alternatively
    container.Register<IUnitOfWork, NorthwindContext>(new LifetimeScopeLifestyle());

Within an explicitly defined scope, there will be only one instance of a service that is defined with the *Lifetime Scope* lifestyle:

.. code-block:: c#

    using (container.BeginLifetimeScope()) {
        var uow1 = container.GetInstance<IUnitOfWork>();
        var uow2 = container.GetInstance<IUnitOfWork>();

        Assert.AreSame(uow1, uow2);
    }

.. container:: Note

    **Note**: A scope is *thread-specific*. A single scope should **not** be used over multiple threads. Do not pass a scope between threads and do not wrap an ASP.NET HTTP request with a Lifetime Scope, since ASP.NET can finish a web request on different thread to the thread the request is started on. Use :ref:`Per Web Request <PerWebRequest>` scoping for ASP.NET web applications while running inside a web request. Lifetime scoping however, can still be used in web applications on background threads that are created by web requests or when processing commands in a Windows Service (where each commands gets its own scope). For developing multi-threaded applications, take :ref:`these guidelines <Multi-Threaded-Applications>` into consideration.

Outside the context of a lifetime scope, i.e. `using (container.BeginLifetimeScope())` no instances can be created. An exception is thrown when a lifetime soped registration is requested outside of a scope instance.

Scopes can be nested and each scope will get its own set of instances:

.. code-block:: c#

    using (container.BeginLifetimeScope()) {
        var outer1 = container.GetInstance<IUnitOfWork>();
        var outer2 = container.GetInstance<IUnitOfWork>();

        Assert.AreSame(outer1, outer2);

        using (container.BeginLifetimeScope()) {
            var inner1 = container.GetInstance<IUnitOfWork>();
            var inner2 = container.GetInstance<IUnitOfWork>();

            Assert.AreSame(inner1, inner2);

            Assert.AreNotSame(outer1, inner1);
        }
    }

In contrast to the default behavior of Simple Injector, a lifetime scope ensures the created service is disposed (when such an instance implements *IDisposable*), unless explicitly disabled. This is happens at the end of the scope.

You can explicitly register services for disposal at the end of the scope:

.. code-block:: c#

    var scopedLifestyle = new LifetimeScopeLifestyle();
    container.Register<IService, ServiceImpl>();
    container.RegisterInitializer<ServiceImpl>(instance =>
        scopedLifestyle.RegisterForDisposal(container, instance));

This ensures that each time a *ServiceImpl* is created by the container, it is disposed when the associated scope (in which it was created) ends.

.. container:: Note

    **Note**: To be able to dispose an instance, the **RegisterForDisposal** method will store a reference to that instance within the **LifetimeScope** instance. This means that the instance will be kept alive for the duration of that scope.

.. container:: Note

    **Note**: Be careful to not register any services for disposal that will outlive the scope itself (such as services registered as singleton), since a service cannot be used once it has been disposed.

.. _PerExecutionContextScope:

Per Execution Context Scope
===========================

.. container:: Note
    
    There will be only one instance of a given service type within a certain (explicitly defined) scope and that instance will be disposed when the scope ends (unless specified otherwise).

This scope will automatically flow with the logical flow of control of asynchronous methods. This lifestyle is especially suited for client applications that work with the new asynchronous programming model. For Web API there's a :ref:`Per Web API Request lifestyle <PerWebAPIRequest>` (which actually uses this Execution Context Scope lifestyle under the covers).

Execution Context Scoping is an extension package for Simple Injector. It is available as `Execution Context Extensions NuGet package <https://nuget.org/packages/SimpleInjector.Extensions.ExecutionContextScoping>`_ and is part of the default download on CodePlex as **SimpleInjector.Extensions.ExecutionContextScoping.dll**. The extension package adds multiple **RegisterExecutionContextScope** extension method overloads and a **ExecutionContextScopeLifestyle** class, which allow to register services with the *Execution Context Scope* lifestyle:

.. code-block:: c#

    container.RegisterExecutionContextScope<IUnitOfWork, NorthwindContext>();

    // Or alternatively
	ver scopedLifestyle = new ExecutionContextScopeLifestyle();
    container.Register<IUnitOfWork, NorthwindContext>(scopedLifestyle);

Within an explicitly defined scope, there will be only one instance of a service that is defined with the *Execution Context Scope* lifestyle:

.. code-block:: c#

    // using SimpleInjector.Extensions.ExecutionContextScoping;

    using (container.BeginExecutionContextScope()) {
        var uow1 = container.GetInstance<IUnitOfWork>();
        await SomeAsyncOperation();
        var uow2 = container.GetInstance<IUnitOfWork>();
        await SomeOtherAsyncOperation();

        Assert.AreSame(uow1, uow2);
    }

.. container:: Note

    **Note**: A scope is specific to the asynchronous flow. A method call on a different (unrelated) thread, will get its own scope.

Outside the context of a lifetime scope no instances can be created. An exception is thrown when this happens.

Scopes can be nested and each scope will get its own set of instances:

.. code-block:: c#

    using (container.BeginLifetimeScope()) {
        var outer1 = container.GetInstance<IUnitOfWork>();
        await SomeAsyncOperation();
        var outer2 = container.GetInstance<IUnitOfWork>();

        Assert.AreSame(outer1, outer2);

        using (container.BeginLifetimeScope()) {
            var inner1 = container.GetInstance<IUnitOfWork>();
            
            await SomeOtherAsyncOperation();
            
            var inner2 = container.GetInstance<IUnitOfWork>();

            Assert.AreSame(inner1, inner2);

            Assert.AreNotSame(outer1, inner1);
        }
    }

In contrast to the default behavior of Simple Injector, a scoped lifestyle ensures the created service is disposed (when such an instance implements *IDisposable*), unless explicitly disabled. This is done at the end of the scope.

Optionally you can register other services for disposal at the end of the scope:

.. code-block:: c#

    var scopedLifestyle = new ExecutionContextScopeLifestyle();
    container.Register<IService, ServiceImpl>();
    container.RegisterInitializer<ServiceImpl>(instance =>
        scopedLifestyle.RegisterForDisposal(container, instance));

This ensures that each time a *ServiceImpl* is created by the container, it is registered for disposal when the scope (in which it is created) ends.

.. container:: Note

    **Note**: To be able to dispose an instance, the **RegisterForDisposal** will store the reference to that instance within that scope. This means that the instance will be kept alive for the duration of that scope.

.. container:: Note

    **Note**: Be careful to not register any services for disposal that will outlive the scope itself (such as services registered as singleton), since a service cannot be used once it has been disposed.

.. _PerGraph:

Per Graph
=========

.. container:: Note
    
    For each explicit call to **Container.GetInstance<T>** a new instance of the service type will be created, but the instance will be reused within the object graph that gets constructed.

Compared to **Transient**, there will be just a single instance per explicit call to the container, while **Transient** services can have multiple new instances per explicit call to the container. This lifestyle can be simulated by using one of the :ref:`Scoped <Scoped>` lifestyles.

.. _PerThread:

Per Thread
==========

.. container:: Note
    
    There will be one instance of the registered service type per thread.

This lifestyle is deliberately left out of Simple Injector because `it is considered to be harmful <https://stackoverflow.com/a/14592419/264697>`_. Instead of using Per Thread lifestyle, you will usually be better of using one of the :ref:`Scoped lifestyles <Scoped>`.

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

    var hybridLifestyle = Lifestyle.CreateHybrid(
        lifestyleSelector: () => HttpContext.Current != null,
        trueLifestyle: new WebRequestLifestyle(),
        falseLifestyle: new LifetimeScopeLifestyle());

    // The created lifestyle can be reused for many registrations.
    container.Register<IUserRepository, SqlUserRepository>(hybridLifestyle);
    container.Register<ICustomerRepository, SqlCustomerRepository>(hybridLifestyle);

In the example a hybrid lifestyle is defined wrapping the :ref:`Web Request <PerWebRequest>` lifestyle and the :ref:`Per Lifetime Scope <PerLifetimeScope>` lifestyle. The supplied *lifestyleSelector* predicate returns *true* when the container should use the *Web Request* lifestyle and *false* when the *Per Lifetime Scope* lifestyle should be selected.

A hybrid lifestyle is useful for registrations that need to be able to dynamically switch lifestyles throughout the lifetime of the application. The shown hybrid example might be useful in a web application, where some operations run outside the context of an *HttpContext* (in a background thread for instance). Please note though that when the lifestyle doesn't have to change throughout the lifetime of the application, a hybrid lifestyle is not needed. A normal lifestyle can be registered instead:

.. code-block:: c#

    var lifestyle =
        RunsOnWebServer ? new WebRequestLifestyle() : new LifetimeScopeLifestyle();

    container.Register<IUserRepository, SqlUserRepository>(lifestyle);
    container.Register<ICustomerRepository, SqlCustomerRepository>(lifestyle);

.. _CustomLifestyles:

Developing a Custom Lifestyle
=============================

The lifestyles supplied by the framework should be sufficient for most scenarios, but in rare circumstances defining a custom lifestyle might be useful. This can be done by creating a class that inherits from `Lifestyle <https://simpleinjector.org/ReferenceLibrary/?topic=html/T_SimpleInjector_Lifestyle.htm>`_ and let it return `Custom Registration <https://simpleinjector.org/ReferenceLibrary/?topic=html/T_SimpleInjector_Registration.htm>`_ instances. This however is a lot of work, and a shortcut is available in the form of the `Lifestyle.CreateCustom <https://simpleinjector.org/ReferenceLibrary/?topic=html/M_SimpleInjector_Lifestyle_CreateCustom.htm>`_.

A custom lifestyle can be created by calling the **Lifestyle.CreateCustom** factory method. This method takes two arguments: the name of the lifestyle to create (used mainly for display in the :ref:`Diagnostic Services <diagnostics>`) and a `CreateLifestyleApplier <https://simpleinjector.org/ReferenceLibrary/?topic=html/T_SimpleInjector_CreateLifestyleApplier.htm>`_ delegate:

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
            return () => {
                return instanceCreator.Invoke();
            };
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

In this example the **Lifestyle.CreateCustom** method is called and supplied with a delegate that returns a delegate that applies the 10 minute cache. This example makes use of the fact that each registration gets its own delegate by using four closures (timeout, syncRoot, expirationTime and instance). Since each registration (in the example *IService* and *AnotherService*) will get its own *Func<object>* delegate, each registration gets its own set of closures. The closures are static per registration.

One of the closure variables is the *instance* and this will contain the cached instance that will change after 10 minutes has passed. As long as the time hasn't passed, the same instance will be returned.

Since the constructed *Func<object>* delegate can be called from multiple threads, the code needs to do its own synchronization. Both the DateTime comparison and the DateTime assignment are not thread-safe and this code needs to handle this itself.