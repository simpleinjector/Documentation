==================
Advanced Scenarios
==================

Although its name may not imply it, Simple Injector is capable of handling many advanced scenarios.

This chapter discusses the following subjects:

* :ref:`Generics <Generics>`
* :ref:`Batch registration / Automatic registration <Batch-Registration>`
* :ref:`Registration of open generic types <Registration-Of-Open-Generic-Types>`
* :ref:`Mixing collections of open-generic and non-generic components <Mixing-collections-of-open-generic-and-non-generic-components>`
* :ref:`Unregistered type resolution <Unregistered-Type-Resolution>`
* :ref:`Context based injection / Contextual binding <Context-Based-Injection>`
* :ref:`Decorators <Decorators>`
* :ref:`Interception <Interception>`
* :ref:`Property injection <Property-Injection>`
* :ref:`Covariance and Contravariance <Covariance-Contravariance>`
* :ref:`Registering plugins dynamically <Plugins>`

.. _Generics:

Generics
========

.NET has superior support for generic programming and Simple Injector has been designed to make full use of it. Simple Injector arguably has the most advanced support for generics of all DI libraries. Simple Injector can handle any generic type and implementing patterns such as decorator, mediator, strategy and chain of responsibility is simple.

`Aspect Oriented Programming <https://en.wikipedia.org/wiki/Aspect-oriented_programming>`_ is easy with Simple Injector's advanced support for generics. Generic decorators with generic type constraints can be registered with a single line of code and can be applied conditionally using predicates. Simple Injector can handle open generic types, closed generic types and partially-closed generic types. The sections below provides more detail on Simple Injector's support for generic typing:

* :ref:`Batch registration of non-generic types based on an open-generic interface<Batch-Registration>`
* :ref:`Registering open generic types and working with partially-closed types <Registration-Of-Open-Generic-Types>`
* :ref:`Mixing collections of open-generic and non-generic components <Mixing-collections-of-open-generic-and-non-generic-components>`
* :ref:`Registration of generic decorators <Decorators>`
* :ref:`Resolving Covariant/Contravariant types <Covariance-Contravariance>`

.. _Batch-Registration:

Batch / Automatic registration
==============================

Batch or automatic registration is a way of registering a set of (related) types in one go based on some convention. This features removes the need to constantly update the container's configuration each and every time a new type is added. The following example show a series of manually registered repositories: 

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
        select new { Service = type.GetInterfaces().Single(), Implementation = type };

    foreach (var reg in registrations) {
        container.Register(reg.Service, reg.Implementation, Lifestyle.Transient);
    }

Although many other DI libraries contain an advanced API for doing convention based registration, we found that doing this with custom LINQ queries is easier to write, more understandable, and can often prove to be more flexible than using a predefined and restrictive API.

Another interesting scenario is registering multiple implementations of a generic interface. Say for instance your application contains the following interface:

.. code-block:: c#

    public interface IValidator<T> {
        ValidationResults Validate(T instance);
    }

Your application might contain many implementations of this interface for validating Customers, Employees, Products, Orders, etc. Without batch registration you would probably end up with a set registrations similar to those we've already seen:

.. code-block:: c#

    container.Register<IValidator<Customer>, CustomerValidator>();
    container.Register<IValidator<Employee>, EmployeeValidator>();
    container.Register<IValidator<Order>, OrderValidator>();
    container.Register<IValidator<Product>, ProductValidator>();
    // and the list goes on...

By using the **Register** overload for batch registration, the same registrations can be made in a single line of code:

.. code-block:: c#

    container.Register(typeof(IValidator<>), new[] { typeof(IValidator<>).Assembly });

By default **Register** searches the supplied assemblies for all types that implement the *IValidator<T>* interface and registers each type by their specific (closed generic) interface. It even works for types that implement multiple closed versions of the given interface.

.. container:: Note

    **Note**: There is a **Register** overload available that take a list of *System.Type* instances, instead a list of *Assembly* instances and there is a **GetTypesToRegister** method that allows retrieving a list of types based on a given service type for a set of given assemblies.

Above are a couple of examples of the things you can do with batch registration. A more advanced scenario could be the registration of multiple implementations of the same closed generic type to a common interface, i.e. a set of types that all implement the same interface.

As an example, imagine the scenario where you have a *CustomerValidator* type and a *GoldCustomerValidator* type and they both implement *IValidator<Customer>* and you want to register them both at the same time. The earlier registration methods would throw an exception alerting you to the fact that you have multiple types implementing the same closed generic type. The following registration however, does enable this scenario:

.. code-block:: c#

    var assemblies = new[] { typeof(IValidator<>).Assembly };
    container.RegisterCollection(typeof(IValidator<>), assemblies);

The code snippet registers all types from the given assembly that implement *IValidator<T>*. As we now have multiple implementations the container cannot inject a single instance of *IValidator<T>* and because of this, we need to register collections. Because we register a collection, we can no longer call *container.GetInstance<IValidator<T>>()*. Instead instances can be retrieved by having an *IEnumerable<IValidator<T>>* constructor argument or by calling *container.GetAllInstances<IValidator<T>>()*.

It is not generally regarded as best practice to have an *IEnumerable<IValidator<T>>* dependency in multiple class constructors (or accessed from the  container directly). Depending on a set of types complicates your application design, can lead to code duplication. This can often be simplified with an alternate configuration. A better way is to have a single composite type that wraps *IEnumerable<IValidator<T>>* and presents it to the consumer as a single instance, in this case a *CompositeValidator<T>*:

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

This *CompositeValidator<T>* can be registered as follows:

.. code-block:: c#

    container.Register(typeof(IValidate<>), typeof(CompositeValidator<>),
        Lifestyle.Singleton);

This registration maps the open generic *IValidator<T>* interface to the open generic *CompositeValidator<T>* implementation. Because the *CompositeValidator<T>* contains an *IEnumerable<IValidator<T>>* dependency, the registered types will be injected into its constructor. This allows you to let the rest of the application simply depend on the *IValidator<T>*, while registering a collection of *IValidator<T>* implementations under the covers.

