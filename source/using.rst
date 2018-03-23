=====================
Using Simple Injector
=====================

This section will walk you through the basics of Simple Injector. After reading this section, you will have a good idea how to use Simple Injector.

Good practice is to minimize the dependency between your application and the DI library. This increases the testability and the flexibility of your application, results in cleaner code, and makes it easier to migrate to another DI library (if ever required). The technique for keeping this dependency to a minimum can be achieved by designing the types in your application around the constructor injection pattern: Define all dependencies of a class in the single public constructor of that type; do this for all service types that need to be resolved and resolve only the top most types in the application directly (i.e. let the container build up the complete graph of dependent objects for you).

Simple Injector's main type is the `Container <https://simpleinjector.org/ReferenceLibrary/?topic=html/T_SimpleInjector_Container.htm>`_ class. An instance of *Container* is used to register mappings between each abstraction (service) and its corresponding implementation (component). Your application code should depend on abstractions and it is the role of the *Container* to supply the application with the right implementation. The easiest way to view the *Container* is as a big dictionary where the type of the abstraction is used as key, and each key's related value is the definition of how to create that particular implementation. Each time the application requests a service, a look up is made within the dictionary and the correct implementation is returned.

.. container:: Note

    **Tip**: You should typically create a single *Container* instance for the whole application (one instance per app domain); *Container* instances are thread-safe.

.. container:: Note

    **Warning**: Registering types in a *Container* instance should be done from one single thread. Requesting instances from the *Container* is thread-safe but registration of types is not.

.. container:: Note

    **Warning**: Do not create an infinite number of *Container* instances (such as one instance per request). Doing so will drain the performance of your application. The library is optimized for using a very limited number of *Container* instances. Creating and initializing *Container* instances has a large overhead, but resolving from the *Container* is extremely fast once initialized.

Creating and configuring a *Container* is done by newing up an instance and calling the **Register** overloads to register each of your services:

.. code-block:: c#

    var container = new SimpleInjector.Container();

    // Registrations here
    container.Register<ILogger, FileLogger>();

Ideally, the only place in an application that should directly reference and use Simple Injector is the startup path. For an ASP.NET Web Forms or MVC application this will usually be the **{"Application_OnStart"}** event in the `Global.asax <https://msdn.microsoft.com/en-us/library/1xaas8a2%28VS.71%29.aspx>`_ page of the web application project. For a Windows Forms or console application this will be the *Main* method in the application assembly.

.. container:: Note

    **Tip**: For more information about usage of Simple Injector for a specific technology, please see the :doc:`integration`.

The usage of Simple Injector consists of four to six steps:

#. Create a new container
#. Configure the container (*Register*)
#. [Optionally] verify the container
#. Store the container for use by the application
#. Retrieve instances from the container (*Resolve*)
#. [Optionally] `Dispose` the container instance when the application ends.

The first four steps are performed only once at application startup. The fifth step is usually performed multiple times (usually once per request) for the majority of applications. The first three steps are platform agnostic but the last three steps depend on a mix of personal preference and which presentation framework is being used. Below is an example for the configuration of an ASP.NET MVC application:

.. code-block:: c#

    using System.Web.Mvc;
    using SimpleInjector;
    using SimpleInjector.Integration.Web.Mvc;

    public class Global : System.Web.HttpApplication {

        protected void Application_Start(object sender, EventArgs e) {
            // 1. Create a new Simple Injector container
            var container = new Container();

            // 2. Configure the container (register)
            // See below for more configuration examples
            container.Register<IUserService, UserService>(Lifestyle.Transient);
            container.Register<IUserRepository, SqlUserRepository>(Lifestyle.Singleton);

            // 3. Optionally verify the container's configuration.
            container.Verify();

            // 4. Store the container for use by the application
            DependencyResolver.SetResolver(
                new SimpleInjectorDependencyResolver(container));
        }
    }

