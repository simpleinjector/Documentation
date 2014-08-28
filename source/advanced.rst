==================
Advanced Scenarios
==================

Although its name may not imply it, *Simple Injector* is capable of handling many advanced scenarios. Either through writing custom code, copying  code from this wiki, or via the extension points that can be found in the *SimpleInjector.Extensions* namespace of the core library.

.. container:: Note

    **Note**: this documentation is specific for *Simple Injector version 2.0* and up. Look `here <https://simpleinjector.codeplex.com/wikipage?title=Advanced-scenarios&version=48>`_ for 1.x specific documentation.

.. container:: Note

    **Note**: After including the *SimpleInjector.dll* to your project, you will have to add the *SimpleInjector.Extensions* namespace to your code to be able to use the majority of features that are presented in this wiki page.

.. _Generics:

Generics
========

.NET has superior support for generic programming and Simple Injector has been designed to make full use of it. Simple Injector arguably has the most advanced support for generics of all DI libraries. Simple Injector can handle any generic type and implementing patterns such as decorator, mediator, strategy and chain of responsibility is simple.

Aspect Oriented Programming is easy with Simple Injector's advanced support for generics. Generic decorators with generic type constraints can be registered with a single line of code and can be applied conditionally using predicates. Simple Injector can handle open generic types, closed generic types and partially-closed generic types. The sections below provides more detail on Simple Injector's support for generic typing:

* :ref:`Batch registration of non-generic types based on an open-generic interface<Batch-Registration>`
* :ref:`Registering open generic types and working with partially-closed types <Registration-Of-Open-Generic-Types>`
* :ref:`Registration of generic decorators <Decorators>`
* :ref:`Resolving Covariant/Contravariant types <Covariance-Contravariance>`

.. _Batch_Registration:
.. _Batch-Registration:

Batch / Automatic registration
==============================

Batch or automatic registration is a way of registering a set of related types in one go based on some convention. This features removes the need to constantly update the containers configuration each and every time a new type is added. The following example show a series of manually registered repositories: 

.. code-block:: c#

    container.Register<IUserRepository, SqlUserRepository>();
    container.Register<ICustomerRepository, SqlCustomerRepository>();
    container.Register<IOrderRepository, SqlOrderRepository>();
    container.Register<IProductRepository, SqlProductRepository>();
    // and the list goes on...

To prevent having to change the container for each new repository we can use the non-generic registration overloads in combination with a simple LINQ query:

.. code-block:: c#

    var repositoryAssembly = typeof(SqlUserRepository).Assembly;

    var registrations =
        from type in repositoryAssembly.GetExportedTypes()
        where type.Namespace == "MyComp.MyProd.BL.SqlRepositories"
        where type.GetInterfaces().Any()
        select new
        {
            Service = type.GetInterfaces().Single(),
            Implementation = type
        };

    foreach (var reg in registrations)
    {
        container.Register(reg.Service, reg.Implementation, Lifestyle.Transient);
    }

Although many other DI libraries contain an advanced API for doing convention based registration, we found that doing this with custom LINQ queries is easier to write, more understandable, and can often prove to be more flexible than using a predefined and restrictive API.

Another interesting scenario is registering multiple implementations of a generic interface. Say for instance your application contains the following interface:

.. code-block:: c#

    public interface IValidator<T>
    {
        ValidationResults Validate(T instance);
    }

Your application might contain many implementations of this interface for validating Customers, Employees, Products, Orders, etc. Without batch registration you would probably end up with a set registration similar to those we've already seen:

.. code-block:: c#

    container.Register<IValidator<Customer>, CustomerValidator>();
    container.Register<IValidator<Employee>, EmployeeValidator>();
    container.Register<IValidator<Order>, OrderValidator>();
    container.Register<IValidator<Product>, ProductValidator>();
    // and the list goes on...

By using the extension methods for batch registration of open generic types from the **SimpleInjector.Extensions** namespace the same registrations can be made in a single line of code:

.. code-block:: c#

    container.RegisterManyForOpenGeneric(typeof(IValidator<>),
        typeof(IValidator<>).Assembly);

By default *RegisterManyForOpenGeneric* searches the supplied assembly for all public types that implement the **IValidator<T>** interface and registers each type by their specific (closed generic) interface. It even works for types that implement multiple closed versions of the given interface.

.. container:: Note

    **Note**: There are numerous *RegisterManyForOpenGeneric* `overloads <https://simpleinjector.org/ReferenceLibrary/?topic=html/Overload_SimpleInjector_Extensions_OpenGenericBatchRegistrationExtensions_RegisterManyForOpenGeneric.htm>`_ available that take a list of *System.Type*'s, instead a list of *Assembly*'s.

Above are a couple of examples of the things you can do with batch registration. A more advanced scenario could be the registration of multiple implementations of the same closed generic type to a common interface, i.e. a set of types that all implement the same interface. There are so many possible variations of this scenario that *Simple Injector* does not contain an explicit method to handle this. What it does contain, however, are multiple overloads of the *RegisterManyForOpenGeneric* method that allow you to supply a callback delegate that enables you make the registrations yourself. 

As an example, imagine the scenario where you have a **CustomerValidator** type and a **GoldCustomerValidator** type and they both implement **IValidator<Customer>** and you want to register them both at the same time. The earlier registration methods would throw an exception alerting you to the fact that you have multiple types implementing the same closed generic type. The following registration however, does enable this scenario:

.. code-block:: c#

    container.RegisterManyForOpenGeneric(typeof(IValidator<>),
        AccessibilityOption.PublicTypesOnly,
        (serviceType, implTypes) => container.RegisterAll(serviceType, implTypes),
        typeof(IValidator<>).Assembly);

The code snippet registers all types from the given assembly that implement **IValidator<T>**. As we now have multiple implementations the container cannot inject a single instance of **IValidator<T>** and we can no longer call *container.GetInstance<IValidator<T>>()*. Instead instances can be retrieved by having an **IEnumerable<IValidator<T>>** constructor argument or by calling *container.GetAllInstances<IValidator<T>>()*.

It is not generally regarded as best practice to have an **IEnumerable<IValidator<T>>** dependency in multiple class constructors (or accessed from the  container directly). Depending on a set of types complicates your application design and can often be simplified with an alternate configuration. A better way is to have a single composite type that wraps **IEnumerable<IValidator<T>>** and presents it to the consumer as a single instance, in this case a **CompositeValidator<T>**:

.. code-block:: c#

    public class CompositeValidator<T> : IValidator<T> {
        private readonly IEnumerable<IValidator<T>> validators;

        public CompositeValidator(IEnumerable<IValidator<T>> validators) {
            this.validators = validators;
        }

        public ValidationResults Validate(T instance) {
            var allResults = ValidationResults.Valid;

            foreach (var validator in this.validators) {
                var results = validator.Validate(instance);
                allResults = ValidationResults.Join(allResults, results);
            }

            return allResults;
        }
    }

This **CompositeValidator<T>** can be registered as follows:

.. code-block:: c#

    container.RegisterSingleOpenGeneric(typeof(IValidate<>), 
        typeof(CompositeValidator<>));

This registration maps the open generic **IValidator<T>** interface to the open generic **CompositeValidator<T>** implementation. Because the **CompositeValidator<T>** contains an **IEnumerable<IValidator<T>>** dependency, the registered types will be injected into its constructor. This allows you to let the rest of the application simply depend on the **IValidator<T>**, while registering a collection of **IValidator<T>** implementations under the covers.

.. container:: Note

    **Note**: *Simple Injector* preserves the lifestyle of instances that are returned from an injected **IEnumerable<T>** instance. In reality you should not see the the injected **IEnumerable<IValidator<T>>** as a collection of implementations, you should consider it a **stream** of instances. Simple Injector will always inject a reference to the same stream (the **IEnumerable<T>** itself is a *Singleton*) and each time you iterate the **IEnumerable<T>**, for each individual component, the container is asked to resolve the instance based on the lifestyle of that component. Regardless of the fact that the **CompositeValidator<T>** is registered as singleton the validators it wraps will each have their own specific lifestyle.

The next section will explain mapping of open generic types (just like **CompositeValidator<>** seen above).

.. _Registration_Of_Open_Generic_Types:
.. _Registration-Of-Open-Generic-Types:

Registration of open generic types
==================================

When working with generic interfaces, we will often see numerous implementations of that interface being registered:

.. code-block:: c#

    container.Register<IValidate<Customer>, CustomerValidator>();
    container.Register<IValidate<Employee>, EmployeeValidator>();
    container.Register<IValidate<Order>, OrderValidator>();
    container.Register<IValidate<Product>, ProductValidator>();
    // and the list goes on...

As the previous section explained, this can be rewritten to the following one-liner:

.. code-block:: c#

    container.RegisterManyForOpenGeneric(typeof(IValidate<>), 
        typeof(IValidate<>).Assembly);

Sometimes you'll find that many implementations of the given generic interface are no-ops or need the same standard implementation. The **IValidate<T>** is a good example, it is very likely that not all entities will need validation but your solution would like to treat all entities the same and not need to know whether any particular type has validation or not (having to write a specific empty validation for each type would be a horrible task). In a situation such as this we would ideally like to use the registration as described above, and have some way to fallback to some default implementation when no explicit registration exist for a given type. Such a default implementation could look like this:
 
.. code-block:: c#

    // Implementation of the Null Object pattern.
    class NullValidator<T> : IValidate<T> {
        public ValidationResults Validate(T instance) {
            return ValidationResults.Valid;
        }
    }


We could configure the container to use this **NullValidator<T>** for any entity that does not need validation:

.. code-block:: c#

    container.Register<IValidate<OrderLine>, NullValidator<OrderLine>>();
    container.Register<IValidate<Address>, NullValidator<Address>>();
    container.Register<IValidate<UploadImage>, NullValidator<UploadImage>>();
    container.Register<IValidate<Mothership>, NullValidator<Mothership>>();
    // and the list goes on...

This repeated registration is, of course, not very practical. Falling back to such a default implementation is a good example for **unregistered type resolution**. *Simple Injector* contains an event that you can hook into that allows you to fallback to a default implementation. The `RegisterOpenGeneric <https://simpleinjector.org/ReferenceLibrary/?topic=html/Methods_T_SimpleInjector_Extensions_OpenGenericRegistrationExtensions.htm>`_ extension method is defined to handle this registration. The **NullValidator<>** would be registered as follows:

.. code-block:: c#

    // using SimpleInjector.Extensions;
    container.RegisterOpenGeneric(typeof(IValidate<>), typeof(NullValidator<>));