.. container:: Note

    **Note**: Simple Injector preserves the lifestyle of instances that are returned from an injected *IEnumerable<T>* instance. In reality you should not see the the injected *IEnumerable<IValidator<T>>* as a collection of implementations, you should consider it a **stream** of instances. Simple Injector will always inject a reference to the same stream (the *IEnumerable<T>* itself is a singleton) and each time you iterate the *IEnumerable<T>*, for each individual component, the container is asked to resolve the instance based on the lifestyle of that component. Regardless of the fact that the *CompositeValidator<T>* is registered as singleton the validators it wraps will each have their own specific lifestyle.

The next section will explain mapping of open generic types (just like the *CompositeValidator<T>* as seen above).

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

    container.Register(typeof(IValidate<>), new[] { typeof(IValidate<>).Assembly });

Sometimes you'll find that many implementations of the given generic interface are no-ops or need the same standard implementation. The *IValidate<T>* is a good example. It is very likely that not all entities will need validation but your solution would like to treat all entities the same and not need to know whether any particular type has validation or not (having to write a specific empty validation for each type would be a horrible task). In a situation such as this we would ideally like to use the registration as described above, and have some way to fallback to some default implementation when no explicit registration exist for a given type. Such a default implementation could look like this:
 
.. code-block:: c#

    // Implementation of the Null Object pattern.
    sealed class NullValidator<T> : IValidate<T> {
        public ValidationResults Validate(T instance) {
            return ValidationResults.Valid;
        }
    }

We could configure the container to use this *NullValidator<T>* for any entity that does not need validation:

.. code-block:: c#

    container.Register<IValidate<OrderLine>, NullValidator<OrderLine>>();
    container.Register<IValidate<Address>, NullValidator<Address>>();
    container.Register<IValidate<UploadImage>, NullValidator<UploadImage>>();
    container.Register<IValidate<Mothership>, NullValidator<Mothership>>();
    // and the list goes on...

This repeated registration is, of course, not very practical. We might be tempted to again fix this as follows:

.. code-block:: c#

    container.Register(typeof(IValidate<>), typeof(NullValidator<>));
	
This willl however not work, because this registration will try to map any closed *IValidate<T>* abstraction to the *NullValidator<T>* implementation, but other registrations (such as *ProductValidator* and *OrderValidator*) already exist. What we need here is to make *NullValidator<T>* as fallback registration and Simple Injector allows this using the **RegisterConditional** method overloads:

.. code-block:: c#

    container.RegisterConditional(typeof(IValidate<>), typeof(NullValidator<>),
        c => !c.Handled);

The result of this registration is exactly as you would have expected to see from the individual registrations above. Each request for *IValidate<Department>*, for example, will return a *NullValidator<Department>* instance each time. The **RegisterConditional** is supplied with a predicate. In this case the predicate checks whether there already is a different registration that handles the requested service type. In that case the predicate returns falls and the registration is not applied.

This predicate can also be used to apply types conditionally based on a number of contextual arguments. Here's an example:

.. code-block:: c#

    container.RegisterConditional(typeof(IValidator<>), typeof(LeftValidator<>),
        c => c.ServiceType.GetGenericArguments().Single().Namespace.Contains("Left"));

    container.RegisterConditional(typeof(IValidator<>), typeof(RightValidator<>),
        c => c.ServiceType.GetGenericArguments().Single().Namespace.Contains("Right"));

Simple Injector protects you from defining invalid registrations by ensuring that given the registrations do not overlap. Building on the last code snippet, imagine accidentally defining a type in the namespace "MyCompany.LeftRight". In this case both open-generic implementations would apply, but Simple Injector will never silently pick one. It will throw an exception instead.

As discussed before, the **PredicateContext.Handled** property can be used to implement a fallback mechanism. A more complex example is given below:

.. code-block:: c#

    container.RegisterConditional(typeof(IRepository<>), typeof(ReadOnlyRepository<>),
        c => typeof(IReadOnlyEntity).IsAssignableFrom(
            c.ServiceType.GetGenericArguments()[0]));

    container.RegisterConditional(typeof(IRepository<>), typeof(ReadWriteRepository<>),
        c => !c.Handled);

In the case above we tell Simple Injector to only apply the *ReadOnlyRepository<T>* registration in case the given *T* implements *IReadOnlyEntity*. Although applying the predicate can be useful, in this particular case it's better to apply a generic type constraint to *ReadOnlyRepository<T>*. Simple Injector will automatically apply the registered type conditionally based on it generic type constraints. So if we apply the generic type constraint to the *ReadOnlyRepository<T>* we can remove the predicate:

.. code-block:: c#

    class ReadOnlyRepository<T> : IRepository<T> where T : IReadOnlyEntity { }

    container.Register(typeof(IRepository<>), typeof(ReadOnlyRepository<>));
    container.RegisterConditional(typeof(IRepository<>), typeof(ReadWriteRepository<>),
        c => !c.Handled);

The final option in Simple Injector is to supply the **Register** or **RegisterConditional** methods with a partially-closed generic type:

.. code-block:: c#

    // SomeValidator<List<T>>
    var partiallyClosedType = typeof(SomeValidator<>).MakeGenericType(typeof(List<>));
    container.Register(typeof(IValidator<>), partiallyClosedType);

The type *SomeValidator<List<T>>* is called *partially-closed*, since although its generic type argument has been filled in with a type, it still contains a generic type argument. Simple Injector will be able to apply these constraints, just as it handles any other generic type constraints.

.. _Mixing-collections-of-open-generic-and-non-generic-components:

Mixing collections of open-generic and non-generic components
=============================================================

The **Register** overload that take in a list of assemblies only select non-generic implementations of the given open-generic type. Open-generic implementations are skipped, because they often need special attention.

To register collections that contain both non-generic and open-generic components a **RegisterCollection** overload is available that accept a list of Type instances. For instance:

.. code-block:: c#

    container.RegisterCollection(typeof(IValidator<>), new[] {
        typeof(DataAnnotationsValidator<>), // open generic
        typeof(CustomerValidator), // implements IValidator<Customer>
        typeof(GoldCustomerValidator), // implements IValidator<Customer>
        typeof(EmployeeValidator), // implements IValidator<Employee>
        typeof(OrderValidator) // implements IValidator<Order>
    });

