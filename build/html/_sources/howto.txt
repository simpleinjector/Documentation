======
How To
======

* How to :ref:`Register factory delegates <Register-Factory-Delegates>`
* How to :ref:`Resolve instances by key <Resolve-Instances-By-Key>`
* How to :ref:`Register multiple interfaces with the same implementation <Register-Multiple-Interfaces-With-The-Same-Implementation>`
* How to :ref:`Override existing registrations <Override-Existing-Registrations>`
* How to :ref:`Verify the container's configuration <Verify-Configuration>`
* How to :ref:`Work with dependency injection in multi-threaded applications <Multi-Threaded-Applications>`

.. _Register-Factory-Delegates:

Register factory delegates
==========================

Simple Injector allows you to register a *Func<T>* delegate for the creation of an instance. This is especially useful in scenarios where it is impossible for the *Container* to create the instance. There are overloads of the **Register** method available that accept a  *Func<T>* argument:

.. code-block:: c#

    container.Register<IMyService>(() => SomeSubSystem.CreateMyService());

In situations where a service needs to create multiple instances of a certain component, or needs to explicitly control the lifetime of such component, abstract factories can be used. Instead of injecting an *IMyService*, you should inject an *IMyServiceFactory* that creates new instances of *IMyService*:

.. code-block:: c#

    // Definition
    public interface IMyServiceFactory {
        IMyService CreateNew();
    }

    // Implementation
    sealed class ServiceFactory : IMyServiceFactory {
        public IMyService CreateNew() {
            return new MyServiceImpl();
        }
    }

    // Registration
    container.RegisterSingleton<IMyServiceFactory>(new ServiceFactory());

    // Usage
    public class MyService {
        private readonly IMyServiceFactory factory;
        
        public MyService(IMyServiceFactory factory) {
            this.factory = factory;
        }
        
        public void SomeOperation() {
            using (var service1 = this.factory.CreateNew()) {
                // use service 1
            }

            using (var service2 = this.factory.CreateNew()) {
                // use service 2
            }
        }
    }

Instead of creating specific interfaces for your factories, you can also choose to inject *Func<T>* delegates into your services:

.. code-block:: c#

    // Registration
    container.RegisterSingleton<Func<IMyService>>(() => new MyServiceImpl());

    // Usage
    public class MyService {
        private readonly Func<IMyService> factory;
        
        public MyService(Func<IMyService> factory) {
            this.factory = factory;
        }
        
        public void SomeOperation() {
            using (var service1 = this.factory.Invoke()) {
                // use service 1
            }
        }
    }

This saves you from having to define a new interface and implementation per factory.

.. container:: Note

    **Note**: On the downside however, this communicates less clearly the intent of your code and as a result might make your code harder to grasp.

When you choose *Func<T>* delegates over specific factory interfaces you can define the following extension method to simplify the registration of *Func<T>* factories:

.. code-block:: c#

    // using System;
    // using SimpleInjector;
    // using SimpleInjector.Advanced;
    public static void RegisterFuncFactory<TService, TImpl>(
        this Container container, Lifestyle lifestyle = null)
        where TService : class
        where TImpl : class, TService
    {
        lifestyle = lifestyle ?? Lifestyle.Transient;
        var producer = lifestyle.CreateProducer<TService, TImpl>(container);
        container.RegisterSingleton<Func<TService>>(producer.GetInstance);
    }

    // Registration
    container.RegisterFuncFactory<IMyService, RealService>();

The extension method allows registration of a single factory.

To take this one step further, the following extension method allows Simple Injector to resolve all types using a *Func<T>* delegate by default:

.. code-block:: c#

    // using System;
    // using System.Linq;
    // using System.Linq.Expressions;
    // using SimpleInjector;
    public static void AllowResolvingFuncFactories(this ContainerOptions options) {
        options.Container.ResolveUnregisteredType += (s, e) => {
            var type = e.UnregisteredServiceType;

            if (!type.IsGenericType || type.GetGenericTypeDefinition() != typeof(Func<>)) {
                return;
            }

            Type serviceType = type.GetGenericArguments().First();

            InstanceProducer registration =
                options.Container.GetRegistration(serviceType, true);

            Type funcType = typeof(Func<>).MakeGenericType(serviceType);

            var factoryDelegate = Expression.Lambda(funcType,
                registration.BuildExpression()).Compile();

            e.Register(Expression.Constant(factoryDelegate));
        };
    }

    // Registration
    container.Options.AllowResolvingFuncFactories();

After calling this *AllowResolvingFuncFactories* extension method, the container allows resolving *Func<T>* delegates.

.. container:: Note

    **Note**: We personally think that allowing to register *Func<T>* delegates by default is a design smell. The use of *Func<T>* delegates makes your design harder to follow and your system harder to maintain and test. Your system should only have a few of those factories at most. If you have many constructors in your system that depend on a *Func<T>*, please take a good look at your dependency strategy. If in doubt, please ask us here on the forum or on Stackoverflow.


.. _lazy:

Just like *Func<T>* delegates can be injected, *Lazy<T>* instances can also be injected into services. *Lazy<T>* is useful in situations where the creation of a service is time consuming and not always required. *Lazy<T>* enables you to postpone the creation of a service until the moment it is actually required:

.. code-block:: c#

    // Registration    
    container.Register<Lazy<IMyService>>(
        () => new Lazy<IMyService>(container.GetInstance<IMyService>));

    // Usage
    public class MyService {
        private readonly Lazy<IMyService> myService;
        
        public MyService(Lazy<IMyService> myService) {
            this.myService = myService;
        }
        
        public void SomeOperation() {
            if (someCondition) {
                this.myService.Value.Operate();
            }
        }
    }

.. container:: Note

    **Note**: instead of polluting the API of your application with *Lazy<T>* dependencies, it is usually cleaner to hide the *Lazy<T>* behind a proxy:

.. code-block:: c#

    // Proxy definition
    public class LazyServiceProxy : IMyService {
        private readonly Lazy<IMyService> wrapped;
        
        public LazyServiceProxy(Lazy<IMyService> wrapped) {
            this.wrapped = wrapped;
        }
        
        public void Operate() {
            this.wrapped.Value.Operate();
        }
    }

    // Registration
    container.Register<IMyService>(() => new LazyServiceProxy(
        new Lazy<IMyService>(container.GetInstance<RealService>)));
    
This way the application can simply depend on *IMyService* instead of *Lazy<IMyService>*.

.. container:: Note

    **Warning**: The same warning applies to the use of *Lazy<T>* as it does for the use of *Func<T>* delegates. Further more, the constructors of your components should be simple, reliable and quick, and that would remove the need for lazy initialization. For more information about creating an application and container configuration that can be successfully verified, please read the :ref:`How To Verify the container's configuration <Verify-Configuration>`.

.. _Resolve-Instances-By-Key:

Resolve instances by key
========================

Resolving instances by a key is a feature that is deliberately left out of Simple Injector, because it invariably leads to a design where the application tends to have numerous dependencies on the DI container itself. To resolve a keyed instance you will likely need to call directly into the *Container* instance and this leads to the `Service Locator anti-pattern <http://blog.ploeh.dk/2010/02/03/ServiceLocatorIsAnAntiPattern.aspx>`_.

This doesn't mean that resolving instances by a key is never useful. Resolving instances by a key is normally a job for a specific factory rather than the *Container*. This approach makes the design much cleaner, saves you from having to take numerous dependencies on the DI library and enables many scenarios that the DI container authors simply didn't consider.

.. container:: Note

    **Note**: The need for keyed registration can be an indication of ambiguity in the application design and a sign of a `Liskov Substitution Principle  <https://en.wikipedia.org/wiki/Liskov_substitution_principle>`_ violation. Take a good look if each keyed registration shouldn't have its own unique interface, or perhaps each registration should implement its own version of a generic interface.