The result of this registration is exactly as you would have expected to see from the individual registrations above. Each request for **IValidate<Department>**, for example, will return a single **NullValidator<Department>** instance each time.

.. container:: Note

    **Note**: Because the use of unregistered type resolution will only get called for types that are not explicitly registered this allows for the default implementation to be overridden with specific implementations. The *RegisterManyForOpenGeneric* method covered above does not use unregistered type resolution, it registers all the concrete types it finds in the given assemblies. Those types will therefore always be returned, giving a very convenient and easy to grasp mix.

There's an advanced version of *RegisterOpenGeneric* overload that allows applying the open generic type conditionally, based on a supplied predicate. Example:

.. code-block:: c#

    container.RegisterOpenGeneric(typeof(IValidator<>), typeof(LeftValidator<>),
        c => c.ServiceType.GetGenericArguments().Single().Namespace.Contains("Left"));

    container.RegisterOpenGeneric(typeof(IValidator<>), typeof(RightValidator<>),
        c => c.ServiceType.GetGenericArguments().Single().Namespace.Contains("Right"));

*Simple Injector* protects you from defining invalid registrations by ensuring that given the registrations do not overlap. Building on the last code snippet, imagine accidentally defining a type in the namespace "MyCompany.LeftRight". In this case both open-generic implementations would apply, but *Simple Injector* will never silently pick one. It will throw an exception instead.

There are some instance where want to have a fallback implementation in the case that no other implementation was applied and this can be achieved by checking the **Handled** property of the predicate's **OpenGenericPredicateContext** object:

.. code-block:: c#

    container.RegisterOpenGeneric(typeof(IRepository<>), typeof(ReadOnlyRepository<>),
        c => typeof(IReadOnlyEntity).IsAssignableFrom(c.ServiceType.GetGenericArguments().Single()));

    container.RegisterOpenGeneric(typeof(IRepository<>), typeof(ReadWriteRepository<>),
        c => !c.Handled);

In the case where the open generic implementation contains generic type constraints *Simple Injector* will automatically apply the type conditionally based on its generic type constraints:

.. code-block:: c#

    class ReadOnlyRepository<T> : IRepository<T> where T : IReadOnlyEntity { }

    container.RegisterOpenGeneric(typeof(IRepository<>), typeof(ReadOnlyRepository<>));
    container.RegisterOpenGeneric(typeof(IRepository<>), typeof(ReadWriteRepository<>),
        c => !c.Handled);

The final option in *Simple Injector* is to supply the *RegisterOpenGeneric* method with a partially-closed generic type:

.. code-block:: c#

    // SomeValidator<List<T>>
    var partiallyClosedType = typeof(SomeValidator<>).MakeGenericType(typeof(List<>));
    container.RegisterOpenGeneric(typeof(IValidator<>), partiallyClosedType);

The type **SomeValidator<List<T>>** is called **partially-closed**, since although its generic type argument has been filled in with a type, it still contains a generic type argument. *Simple Injector* will be able to apply these constraints, just as it handles any other generic type constraints.

.. _Unregistered_Type_Resolution:
.. _Unregistered-Type-Resolution:

Unregistered type resolution
============================

Unregistered type resolution is the ability to get notified by the container when a type that is currently unregistered in the container, is requested for the first time. This gives the user (or extension point) the change of registering that type. *Simple Injector* supports this scenario with the `ResolveUnregisteredType <https://simpleinjector.org/ReferenceLibrary/?topic=html/E_SimpleInjector_Container_ResolveUnregisteredType.htm>`_ event. Unregistered type resolution enables many advanced scenarios. The library itself uses this event for implementing the :ref:`registration of open generic types <Registration_Of_Open_Generic_Types>`. Other examples of possible scenarios that can be built on top of this event are :ref:`resolving array and lists <Resolve-Arrays-And-Lists>` and :ref:`covariance and contravariance <Covariance-Contravariance>`. Those scenarios are described here in the advanced scenarios page.

For more information about how to use this event, please take a look at the `ResolveUnregisteredType event documentation <https://simpleinjector.org/ReferenceLibrary/?topic=html/E_SimpleInjector_Container_ResolveUnregisteredType.htm>`_ in the `reference library <https://simpleinjector.org/ReferenceLibrary/>`_.


.. _Context_Based_Injection:
.. _Contextual_Binding:
.. _Context-Based-Injection:

Context based injection
=======================

Context based injection is the ability to inject a particular dependency based on the context it lives in (for change the implementation based on the type it is injected into). This context is often supplied by the container. Some DI libraries contain a feature that allows this, while others don’t. *Simple Injector* does **not** contain such a feature out of the box, but this ability can easily be added by using the [context based injection extension method|ContextDependentExtensions] code snippet.

.. container:: Note

    **Note**: In many cases context based injection is not the best solution, and the design should be reevaluated. In some narrow cases however it can make sense.

The most common scenario is to base the type of the injected dependency on the type of the consumer. Take for instance the following **ILogger** interface with a generic **Logger<T>** class that needs to be injected into several consumers. 

.. code-block:: c#

    public interface ILogger {
        void Log(string message);
    }

    public class Logger<T> : ILogger {
        public void Log(string message) { }
    }

    public class Consumer1 {
        public Consumer1(ILogger logger) { }
    }

    public class Consumer2 {
        public Consumer2(ILogger logger) { }
    }