In the previous example a set of *IValidator<T>* implementations is supplied to the **RegisterCollection** overload. This list contains one generic implementation, namely *DataAnnotationsValidator<T>*. This leads to a registration that is equivalent to the following manual registration:

.. code-block:: c#

    container.RegisterCollection<IValidator<Customer>>(
        typeof(DataAnnotationsValidator<Customer>),
        typeof(CustomerValidator),
        typeof(GoldCustomerValidator));
        
    container.RegisterCollection<IValidator<Employee>>(
        typeof(DataAnnotationsValidator<Employee>),
        typeof(EmployeeValidator));
        
    container.RegisterCollection<IValidator<Order>>(
        typeof(DataAnnotationsValidator<Order>),
        typeof(OrderValidator));

In other words, the supplied non-generic types are grouped by their closed *IValidator<T>* interface and the *DataAnnotationsValidator<T>* is applied to every group. This leads to three separate *IEnumerable<IValidator<T>>* registrations. One for each closed-generic *IValidator<T>* type.

.. container:: Note

    **Note**: **RegisterCollection** is guaranteed to preserve the order of the types that you supply.
        
But besides these three *IEnumerable<IValidator<T>>* registrations, an invisible fourth registration is made. This is a registration that hooks onto the **unregistered type resolution** event and this will ensure that any time an *IEnumerable<IValidator<T>>* for a *T* that is anything other than *Customer*, *Employee* and *Order*, an *IEnumerable<IValidator<T>>* is returned that contains the closed-generic versions of the supplied open-generic types; *DataAnnotationsValidator<T>* in the given example.

.. container:: Note

    **Note**: This will work equally well when the open generic types contain type constraints. In that case those types will be applied conditionally to the collections based on their generic type constraints.

In most cases however, manually supplying the **RegisterCollection** with a list of types leads to hard to maintain configurations, since the registration needs to be changed for each new validator we add to the system. Instead we can make use of one of the **RegisterCollection** overloads that accepts the `BatchRegistrationCallback <https://simpleinjector.org/ReferenceLibrary/?topic=html/T_SimpleInjector_Extensions_BatchRegistrationCallback.htm>`_ delegate and append the open generic type separately:

.. code-block:: c#

    // Extension method from the SimpleInjector.Advanced namespace.
    container.AppendToCollection(typeof(IValidator<>), typeof(DataAnnotationsValidator<>));

    container.RegisterCollection(typeof(IValidator<>),
        new[] { typeof(IValidator<>).Assembly });

Alternatively, we can make use of the Container's **GetTypesToRegister** to find the types for us:

.. code-block:: c#

    List<Type> typesToRegister = new List<Type> {
        typeof(DataAnnotationsValidator<>)
    };
    
    var assemblies = new[] { typeof(IValidator<>).Assembly) };
    typesToRegister.AddRange(container.GetTypesToRegister(typeof(IValidator<>), assemblies));

    container.RegisterCollection(typeof(IValidator<>), typesToRegister);
        
.. container:: Note

    The **Register** overloads that accept a list of assemblies use this **GetTypesToRegister** method internally as well.


.. _Unregistered-Type-Resolution:

Unregistered type resolution
============================

Unregistered type resolution is the ability to get notified by the container when a type that is currently unregistered in the container, is requested for the first time. This gives the user (or extension point) the chance of registering that type. Simple Injector supports this scenario with the `ResolveUnregisteredType <https://simpleinjector.org/ReferenceLibrary/?topic=html/E_SimpleInjector_Container_ResolveUnregisteredType.htm>`_ event. Unregistered type resolution enables many advanced scenarios. The library itself uses this event for implementing the :ref:`decorators <Decorators>`.

For more information about how to use this event, please take a look at the `ResolveUnregisteredType event documentation <https://simpleinjector.org/ReferenceLibrary/?topic=html/E_SimpleInjector_Container_ResolveUnregisteredType.htm>`_ in the `reference library <https://simpleinjector.org/ReferenceLibrary/>`_.


.. _Context-Based-Injection:

Context based injection
=======================

Context based injection is the ability to inject a particular dependency based on the context it lives in (or change the implementation based on the type it is injected into). Simple Injector contains the **RegisterConditional** method overloads that enable context based injection.

.. container:: Note

    **Note**: In many cases context based injection is not the best solution, and the design should be reevaluated. In some narrow cases however it can make sense.

The most common scenario is to base the type of the injected dependency on the type of the consumer. Take for instance the following *ILogger* interface with a generic *Logger<T>* class that needs to be injected into several consumers. 

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

In this case we want to inject a *Logger<Consumer1>* into *Consumer1* and a *Logger<Consumer2>* into *Consumer2*. By using the **RegisterConditional** overload that accepts a *implementation type factory delegate*, we can accomplish this as follows:

.. code-block:: c#

    container.RegisterConditional(
        typeof(ILogger),
        c => typeof(Logger<>).MakeGenericType(c.Consumer.ImplementationType),
        Lifestyle.Transient,
        c => true);

In the previous code snippet we supply the **RegisterConditional** method with a lambda presenting a *Func<TypeFactoryContext, Type>* delegate that allows building the exact implementation type based on contextual information. In this case we use the implementation type of the consuming component to build the correct closed *Logger<T>* type. We also supply the method with a predicate, but in this case we make the registration unconditional by returning true from the predicate.

.. container:: Note

    **Note**: Although building a generic type using MakeGenericType is relatively slow, the call to the *Func<TypeFactoryContext, Type>* delegate itself has a one-time cost. The factory delegate will usually be called a finite number of times. After an object graph has been built, the delegate will not be called again when that same object graph is resolved.

.. container:: Note

    **Note**: Even though the use of a generic *Logger<T>* is a common design (with log4net as the grand godfather of this design), doesn't always make it a good design. The need for having the logger contain information about its parent type, might indicate design problems. If you're doing this, please take a look at `this Stackoverflow answer <https://stackoverflow.com/a/9915056/264697>`_. It talks about logging in conjunction with the SOLID design principles.