In the case of MVC, the fifth step is the responsibility of the MVC framework. For each received web requests, the MVC framework will map that request to a *Controller* type and ask the application's *IDependencyResolver* to create an instance of that controller type. The registration of the **SimpleInjectorDependencyResolver** (part of the **SimpleInjector.Integration.Web.Mvc.dll**) will ensure that the request for creating an instance is forwarded on to Simple Injector. Simple Injector will create that controller with all of its nested dependencies.

The example below is a very basic MVC Controller:

.. code-block:: c#

    using System;
    using System.Web.Mvc;

    public class UserController : Controller {
        private readonly IUserRepository repository;
        private readonly ILogger logger;

        public UserController(IUserRepository repository, ILogger logger) {
            this.repository = repository;
            this.logger = logger;
        }

        [HttpGet]
        public ActionResult Index(Guid id) {
            this.logger.Log("Index called.");
            User user = this.repository.GetById(id);
            return this.View(user);
        }
    }

.. _Resolving-Instances:

Resolving instances
===================

Simple Injector supports two scenarios for retrieving component instances:

1. **Getting an object by a specified type**

.. code-block:: c#

    var repository = container.GetInstance<IUserRepository>();

    // Alternatively, you can use the weakly typed version
    var repository = (IUserRepository)container.GetInstance(typeof(IUserRepository));

2. **Getting a collection of objects by their type**

.. code-block:: c#

    IEnumerable<ICommand> commands = container.GetAllInstances<ICommand>();

    // Alternatively, you can use the weakly typed version
    IEnumerable<object> commands = container.GetAllInstances(typeof(ICommand));

.. _Usage-Configuring-Simple-Injector:

Configuring Simple Injector
===========================

The *Container* class consists of several methods that enable registering instances for retrieval when requested by the application. These methods enable most common scenarios. Here are many of these common scenarios with a code example for each:

**Configuring an automatically constructed single instance (Singleton) to always be returned:**

The following example configures a single instance of type *RealUserService* to always be returned when an instance of *IUserService* is requested. The *RealUserService* will be constructed using :ref:`automatic constructor injection <Automatic-constructor-injection>`.

.. code-block:: c#

    // Configuration
    container.Register<IUserService, RealUserService>(Lifestyle.Singleton);

    // Usage
    IUserService service = container.GetInstance<IUserService>();

.. container:: Note

    **Note**: instances that are declared as *Singleton* should be thread-safe in a multi-threaded environment.

**Configuring a single - manually created - instance (Singleton) to always be returned:**

The following example configures a single instance of a manually created object `SqlUserRepository` to always be returned when a type of `IUserRepository` is requested.

.. code-block:: c#

    // Configuration
    container.RegisterInstance<IUserRepository>(new SqlUserRepository());

    // Usage
    IUserRepository repository = container.GetInstance<IUserRepository>();

.. container:: Note

    **Note**: Registering types using :ref:`automatic constructor injection <Automatic-constructor-injection>` (auto-wiring) is the preferred method of registering types. Only new up instances manually when automatic constructor injection is not possible.

**Configuring a single instance using a delegate:**

This example configures a single instance as a delegate. The *Container* will ensure that the delegate is only called once.

.. code-block:: c#

    // Configuration
    container.Register<IUserRepository>(() => new SqlUserRepository("some constr"),
        Lifestyle.Singleton);

    // Usage
    IUserRepository repository = container.GetInstance<IUserRepository>();

.. container:: Note

    **Note**: Registering types using :ref:`automatic constructor injection <Automatic-constructor-injection>` (auto-wiring) is the recommended method of registering types. Only new up instances manually when automatic constructor injection is not possible.

**Configuring an automatically constructed new instance to be returned:**

By supplying the service type and the created implementation as generic types, the container can create new instances of the implementation (*MoveCustomerHandler* in this case) by :ref:`automatic constructor injection <Automatic-constructor-injection>`.