Take a look at the following scenario, where we want to retrieve instances of type *IRequestHandler* by a string key. There are of course several ways to achieve this, but here is a simple but effective way, by defining an *IRequestHandlerFactory*:

.. code-block:: c#

    // Definition
    public interface IRequestHandlerFactory
    {
        IRequestHandler CreateNew(string name);
    }

    // Usage
    var factory = container.GetInstance<IRequestHandlerFactory>();
    var handler = factory.CreateNew("customers");
    handler.Handle(requestContext);

By inheriting from the BCL's *Dictionary<TKey, TValue>*, creating an *IRequestHandlerFactory* implementation is almost a one-liner:

.. code-block:: c#

    public class RequestHandlerFactory : Dictionary<string, Func<IRequestHandler>>,
        IRequestHandlerFactory 
    {
        public IRequestHandler CreateNew(string name) {
            return this[name]();
        }
    }

With this class, we can register *Func<IRequestHandler>* factory methods by a key. With this in place the registration of keyed instances is a breeze:

.. code-block:: c#

    var container = new Container();
     
    container.RegisterSingle<IRequestHandlerFactory>(new RequestHandlerFactory
    {
        { "default", () => container.GetInstance<DefaultRequestHandler>() },
        { "orders", () => container.GetInstance<OrdersRequestHandler>() },
        { "customers", () => container.GetInstance<CustomersRequestHandler>() },
    });

.. container:: Note

    **Note**: this design will work with almost all DI containers making the design easy to follow and also making it portable between DI libraries.

If you don't like a design that uses *Func<T>* delegates this way, it can easily be changed to be a *Dictionary<string, Type>* instead. The *RequestHandlerFactory* can be implemented as follows:

.. code-block:: c#

    public class RequestHandlerFactory : Dictionary<string, Type>, IRequestHandlerFactory
    {
        private readonly Container container;
        
        public RequestHandlerFactory(Container container) {
            this.container = container;
        }

        public IRequestHandler CreateNew(string name) {
            return (IRequestHandler)this.container.GetInstance(this[name]);
        }
    }

The registration will then look as follows:

.. code-block:: c#

    var container = new Container();

    container.RegisterSingle<IRequestHandlerFactory>(new RequestHandlerFactory(container)
    {
        { "default", typeof(DefaultRequestHandler) },
        { "orders", typeof(OrdersRequestHandler) },
        { "customers", typeof(CustomersRequestHandler) },
    });

.. container:: Note

    **Note**: Please remember the previous note about ambiguity in the application design. In the given example the design would probably be better of by using a generic *IRequestHandler<TRequest>* interface. This would allow the implementations to be :ref:`batch registered using a single line of code <Batch-Registration>`, saves you from using keys, and results in a configuration the is :ref:`verifiable by the container <Verify-Configuration>`.

A final option for implementing keyed registrations is to manually create the registrations and store them in a dictionary. The following example shows the same *RequestHandlerFactory* using this approach:

.. code-block:: c#

    public class RequestHandlerFactory : IRequestHandlerFactory {
        private readonly Dictionary<string, InstanceProducer> producers =
            new Dictionary<string, InstanceProducer>(
                StringComparer.OrdinalIgnoreCase);

        private readonly Container container;

        public RequestHandlerFactory(Container container) {
            this.container = container;
        }

        IRequestHandler IRequestHandlerFactory.CreateNew(string name) {
            return (IRequestHandler)this.producers[name].GetInstance();
        }

        public void Register<TImplementation>(string name, Lifestyle lifestyle = null)
            where TImplementation : class, IRequestHandler {
            lifestyle = lifestyle ?? Lifestyle.Transient;

            var producer = lifestyle
                .CreateProducer<IRequestHandler, TImplementation>(container);

            this.producers.Add(name, producer);
        }
    }

The registration will then look as follows:

.. code-block:: c#

    var container = new Container();

    var factory = new RequestHandlerFactory(container);

    factory.Register<DefaultRequestHandler>("default");
    factory.Register<OrdersRequestHandler>("orders");
    factory.Register<CustomersRequestHandler>("customers");

    container.RegisterSingle<IRequestHandlerFactory>(factory);

The advantage of this method is that it completely integrates with the *Container*. :ref:`Decorators` can be applied to individual returned instances, types can be registered multiple times and the registered handlers can be analyzed using the :doc:`Diagnostic Services <diagnostics>`.


.. _Register-Multiple-Interfaces-With-The-Same-Implementation:

Register multiple interfaces with the same implementation
=========================================================

To adhere to the `Interface Segregation Principle <http://en.wikipedia.org/wiki/Interface_segregation_principle>`_, it is important to keep interfaces narrow. Although in most situations implementations implement a single interface, it can sometimes be beneficial to have multiple interfaces on a single implementation. Here is an example of how to register this:

.. code-block:: c#

    // Impl implements IInterface1, IInterface2 and IInterface3.
    var registration = Lifestyle.Singleton.CreateRegistration<Impl>(container);

    container.AddRegistration(typeof(IInterface1), registration);
    container.AddRegistration(typeof(IInterface2), registration);
    container.AddRegistration(typeof(IInterface3), registration);

    var a = container.GetInstance<IInterface1>();
    var b = container.GetInstance<IInterface2>();

    // Since Impl is a singleton, both requests return the same instance.
    Assert.AreEqual(a, b);

The first line creates a **Registration** instance for the *Impl*, in this case with a singleton lifestyle. The other lines add this registration to the container, once for each interface. This maps multiple service types to the exact same registration.

.. container:: Note

    **Note:** This is different from having three **RegisterSingleton** registrations, since that will results three separate singletons.

.. _Override-Existing-Registrations:

Override existing registrations
===============================

The default behavior of Simple Injector is to fail when a service is registered for a second time. Most of the time the developer didn't intend to override a previous registration and allowing this would lead to a configuration that would pass the container's verification, but doesn't behave as expected.

:ref:`This design decision <Separate-collections>` differs from most other DI libraries, where adding new registrations results in appending the collection of registrations for that abstraction. Registering collections in Simple Injector is an explicit action done using one of the `RegisterCollection <https://simpleinjector.org/ReferenceLibrary/?topic=html/Overload_SimpleInjector_Container_RegisterCollection.htm>`_ method overloads.

There are certain scenarios however where overriding is useful. An example of such is a bootstrapper project for a business layer that is reused in multiple applications (in both a web application, web service, and Windows service for instance). Not having a business layer specific bootstrapper project would mean the complete DI configuration would be duplicated in the startup path of each application, which would lead to code duplication. In that situation the applications would roughly have the same configuration, with a few adjustments.

Best is to start of by configuring all possible dependencies in the BL bootstrapper and leave out the service registrations where the implementation differs for each application. In other words, the BL bootstrapper would result in an incomplete configuration. After that, each application can finish the configuration by registering the missing dependencies. This way you still don't need to override the existing configuration.

In certain scenarios it can be beneficial to allow an application override an existing configuration. The container can be configured to allow overriding as follows:

.. code-block:: c#

    var container = new Container();

    container.Options.AllowOverridingRegistrations = true;

    // Register IUserService.
    container.Register<IUserService, FakeUserService>();

    // Replaces the previous registration
    container.Register<IUserService, RealUserService>();

The previous example created a *Container* instance that allows overriding. It is also possible to enable overriding half way the registration process:

.. code-block:: c#

    // Create a container with overriding disabled
    var container = new Container();

    // Pass container to the business layer.
    BusinessLayer.Bootstrapper.Bootstrap(container);

    // Enable overriding
    container.Options.AllowOverridingRegistrations = true;

    // Replaces the previous registration
    container.Register<IUserService, RealUserService>();

.. _Verify-Configuration:

Verify the container's configuration
====================================