In this case we want to inject a **Logger<Consumer1>** into **Consumer1** and a **Logger<Consumer2>** into **Consumer2**. By using the previous [extension method|ContextDependentExtensions], we can accomplish this as follows:

.. code-block:: c#

    container.RegisterWithContext<ILogger>(dependencyContext => {
        var type = typeof(Logger<>).MakeGenericType(
            dependencyContext.ImplementationType);
        
        return (ILogger)container.GetInstance(type);
    });

In the previous code snippet we registered a **Func<DependencyContext, ILogger>** delegate, that will get called each time a **ILogger** dependency gets resolved. The **DependencyContext** instance that gets supplied to that instance, contains the **ServiceType** and **ImplementationType** into which the **ILogger** is getting injected.

.. container:: Note

    **Note**: Although building a generic type using MakeGenericType is relatively slow, the call to the **Func<DependencyContext, TService>** delegate itself is about as cheap as calling a **Func<TService>** delegate. If performance of the MakeGenericType gets a problem, you can always cache the generated types, cache **InstanceProducer** instances, or cache **ILogger** instances (note that caching the **ILogger** instances will make them singletons).

.. container:: Note

    **Note**: Even though the use of a generic **Logger<T>** is a common design (with log4net as the grand godfather of this design), doesn't always make it a good design. The need for having the logger contain information about its parent type, might indicate design problems. If you're doing this, please take a look at `this Stackoverflow answer <https://stackoverflow.com/a/9915056/264697>`_. It talks about logging in conjunction with the SOLID design principles.

.. _Decorators:
.. _Generic_Decorators:

Decorators
==========

The `SOLID <https://en.wikipedia.org/wiki/SOLID>`_ principles give us important guidance when it comes to writing maintainable software. The 'O' of the 'SOLID' acronym stands for the `Open/closed Principle <https://en.wikipedia.org/wiki/Open/closed_principle>`_ which states that classes should be open for extension, but closed for modification. Designing systems around the Open/closed principle means that new behavior can be plugged into the system, without the need to change any existing parts, making the change of breaking existing code much smaller.


One of the ways to add new functionality (such as `cross-cutting concerns <https://en.wikipedia.org/wiki/Cross-cutting_concern>`_) to classes is by the use of the `decorator pattern <https://en.wikipedia.org/wiki/Decorator_pattern>`_. The decorator pattern can be used to extend (decorate) the functionality of a certain object at run-time. Especially when using generic interfaces, the concept of decorators gets really powerful. Take for instance the examples given in the :ref:`Registration of open generic types <Registration_Of_Open_Generic_Types>` section of this page or for instance the use of an generic **ICommandHandler<TCommand>** interface.

.. container:: Note

    **Tip**: `This article <https://cuttingedge.it/blogs/steven/pivot/entry.php?id=91>`_ describes an architecture based on the use of the **ICommandHandler<TCommand>** interface.

Take the plausible scenario where we want to validate all commands that get executed by an **ICommandHandler<TCommand>** implementation. The Open/Closed principle states that we want to do this, without having to alter each and every implementation. We can do this using a (single) decorator:

.. code-block:: c#

    public class ValidationCommandHandlerDecorator<TCommand> : ICommandHandler<TCommand> {
        private readonly IValidator validator;
        private readonly ICommandHandler<TCommand> handler;

        public ValidationCommandHandlerDecorator(IValidator validator, 
            ICommandHandler<TCommand> handler) {
            this.validator = validator;
            this.handler = handler;
        }

        void ICommandHandler<TCommand>.Handle(TCommand command) {
            // validate the supplied command (throws when invalid).
            this.validator.ValidateObject(command);
            
            // forward the (valid) command to the real
            // command handler.
            this.handler.Handle(command);
        }
    }

The **ValidationCommandHandlerDecorator<TCommand>** class is an implementation of the **ICommandHandler<TCommand>** interface, but it also wraps / decorates an **ICommandHandler<TCommand>** instance. Instead of injecting the real implementation directly into a consumer, we can (let Simple Injector) inject a validator decorator that wraps the real implementation.

The **ValidationCommandHandlerDecorator<TCommand>** depends on an **IValidator** interface. An implementation that used Microsoft Data Annotations might look like this:

.. code-block:: c#

    using System.ComponentModel.DataAnnotations;

    public class DataAnnotationsValidator : IValidator {
        
        void IValidator.ValidateObject(object instance) {
            var context = new ValidationContext(instance, null, null);

            // Throws an exception when instance is invalid.
            Validator.ValidateObject(instance, context, validateAllProperties: true);
        }
    }

The implementations of the **ICommandHandler<T>** interface can be registered using the `RegisterManyForOpenGeneric <https://simpleinjector.org/ReferenceLibrary/?topic=html/Overload_SimpleInjector_Extensions_OpenGenericBatchRegistrationExtensions_RegisterManyForOpenGeneric.htm>`_ extension method:

.. code-block:: c#

    container.RegisterManyForOpenGeneric(
        typeof(ICommandHandler<>), 
        typeof(ICommandHandler<>).Assembly);

By using the following extension method, you can wrap the **ValidationCommandHandlerDecorator<TCommand>** around each and every **ICommandHandler<TCommand>** implementation:

.. code-block:: c#

    // using SimpleInjector.Extensions;
    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(ValidationCommandHandlerDecorator<>));