.. code-block:: c#

    // Configuration
    container.Register<IHandler<MoveCustomerCommand>, MoveCustomerHandler>();

    // Alternatively you can supply the transient Lifestyle with the same effect.
    container.Register<IHandler<MoveCustomerCommand>, MoveCustomerHandler>(
        Lifestyle.Transient);

    // Usage
    var handler = container.GetInstance<IHandler<MoveCustomerCommand>>();

**Configuring a new instance to be returned on each call using a delegate:**

By supplying a delegate, types can be registered that cannot be created by using :ref:`automatic constructor injection <Automatic-constructor-injection>`.


.. container:: Note

    By referencing the *Container* instance within the delegate, the *Container* can still manage as much of the object creation work as possible:

.. code-block:: c#

    // Configuration
    container.Register<IHandler<MoveCustomerCommand>>(() => {
        // Get a new instance of the concrete MoveCustomerHandler class:
        var handler = container.GetInstance<MoveCustomerHandler>();

        // Configure the handler:
        handler.ExecuteAsynchronously = true;

        return handler;
    });

    container.Register<IHandler<MoveCustomerCommand>>(() => { ... }, Lifestyle.Transient);
    // Alternatively you can supply the transient Lifestyle with the same effect.
    // Usage
    var handler = container.GetInstance<IHandler<MoveCustomerCommand>>();

.. _Configuring-Property-Injection:
.. _Initializing-Auto-Wired-Instances:

**Initializing auto-wired instances:**

For types that need to be injected we recommend that you define a single public constructor that contains all dependencies. In scenarios where its impossible to fully configure a type using constructor injection, the *RegisterInitializer* method can be used to add additional initialization for such type. The previous example showed an example of property injection but a more preferred approach is to use the **RegisterInitializer** method:

.. code-block:: c#

    // Configuration
    container.Register<IHandler<MoveCustomerCommand>>, MoveCustomerHandler>();
    container.Register<IHandler<ShipOrderCommand>>, ShipOrderHandler>();

    // IHandler<T> implements IHandler
    container.RegisterInitializer<IHandler>(handlerToInitialize => {
        handlerToInitialize.ExecuteAsynchronously = true;
    });

    // Usage
    var handler1 = container.GetInstance<IHandler<MoveCustomerCommand>>();
    Assert.IsTrue(handler1.ExecuteAsynchronously);

    var handler2 = container.GetInstance<IHandler<ShipOrderCommand>>();
    Assert.IsTrue(handler2.ExecuteAsynchronously);

The *Action<T>* delegate that is registered by the **RegisterInitializer** method is called once the *Container* has created a new instance of `T` (or any instance that inherits from or implements `T` depending on exactly how you have configured your registrations). In the example *MoveCustomerHandler* implements *IHandler* and because of this the *Action<IHandler>* delegate will be called with a reference to the newly created instance.

.. container:: Note

    **Note**: The *Container* will not be able to call an initializer delegate on a type that is manually constructed using the *new* operator. Use :ref:`automatic constructor injection <Automatic-constructor-injection>` whenever possible.

.. container:: Note

    **Tip**: Multiple initializers can be applied to a concrete type and the *Container* will call all initializers that apply. They are **guaranteed** to run in the same order that they are registered.

.. _Automatic-Batch-registration:

Automatic/Batch-registration
----------------------------

When an application starts to grow, so does the number of types to register in the container. This can cause a lot of maintenance on part of your application that holds your container registration. When working with a team, you'll start to experience many merge conflicts which increases the chance of errors.

To minimize these problems, Simple Injector allows groups of types to be registered with a few lines of code. Especially when registering a family of types that are defined using the same (generic) interface. For instance, the previous example with the  *IHandler<T>* registrations can be reduced to the following code:

.. code-block:: c#

    // Configuration
    Assembly[] assemblies = // determine list of assemblies to search in
    container.Register(typeof(IHandler<>), assemblies);

