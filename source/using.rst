=====================
Using Simple Injector
=====================

This section will walk you through the basics of Simple Injector. After reading this section, you will have a good idea how to use Simple Injector.

.. _Using_Simple_Injector:
.. _Using-Simple-Injector:

Good practice is to minimize the dependency between your application and the DI library. This increases the testability and the flexibility of your application, results in cleaner code, and makes it easier to migrate to another DI library if ever required. Minimizing can be achieved by designing the types in your application around the constructor injection pattern: Define all dependencies of a class in the single public constructor of that type; do this for all service types that need to be resolved and resolve only the top most types in the application directly (let the container build up the complete graph of dependent objects for you).

.. _The-Container:

Simple Injector's main type is the `Container <https://simpleinjector.org/ReferenceLibrary/?topic=html/T_SimpleInjector_Container.htm>`_ class. An instance of **Container** is used to register mappings between an abstraction (service) and implementation (component). Your application code should depend on abstractions, and it is the role of the **Container** to supply the application with the right implementation. The easiest way to look at a **Container** is as a big dictionary where the type of the abstraction is used as key, and its value is the definition of how to create the implementation. When the application requests for a service, it is looked up in the dictionary, and the correct implementation is returned.

.. container:: Note

    **Tip**: You should typically create a single Container instance for the whole application (one instance per app domain); Container instances are thread-safe

.. container:: Note

    **Warning**: Registering types in a container instance should be done from one single thread. Although requesting instances from the container is thread-safe, `registration is not <https://simpleinjector.codeplex.com/discussions/349908]>`_.

.. container:: Note

    **Warning**: Do not create an infinite number of Container instances (such as one instance per request). This will drain the performance of your application. The library is optimized for using a limited number of **Container** instances. Creating and initializing a container instance has a lot of overhead, but is extremely fast once initialized.

Creating a new container is done by newing up a new instance and start calling the *RegisterXXX* overloads to register new services:

.. code-block:: c#

    var container = new SimpleInjector.Container();

    // Registrations here
    container.Register<ILogger, FileLogger>();

Ideally, the only place in an application that should directly reference and use Simple Injector is the startup path. For an ASP.NET Web Forms or MVC application this will usually be the **{"Application_OnStart"}** event in the `Global.asax <https://msdn.microsoft.com/en-us/library/1xaas8a2%28VS.71%29.aspx>`_ page of the web application project. For a Windows Forms or console application this will be the **Main** method in the application assembly.

.. container:: Note

    **Tip**: For more information about usage of Simple Injector for a specific technology, please see the [Integration Guide].

The usage of Simple Injector consists of four or five steps:

#. Create a new container
#. Configure the container (register)
#. Optionally verify the container
#. Store the container for use by the application
#. Retrieve instances from the container (resolve)

The first four steps are done once during application startup. The last step is usually performed more than once (usually once per request) for most types of applications. While the first three steps are platform agnostic, performing the last two steps depends on your own taste and which presentation framework you use, but below is an example for the configuration of a ASP.NET MVC application:

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

In the case of MVC, the fifth step is done for us by MVC. When a web requests comes in, MVC will map that request to a controller type and asks the application's **IDependencyResolver** to create an instance of that controller type. The registration of the **SimpleInjectorDependencyResolver** (which is part of the *SimpleInjector.Integration.Web.Mvc.dll*) will ensure that the request for creating an instance is forwarded to Simple Injector. Simple Injector will create that controller with its dependencies.

The example below shows an MVC Controller:

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

.. _Resolving_Instances:
.. _Resolving-Instances:

Resolving instances
===================

Simple Injector allows two scenarios by which you can retrieve instances:

**Getting an object by a specified type**

.. code-block:: c#

    var repository = container.GetInstance<IUserRepository>();

    // Alternatively, you can use the weakly typed version
    var repository = (IUserRepository)container.GetInstance(typeof(IUserRepository));