Dependency Injection promotes the concept of programming against abstractions. This makes your code much easier to test, easier to change and maintain. However, since the code itself isn't responsible for maintaining the dependencies between implementations when using a DI library, the compiler will not be able to verify whether the dependency graph is correct.

When starting to use a Dependency Injection container, many developers see their application fail when it is deployed in staging or sometimes even production, because of container misconfigurations. This makes developers often conclude that dependency injection is bad, since the dependency graph cannot be verified. This conclusion however, is incorrect. First of all, the use of Dependency Injection doesn't require a DI library at all. The pattern is still valid, even without the use of tooling that will wire everything together for you. For some types of applications `Pure DI <http://blog.ploeh.dk/2014/06/10/pure-di/>`_ is even advisable. Second, although it is impossible for the compiler to verify the dependency graph when using a DI library, verifying the dependency graph is still possible and advisable.

Simple Injector contains a **Verify()** method, that will iterate over all registrations and resolve an instance for each registration. Calling this method directly after configuring the container allows the application to fail during start-up if the configuration is invalid.

Calling the **Verify()** method however, is just part of the story. It is very easy to create a configuration that passes any verification, but still fails at runtime. Here are some tips to help building a verifiable configuration:

#. Stay away from :ref:`implicit property injection <Property-Injection>`, where the container is allowed to skip injecting the property if a corresponding or correctly registered dependency can't be found. This will disallow your application to fail fast and will result in *NullReferenceException*'s later on. Only use implicit property injection when the property is truly optional, omitting the dependency still keeps the configuration valid, and the application still runs correctly without that dependency. Truly optional dependencies should be very rare though, since most of the time you should prefer injecting empty implementations (a.k.a. the `Null Object pattern <https://en.wikipedia.org/wiki/Null_Object_pattern>`_) instead of allowing dependencies to be a null reference. :ref:`Explicit property injection <Configuring-Property-Injection>` on the other hand is fine. With explicit property injection you force the container to inject a property and it will fail when it can't succeed. However, you should prefer constructor injection whenever possible. Note that the need for property injection is often an indication of problems in the design. If you revert to property injection because you otherwise have too many constructor arguments, you're probably violating the `Single Responsibility Principle <https://en.wikipedia.org/wiki/Single_responsibility_principle>`.

#. Register all root objects explicitly. For instance, register all ASP.NET MVC Controller instances explicitly in the container (Controller instances are requested directly and are therefore called 'root objects'). This way the container can check the complete dependency graph starting from the root object when you call **Verify()**. Prefer registering all root objects in an automated fashion, for instance by using reflection to find all root types. The `Simple Injector ASP.NET MVC Integration NuGet Package <https://nuget.org/packages/SimpleInjector.Integration.Web.Mvc>`_ for instance, contains a `RegisterMvcControllers <https://simpleinjector.org/ReferenceLibrary/?topic=html/M_SimpleInjector_SimpleInjectorMvcExtensions_RegisterMvcControllers.htm>`_ extension method that will do this for you and the `WCF Integration NuGet Package <https://nuget.org/packages/SimpleInjector.Integration.Wcf>`_ contains a similar `RegisterWcfServices <https://simpleinjector.org/ReferenceLibrary.v2/?topic=html/M_SimpleInjector_SimpleInjectorWcfExtensions_RegisterWcfServices.htm>`_ extension method for this purpose.

#. If any of your root types are generic you should explicitly register each required closed-generic version of the type instead of making a single open-generic registration per generic type. Simple Injector will not be able to guess the closed types that could be resolved (root types are not referenced by other types and there can be endless permutations of closed-generic types) and as such open generic registrations are skipped by Simple Injector's verification system. Making an explicit registration for each closed-generic root type allows Simple Injector to verify and diagnose those registrations.

#. If registering root objects is not possible or feasible, test the creation of each root object manually during start-up. With ASP.NET Web Form Page classes for instance, you will probably call the container (directly or indirectly) from within their constructor (since Page classes must unfortunately have a default constructor). The key here again is finding them all in once using reflection. By finding all Page classes using reflection and instantiating them, you'll find out (during app start-up or through automated testing) whether there is a problem with your DI configuration or not. The :doc:`Web Forms Integration <webformsintegration>` guide contains an example of how to verify page classes.