When supplying a list of assemblies to the **Register** method, Simple Injector will go through the assemblies and will register all types that implement the given interface. In this example, an open-generic type (*IHandler<T>*) is supplied. Simple Injector will automatically find all implementations of this interface.

.. container:: Note

    **Note**: For more information about batch registration, please see the :ref:`Batch-registration <batch-registration>` section.

.. _Collections:

Collections
===========

Simple Injector contains several methods for registering and resolving collections of types. Here are some examples:

.. code-block:: c#

    // Configuration
    // Registering a list of instances that will be created by the container.
    // Supplying a collection of types is the preferred way of registering collections.
    container.RegisterCollection<ILogger>(new[] { typeof(MailLogger), typeof(SqlLogger) });

    // Register a fixed list (these instances should be thread-safe).
    container.RegisterCollection<ILogger>(new[] { new MailLogger(), new SqlLogger() });

    // Using a collection from another subsystem
    container.RegisterCollection<ILogger>(Logger.Providers);

    // Usage
    var loggers = container.GetAllInstances<ILogger>();

.. container:: Note

    **Note**:  When zero instances are registered using **RegisterCollection**, each call to **Container.GetAllInstances** will return an empty list.

.. container:: Note

    **Warning**:  Simple Injector requires a call to **RegisterCollection** to be made, even in the absence of any instances. Without a call to **RegisterCollection**, Simple Injector will throw an exception.


Just as with normal types, Simple Injector can inject collections of instances into constructors:

.. code-block:: c#

    // Definition
    public class Service : IService {
        private readonly IEnumerable<ILogger> loggers;

        public Service(IEnumerable<ILogger> loggers) {
            this.loggers = loggers;
        }

        void IService.DoStuff() {
            // Log to all loggers
            foreach (var logger in this.loggers) {
                logger.Log("Some message");
            }
        }
    }

    // Configuration
    container.RegisterCollection<ILogger>(new[] { typeof(MailLogger), typeof(SqlLogger) });
    container.Register<IService, Service>(Lifestyle.Singleton);

    // Usage
    var service = container.GetInstance<IService>();
    service.DoStuff();

The **RegisterCollection** overloads that take a collection of *Type* instances rely on the *Container* to create an instance of each type just as it would for individual registrations. This means that the same rules we have seen above apply to each item in the collection. Take a look at the following configuration:

.. code-block:: c#

    // Configuration
    container.Register<MailLogger>(Lifestyle.Singleton);
    container.Register<ILogger, FileLogger>();

    container.RegisterCollection<ILogger>(new[] {
        typeof(MailLogger), 
        typeof(SqlLogger), 
        typeof(ILogger)
    });

When the registered collection of *ILogger* instances are resolved, the *Container* will resolve each of them applying the specific rules of their configuration. When no registration exists, the type is created with the default **Transient** lifestyle (*transient* means that a new instance is created every time the returned collection is iterated). In the example, the *MailLogger* type is registered as **Singleton**, and so each resolved *ILogger* collection will always have the same instance of *MailLogger* in their collection.

Since the creation is forwarded, abstract types can also be registered using **RegisterCollection**. In the above example the *ILogger* type itself is registered using **RegisterCollection**. This seems like a recursive definition, but it will work nonetheless. In this particular case you could imagine this to be a registration with a default ILogger registration which is also included in the collection of *ILogger* instances as well. A more usual scenario however is the use of a composite as shown next.

While resolving collections is useful and also works with :ref:`automatic constructor injection <Automatic-constructor-injection>`, the registration of *Composites* is preferred over the use of collections as constructor arguments in application code. Register a composite whenever possible, as shown in the example below:

