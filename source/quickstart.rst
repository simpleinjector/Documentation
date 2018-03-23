===========
Quick Start
===========

Overview
========

The goal of Simple Injector is to provide .NET application developers with an easy, flexible, and fast `Inversion of Control library <https://martinfowler.com/articles/injection.html>`_ that promotes best practice to steer developers towards the pit of success.

Many of the existing DI libraries have a big complicated legacy API or are new, immature, and lack features often required by large scale development projects. Simple Injector fills this gap by supplying a simple implementation with a carefully selected and complete set of features. File and attribute based configuration methods have been abandoned (they invariably result in brittle and maintenance heavy applications), favoring simple code based configuration instead. This is enough for most applications, requiring only that the configuration be performed at the start of the program. The core library contains many features and allows almost any :doc:`advanced scenario <advanced>`.

The following platforms are supported:

* *.NET 4.0* and up.
* *.NET Standard* including:
  * *Universal Windows Programs*.
  * *Mono*.
  * *.NET Core*.
  * *Xamarin*.

.. container:: Note

    Simple Injector is carefully designed to run in **partial / medium trust**, and it is fast; blazingly fast.

Getting started
===============

The easiest way to get started is by installing  `the available NuGet packages <https://simpleinjector.org/nuget>`_.

A Quick Example
===============

Dependency Injection
--------------------

The general idea behind Simple Injector (or any DI library for that matter) is that you design your application around loosely coupled components using the `Dependency Injection pattern <https://en.wikipedia.org/wiki/Dependency_injection>`_ while adhering to the `Dependency Inversion Principle <https://en.wikipedia.org/wiki/Dependency_inversion_principle>`_. Take for instance the following **CancelOrderHandler** class:

.. code-block:: c#

    public class CancelOrderHandler {
        private readonly IOrderRepository repository;
        private readonly ILogger logger;
        private readonly IEventPublisher publisher;

        // Use constructor injection for the dependencies
        public CancelOrderHandler(
            IOrderRepository repository, ILogger logger, IEventPublisher publisher) {
            this.repository = repository;
            this.logger = logger;
            this.publisher = publisher;
        }

        public void Handle(CancelOrder command) {
            this.logger.Log("Cancelling order " + command.OrderId);
            var order = this.repository.GetById(command.OrderId);
            order.Status = OrderStatus.Cancelled;
            this.repository.Save(order);
            this.publisher.Publish(new OrderCancelled(command.OrderId));
        }
    }
    
    public class SqlOrderRepository : IOrderRepository {
        private readonly ILogger logger;

        // Use constructor injection for the dependencies
        public SqlOrderRepository(ILogger logger) {
            this.logger = logger;
        }
    
        public Order GetById(Guid id) {
            this.logger.Log("Getting Order " + order.Id);
            // Retrieve from db.
        }
        
        public void Save(Order order) {
            this.logger.Log("Saving order " + order.Id);
            // Save to db.
        }        
    }

The *CancelOrderHandler* class depends on the *IOrderRepository*, *ILogger* and *IEventPublisher* interfaces. By not depending on concrete implementations, we can test *CancelOrderHandler* in isolation. But ease of testing is only one of a number of things that Dependency Injection gives us. It also enables us, for example, to design highly flexible systems that can be completely composed in one specific location (often the startup path) of the application.

Introducing Simple Injector
---------------------------

Using Simple Injector, the configuration of the application using the *CancelOrderHandler* and *SqlOrderRepository* classes shown above, might look something like this:

.. code-block:: csharp

    using SimpleInjector;
    
    static class Program
    {
        static readonly Container container;
        
        static Program() {
            // 1. Create a new Simple Injector container
            container = new Container();
            
            // 2. Configure the container (register)
            container.Register<IOrderRepository, SqlOrderRepository>();
            container.Register<ILogger, FileLogger>(Lifestyle.Singleton);
            container.Register<CancelOrderHandler>();
            
            // 3. Verify your configuration
            container.Verify();
        }
        
        static void Main(string[] args) {
            // 4. Use the container
            var handler = container.GetInstance<CancelOrderHandler>();            
            
            var orderId = Guid.Parse(args[0]);
            var command = new CancelOrder { OrderId = orderId };
            
            handler.Handle(command);
        }
    }

The given configuration registers implementations for the *ICancelOrderHandler*, *IOrderRepository* and *ILogger* interfaces. The code snippet shows a few interesting things. First of all, you can map concrete instances (such as *SqlOrderRepository*) to an interface or base type (such as *IOrderRepository*). In the given example, every time you ask the container for an *IOrderRepository*, it will always create a new *SqlOrderRepository* on your behalf (in DI terminology: an object with a **Transient** lifestyle).

The second registration maps the *ILogger* interface to a *FileLogger* implementation. This *FileLogger* is registered with the **Singleton** lifestyle; only one instance of *FileLogger* will ever be created by the **Container**.

Further more, you can map a concrete implementation to itself (as shown with the *CancelOrderHandler*). This registration is a short-hand for the following registration:

.. code-block:: csharp

    container.Register<CancelOrderHandler, CancelOrderHandler>();
    
This basically means, every time you request a *CancelOrderHandler*, you'll get a new *CancelOrderHandler*.

Using this configuration, when a *CancelOrderHandler* is requested, the following object graph is constructed:

.. code-block:: csharp

    new CancelOrderHandler(
        new SqlOrderRepository(
            logger),
        logger);
        
Note that object graphs can become very deep. What you can see is that not only *CancelOrderHandler* contains dependencies, so does *SqlOrderRepository*. In this case *SqlOrderRepository* itself contains an *ILogger* dependency. Simple Injector will not only resolve the dependencies of *CancelOrderHandler* but will instead build a whole tree structure of any level deep for you.

And this is all it takes to start using Simple Injector. Design your classes around the SOLID principles and the Dependency Injection pattern (which is actually the hard part) and configure them during application initialization. Some frameworks (such as ASP.NET MVC) will do the rest for you, other frameworks (like ASP.NET Web Forms) will need a little bit more work. See the :doc:`integration` for examples of integrating with many common frameworks.

.. container:: Note

    Please go to the :doc:`using` section in the documentation to see more examples.

.. _QuickStart-More-Information:

More information
================

For more information about Simple Injector please visit the following links: 

* :doc:`using` will guide you through the Simple Injector basics.
* The :doc:`lifetimes` page explains how to configure lifestyles such as *Transient*, *Singleton*, and many others.
* See the `Reference library <https://simpleinjector.org/ReferenceLibrary/>`_ for the complete API documentation.
* See the :doc:`integration` for more information about how to integrate Simple Injector into your specific application framework.
* For more information about dependency injection in general, please visit `this page on Stackoverflow <https://stackoverflow.com/tags/dependency-injection/info>`_.
* If you have any questions about how to use Simple Injector or about dependency injection in general, the experts at `Stackoverflow.com <https://stackoverflow.com/questions/ask?tags=simple-injector%20ioc-container%20dependency-injection%20.net%20c%23>`_ are waiting for you.
* For all other Simple Injector related question and discussions, such as bug reports and feature requests, the `Simple Injector discussion forum <https://simpleinjector.org/forum>`_ will be the place to start.
* The book `Dependency Injection in .NET <https://manning.com/seemann/>`_ presents core DI patterns in plain C# so you'll fully understand how DI works.

**Happy injecting!**