Multiple decorators can be wrapped by calling the `RegisterDecorator <https://simpleinjector.org/ReferenceLibrary/?topic=html/Overload_SimpleInjector_Extensions_DecoratorExtensions_RegisterDecorator.htm>`_ method multiple times, as the following registration shows:

.. code-block:: c#

    container.RegisterManyForOpenGeneric(
        typeof(ICommandHandler<>), 
        typeof(ICommandHandler<>).Assembly);
        
    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(TransactionCommandHandlerDecorator<>));

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(DeadlockRetryCommandHandlerDecorator<>));

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(ValidationCommandHandlerDecorator<>));

The decorators are applied in the order in which they are registered, which means that the first decorator (**TransactionCommandHandlerDecorator<T>** in this case) wraps the real instance, the second decorator (**DeadlockRetryCommandHandlerDecorator<T>** in this case) wraps the first decorator, and so on.

There's an overload of the *RegisterDecorator* available that allows you to supply a predicate to determine whether that decorator should be applied to a specific service type. Using a given context you can determine whether the decorator should be applied. Here is an example:

.. code-block:: c#

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(AccessValidationCommandHandlerDecorator<>),
        context => !context.ImplementationType.Namespace.EndsWith("Admins"));

The given context contains several properties that allows you to analyze whether a decorator should be applied to a given service type, such as the current closed generic service type (using the **ServiceType** property) and the concrete type that will be created (using the **ImplementationType** property). The predicate will (under normal circumstances) be called only once per generic type, so there is no performance penalty for using it.

.. container:: Note

    **Tip**: [This extension method|Runtime-Decorators] allows registering decorators that can be applied based on runtime conditions (such as the role of the current user).

.. _Decorators_With_Func_Factories:
.. _Decorators-with-Func-factories:

Decorators with Func<T> factories
---------------------------------

In certain scenarios, it is needed to postpone building part of the object graph. For instance when a service needs to control the lifetime of a dependency, needs multiple instances, when instances need to be [executed on a different thread|How-to#Multi_Threaded_Applications], or when instances need to be created in a certain [scope|ObjectLifestyleManagement#Scoped] or (security) context.

When building a 'normal' object graph with dependencies, you can easily delay building a part of the graph by letting a service depend on a factory. This allows building that part of the object graph to be postponed until the time the type starts using the factory. When working with decorators however, injecting a factory to postpone the creation of the decorated instance will not work. Take for instance a **AsyncCommandHandlerDecorator<T>** that allows executing a command handler on a different thread. We could let the **AsyncCommandHandlerDecorator<T>** depend on a **CommandHandlerFactory<T>**, and let this factory call back into the container to retrieve a new **ICommandHandler<T>**. Unfortunately this would fail, since requesting an **ICommandHandler<T>** would again wrap this instance with a new **AsyncCommandHandlerDecorator<T>**, and we'd end up recursively creating the same instance and causing a stack overflow.

Since this is a scenario that is really hard to solve without library support, *Simple Injector* allows injecting a **Func<T>** delegate into registered decorators. This delegate functions as a factory for the creation of the decorated instance. Taking the **AsyncCommandHandlerDecorator<T>** as example, it could be implemented as follows:

.. code-block:: c#

    public class AsyncCommandHandlerDecorator<T> : ICommandHandler<T> {
        private readonly Func<ICommandHandler<T>> factory;

        public AsyncCommandHandlerDecorator(Func<ICommandHandler<T>> factory) {
            this.factory = factory;
        }
        
        public void Handle(T command) {
            // Execute on different thread.
            ThreadPool.QueueUserWorkItem(** => {
                // Create new handler in this thread.
                var handler = this.factory.Invoke();
                handler.Handle(command)
            });
        }
    }

This special decorator can be registered just as any other decorator:

.. code-block:: c#

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(AsyncCommandHandlerDecorator<>),
        c => c.ImplementationType.Name.StartsWith("Async"));

However, since the **AsyncCommandHandlerDecorator<T>** solely has singleton dependencies (the **Func<T>** is a singleton), and creates a new decorated instance each time it’s called, we can even register it as a singleton itself:

.. code-block:: c#

    container.RegisterSingleDecorator(
        typeof(ICommandHandler<>),
        typeof(AsyncCommandHandlerDecorator<>),
        c => c.ImplementationType.Name.StartsWith("Async"));

When mixing this with other (synchronous) decorators, you'll get an extremely powerful and pluggable system:

.. code-block:: c#

    container.RegisterManyForOpenGeneric(
        typeof(ICommandHandler<>), 
        typeof(ICommandHandler<>).Assembly);
        
    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(TransactionCommandHandlerDecorator<>));

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(DeadlockRetryCommandHandlerDecorator<>));

    container.RegisterSingleDecorator(
        typeof(ICommandHandler<>),
        typeof(AsyncCommandHandlerDecorator<>),
        c => c.ImplementationType.Name.StartsWith("Async"));
        
    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(ValidationCommandHandlerDecorator<>));