.. _Decorators:

Decorators
==========

The `SOLID <https://en.wikipedia.org/wiki/SOLID>`_ principles give us important guidance when it comes to writing maintainable software. The 'O' of the 'SOLID' acronym stands for the `Open/closed Principle <https://en.wikipedia.org/wiki/Open/closed_principle>`_ which states that classes should be open for extension, but closed for modification. Designing systems around the Open/closed principle means that new behavior can be plugged into the system, without the need to change any existing parts, making the chance of breaking existing code much smaller and prevent having to make sweeping changes throughout the code base.


One of the ways to add new functionality (such as `cross-cutting concerns <https://en.wikipedia.org/wiki/Cross-cutting_concern>`_) to classes is by the use of the `decorator pattern <https://en.wikipedia.org/wiki/Decorator_pattern>`_. The decorator pattern can be used to extend (decorate) the functionality of a certain object at run-time. Especially when using generic interfaces, the concept of decorators gets really powerful. Take for instance the examples given in the :ref:`Registration of open generic types <Registration-Of-Open-Generic-Types>` section of this page or for instance the use of an generic *ICommandHandler<TCommand>* interface.

.. container:: Note

    **Tip**: `This article <https://cuttingedge.it/blogs/steven/pivot/entry.php?id=91>`_ describes an architecture based on the use of the *ICommandHandler<TCommand>* interface.

Take the plausible scenario where we want to validate all commands that get executed by an *ICommandHandler<TCommand>* implementation. The Open/Closed principle states that we want to do this, without having to alter each and every implementation. We can do this using a (single) decorator:

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
            
            // forward the (valid) command to the real command handler.
            this.handler.Handle(command);
        }
    }

The *ValidationCommandHandlerDecorator<TCommand>* class is an implementation of the *ICommandHandler<TCommand>* interface, but it also wraps / decorates an *ICommandHandler<TCommand>* instance. Instead of injecting the real implementation directly into a consumer, we can (let Simple Injector) inject a validator decorator that wraps the real implementation.

The *ValidationCommandHandlerDecorator<TCommand>* depends on an *IValidator* interface. An implementation that used Microsoft Data Annotations might look like this:

.. code-block:: c#

    using System.ComponentModel.DataAnnotations;

    public class DataAnnotationsValidator : IValidator {
        
        void IValidator.ValidateObject(object instance) {
            var context = new ValidationContext(instance, null, null);

            // Throws an exception when instance is invalid.
            Validator.ValidateObject(instance, context, validateAllProperties: true);
        }
    }

The implementations of the *ICommandHandler<T>* interface can be registered using the **Register** method overload that takes in a list of assemblies:

.. code-block:: c#

    container.Register(
        typeof(ICommandHandler<>), 
        new[] { typeof(ICommandHandler<>).Assembly });

By using the following method, you can wrap the *ValidationCommandHandlerDecorator<TCommand>* around each and every *ICommandHandler<TCommand>* implementation:

.. code-block:: c#

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(ValidationCommandHandlerDecorator<>));

Multiple decorators can be wrapped by calling the **RegisterDecorator** method multiple times, as the following registration shows:

.. code-block:: c#

    container.Register(
        typeof(ICommandHandler<>), 
        new[] { typeof(ICommandHandler<>).Assembly });
        
    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(TransactionCommandHandlerDecorator<>));

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(DeadlockRetryCommandHandlerDecorator<>));

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(ValidationCommandHandlerDecorator<>));

The decorators are applied in the order in which they are registered, which means that the first decorator (*TransactionCommandHandlerDecorator<T>* in this case) wraps the real instance, the second decorator (*DeadlockRetryCommandHandlerDecorator<T>* in this case) wraps the first decorator, and so on.

There's an overload of the **RegisterDecorator** available that allows you to supply a predicate to determine whether that decorator should be applied to a specific service type. Using a given context you can determine whether the decorator should be applied. Here is an example:

.. code-block:: c#

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(AccessValidationCommandHandlerDecorator<>),
        context => !context.ImplementationType.Namespace.EndsWith("Admins"));

The given context contains several properties that allows you to analyze whether a decorator should be applied to a given service type, such as the current closed generic service type (using the *ServiceType* property) and the concrete type that will be created (using the *ImplementationType* property). The predicate will (under normal circumstances) be called only once per closed generic type, so there is no performance penalty for using it.

.. _Decorators-with-Func-factories:

Decorators with Func<T> decoratee factories
-------------------------------------------

There are certain scenarios where it is necessary to postpone the building of part of an object graph. For instance when a service needs to control the lifetime of a dependency, needs multiple instances, when instances need to be :ref:`executed on a different thread <Multi-Threaded-Applications>`, or when instances need to be created within a certain :ref:`scope <Scoped>` or context (e.g. security).

You can easily delay the building of part of the graph by depending on a factory; the factory allows building that part of the object graph to be postponed until the moment the type is actually required. However, when working with decorators, injecting a factory to postpone the creation of the decorated instance will not work. This is best demonstrated with an example.

Take for instance a *AsyncCommandHandlerDecorator<T>* that executes a command handler on a different thread. We could let the *AsyncCommandHandlerDecorator<T>* depend on a *CommandHandlerFactory<T>*, and let this factory call back into the container to retrieve a new *ICommandHandler<T>* but this would fail, since requesting an *ICommandHandler<T>* would again wrap the new instance with a *AsyncCommandHandlerDecorator<T>* and we'd end up recursively creating the same instance type again and again resulting in a stack overflow.

This particular scenario is really hard to solve without library support and as such Simple Injector allows injecting a *Func<T>* delegate into registered decorators. This delegate functions as a factory for the creation of the decorated instance and avoids the recursive decoration explained above.

Taking the same *AsyncCommandHandlerDecorator<T>* as an example, it could be implemented as follows:

.. code-block:: c#

    public class AsyncCommandHandlerDecorator<T> : ICommandHandler<T> {
        private readonly Func<ICommandHandler<T>> decorateeFactory;

        public AsyncCommandHandlerDecorator(Func<ICommandHandler<T>> decorateeFactory) {
            this.decorateeFactory = decorateeFactory;
        }
        
        public void Handle(T command) {
            // Execute on different thread.
            ThreadPool.QueueUserWorkItem(state => {
                try {
                    // Create new handler in this thread.
                    ICommandHandler<T> handler = this.decorateeFactory.Invoke();
                    handler.Handle(command);
                } catch (Exception ex) {
                    // log the exception
                }            
            });
        }
    }

This special decorator is registered just as any other decorator:

.. code-block:: c#

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(AsyncCommandHandlerDecorator<>),
        c => c.ImplementationType.Name.StartsWith("Async"));

The *AsyncCommandHandlerDecorator<T>* however, has only singleton dependencies (the *Func<T>* is a singleton) and the *Func<ICommandHandler<T>>* factory always calls back into the container to register a decorated instance conforming the decoratee's lifestyle, each time it's called. If for instance the decoratee is registered as transient, each call to the factory will result in a new instance. It is therefore safe to register this decorator as a singleton:

.. code-block:: c#

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(AsyncCommandHandlerDecorator<>),
        Lifestyle.Singleton,
        c => c.ImplementationType.Name.StartsWith("Async"));

When mixing this decorator with other (synchronous) decorators, you'll get an extremely powerful and pluggable system:

.. code-block:: c#

    container.Register(
        typeof(ICommandHandler<>), 
        new[] { typeof(ICommandHandler<>).Assembly });
        
    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(TransactionCommandHandlerDecorator<>));

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(DeadlockRetryCommandHandlerDecorator<>));

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(AsyncCommandHandlerDecorator<>),
        Lifestyle.Singleton,
        c => c.ImplementationType.Name.StartsWith("Async"));
        
    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(ValidationCommandHandlerDecorator<>));

This configuration has an interesting mix of decorator registrations.

#. The registration of the *AsyncCommandHandlerDecorator<T>* allows (a subset of) command handlers to be executed in the background (while any command handler with a name that does not start with 'Async' will execute synchronously)
#. Prior to this point all commands are validated synchronously (to allow communicating validation errors to the caller)
#. All handlers (sync and async) are executed in a transaction and the operation is retried when the database rolled back because of a deadlock

Another useful application for *Func<T>* decoratee factories is when a command needs to be executed in an isolated fashion, e.g. to prevent sharing the unit of work with the request that triggered the execution of that command. This can be achieved by creating a proxy that starts a new lifetime scope, as follows:

.. code-block:: c#

    using SimpleInjector.Extensions.LifetimeScoping;

    public class LifetimeScopeCommandHandlerProxy<T> : ICommandHandler<T> {
        private readonly Container container;
        private readonly Func<ICommandHandler<T>> decorateeFactory;

        public LifetimeScopeCommandHandlerProxy(Container container,
            Func<ICommandHandler<T>> decorateeFactory) {
            this.container = container;
            this.decorateeFactory = decorateeFactory;
        }

        public void Handle(T command) {
            // Start a new scope.
            using (container.BeginLifetimeScope()) {
                // Create the decorateeFactory within the scope.
                ICommandHandler<T> handler = this.decorateeFactory.Invoke();
                handler.Handle(command);
            };
        }
    }
    
This proxy class starts a new :ref:`lifetime scope lifestyle <PerLifetimeScope>` and resolves the decoratee within that new scope using the factory. The use of the factory ensures that the decoratee is resolved according to its lifestyle, independent of the lifestyle of our proxy class. The proxy can be registered as follows:

.. code-block:: c#

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(LifetimeScopeCommandHandlerProxy<>),
        Lifestyle.Singleton);

.. container:: Note

    **Note**: Since the *LifetimeScopeCommandHandlerProxy<T>* only depends on singletons (both the *Container* and the *Func<ICommandHandler<T>>* are singletons), it too can safely be registered as singleton.
        
Since a typical application will not use the lifetime scope, but would prefer a scope specific to the application type (such as a :ref:`web request <PerWebRequest>`, :ref:`web api request <PerWebAPIRequest>` or :ref:`WCF operation <PerWcfOperation>` lifestyles), a special :ref:`hybrid lifestyle <Hybrid>` needs to be defined that allows object graphs to be resolved in this mixed-request scenario:

.. code-block:: c#

    ScopedLifestyle scopedLifestyle = Lifestyle.CreateHybrid(
        lifestyleSelector: () => container.GetCurrentLifetimeScope() != null,
        trueLifestyle: new LifetimeScopeLifestyle(),
        falseLifestyle: new WebRequestLifestyle());

    container.Register<IUnitOfWork, DbUnitOfWork>(scopedLifestyle);

Obviously, if you run (part of) your commands on a background thread and also use registrations with a :ref:`scoped lifestyle <Scoped>` you will have a use both the *LifetimeScopeCommandHandlerProxy<T>* and *AsyncCommandHandlerDecorator<T>* together which can be seen in the following configuration:

.. code-block:: c#

    container.Options.DefaultScopedLifestyle = Lifestyle.CreateHybrid(
        lifestyleSelector: () => container.GetCurrentLifetimeScope() != null,
        trueLifestyle: new LifetimeScopeLifestyle(),
        falseLifestyle: new WebRequestLifestyle());

    container.Register<IUnitOfWork, DbUnitOfWork>(Lifestyle.Scoped);
    container.Register<IRepository<User>, UserRepository>(Lifestyle.Scoped);
        
    container.Register(
        typeof(ICommandHandler<>), 
        new[] { typeof(ICommandHandler<>).Assembly });

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(LifetimeScopeCommandHandlerProxy<>),
        Lifestyle.Singleton);
        
    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(AsyncCommandHandlerDecorator<>),
        Lifestyle.Singleton,
        c => c.ImplementationType.Name.StartsWith("Async"));

With this configuration all commands are executed in an isolated context and some are also executed on a background thread.

.. _Decorated-Collections:

Decorated collections
---------------------

When registering a decorator, Simple Injector will automatically decorate any collection with elements of that service type:

.. code-block:: c#

    container.RegisterCollection<IEventHandler<CustomerMovedEvent>>(new[] {
        typeof(CustomerMovedEventHandler),
        typeof(NotifyStaffWhenCustomerMovedEventHandler)
	});
        
    container.RegisterDecorator(
        typeof(IEventHandler<>),
        typeof(TransactionEventHandlerDecorator<>),
        c => SomeCondition);

The previous registration registers a collection of *IEventHandler<CustomerMovedEvent>* services. Those services are decorated with a *TransactionEventHandlerDecorator<TEvent>* when the supplied predicate holds.

For collections of elements that are created by the container (container controlled), the predicate is checked for each element in the collection. For collections of uncontrolled elements (a list of items that is not created by the container), the predicate is checked once for the whole collection. This means that controlled collections can be partially decorated. Taking the previous example for instance, you could let the *CustomerMovedEventHandler* be decorated, while leaving the *NotifyStaffWhenCustomerMovedEventHandler* undecorated (determined by the supplied predicate).

When a collection is uncontrolled, it means that the lifetime of its elements are unknown to the container. The following registration is an example of an uncontrolled collection:

.. code-block:: c#

    IEnumerable<IEventHandler<CustomerMovedEvent>> handlers =
        new IEventHandler<CustomerMovedEvent>[] {
            new CustomerMovedEventHandler(),
            new NotifyStaffWhenCustomerMovedEventHandler(),
        };

    container.RegisterCollection<IEventHandler<CustomerMovedEvent>>(handlers);

Although this registration contains a list of singletons, the container has no way of knowing this. The collection could easily have been a dynamic (an ever changing) collection. In this case, the container calls the registered predicate once (and supplies the predicate with the *IEventHandler<CusotmerMovedEvent>* type) and if the predicate returns true, each element in the collection is decorated with a decorator instance.

.. container:: Note

    **Warning**: In general you should prevent registering uncontrolled collections. The container knows nothing about them, and can't help you in doing :doc:`diagnostics <diagnostics>`. Since the lifetime of those items is unknown, the container will be unable to wrap a decorator with a lifestyle other than transient. Best practice is to register container-controlled collections which is done by using one of the **RegisterCollection** overloads that take a collection of *System.Type* instances.

.. _Using-contextual-information-inside-decorators:

Using contextual information inside decorators
----------------------------------------------

As we shown before, you can apply a decorator conditionally based on a predicate you can supply to the **RegisterDecorator** overloads:

.. code-block:: c#

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(AsyncCommandHandlerDecorator<>),
        c => c.ImplementationType.Name.StartsWith("Async"));

Sometimes however you might want to apply a decorator unconditionally, but let the decorator act at runtime based on this contextual information. You can do this by injecting the **DecoratorContext** into the decorator's constructor as can be seem in the following example:

.. code-block:: c#

    public class TransactionCommandHandlerDecorator<T> : ICommandHandler<T> {
        private readonly ITransactionBuilder transactionBuilder;
        private readonly ICommandHandler<T> decoratee;
        private readonly TransactionType transactionType;

        public TransactionCommandHandlerDecorator(DecoratorContext decoratorContext,
            ITransactionBuilder transactionBuilder, ICommandHandler<T> decoratee) {
            this.transactionBuilder = transactionBuilder;
            this.decoratee = decoratee;
            this.transactionType = decoratorContext.ImplementationType
                .GetCustomAttribute<TransactionAttribute>()
                .TransactionType;
        }
        
        public void Handle(T command) {
            using (var ta = this.transactionBuilder.BeginTransaction(this.transactionType)) {
                this.decoratee.Handle(command);
                ta.Complete();
            }
        }
    }
    
The previous code snippet shows a decorator that applies a transaction behavior to command handlers. The decorator is injected with the **DecoratorContext** class which supplies the decorator with contextual information about the other decorators in the chain and the actual implementation type. In this example the decorator expects a *TransactionAttribute* to be applied to the wrapped command handler implementation and it starts the correct transaction type based on this information.

If the attribute was applied to the command class instead of the command handler, this decorator would been able to gather this information without the use of the **DecoratorContext**. This would however leak implementation details into the command, since which type of transaction a handler should run is clearly an implementation detail and is of no concern to the consumer of that command. Placing that attribute on the handler instead of the command is therefore a much more reasonable thing to do.

The decorator would also be able to get the attribute by using the injected decoratee, but this would only work when the decorator would directly wrap the handler. This would make the system quite fragile, since it would break once you start placing other decorator in between this decorator and the handler, which is a very likely thing to happen.
    
.. _Decorator-registration-factories:

Decorator registration factories
--------------------------------

In some advanced scenarios, it can be useful to depend the actual decorator type based on some contextual information. There is a **RegisterDecorator** overload that accepts a factory delegate that allows building the exact decorator type based on the actual type being decorated.

Take the following registration for instance:

.. code-block:: c#

    container.RegisterDecorator(
        typeof(IEventHandler<>),
        factoryContext => typeof(LoggingEventHandlerDecorator<,>).MakeGenericType(
            typeof(LoggingEventHandler<,>).GetGenericArguments().First(),
            factoryContext.ImplementationType),
        Lifestyle.Transient,
        predicateContext => true);

This example registers a decorator for the *IEventHandler<TEvent>* abstraction. The decorator to be used is the *LoggingEventHandlerDecorator<TEvent, TLogTarget>* type. The supplied factory delegate builds up a partially-closed open-generic type by filling in the *TLogTarget* argument with the actual wrapped event handler implementation type. Simple Injector will fill in the generic type argument *TEvent*. 

.. _Interception:

Interception
============

Interception is the ability to intercept a call from a consumer to a service, and add or change behavior. The `decorator pattern <https://en.wikipedia.org/wiki/Decorator_pattern>`_ describes a form of interception, but when it comes to applying cross-cutting concerns, you might end up writing decorators for many service interfaces, but with the exact same code. If this is happening, it's time to take a close look at your design. If for what ever reason, it's impossible for you to make the required improvements to your design, your second best bet is to explore the possibilities of interception.