.. code-block:: c#

    // Definition
    public class CompositeLogger : ILogger {
        private readonly IEnumerable<ILogger> loggers;

        public CompositeLogger(IEnumerable<ILogger> loggers) {
            this.loggers = loggers;
        }

        public void Log(string message) {
            foreach (var logger in this.loggers) {
                logger.Log(message);
            }
        }
    }

    // Configuration
    container.Register<IService, Service>(Lifestyle.Singleton);
    container.Register<ILogger, CompositeLogger>(Lifestyle.Singleton);
    container.RegisterCollection<ILogger>(new[] { typeof(MailLogger), typeof(SqlLogger) });

    // Usage
    var service = container.GetInstance<IService>();
    service.DoStuff();

When using this approach none of your services (except *CompositeLogger*) need a dependency on *IEnumerable<ILogger>* - they can all simply have a dependency on the *ILogger* interface itself.

.. _Collection-types:

Collection types
----------------

Besides *IEnumerable<ILogger>*, Simple Injector natively supports some other collection types as well. The following types are supported:

 - *IEnumerable<T>*
 - *ICollection<T>*
 - *IList<T>*
 - *IReadOnlyCollection<T>*
 - *IReadOnlyList<T>*
 - *T[]* (array)

.. container:: Note

    **Note:** The *IReadOnlyCollection<T>* and *IReadOnlyList<T>* interfaces are new in .NET 4.5. Only the .NET 4.5 and .NET Standard (including .NET Core and Xamarin) builds of Simple Injector will be able to automatically inject these abstractions into your components. These interfaces are *not* supported by the .NET 4.0 version of Simple Injector.

Simple Injector preserves the lifestyle of instances that are returned from an injected *IEnumerable<T>*, *ICollection<T>*, *IList<T>*, *IReadOnlyCollection<T>* and *IReadOnlyList<T>* instance. In reality you should not see the the injected *IEnumerable<T>* as a collection of instances; you should consider it a **stream** of instances. Simple Injector will always inject a reference to the same stream (the *IEnumerable<T>* or *ICollection<T>* itself is a singleton) and each time you iterate the *IEnumerable<T>*, for each individual component, the container is asked to resolve the instance based on the lifestyle of that component.

.. container:: Note

    **Warning**: In contrast to the collection abstractions, an **array** is registered as **transient**. An array is a mutable type; a consumer can change the contents of an array. Sharing the array (by making it singleton) might cause unrelated parts of your applications to fail because of changes to the array. Since an array is a concrete type, it can not function as a stream, causing the elements in the array to get the lifetime of the consuming component. This could cause :doc:`lifestyle mismatches <LifestyleMismatches>` when the array wasn't registered as transient.

.. _Batch-registering-collections:

Batch-registering collections
-----------------------------

Just as with one-to-one mappings, Simple Injector allows collections of types to be batch-registered. There are overloads of the **RegisterCollection** method that accept a list of *Assembly* instances. Simple Injector will go through those assemblies to look for implementations of the supplied type:

.. code-block:: c#

    Assembly[] assemblies = // determine list of assemblies to search in
    container.RegisterCollection(typeof(ILogger), assemblies);

The previous code snippet will register all *ILogger* implementations that can be found in the supplied assemblies as part of the collection.

.. container:: Note

    **Warning**: This **RegisterCollection** overload will request all the types from the supplied *Assembly* instances. The CLR however does not give *any* guarantees what so ever about the order in which these types are returned. Don't be surprised if the order of these types in the collection change after a recompile or an application restart.

.. container:: Note

    **Note**: For more information about batch registration, please see the :ref:`Batch-registration <batch-registration>` section.

.. _Appending-to-collections:

Adding registrations to an existing collection
----------------------------------------------

In most cases you would register a collection with a single line of code. There are cases where you need to append registrations to an already registered collection. Common use cases for this are integration scenarios where you need to interact with some DI Containers that made its own registrations on your behalf, or in cases where you want to add extra types based on configuration settings. In these cases it might be benifecial to append registrations to an existing collection.

To be able to do this, Simple Injector contains the **Collections.AppendTo** method.

.. code-block:: c#

    Assembly[] assemblies = // determine list of assemblies to search in
    container.RegisterCollection(typeof(ILogger), assemblies);

    container.Collections.AppendTo(typeof(ILogger), typeof(ExtraLogger));