This configuration has an interesting mix of decorator registrations. The registration of the **AsyncCommandHandlerDecorator<T>** allows (some of) the command handlers to be executed on the background (while others -who's name does not start with 'Async'- still run synchronously), but before execution, all commands are validated synchronously (to allow communicating validation errors to the caller). And all handlers (even the asynchronous ones) are executed in a transaction and the operation is retried when the database rolled back because of a deadlock).

.. _Decorated_Collections:
.. _Decorated-Collections:

Decorated collections
---------------------

When registering a decorator, *Simple Injector* will automatically decorate any collection with elements of that service type:

.. code-block:: c#

    container.RegisterAll<IEventHandler<CustomerMovedEvent>>(
        typeof(CustomerMovedEventHandler),
        typeof(NotifyStaffWhenCustomerMovedEventHandler));
        
    container.RegisterDecorator(
        typeof(IEventHandler<>),
        typeof(ValidationEventHandlerDecorator<>),
        c => SomeCondition);

The previous registration registers a collection of **IEventHandler<CustomerMovedEvent>** services. Those services are decorated with a **ValidationEventHandlerDecorator<TEvent>** when the supplied predicate holds.

For collections of elements that are created by the container (container controlled), the predicate is checked for each element in the collection. For collections of uncontrolled elements (a list of items that is not created by the container), the predicate is checked once for the whole collection. This means that controlled collections can be partially decorated. Taking the previous example for instance, you could let the **CustomerMovedEventHandler** be decorated, while leaving the **NotifyStaffWhenCustomerMovedEventHandler** undecorated (determined by the supplied predicate).

When a collection is uncontrolled, it means that the lifetime of its elements are unknown to the container. The following registration is an example of an uncontrolled collection:

.. code-block:: c#

    IEnumerable<IEventHandler<CustomerMovedEvent>> handlers =
        new IEventHandler<CustomerMovedEvent>[]
        {
            new CustomerMovedEventHandler(),
            new NotifyStaffWhenCustomerMovedEventHandler(),
        };

    container.RegisterAll<IEventHandler<CustomerMovedEvent>>(handlers);

Although this registration contains a list of singletons, the container has no way of knowing this. The collection could easily have been a dynamic (an ever changing) collection. In this case, the container calls the registered predicate once (and supplies the predicate with the **IEventHandler<CusotmerMovedEvent>** type) and if the predicate returns true, each element in the collection is decorated with a decorator instance.

.. container:: Note

    **Warning**: In general you should prevent registering uncontrolled collections. The container knows nothing about them, and can't help you in doing [diagnostics|Diagnostics]. Since the lifetime of those items is unknown, the container will be unable to wrap a decorator with a lifestyle other than transient. Best practice is to register container-controlled collections which is done by using one of the *RegisterAll* overloads that take a collection of *System.Type* instances.

.. _Decorator-registration-factories:

Decorator registration factories
--------------------------------

In some advanced scenarios, it can be useful to depend the actual decorator type based on some contextual information. *Simple Injector* contains a *RegisterDecorator* overload that accepts a factory delegate that allows building the exact decorator type based on the actual type being decorated.

Take the following registration for instance:

.. code-block:: c#

    container.RegisterDecorator(
        typeof(IEventHandler<>),
        factoryContext => typeof(LoggingEventHandlerDecorator<,>).MakeGenericType(
            typeof(LoggingEventHandler<,>).GetGenericArguments().First(),
            factoryContext.ImplementationType),
        Lifestyle.Transient,
        predicateContext => true);

This example registers a decorator for the **IEventHandler<TEvent>** abstraction. The decorator to be used is the **LoggingEventHandlerDecorator<TEvent, TLogTarget>** type. The supplied factory delegate builds up a partially-closed open-generic type by filling in the **TLogTarget** argument with the actual wrapped event handler implementation type. Simple Injector will fill in the generic type argument **TEvent**. 

.. _Interception:

Interception
============

Interception is the ability to intercept a call from a consumer to a service, and add or change behavior. The `decorator pattern <https://en.wikipedia.org/wiki/Decorator_pattern>`_ describes a form of interception, but when it comes to applying cross-cutting concerns, you might end up writing decorators for many service interfaces, but with the exact same code. If this is happening, it is time to explore the possibilities of interception.

Using the [Interception extensions|InterceptionExtensions] code snippets, you can add the ability to do interception with *Simple Injector*. Using the given code, you can for instance define a **MonitoringInterceptor** that allows logging the execution time of the called service method:

.. code-block:: c#

    private class MonitoringInterceptor : IInterceptor {
        private readonly ILogger logger;

        // Using constructor injection on the interceptor
        public MonitoringInterceptor(ILogger logger) {
            this.logger = logger;
        }

        public void Intercept(IInvocation invocation) {
            var watch = Stopwatch.StartNew();

            // Calls the decorated instance.
            invocation.Proceed();

            var decoratedType =
                invocation.InvocationTarget.GetType();
            
            this.logger.Log(string.Format(
                "{0} executed in {1} ms.",
                decoratedType.Name,
                watch.ElapsedMiliseconds));
        }
    }

This interceptor can be registered to be wrapped around a concrete implementation. Using the given extension methods, this can be done as follows:

.. code-block:: c#

    container.InterceptWith<MonitoringInterceptor>(type => type == typeof(IUserRepository));

This registration ensures that every time an **IUserRepository** interface is requested, an interception proxy is returned that wraps that instance and uses the **MonitoringInterceptor** to extend the behavior.

The current example doesn't add much compared to simply using a decorator. When having many interface service types that need to be decorated with the same behavior however, it gets different:

.. code-block:: c#

    container.InterceptWith<MonitoringInterceptor>(t => t.Name.EndsWith("Repository"));

.. container:: Note

    **Note**: The [Interception extensions|InterceptionExtensions] code snippets use .NET's **System.Runtime.Remoting.Proxies.RealProxy** class to generate interception proxies. The **RealProxy** only allows to proxy interfaces.

.. container:: Note

    **Note**: the interfaces in the given [Interception extensions|InterceptionExtensions] code snippets are a simplified version of the Castle Project interception facility. If you need to create lots different interceptors, you might benefit from using the interception abilities of the Castle Project. Also please note that the given snippets use dynamic proxies to do the interception, while Castle uses lightweight code generation (LCG). LCG allows much better performance than the use of dynamic proxies.

.. container:: Note

    **Note**: Don't use interception for intercepting types that all implement the same generic interface, such as **ICommandHandler<T>** or **IValidator<T>**. Try using decorator classes instead, as shown in the :ref:`Decorators <Decorators>` section on this page.

.. _Implicit_Property_Injection:
.. _Implicit-Property-Injection:
.. _Property-Injection:

Property injection
==================

Simple Injector does not inject any properties into types that get resolved by the container. In general there are two ways of doing property injection, and both are not enabled by default for reasons explained below.

*Implicit property injection*
Some containers (such as Castle Windsor) implicitly inject public writable properties by default for any instance you resolve. They do this by mapping those properties to configured types. When no such registration exists, or when the property doesn’t have a public setter, the property will be skipped. Simple Injector does not do implicit property injection, and for good reason. We think that **implicit property injection** is simply too uuhh...  implicit :-). Silently skipping properties that can't be mapped can lead to a DI configuration that can't be easily verified and can therefore result in an application that fails at runtime instead of failing when the container is verified.