**Getting a collection of objects by their type**

.. code-block:: c#

    IEnumerable<ICommand> commands = container.GetAllInstances<ICommand>();

    // Alternatively, you can use the weakly typed version
    IEnumerable<object> commands = container.GetAllInstances(typeof(ICommand));

.. _Usage_Configuring_Simple_Injector:
.. _Usage-Configuring-Simple-Injector:

Configuring Simple Injector
===========================

The *Container* class consists of several methods that enable registering instances to be retrieved when requested from the application. These methods enable most common scenarios. Here are the most common scenarios with a code example per scenario:

**Configuring an automatically constructed single instance to be always returned:**

The following example configures that a single instance of type **RealUserService** will always be returned when an instance of **IUserService** is requested. The **RealUserService** will be constructed using :ref:`automatic constructor injection <Automatic_constructor_injection>`.

.. code-block:: c#

    // Configuration
    container.RegisterSingle<IUserService, RealUserService>();

    // Alternatively you can supply a Lifestyle with the same effect.
    container.Register<IUserService, RealUserService>(Lifestyle.Singleton);

    // Usage
    IUserService service = container.GetInstance<IUserService>();

.. container:: Note

    **Note**: instances that are declared as *Single* should be thread-safe in a multi-threaded environment.

**Configuring a single - manually created - instance to be always returned:**

The following example configures a single instance that will always be returned when an instance of that type will be requested.

.. code-block:: c#

    // Configuration
    container.RegisterSingle<IUserRepository>(new SqlUserRepository());

    // Usage
    IUserRepository repository = container.GetInstance<IUserRepository>();

.. container:: Note

    **Note**: Registering types using automatic constructor injection (auto-wiring) is the preferred way of registering types. Only new up instances manually when automatic constructor injection is not possible.

**Configuring a single instance using a delegate:**

The following example configures a single instance using a delegate. The container will ensure that the delegate is not called more than once.

.. code-block:: c#

    // Configuration
    container.RegisterSingle<IUserRepository>(() => UserRepFactory.Create("some constr"));

    // Alternatively you can supply the singleton Lifestyle with the same effect.
    container.Register<IUserRepository>(() => UserRepFactory.Create("some constr"), Lifestyle.Singleton);

    // Usage
    IUserRepository repository = container.GetInstance<IUserRepository>();

.. container:: Note

    **Note**: Registering types using automatic constructor injection (auto-wiring) is the preferred way of registering types. Only new up instances manually when automatic constructor injection is not possible.

**Configuring an automatically constructed new instance to be returned:**

By supplying the service type and the created implementation as generic types, the container can create new instances of the implementation (**MoveCustomerHandler** in this case) by using :ref:`automatic constructor injection <Automatic_constructor_injection>`.

.. code-block:: c#

    // Configuration
    container.Register<IHandler<MoveCustomerCommand>, MoveCustomerHandler>();

    // Alternatively you can supply the transient Lifestyle with the same effect.
    container.Register<IHandler<MoveCustomerCommand>, MoveCustomerHandler>(Lifestyle.Transient);

    // Usage
    var handler = container.GetInstance<IHandler<MoveCustomerCommand>>();

**Configuring a new instance to be returned on each call using a delegate:**

By supplying a delegate, types can be registered that can not be created by using automatic constructor injection. By calling the container inside the delegate, you can let the container do as much as work for you as possible:

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

.. _Configuring_Property_Injection:
.. _Configuring-Property-Injection:

**Configuring property injection on an instance:**

For types that need to be injected, define a single public constructor that holds all dependencies whenever possible. In scenarios where constructor injection is not possible, property injection is your second best pick. The previous example already showed an example of this. The preferred way of doing this however, is by using the *RegisterInitializer* method:

.. code-block:: c#

    // Configuration
    container.Register<IHandler<MoveCustomerCommand>>, MoveCustomerHandler>();
    container.Register<IHandler<ShipOrderCommand>>, ShipOrderHandler>();

    // MoveCustomerCommand and ShipOrderCommand both inherit from HandlerBase
    container.RegisterInitializer<HandlerBase>(handlerToInitialize => {
        handlerToInitialize.ExecuteAsynchronously = true;
    });

    // Usage
    var handler1 = container.GetInstance<IHandler<MoveCustomerCommand>>();
    Assert.IsTrue(handler1.ExecuteAsynchronously);

    var handler2 = container.GetInstance<IHandler<ShipOrderCommand>>();
    Assert.IsTrue(handler2.ExecuteAsynchronously);

The **Action<T>** delegate that is registered using the *RegisterInitializer* method will be called after the container created a new instance that inherits from or implements the given T (or inherits from or implements the given T). In the case of the given example, the **MoveCustomerHandler** inherits from **HandlerBase** and because of this, **Action<HandlerBase>** delegate will get called with the reference to the created instance.

.. container:: Note

    **Note**: The container will not be able to call an initializer delegate on a type that is manually constructed using the *new* operator. Use automatic constructor injection whenever possible.

.. container:: Note

    **Tip**: Multiple initializers can apply to a concrete type and the container will call all initializers that apply to that type. They are guaranteed to run in the same order as they are registered.

.. _Collections:

**Configuring a collection of instances to be returned:**

Simple Injector contains several methods for registration and resolving collections of types. Here are some examples:

.. code-block:: c#

    // Configuration
    // Registering a list of instances that will be created by the container.
    // Supplying a collection of types is the preferred way of registering collections.
    container.RegisterAll<ILogger>(typeof(IMailLogger), typeof(SqlLogger));

    // Register a fixed list (these instances should be thread-safe).
    container.RegisterAll<ILogger>(new MailLogger(), new SqlLogger());

    // Using a collection from another subsystem
    container.RegisterAll<ILogger>(Logger.Providers);

    // Usage
    var loggers = container.GetAllInstances<ILogger>();

.. container:: Note

    **Note**:  When no instances are registered using *RegisterAll*, *Container.GetAllInstances* will always return an empty list.

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
            foreach (var logger in this.loggers)
            {
                logger.Log("Some message");
            }
        }
    }

    // Configuration
    container.RegisterAll<ILogger>(typeof(MailLogger)), typeof(SqlLogger));
    container.RegisterSingle<IService, Service>();

    // Usage
    var service = container.GetInstance<IService>();
    service.DoStuff();

The *RegisterAll* overloads that take a collection of **Type** instances, forward the creation of those types to the container, which means that the same rules apply to them. Take a look at the following configuration:

.. code-block:: c#

    // Configuration
    container.Register<MailLogger>(Lifestyle.Singleton);
    container.Register<ILogger, FileLogger>();

    container.RegisterAll<ILogger>(typeof(MailLogger)), typeof(SqlLogger), typeof(ILogger));

When the registered collection of **ILogger** instance is resolved, the container will resolve each and every one of them using their configuration. When no such registration exists, the type is created with the **Transient** lifestyle (which means, that a new instance is created every time the returned collection is iterated). The **MailLogger** type however, has an explicit registration and since it is registered as **Singleton**, the resolved **ILogger** collections will always have the same instance.

Since the creation is forwarded, also abstract types can be registered using *RegisterAll*. In this case the **ILogger** type itself is registered using *RegisterAll*. This seems like a recursive definition, but it will work nonetheless. In this particular case you could imagine this to be a registration with a default ILogger registration, that is included in the collection of **ILogger** instances as well.

While resolving collections is useful and also works with automatic constructor injection, the registration of composites is preferred over the use of collections as constructor arguments in application code. Register a composite whenever possible, as shown in the example below:

.. code-block:: c#

    // Definition
    public class CompositeLogger : ILogger {
        private readonly ILogger[] loggers;

        public CompositeLogger(params ILogger[] loggers) {
            this.loggers = loggers;
        }

        public void Log(string message) {
            foreach (var logger in this.loggers)
                logger.Log(message);
        }
    }

    // Configuration
    container.RegisterSingle<IService, Service>();
    container.RegisterSingle<ILogger>(() => 
        new CompositeLogger(
            container.GetInstance<MailLogger>(),
            container.GetInstance<SqlLogger>()
        )
    );

    // Usage
    var service = container.GetInstance<IService>();
    service.DoStuff();

When using the approach given above, your services don’t need a dependency on **IEnumerable<ILogger>**, but can simply have a dependency on the **ILogger** interface itself.

.. _Verifying_Container:
.. _Verifying-Container:

Verifying the container's configuration
=======================================

Optionally, you can call the *Verify* method of the *Container*. This method allows a fail-fast mechanism to prevent the application to start when the container is misconfigured. The *Verify* method checks the container's configuration by creating an instance of all registered types.

For more information about creating an application and container configuration that can be succesfully verified, please read the [How To Verify the container’s configuration|How-to#Verifying_Configuration].

.. _Automatic_constructor_injection:
.. _Automatic-Constructor-Injection:

Automatic constructor injection / auto-wiring
=============================================

Simple Injector uses the public constructor of a registered type and looks at the arguments of that constructor. The container will resolve instances for the argument types and invokes the constructor using those instances. This mechanism is called automatic constructor injection or auto-wiring and this is one of the core differences that separates DI containers from doing injection manually. For Simple Injector to be able to use auto-wiring, the following requirements must be met:

# The type is concrete (not abstract, no interface, no generic type definition).
# The type has exactly one public constructor (this may be a default constructor).
# All types of the arguments on that constructor can be resolved by the container.

Simple Injector can create a type even if it hasn’t registered in the container by using constructor injection.

The following code shows an example of the use of automatic constructor injection. The example shows an **IUserRepository** interface with a concrete **SqlUserRepository** implementation and a concrete **UserService** class. The **UserService** class has one public constructor with an **IUserRepository** argument. Because the dependencies of the **UserService** are registered, Simple Injector is able to create a new **UserService** instance.

.. code-block:: c#

    // Definitions
    public interface IUserRepository { }
    public class SqlUserRepository : IUserRepository { }
    public class UserService : IUserService
    {
        public UserService(IUserRepository repository) { }
    }

    // Configuration
    var container = new Container();

    container.RegisterSingle<IUserRepository, SqlUserRepository>();
    container.RegisterSingle<IUserService, UserService>();

    // Usage
    var service = container.GetInstance<IUserService>();

.. container:: Note

    **Note**: Because **UserService** is a concrete type, calling *container.GetInstance<UserService>()* without registering it explicitly will work as well. This can simplify the container’s configuration significantly for more complex scenarios. However, keep in mind that the best practice is to program to an interface, not a concrete type. Prevent using and depending on concrete types whenever possible.

.. _More_information:
.. _More-Information:

More information
================
For more information about Simple Injector please visit the following links: 

* The [Simple Injector and object lifetime management|ObjectLifestyleManagement] page explains how to configure lifestyles such as **transient**, **singleton**, and many others.
* See the [Integration Guide] for more information about how to integrate Simple Injector into your specific application framework.
* For more information about **dependency injection** in general, please visit `this page on Stackoverflow <https://stackoverflow.com/tags/dependency-injection/info>`_.
* If you have any questions about how to use Simple Injector or about **dependency injection** in general, the experts at `Stackoverflow.com <https://stackoverflow.com/questions/ask?tags=simple-injector+%20ioc-container+dependency-injection+.net+c%23>`_ are waiting for you.
* For all other Simple Injector related question and discussions, such as bug reports and feature requests, the `Simple Injector discussion forum <https://simpleinjector.codeplex.com/discussions>`_ will be the place to start.