.. _Verifying-Container:

Verifying the container's configuration
=======================================

You can call the *Verify* method of the *Container*. The *Verify* method provides a fail-fast mechanism to prevent your application from starting when the *Container* has been accidentally misconfigured. The *Verify* method checks the entire configuration by creating an instance of each registered type.

.. container:: Note

    **Tip**: Calling **Verify** is not required, but is *highly encouraged*.


For more information about creating an application and container configuration that can be successfully verified, please read the :ref:`How To Verify the container's configuration <Verify-Configuration>`.

.. _Automatic-Constructor-Injection:

Automatic constructor injection / auto-wiring
=============================================

Simple Injector uses the public constructor of a registered type and analyzes each constructor argument. The *Container* will resolve an instance for each argument type and then invoke the constructor using those instances. This mechanism is called *Automatic Constructor Injection* or *auto-wiring* and is one of the fundamental features that separates a DI Container from applying DI by hand. 

Simple Injector has the following prerequisites to be able to provide auto-wiring:

#. Each type to be created must be concrete (not abstract, an interface or an open generic type). Types may be internal, although this can be limited if you're running in a sandbox (e.g. Silverlight or Windows Phone).
#. The type *should* have one public constructor (this may be a default constructor).
#. All the types of the arguments in that constructor must be resolvable by the *Container*; optional arguments are not supported.

Simple Injector can create a concrete type even if it hasn't been registered explicitly in the container by using constructor injection.

The following code shows an example of the use of automatic constructor injection. The example shows an *IUserRepository* interface with a concrete *SqlUserRepository* implementation and a concrete *UserService* class. The *UserService* class has one public constructor with an *IUserRepository* argument. Because the dependencies of the *UserService* are registered, Simple Injector is able to create a new *UserService* instance.

.. code-block:: c#

    // Definitions
    public interface IUserRepository { }
    public class SqlUserRepository : IUserRepository { }
    public class UserService : IUserService {
        private readonly IUserRepository repository;
        public UserService(IUserRepository repository) { 
            this.repository = repository;
        }
    }

    // Configuration
    var container = new Container();

    container.Register<IUserRepository, SqlUserRepository>(Lifestyle.Singleton);
    container.Register<IUserService, UserService>(Lifestyle.Singleton);

    // Usage
    var service = container.GetInstance<IUserService>();

.. container:: Note

    **Note**: Because *UserService* is a concrete type, calling *container.GetInstance<UserService>()* without registering it explicitly will work. This feature can simplify the *Container*'s configuration for some scenarios. Always keep in mind that best practice is to program to an interface not a concrete type. Prevent using and depending on concrete types as much possible.

.. container:: Note

    **Warning**: Even though registration of concrete types is not required, it is adviced to register all root types explicitly. For instance, register all ASP.NET MVC Controller instances explicitly in the container (Controller instances are requested directly and are therefore called 'root objects'). This way the container can check the complete dependency graph starting from the root object when you call **Verify()**.

.. _More-Information:

More information
================
For more information about Simple Injector please visit the following links: 

* The :doc:`lifetimes` page explains how to configure lifestyles such as **transient**, **singleton**, and many others.
* See the :doc:`integration` for more information about how to integrate Simple Injector into your specific application framework.
* For more information about dependency injection in general, please visit `this page on Stackoverflow <https://stackoverflow.com/tags/dependency-injection/info>`_.
* If you have any questions about how to use Simple Injector or about dependency injection in general, the experts at `Stackoverflow.com <https://stackoverflow.com/questions/ask?tags=simple-injector%20ioc-container%20dependency-injection%20.net%20c%23>`_ are waiting for you.
* For all other Simple Injector related question and discussions, such as bug reports and feature requests, the `Simple Injector discussion forum <https://simpleinjector.org/forum>`_ will be the place to start.