*Explicit property injection*
We strongly feel that explicit property injection is a much better way to go. With explicit property injection the container is forced to inject a property and the process will fail immediately when a property can't be mapped or injected. Some containers (such as Unity and Ninject) allow explicit property injection by allowing properties to be decorated with attributes that are defined by the DI library. Problem with this is that this forces the application to take a dependency on the library, which is something that should be prevented.

Because *Simple Injector* does not encourage its users to take a dependency on the container (except for the startup path of course), *Simple Injector* does not contain any attributes that allow explicit property injection and it can therefore not explicitly inject properties out-of-the-box.

Besides this, the use of property injection should be very exceptional and in general constructor injection should be used in the majority of cases. If a constructor gets too many parameters (constructor over-injection anti-pattern), it is an indication of a violation of the `Single Responsibility Principle <https://en.wikipedia.org/wiki/Single_responsibility_principle>`_ (SRP). SRP violations often lead to maintainability issues. So instead of patching constructor over-injection with property injection, the root cause should be analyzed and the type should be refactored, probably with `Facade Services <http://blog.ploeh.dk/2010/02/02/RefactoringtoAggregateServices/>`_. Another common reason to use properties is because those dependencies are optional. Instead of using optional property dependencies, best practice is to inject empty implementations (a.k.a. `Null Object pattern <https://en.wikipedia.org/wiki/Null_Object_pattern>`_) into the constructor.

*Enabling property injection*
*Simple Injector* contains two ways to enable property injection. First of all the :ref:`RegisterInitializer\<T\> <Configuring_Property_Injection>` method can be used to inject properties (especially configuration values) on a per-type basis. Take for instance the following code snippet:

.. code-block:: c#

    container.RegisterInitializer<HandlerBase>(handlerToInitialize => {
        handlerToInitialize.ExecuteAsynchronously = true;
    });

In the previous example an **Action<T>** delegate is registered that will be called every time the container creates a type that inherits from **HandlerBase**. In this case, the handler will set a configuration value on that class.

.. container:: Note

    **Note**: although this method can also be used injecting services, please note that the [Diagnostic Services|Diagnostics] will be unable to see and analyze that dependency.

.. _ImportPropertySelectionBehavior:

The second way to inject properties is by implementing a custom *IPropertySelectionBehavior*. The **property selection behavior** is a general extension point provided by the container, to override the library's default behavior (which is to **not** inject properties). The following example enables explicit property injection using attributes, using the **ImportAttribute** from the **System.ComponentModel.Composition.dll**:

.. code-block:: c#

    using System;
    using System.ComponentModel.Composition;
    using System.Linq;
    using System.Reflection;
    using SimpleInjector.Advanced;

    class ImportPropertySelectionBehavior : IPropertySelectionBehavior {
        public bool SelectProperty(Type type, PropertyInfo prop) {
            return prop.GetCustomAttributes(typeof(ImportAttribute)).Any();
        }
    }

The previous class can be registered as follows:

.. code-block:: c#

    var container = new Container();
    container.Options.PropertySelectionBehavior = 
        new ImportPropertySelectionBehavior();

This enables explicit property injection on all properties that are marked with the [Import] attribute and an exception will be thrown when the property cannot be injected for whatever reason.

.. container:: Note

    **Tip**: Properties injected by the container through the **IPropertySelectionBehavior** will be analyzed by the [Diagnostic Services|Diagnostics].

.. container:: Note

    **Note**: The **IPropertySelectionBehavior** extension mechanism can also be used to implement implicit property injection. There's `an example of this <https://simpleinjector.codeplex.com/SourceControl/latest#SimpleInjector.CodeSamples/ImplicitPropertyInjectionExtensions.cs>`_ in the source code. Doing so however is not advised because of the reasons given above.