#. There are scenarios where some dependencies cannot yet be created during application start-up. To ensure that the application can be started normally and the rest of the DI configuration can still be verified, abstract those dependencies behind a proxy or abstract factory. Try to keep those unverifiable dependencies to a minimum and keep good track of them, because you will probably have to test them manually or using an integration test.

#. But even when all registrations can be resolved successfully by the container, that still doesn't mean your configuration is correct. It is very easy to accidentally misconfigure the container in a way that only shows up late in the development process. Simple Injector contains :doc:`Diagnostics Services <diagnostics>` to help you spot common configuration mistakes. With Simple Injector 3, most of the diagnostic warnings are integrated into the verification mechanism. This means that a call to **Verify()** will also check for diagnostic warnings for you. It is advisable to analyze the container by calling **Verify** or by using the diagnostic services either during application startup or as part of an automated test that does this for you.

.. _Multi-Threaded-Applications:

Work with dependency injection in multi-threaded applications
=============================================================

.. container:: Note

    **Note:** Simple Injector is designed for use in highly-concurrent applications and the container is thread-safe. Its lock-free design allows it to scale linearly with the number of threads and processors in your system.

Many applications and application frameworks are inherently multi-threaded. Working in multi-threaded applications forces developers to take special care. It is easy for a less experienced developer to introduce a race condition in the code. Even although some frameworks such as ASP.NET make it easy to write thread-safe code, introducing a simple static field could break thread-safety.

This same holds when working with DI containers in multi-threaded applications. The developer that configures the container should be aware of the risks of shared state. **Not knowing which configured services are thread-safe is a sin.** Registering a service that is not thread-safe as singleton, will eventually lead to concurrency bugs, that usually only appear in production. Those bugs are often hard to reproduce and hard to find, making them costly to fix. And even when you correctly configured a service with the correct lifestyle, when another component that depends on it accidentally as a longer lifetime, the service might be kept alive much longer and might even be accessible from other threads.

Dependency injection however, can actually help in writing multi-threaded applications. Dependency injection forces you to wire all dependencies together in a single place in the application: the `Composition Root <http://blog.ploeh.dk/2011/07/28/CompositionRoot/>`_. This means that there is a single place in the application that knows about how services behave, whether they are thread-safe, and how they should be wired. Without this centralization, this knowledge would be scattered throughout the code base, making it very hard to change the behavior of a service.

.. container:: Note

    **Tip:** Take a close look at the 'Lifestyle Mismatches' warnings in the :doc:`Diagnostic Services <diagnostics>`. Lifestyle mismatches are a source of concurrency bugs.

.. container:: Note

    **Note:** By default, Simple Injector 3 will check for Lifestyle Mismatches for you when you resolve a service. In other words, Simple Injector will fail fast when there is a Lifestyle Mismatch in your configuration.

In a multi-threaded application, each thread should get its own object graph. This means that you should typically call *container.GetInstance<T>()* once at the beginning of the thread's execution to get the root object for processing that thread (or request). The container will build an object graph with all root object's dependencies. Some of those dependencies will be singletons; shared between all threads. Other dependencies might be transient; a new instance is created per dependency. Other dependencies might be thread-specific, request-specific, or with some other lifestyle. The application code itself is unaware of the way the dependencies are registered and that's the way it is supposed to be.

For web applications, you typically call **GetInstance<T>()** at the beginning of the web request. In an ASP.NET MVC application for instance, one Controller instance will be requested from the container (by the Controller Factory) per web request. When using one of the integration packages, such as the `Simple Injector MVC Integration Quick Start NuGet package <https://nuget.org/packages/SimpleInjector.MVC3>`_ for instance, you don't have to call **GetInstance<T>()** yourself, the package will ensure this is done for you. Still, **GetInstance<T>()** is typically called once per request.