.. container:: Note

    **Warning**: Simple Injector has :ref:`no out-of-the-box support for interception <No-interception>` because the use of interception is an indication of a sub optimal design and we are keen on pushing developers into best practices. Whenever possible, choose to improve your design to make decoration possible.	

Using the :doc:`Interception extensions <InterceptionExtensions>` code snippets, you can add the ability to do interception with Simple Injector. Using the given code, you can for instance define a *MonitoringInterceptor* that allows logging the execution time of the called service method:

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

            var decoratedType = invocation.InvocationTarget.GetType();
            
            this.logger.Log(string.Format("{0} executed in {1} ms.",
                decoratedType.Name, watch.ElapsedMiliseconds));
        }
    }

This interceptor can be registered to be wrapped around a concrete implementation. Using the given extension methods, this can be done as follows:

.. code-block:: c#

    container.InterceptWith<MonitoringInterceptor>(type => type == typeof(IUserRepository));

This registration ensures that every time an *IUserRepository* interface is requested, an interception proxy is returned that wraps that instance and uses the *MonitoringInterceptor* to extend the behavior.

The current example doesn't add much compared to simply using a decorator. When having many interface service types that need to be decorated with the same behavior however, it gets different:

.. code-block:: c#

    container.InterceptWith<MonitoringInterceptor>(t => t.Name.EndsWith("Repository"));

.. container:: Note

    **Note**: The :doc:`Interception extensions <InterceptionExtensions>` code snippets use .NET's *System.Runtime.Remoting.Proxies.RealProxy* class to generate interception proxies. The *RealProxy* only allows to proxy interfaces.

.. container:: Note

    **Note**: the interfaces in the given :doc:`Interception extensions <InterceptionExtensions>` code snippets are a simplified version of the Castle Project interception facility. If you need to create lots different interceptors, you might benefit from using the interception abilities of the Castle Project. Also please note that the given snippets use dynamic proxies to do the interception, while Castle uses lightweight code generation (LCG). LCG allows much better performance than the use of dynamic proxies. Please see `this stackoverflow q/a <https://stackoverflow.com/questions/24513530/using-simple-injector-with-castle-proxy-interceptor>`_ for an implementation for Castle Windsor.

.. container:: Note

    **Note**: Don't use interception for intercepting types that all implement the same generic interface, such as *ICommandHandler<T>* or *IValidator<T>*. Try using decorator classes instead, as shown in the :ref:`Decorators <Decorators>` section on this page.

.. _Property-Injection:

Property injection
==================

Simple Injector does not inject any properties into types that get resolved by the container. In general there are two ways of doing property injection, and both are not enabled by default for reasons explained below.

**Implicit property injection**

Some containers (such as Castle Windsor) implicitly inject public writable properties by default for any instance you resolve. They do this by mapping those properties to configured types. When no such registration exists, or when the property doesn't have a public setter, the property will be skipped. Simple Injector does not do implicit property injection, and for good reason. We think that **implicit property injection** is simply too uuhh... implicit :-). Silently skipping properties that can't be mapped can lead to a DI configuration that can't be easily verified and can therefore result in an application that fails at runtime instead of failing when the container is verified.


.. _Explicit-Property-Injection:

**Explicit property injection**

We strongly feel that explicit property injection is a much better way to go. With explicit property injection the container is forced to inject a property and the process will fail immediately when a property can't be mapped or injected. Some containers (such as Unity and Ninject) allow explicit property injection by allowing properties to be decorated with attributes that are defined by the DI library. Problem with this is that this forces the application to take a dependency on the library, which is something that should be prevented.

Because Simple Injector does not encourage its users to take a dependency on the container (except for the startup path of course), Simple Injector does not contain any attributes that allow explicit property injection and it can therefore not explicitly inject properties out-of-the-box.

Besides this, the use of property injection should be very exceptional and in general constructor injection should be used in the majority of cases. If a constructor gets too many parameters (constructor over-injection anti-pattern), it is an indication of a violation of the `Single Responsibility Principle <https://en.wikipedia.org/wiki/Single_responsibility_principle>`_ (SRP). SRP violations often lead to maintainability issues. So instead of patching constructor over-injection with property injection, the root cause should be analyzed and the type should be refactored, probably with `Facade Services <http://blog.ploeh.dk/2010/02/02/RefactoringtoAggregateServices/>`_. Another common reason to use properties is because those dependencies are optional. Instead of using optional property dependencies, best practice is to inject empty implementations (a.k.a. `Null Object pattern <https://en.wikipedia.org/wiki/Null_Object_pattern>`_) into the constructor.

**Enabling property injection**

Simple Injector contains two ways to enable property injection. First of all the :ref:`RegisterInitializer\<T\> <Configuring-Property-Injection>` method can be used to inject properties (especially configuration values) on a per-type basis. Take for instance the following code snippet:

.. code-block:: c#

    container.RegisterInitializer<HandlerBase>(handlerToInitialize => {
        handlerToInitialize.ExecuteAsynchronously = true;
    });

In the previous example an *Action<T>* delegate is registered that will be called every time the container creates a type that inherits from *HandlerBase*. In this case, the handler will set a configuration value on that class.

.. container:: Note

    **Note**: although this method can also be used injecting services, please note that the :doc:`Diagnostic Services <diagnostics>` will be unable to see and analyze that dependency.


.. _ImportPropertySelectionBehavior:

The second way to inject properties is by implementing a custom **IPropertySelectionBehavior**. The *property selection behavior* is a general extension point provided by the container, to override the library's default behavior (which is to *not* inject properties). The following example enables explicit property injection using attributes, using the *ImportAttribute* from the *System.ComponentModel.Composition.dll*:

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
    container.Options.PropertySelectionBehavior = new ImportPropertySelectionBehavior();

This enables explicit property injection on all properties that are marked with the [Import] attribute and an exception will be thrown when the property cannot be injected for whatever reason.

.. container:: Note

    **Tip**: Properties injected by the container through the **IPropertySelectionBehavior** will be analyzed by the :doc:`Diagnostic Services <diagnostics>`.