.. _Covariance_Contravariance:
.. _Covariance-Contravariance:

Covariance and Contravariance
=============================

Since version 4.0 of the .NET framework, the type system allows `Covariance and Contravariance in Generics <https://msdn.microsoft.com/en-us/library/dd799517.aspx>`_ (especially interfaces and delegates). This allows for instance, to use a **IEnumerable<string>** as an **IEnumerable<object>** (covariance), or to use an **Action<object>** as an **Action<string>** (contravariance).

In some circumstances, the application design can benefit from the use of covariance and contravariance (or variance for short) and it would be beneficial when the IoC container returns services that are 'compatible' to the requested service, even although the requested service is not registered. To stick with the previous example, the container could return an **IEnumerable<string>** even when an **IEnumerable<object>** is requested.

By default, *Simple Injector* does not return variant implementations of given services, but Simple Injector can be extended to behave this way. The actual way to write this extension depends on the requirements of the application.

Take a look at the following application design around the **IEventHandler<in TEvent>** interface:

.. code-block:: c#

    public interface IEventHandler<in TEvent> {
        void Handle(TEvent e);
    }

    public class CustomerMovedEvent {
        public int CustomerId { get; set; }
        public Address NewAddress { get; set; }
    }

    public class CustomerMovedAbroadEvent : CustomerMovedEvent {
        public Country Country { get; set; }
    }

    public class CustomerMovedEventHandler : IEventHandler<CustomerMovedEvent> {
        public void Handle(CustomerMovedEvent e) { ... }
    }

The design contains two event classes **CustomerMovedEvent** and **CustomerMovedAbroadEvent** (where **CustomerMovedAbroadEvent** inherits from **CustomerMovedEvent**) one concrete event handler **CustomerMovedEventHandler** and a generic interface for event handlers.

We can configure the container in such way that not only a request for **IEventHandler<CustomerMovedEvent>** results in a **CustomerMovedEventHandler,** but also a request for **IEventHandler<CustomerMovedAbroadEvent>** results in that same **CustomerMovedEventHandler** (because **CustomerMovedEventHandler** also accepts **CustomerMovedAbroadEvents**).

There are multiple ways to achieve this. Here's one:

.. code-block:: c#

    container.Register<CustomerMovedEventHandler>();

    container.RegisterSingleOpenGeneric(typeof(IEventHandler<>), 
        typeof(ContravarianceEventHandler<>));

This registration depends on the custom **ContravarianceEventHandler<TEvent>** that should be placed close to the registration itself:

.. code-block:: c#

    public sealed class ContravarianceEventHandler<TEvent> : IEventHandler<TEvent> {
        private Registration registration;

        public ContravarianceEventHandler(Container container) {
            // NOTE: GetCurrentRegistrations has a perf characteristic of O(n), so
            // make sure this type is registered as singleton.
            registration = (
                from reg in container.GetCurrentRegistrations()
                where typeof(IEventHandler<TEvent>).IsAssignableFrom(reg.ServiceType)
                select reg)
                .Single();
        }

        void IEventHandler<TEvent>.Handle(TEvent e)
        {
            var handler = (IEventHandler<TEvent>)this.registration.GetInstance();
            handler.Handle(e);
        }
    }

The registration ensures that every time an **IEventHandler<TEvent>** is requested, a **ContravarianceEventHandler<TEvent>** is returned. The **ContravarianceEventHandler<TEvent>** will on creation query the container for a single service type that implements the specified **IEventHandler<TEvent>**. Because the **CustomerMovedEventHandler** is the only registered event handler for **IEventHandler<CustomerMovedEvent>**, the **ContravarianceEventHandler<CustomerMovedEvent>** will find that type and call it.

This is just one example and one way of adding variance support. For a more elaborate discussion on this subject, please read the following article: `Adding Covariance and Contravariance to Simple Injector <https://cuttingedge.it/blogs/steven/pivot/entry.php?id=90>`_.

.. _Plugins:

Registering plugins dynamically
===============================

Applications with a plugin architecture often allow special plugin assemblies to be dropped in a special folder and to be picked up by the application, without the need of a recompile. Although *Simple Injector* has no out of the box support for this, registering plugins from dynamically loaded assemblies can be implemented in a few lines of code. Here is an example:

.. code-block:: c#

    string pluginDirectory =
        Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Plugins");

    var pluginAssemblies =
        from file in new DirectoryInfo(pluginDirectory).GetFiles()
        where file.Extension.ToLower() == ".dll"
        select Assembly.LoadFile(file.FullName);

    var pluginTypes =
        from assembly in pluginAssemblies
        from type in assembly.GetExportedTypes()
        where typeof(IPlugin).IsAssignableFrom(type)
        where !type.IsAbstract
        where !type.IsGenericTypeDefinition
        select type;

    container.RegisterAll<IPlugin>(pluginTypes);

The given example makes use of an **IPlugin** interface that is known to the application, and probably located in a shared assembly. The dynamically loaded plugin .dll files can contain multiple classes that implement **IPlugin**, and all publicly exposed concrete types that implements **IPlugin** will be registered using the **RegisterAll** method and can get resolved using the default auto-wiring behavior of the container, meaning that the plugin must have a single public constructor and all constructor arguments must be resolvable by the container. The plugins can get resolved using **container.GetAllInstances<IPlugin>()** or by adding an **IEnumerable<IPlugin>** argument to a constructor.