The advice of building a new object graph (calling **GetInstance<T>()**) at the beginning of a thread, also holds when manually starting a new (background) thread. Although you can pass on data to other threads, you should not pass on container controlled dependencies to other threads. On each new thread, you should ask the container again for the dependencies. When you start passing dependencies from one thread to the other, those parts of the code have to know whether it is safe to pass those dependencies on. For instance, are those dependencies thread-safe? This might be trivial to analyze in some situations, but prevents you to change those dependencies with other implementations, since now you have to remember that there is a place in your code where this is happening and you need to know which dependencies are passed on. You are decentralizing this knowledge again, making it harder to reason about the correctness of your DI configuration and making it easier to misconfigure the container in a way that causes concurrency problems.

Running code on a new thread can be done by adding a little bit of infrastructural code. Take for instance the following example where we want to send e-mail messages asynchronously. Instead of letting the caller implement this logic, it is better to hide the logic for asynchronicity behind an abstraction; a proxy. This ensures that this logic is centralized to a single place, and by placing this proxy inside the composition root, we prevent the application code to take a dependency on the container itself (which should be prevented).

.. code-block:: c#

    // Synchronous implementation of IMailSender
    public sealed class RealMailSender : IMailSender {
        private readonly IMailFormatter formatter;
        
        public class RealMailSender(IMailFormatter formatter) {
            this.formatter = formatter;
        }

        void IMailSender.SendMail(string to, string message) {
            // format mail
            // send mail
        }
    }

    // Proxy for executing IMailSender asynchronously.
    sealed class AsyncMailSenderProxy : IMailSender {
        private readonly ILogger logger;
        private readonly Func<IMailSender> mailSenderFactory;

        public AsyncMailSenderProxy(ILogger logger, Func<IMailSender> mailSenderFactory) {
            this.logger = logger;
            this.mailSenderFactory = mailSenderFactory;
        }

        void IMailSender.SendMail(string to, string message) {
            // Run on a new thread
            Task.Factory.StartNew(() => {
                this.SendMailAsync(to, message);
            });        
        }

        private void SendMailAsync(string to, string message) {
            // Here we run on a different thread and the
            // services should be requested on this thread.
            var mailSender = this.mailSenderFactory();

            try {
                mailSender.SendMail(to, message);
            }
            catch (Exception ex) {
                // logging is important, since we run on a
                // different thread.
                this.logger.Log(ex);
            }
        }
    }

In the Composition Root, instead of registering the *MailSender*, we register the *AsyncMailSenderProxy* as follows:

.. code-block:: c#

    container.Register<ILogger, FileLogger>(Lifestyle.Singleton);
    container.Register<IMailSender, RealMailSender>();
    container.RegisterDecorator<IMailSender, AsyncMailSenderProxy>(Lifestyle.Singleton);

In this case the container will ensure that when an *IMailSender* is requested, a single *AsyncMailSenderProxy* is returned with a *Func<IMailSender>* delegate that will create a new *RealMailSender* when requested. The `RegisterDecorator <https://simpleinjector.org/ReferenceLibrary/?topic=html/Overload_SimpleInjector_Extensions_DecoratorExtensions_RegisterDecorator.htm>`_ and `RegisterSingleDecorator <https://simpleinjector.org/ReferenceLibrary/?topic=html/Overload_SimpleInjector_Extensions_DecoratorExtensions_RegisterSingleDecorator.htm>`_ overloads natively understand how to handle *Func<Decoratee>* dependencies. The :ref:`Decorators <Decorators>` section of the :doc:`Advanced Scenarios <advanced>` wiki page explains more about registering decorators.

|
|
|
|
|
|
|
|
|
|
|
|
|
|
|
|
|
|
|
|
|
|
|
|
|
|
|
|
|
|

.. _Resolve-Arrays-And-Lists:

**Resolve arrays and lists**: The information in this section has been moved to :ref:`here <Collections>`.

|
|
|
|
|
|
|
|
|
|