.. container:: Note

    **Note**: The **IPropertySelectionBehavior** extension mechanism can also be used to implement implicit property injection. There's `an example of this <https://simpleinjector.codeplex.com/SourceControl/latest#SimpleInjector.CodeSamples/ImplicitPropertyInjectionExtensions.cs>`_ in the source code. Doing so however is not advised because of the reasons given above.

.. _Covariance-Contravariance:

Covariance and Contravariance
=============================

Since version 4.0 of the .NET framework, the type system allows `Covariance and Contravariance in Generics <https://msdn.microsoft.com/en-us/library/dd799517.aspx>`_ (especially interfaces and delegates). This allows for instance, to use a *IEnumerable<string>* as an *IEnumerable<object>* (covariance), or to use an *Action<object>* as an *Action<string>* (contravariance).

In some circumstances, the application design can benefit from the use of covariance and contravariance (or variance for short) and it would be beneficial if the container returned services that were 'compatible' with the requested service, even when the requested service type itself is not explicitly registered. To stick with the previous example, the container could return an *IEnumerable<string>* even when an *IEnumerable<object>* is requested.

When resolving a collection, Simple Injector will resolve all assignable (variant) implementations of the requested service type as part of the requested collection.

Take a look at the following application design around the *IEventHandler<in TEvent>* interface:

.. code-block:: c#

    public interface IEventHandler<in TEvent> {
        void Handle(TEvent e);
    }

    public class CustomerMovedEvent {
        public readonly Guid CustomerId;
        public CustomerMovedEvent(Guid customerId) {
            this.CustomerId = customerId;
        }
    }

    public class CustomerMovedAbroadEvent : CustomerMovedEvent {
        public CustomerMovedEvent(Guid customerId) : base(customerId) { }    
    }

    public class SendFlowersToMovedCustomer : IEventHandler<CustomerMovedEvent> {
        public void Handle(CustomerMovedEvent e) { ... }
    }

    public class WarnShippingDepartmentAboutMove : IEventHandler<CustomerMovedAbroadEvent> {
        public void Handle(CustomerMovedEvent e) { ... }
    }    

The design contains two event classes *CustomerMovedEvent* and *CustomerMovedAbroadEvent* (where *CustomerMovedAbroadEvent* inherits from *CustomerMovedEvent*) and two concrete event handlers *SendFlowersToMovedCustomer* and *WarnShippingDepartmentAboutMove*. These classes can be registered using the following registration:

.. code-block:: c#

    // Configuration
    container.RegisterCollection(typeof(IEventHandler<>),
        new[] { typeof(IEventHandler<>).Assembly });

    // Usage
    var handlers = container.GetAllInstances<IEventHandler<CustomerMovedAbroadEvent>>();

    foreach (var handler in handlers) {
        Console.WriteLine(handler.GetType().Name);
    }
    
With the given classes, the code snippet above will give the following output:

.. code-block

    SendFlowersToMovedCustomer
    WarnShippingDepartmentAboutMove
    
Although we requested all registrations for *IEventHandler<CustomerMovedAbroadEvent>*, the container returned *IEventHandler<CustomerMovedEvent>* and *IEventHandler<CustomerMovedAbroadEvent>*. Simple Injector did this because the *IEventHandler<in TEvent>* interface was defined with the *in* keyword, which makes *SendFlowerToMovedCustomer* assignable to *IEventHandler<CustomerMovedAbroadEvent>* (since *CustomerMovedAbroadEvent* inherits from *CustomerMovedEvent*, *SendFlowerToMovedCustomer* can also process *CustomerMovedAbroadEvent* events). 

.. container:: Note

    **Tip**: If you don't want Simple Injector to resolve variant registrations remove the *in* and *out* keywords from the interface definition. I.e. the *in* and *out* keywords are the trigger for Simple Injector to apply variance.

.. container:: Note

    **Tip**: Don't mark generic type arguments with *in* and *out* keywords by default, even if Resharper tells you to. Most of the generic abstractions you define will always have exactly one non-generic implementation but marking the interface with *in* and *out* keywords communicates that covariance and contravariance is expected and there could therefore be multiple applicable implementations. This will confuse the reader of your code. Only apply these keywords if variance is actually required. You should typically not use variance when defining *ICommandHandler<TCommand>* or *IQueryHandler<TQuery, TResult>*, but it might make sense for *IEventHandler<in TEvent>* and *IValidator<in T>*.
    
.. container:: Note
    
    **Note**: Simple Injector only resolves variant implementations for collections that are registered using the *RegisterCollection* overloads. In the screnario you are resolving a single instance using *GetInstance<T>* then Simple Injector will not return an assignable type, even if the exact type is not registered, because this could easily lead to ambiguity; Simple Injector will not know which implementation to select.

.. _Plugins:

Registering plugins dynamically
===============================

Applications with a plugin architecture often allow special plugin assemblies to be dropped in a special folder and to be picked up by the application, without the need of a recompile. Although Simple Injector has no out of the box support for this, registering plugins from dynamically loaded assemblies can be implemented in a few lines of code. Here is an example:

.. code-block:: c#

    string pluginDirectory =
        Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Plugins");

    var pluginAssemblies =
        from file in new DirectoryInfo(pluginDirectory).GetFiles()
        where file.Extension.ToLower() == ".dll"
        select Assembly.LoadFile(file.FullName);

    var pluginTypes = container.GetTypesToRegister(typeof(IPlugin), pluginAssemblies);

    container.RegisterCollection<IPlugin>(pluginTypes);

The given example makes use of an *IPlugin* interface that is known to the application, and probably located in a shared assembly. The dynamically loaded plugin .dll files can contain multiple classes that implement *IPlugin*, and all publicly exposed concrete types that implement *IPlugin* will be registered using the **RegisterCollection** method and can get resolved using the default auto-wiring behavior of the container, meaning that the plugin must have a single public constructor and all constructor arguments must be resolvable by the container. The plugins can get resolved using *container.GetAllInstances<IPlugin>()* or by adding an *IEnumerable<IPlugin>* argument to a constructor.
