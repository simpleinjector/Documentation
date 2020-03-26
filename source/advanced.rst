==================
Advanced Scenarios
==================

Although its name may not imply it, Simple Injector is capable of handling many advanced scenarios.

This chapter discusses the following subjects:

* :ref:`Generics <Generics>`
* :ref:`Batch-Registration / Auto-Registration <Auto-Registration>`
* :ref:`Registration of open generic types <Registration-Of-Open-Generic-Types>`
* :ref:`Mixing collections of open-generic and non-generic components <Mixing-collections-of-open-generic-and-non-generic-components>`
* :ref:`Unregistered type resolution <Unregistered-Type-Resolution>`
* :ref:`Context-based injection / Contextual binding <Context-Based-Injection>`
* :ref:`Property injection <Property-Injection>`
* :ref:`Covariance and Contravariance <Covariance-Contravariance>`
* :ref:`Registering plugins dynamically <Plugins>`

.. _Generics:

Generics
========

.NET has superior support for generic programming and Simple Injector has been designed to make full use of it. Simple Injector arguably has the most advanced support for generics of all DI libraries. Simple Injector can handle any generic type and implementing patterns such as decorator, mediator, strategy, composite and chain of responsibility is a breeze.

:doc:`Aspect-Oriented Programming <aop>` is easy with Simple Injector's advanced support for generics. Generic decorators with generic-type constraints can be registered with a single line of code and can be applied conditionally using predicates. Simple Injector can handle open-generic types, closed-generic types and partially-closed generic types. The sections below provides more detail on Simple Injector's support for generic typing:

* :ref:`Batch registration of non-generic types based on an open-generic interface <Auto-Registration>`
* :ref:`Registering open generic types and working with partially-closed types <Registration-Of-Open-Generic-Types>`
* :ref:`Mixing collections of open-generic and non-generic components <Mixing-collections-of-open-generic-and-non-generic-components>`
* :ref:`Resolving Covariant/Contravariant types <Covariance-Contravariance>`
* :ref:`Registration of generic decorators <Decoration>`

.. _Batch-Registration:
.. _Auto-Registration:

Batch-Registration / Auto-Registration
======================================

Auto-registration or batch-registration is a way of registering a set of (related) types in one go based on some convention. This feature removes the need to constantly update the container's configuration each and every time a new type is added. The following example show a series of manually registered repositories: 

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
        where type.Namespace.StartsWith("MyComp.MyProd.DAL")
        from service in type.GetInterfaces()
        select new { service, implementation = type };

    foreach (var reg in registrations)
    {
        container.Register(reg.service, reg.implementation, Lifestyle.Transient);
    }

Although many other DI libraries contain an advanced API for doing convention based registration, we found that doing this with custom LINQ queries is easier to write, more understandable, and can often prove to be more flexible than using a predefined and restrictive API.

Another interesting scenario is registering multiple implementations of a generic interface. Say, for instance, your application contains the following interface:

.. code-block:: c#

    public interface IValidator<T>
    {
        ValidationResults Validate(T instance);
    }

Your application might contain many implementations of this interface for validating customers, employees, products, orders, etc. Without auto-registration you would probably end up with a set registrations similar to those you previously saw:

.. code-block:: c#

    container.Register<IValidator<Customer>, CustomerValidator>();
    container.Register<IValidator<Employee>, EmployeeValidator>();
    container.Register<IValidator<Order>, OrderValidator>();
    container.Register<IValidator<Product>, ProductValidator>();
    // and the list goes on...

By using the **Register** overload for auto-registration, the same registrations can be made in a single line of code:

.. code-block:: c#

    container.Register(typeof(IValidator<>), typeof(IValidator<>).Assembly);

By default, **Register** searches the supplied assemblies for all types that implement the *IValidator<T>* interface and registers each type by their specific (closed-generic) interface. It even works for types that implement multiple closed versions of the given interface.

.. container:: Note

    **Note**: There is a **Register** overload available that takes a list of *System.Type* instances, instead a list of *Assembly* instances and there is a **Container.GetTypesToRegister** method that allows retrieving a list of types based on a given service type for a set of given assemblies. This gives you more control over how these types are registered.

Above are a couple of basic examples of the things you can do with auto-registration. A more advanced scenario could be the registration of multiple implementations of the same closed-generic type to a common interface, i.e. a set of types that all implement the same interface.

As an example, imagine the scenario where you have a *CustomerValidator* type and a *GoldCustomerValidator* type and they both implement *IValidator<Customer>* and you want to register them both at the same time. The earlier registration methods would throw an exception alerting you to the fact that you have multiple types implementing the same closed-generic type. The following registration, however, does enable this scenario:

.. code-block:: c#

    var assemblies = new[] { typeof(IValidator<>).Assembly };
    container.Collection.Register(typeof(IValidator<>), assemblies);

The code snippet registers all types from the given assembly that implement *IValidator<T>*. As you now have multiple implementations the container cannot inject a single instance of *IValidator<T>* and because of this, you need to register a collection. Because you register a collection, you can no longer call **container.GetInstance<IValidator<T>>()**. Instead instances can be retrieved by having an *IEnumerable<IValidator<T>>* constructor argument or by calling **container.GetAllInstances<IValidator<T>>()**.

It is not generally regarded as best practice to have an *IEnumerable<IValidator<T>>* dependency in multiple class constructors (or accessed from the container directly). Depending on a set of types complicates your application design and can lead to code duplication. This can often be simplified with an alternate configuration. A better way is to have a single composite type that wraps *IEnumerable<IValidator<T>>* and presents it to the consumer as a single instance, in this case a *CompositeValidator<T>*:

.. code-block:: c#

    public class CompositeValidator<T> : IValidator<T>
    {
        private readonly IEnumerable<IValidator<T>> validators;

        public CompositeValidator(IEnumerable<IValidator<T>> validators)
        {
            this.validators = validators;
        }

        public ValidationResults Validate(T instance)
        {
            var allResults = ValidationResults.Valid;

            foreach (var validator in this.validators)
            {
                var results = validator.Validate(instance);
                allResults = ValidationResults.Join(allResults, results);
            }

            return allResults;
        }
    }

This *CompositeValidator<T>* can be registered as follows:

.. code-block:: c#

    container.Register(
        typeof(IValidate<>),
        typeof(CompositeValidator<>),
        Lifestyle.Singleton);

This registration maps the open-generic *IValidator<T>* interface to the open-generic *CompositeValidator<T>* implementation. Because the *CompositeValidator<T>* contains an *IEnumerable<IValidator<T>>* dependency, the registered types will be injected into its constructor. This allows you to let the rest of the application simply depend on the *IValidator<T>*, while registering a collection of *IValidator<T>* implementations under the covers.

.. container:: Note

    **Note**: Simple Injector preserves the lifestyle of instances that are returned from an injected *IEnumerable<T>* instance. In reality you should not see the injected *IEnumerable<IValidator<T>>* as a collection of implementations—you should consider it a **stream** of instances. Simple Injector will always inject a reference to the same object (the *IEnumerable<T>* itself is a singleton) and each time you iterate the *IEnumerable<T>*, for each individual component, the container is asked to resolve the instance based on the lifestyle of that component. Regardless of the fact that the *CompositeValidator<T>* is registered as singleton, the validators it wraps will each have their own specific lifestyle.

The next section will explain mapping of open-generic types, just like the *CompositeValidator<T>* as seen above.

.. _Registration-Of-Open-Generic-Types:

Registration of open-generic types
==================================

When working with generic interfaces, you will often see numerous implementations of that interface being registered:

.. code-block:: c#

    container.Register<IValidate<Customer>, CustomerValidator>();
    container.Register<IValidate<Employee>, EmployeeValidator>();
    container.Register<IValidate<Order>, OrderValidator>();
    container.Register<IValidate<Product>, ProductValidator>();
    // and the list goes on...

As the previous section explained, this can be rewritten to the following one-liner:

.. code-block:: c#

    container.Register(typeof(IValidate<>), typeof(IValidate<>).Assembly);

Sometimes you'll find that many implementations of the given generic interface are no-ops or need the same standard implementation. The *IValidate<T>* is a good example. It is very likely that not all entities will need validation but your solution would like to treat all entities the same and not need to know whether any particular type has validation or not (having to write a specific empty validation for each type would be a horrible task). In a situation such as this you would ideally like to use the registration as described above, and have some way to fallback to some default implementation when no explicit registration exist for a given type. Such a default implementation could look like this:
 
.. code-block:: c#

    // Implementation of the Null Object pattern.
    public sealed class NullValidator<T> : IValidate<T> {
        public ValidationResults Validate(T instance) => ValidationResults.Valid;
    }

We could configure the container to use this *NullValidator<T>* for any entity that does not need validation:

.. code-block:: c#

    container.Register<IValidate<OrderLine>, NullValidator<OrderLine>>();
    container.Register<IValidate<Address>, NullValidator<Address>>();
    container.Register<IValidate<UploadImage>, NullValidator<UploadImage>>();
    container.Register<IValidate<Mothership>, NullValidator<Mothership>>();
    // and the list goes on...

This repeated registration is, of course, not very practical. You might be tempted to again fix this as follows:

.. code-block:: c#

    container.Register(typeof(IValidate<>), typeof(NullValidator<>));
    
This will, however, not work because this registration will try to map any closed *IValidate<T>* abstraction to the *NullValidator<T>* implementation, but other registrations (such as *ProductValidator* and *OrderValidator*) already exist. What you need here is to make *NullValidator<T>* a fallback registration and Simple Injector allows this using the **RegisterConditional** method overloads:

.. code-block:: c#

    container.RegisterConditional(
        typeof(IValidate<>),
        typeof(NullValidator<>),
        c => !c.Handled);

The result of this registration is exactly as you would have expected to see from the individual registrations above. Each request for *IValidate<Department>*, for example, will return a *NullValidator<Department>* instance each time. The **RegisterConditional** is supplied with a predicate. In this case the predicate checks whether there already is a different registration that handles the requested service type. In that case the predicate returns *false* and the registration is not applied.

This predicate can also be used to apply types conditionally based on a number of contextual arguments. Here's an example:

.. code-block:: c#

    container.RegisterConditional(
        typeof(IValidator<>),
        typeof(LeftValidator<>),
        c => c.ServiceType.GetGenericArguments().Single().Namespace.Contains("Left"));

    container.RegisterConditional(
        typeof(IValidator<>),
        typeof(RightValidator<>),
        c => c.ServiceType.GetGenericArguments().Single().Namespace.Contains("Right"));

Simple Injector protects you from defining invalid registrations by ensuring that given the registrations do not overlap. Building on the last code snippet, imagine accidentally defining a type in the namespace "MyCompany.LeftRight". In this case both open-generic implementations would apply, but Simple Injector will never silently pick one. It will throw an exception instead.

As discussed before, the **PredicateContext.Handled** property can be used to implement a fallback mechanism. A more complex example is given below:

.. code-block:: c#

    container.RegisterConditional(
        typeof(IRepository<>),
        typeof(ReadOnlyRepository<>),
        c => typeof(IReadOnlyEntity).IsAssignableFrom(
            c.ServiceType.GetGenericArguments()[0]));

    container.RegisterConditional(
        typeof(IRepository<>),
        typeof(ReadWriteRepository<>),
        c => !c.Handled);

In the case above you tell Simple Injector to only apply the *ReadOnlyRepository<T>* registration in case the given *T* implements *IReadOnlyEntity*. Although applying the predicate can be useful, in this particular case it's better to apply a generic-type constraint to *ReadOnlyRepository<T>*. Simple Injector will automatically apply the registered type conditionally based on it generic-type constraints. So if you apply the generic-type constraint to the *ReadOnlyRepository<T>*, you can remove the predicate:

.. code-block:: c#

    class ReadOnlyRepository<T> : IRepository<T> where T : IReadOnlyEntity { }

    container.Register(
        typeof(IRepository<>),
        typeof(ReadOnlyRepository<>));
        
    container.RegisterConditional(
        typeof(IRepository<>),
        typeof(ReadWriteRepository<>),
        c => !c.Handled);

The final option in Simple Injector is to supply the **Register** or **RegisterConditional** methods with a partially-closed generic type:

.. code-block:: c#

    // SomeValidator<List<T>>
    var partiallyClosedType = typeof(SomeValidator<>).MakeGenericType(typeof(List<>));
    container.Register(typeof(IValidator<>), partiallyClosedType);

The type *SomeValidator<List<T>>* is called *partially-closed*, since although its generic-type argument has been filled in with a type, it still contains a generic-type argument. Simple Injector will be able to apply these constraints, just as it handles any other generic-type constraints.

.. _Mixing-collections-of-open-generic-and-non-generic-components:

Mixing collections of open-generic and non-generic components
=============================================================

The **Register** overload that takes in a list of assemblies only selects non-generic implementations of the given open-generic type. Open-generic implementations are skipped, because they often need special attention.

To register collections that contain both non-generic and open-generic components, a **Collection.Register** overload is available that accept a list of Type instances. For instance:

.. code-block:: c#

    container.Collection.Register(typeof(IValidator<>), new[]
    {
        typeof(DataAnnotationsValidator<>), // open generic
        typeof(CustomerValidator), // implements IValidator<Customer>
        typeof(GoldCustomerValidator), // implements IValidator<Customer>
        typeof(EmployeeValidator), // implements IValidator<Employee>
        typeof(OrderValidator) // implements IValidator<Order>
    });

In the previous example a set of *IValidator<T>* implementations is supplied to the **Collection.Register** overload. This list contains one generic implementation, namely *DataAnnotationsValidator<T>*. This leads to a registration that is equivalent to the following manual registration:

.. code-block:: c#

    container.Collection.Register<IValidator<Customer>>(
        typeof(DataAnnotationsValidator<Customer>),
        typeof(CustomerValidator),
        typeof(GoldCustomerValidator));
        
    container.Collection.Register<IValidator<Employee>>(
        typeof(DataAnnotationsValidator<Employee>),
        typeof(EmployeeValidator));
        
    container.Collection.Register<IValidator<Order>>(
        typeof(DataAnnotationsValidator<Order>),
        typeof(OrderValidator));

In other words, the supplied non-generic types are grouped by their closed *IValidator<T>* interface and the *DataAnnotationsValidator<T>* is applied to every group. This leads to three separate *IEnumerable<IValidator<T>>* registrations. One for each closed-generic *IValidator<T>* type.

.. container:: Note

    **Note**: **Collection.Register** is guaranteed to preserve the order of the types that you supply.
        
But besides these three *IEnumerable<IValidator<T>>* registrations, an invisible fourth registration is made. This is a registration that hooks onto the **unregistered type resolution** event and this will ensure that any time an *IEnumerable<IValidator<T>>* for a *T* that is anything other than *Customer*, *Employee* and *Order*, an *IEnumerable<IValidator<T>>* is returned that contains the closed-generic versions of the supplied open-generic types—*DataAnnotationsValidator<T>* in the given example.

.. container:: Note

    **Note**: This will work equally well when the open-generic types contain type constraints. In that case those types will be applied conditionally to the collections based on their generic-type constraints.

In most cases, however, manually supplying the **Collection.Register** with a list of types leads to hard-to-maintain configurations, because the registration needs to be changed for each new validator you add to the system. Instead, you can make use of one of the **Collection.Register** overloads that accepts a list of assemblies and append the open-generic type separately:

.. code-block:: c#

    container.Collection.Append(typeof(IValidator<>), typeof(DataAnnotationsValidator<>));

    container.Collection.Register(typeof(IValidator<>), typeof(IValidator<>).Assembly);

.. container:: Note

    **Warning**: This **Collection.Register** overload will request all the types from the supplied *Assembly* instances. The CLR however does not give *any* guarantees about the order in which these types are returned. Don't be surprised if the order of these types in the collection change after a recompile or even a mere application restart. In case strict ordering is required, use the **GetTypesToRegister** method (as explained below) and order types manually.
        
Alternatively, we can make use of the Container's **GetTypesToRegister** to find the types for us:

.. code-block:: c#

    var typesToRegister = container.GetTypesToRegister(
        serviceType: typeof(IValidator<>),
        assemblies: new[] { typeof(IValidator<>).Assembly) }, 
        options: new TypesToRegisterOptions { 
            IncludeGenericTypeDefinitions = true,
            IncludeComposites = false,
        });

    container.Collection.Register(typeof(IValidator<>), typesToRegister);    
    
.. container:: Note

    The **Register** and **Collection.Register** overloads that accept a list of assemblies use this **GetTypesToRegister** method internally as well. Each, however, use their own **TypesToRegisterOptions** configuration.

.. container:: Note

    **Note**: Collections in Simple Injector behave as **streams**. Please see the section about :ref:`collection types <Collection-types>` for more information.


.. _Unregistered-Type-Resolution:

Unregistered type resolution
============================

Unregistered-type resolution is the ability to get notified by the container when a type that is currently unregistered in the container, is requested for the first time. This gives the user (or extension point) the chance of registering that type. Simple Injector supports this scenario with the `ResolveUnregisteredType <https://simpleinjector.org/ReferenceLibrary/?topic=html/E_SimpleInjector_Container_ResolveUnregisteredType.htm>`_ event. Unregistered type resolution enables many advanced scenarios.

For more information about how to use this event, please take a look at the `ResolveUnregisteredType event documentation <https://simpleinjector.org/ReferenceLibrary/?topic=html/E_SimpleInjector_Container_ResolveUnregisteredType.htm>`_ in the `reference library <https://simpleinjector.org/ReferenceLibrary/>`_.


.. _Context-Based-Injection:

Context-based injection
=======================

Context-based injection is the ability to inject a particular dependency based on the context it lives in (or change the implementation based on the type it is injected into). Simple Injector contains the **RegisterConditional** method overloads that enable context-based injection.

.. container:: Note

    **Note**: In many cases context-based injection is not the best solution, and the design should be reevaluated. In some narrow cases however it can make sense.

One of the simplest use cases for **RegisterConditional** is to select an implementation depending on the consumer a dependency is injected into. Take a look at the following registrations for instance:

.. code-block:: c#

    container.RegisterConditional<ILogger, NullLogger>(
        c => c.Consumer.ImplementationType == typeof(HomeController));
    container.RegisterConditional<ILogger, FileLogger>(
        c => c.Consumer.ImplementationType == typeof(UsersController));
    container.RegisterConditional<ILogger, DatabaseLogger>(c => !c.Handled);
    
Here you register three implementations, namely *NullLogger*, *FileLogger* and *DatabaseLogger*, all of which implement *ILogger*. The registrations are made using a predicate (lambda) describing for which condition they hold. The *NullLogger* will only be injected into the *HomeController* and the *FileLogger* will only be injected into the *UsersController*. The *DatabaseLogger* on the other hand is configured as fallback registration and will be injected in all other consumers.

Simple Injector will process conditional registrations in the order in which they are made. This means that fallback registrations, such as for the previous *DatabaseLogger*, should be made last. Simple Injector will always call the predicates of all registrations to ensure no overlapping registrations are made. In case there are multiple conditional registrations that can be applied, Simple Injector will throw an exception.

.. container:: Note

    **Note**: The predicates are only used during object-graph compilation and the predicate’s result is burned in the structure of returned object graph. For a requested type, the exact same graph will be created on every subsequent call. This disallows changing the graph based on runtime conditions.
    
A very common scenario is to base the type of the injected dependency on the type of the consumer. Take for instance the following *ILogger* interface with a generic *Logger<T>* class that needs to be injected into several consumers. 

.. code-block:: c#

    public interface ILogger { }

    public class Logger<T> : ILogger { }

    public class Consumer1
    {
        public Consumer1(ILogger logger) { }
    }

    public class Consumer2
    {
        public Consumer2(ILogger logger) { }
    }

In this case you want to inject a *Logger<Consumer1>* into *Consumer1* and a *Logger<Consumer2>* into *Consumer2*. By using the **RegisterConditional** overload that accepts a *implementation type factory delegate*, you can accomplish this as follows:

.. code-block:: c#

    container.RegisterConditional(
        typeof(ILogger),
        c => typeof(Logger<>).MakeGenericType(c.Consumer.ImplementationType),
        Lifestyle.Singleton,
        c => true);

In the previous code snippet you supply the **RegisterConditional** method with a lambda presenting a *Func<TypeFactoryContext, Type>* delegate that allows building the exact implementation type based on contextual information. In this case you use the implementation type of the consuming component to build the correct closed *Logger<T>* type. You also supply a predicate, but in this case you make the registration unconditional by returning *true* from the predicate, meaning that this is the only registration for *ILogger*.

.. container:: Note

    **Note**: Although building a generic type using *Type.MakeGenericType* is relatively slow, the call to the *Func<TypeFactoryContext, Type>* delegate itself has a one-time cost. The factory delegate will only be called a finite number of times. After an object graph has been built, the delegate will not be called again when that same object graph is resolved.

.. container:: Note

    **Note**: Even though the use of a generic *Logger<T>* is a common design (with log4net as the grand godfather of this design), doesn't always make it a good design. The need for having the logger contain information about its parent type, might indicate design problems. If you're doing this, please take a look at `this Stackoverflow answer <https://stackoverflow.com/a/9915056/264697>`_. It talks about logging in conjunction with the SOLID design principles.

.. _contextual-parent-metadata:

Making contextual registrations based on the parent's metadata
--------------------------------------------------------------

Apart from making the conditional registration based on the consumer's type, other metadata can be used to make the decision of whether to inject the dependency or not. For instance, Simple Injector provides the predicate, supplied by you to the **RegisterConditional** method, with information about the member or parameter that the dependency will be injected into—this is called the injection *target*. This allows you check the target's name or its attributes and make a decision based on that metadata. Take the following example, for instance:

.. code-block:: c#

    public class ShipmentRepository : IShipmentRepository
    {
        private readonly IDbContextProvider productsContextProvider;
        private readonly IDbContextProvider customersContextProvider;
    
        public ProductRepository(
            IDbContextProvider productsContextProvider,
            IDbContextProvider customersContextProvider)
        {
            this.productsContextProvider = productsContextProvider;
            this.customersContextProvider = customersContextProvider;
        }
    }
    
The previous `ShipmentRepository` contains two dependencies, both of type `IDbContextProvider`. As a convention, the `ShipmentRepository` prefixes the parameter names with either "products" or "customers" and this allows you to make the registrations conditionally: 

.. code-block:: c#

    container.RegisterConditional<IDbContextProvider, ProductsContextProvider>(
        c => c.Consumer.Target.Name.StartsWith("products"));

    container.RegisterConditional<IDbContextProvider, CustomersContextProvider>(
        c => c.Consumer.Target.Name.StartsWith("customers"));

In this example, the name of the consumer's *injection target* (the constructor parameter) is used to determine whether the dependency should be injected or not.

.. container:: Note

    **Note**: Do note that in the previous example, the `ProductsContextProvider` and `CustomersContextProvider` implementations likely violate the Liskov Substitution Principle. In this case, a better solution is to give each implementation its own abstraction (e.g. `IProductsContextProvider` and `ICustomersContextProvider`.


.. _contextual-parent-parent:

Making contextual registrations based on the parent's parent
------------------------------------------------------------

As shown in the previous examples, Simple Injector allows looking at the dependency's direct consumer to determine whether or not the dependency should be injected, or that Simple Injector should try the next conditional registration on the consumer. This 'looking up' the dependency graph, however, is limited to looking at the dependency's direct consumer. This limitation is deliberate. Making a decision based on the parent's parent can lead to all sorts of complications and subtle bugs.

There are several ways to work around this seeming limitation in Simple Injector. The first thing you should do, however, is take a step back and see whether or not you can simplify your design, as these kinds of requirements often (but not always) come from design inefficiencies. One such issue is `Liskov Substitution Principle <https://en.wikipedia.org/wiki/Liskov_substitution_principle>`_ (LSP) violations. From this perspective, it's good to ask yourself the question: "would my consumer break when it gets injected with a dependency for another consumer?" If the answer is "yes," you are likely violating the LSP and you should first and foremost try to fix that problem first. When fixed, you'll likely see your configuration problems go away as well.

If the LSP is not violated, and changing the design is not feasible, a common solution is to make the intermediate consumer(s) generic. This is discussed in more detail in `this Stack Overflow Q/A <https://stackoverflow.com/questions/53815493/inject-dependency-dynamically-based-on-call-chain-using-simple-injector>`_.


.. _Property-Injection:

Property injection
==================

Simple Injector does not out-of-the-box inject any properties into types that get resolved by the container. In general there are two ways of doing property injection, and both are not enabled by default for reasons explained below.

Implicit property injection
---------------------------

Some containers implicitly inject public writable properties by default for any instance you resolve. They do this by mapping those properties to configured types. When no such registration exists, or when the property doesn't have a public setter, the property will be skipped. Simple Injector does not do implicit property injection, and for good reason. We think that **implicit property injection** is simply too... implicit :-). Silently skipping properties that can't be mapped can lead to a DI configuration that can't be easily verified and can therefore result in an application that fails at runtime instead of failing when the container is verified.


.. _Explicit-Property-Injection:

Explicit property injection
---------------------------

We strongly feel that explicit property injection is a much better way to go. With explicit property injection the container is forced to inject a property and the process will fail immediately when a property can't be mapped or injected. Some containers allow explicit property injection by allowing properties to be marked with attributes that are defined by the DI library. Problem with this is that this forces the application to take a dependency on the library, which is something that should be prevented.

Because Simple Injector does not encourage its users to take a dependency on the container (except for the startup path of course), Simple Injector does not contain any attributes that allow explicit property injection and it can, therefore, not explicitly inject properties out-of-the-box.

One major downside of property injection is that it caused `Temporal Coupling <https://blog.ploeh.dk/2011/05/24/DesignSmellTemporalCoupling/>`_. The use of property injection should, therefore, be very exceptional and in general constructor injection should be used in the majority of cases. If a constructor gets too many parameters (a code smell called *constructor over-injection*), it is an indication of a violation of the `Single Responsibility Principle <https://en.wikipedia.org/wiki/Single_responsibility_principle>`_ (SRP). SRP violations often lead to maintainability issues. So instead of patching constructor over-injection with property injection, the root cause should be analyzed and the type should be refactored, probably with `Facade Services <https://blog.ploeh.dk/2010/02/02/RefactoringtoAggregateServices/>`_. Another common reason to use properties is because those dependencies are optional. Instead of using optional property dependencies, best practice is to inject empty implementations (a.k.a. `Null Object pattern <https://en.wikipedia.org/wiki/Null_Object_pattern>`_) into the constructor.

Enabling property injection
---------------------------

Simple Injector contains two ways to enable property injection. First of all the :ref:`RegisterInitializer\<T\> <Configuring-Property-Injection>` method can be used to inject properties (especially configuration values) on a per-type basis. Take for instance the following code snippet:

.. code-block:: c#

    container.RegisterInitializer<HandlerBase>(handlerToInitialize => {
        handlerToInitialize.ExecuteAsynchronously = true;
    });

In the previous example an *Action<T>* delegate is registered that will be called every time the container creates a type that inherits from *HandlerBase*. In this case, the handler will set a configuration value on that class.

.. container:: Note

    **Note**: although this method can also be used injecting services, please note that the :doc:`Diagnostic Services <diagnostics>` will be unable to see and analyze that dependency.


.. _ImportPropertySelectionBehavior:
.. _IPropertySelectionBehavior:

IPropertySelectionBehavior
--------------------------

The second way to inject properties is by implementing a custom **IPropertySelectionBehavior**. The *property selection behavior* is a general extension point provided by the container, to override the library's default behavior (which is to *not* inject properties). The following example enables explicit property injection using attributes, using the *ImportAttribute* from the *System.ComponentModel.Composition.dll*:

.. code-block:: c#

    using System;
    using System.ComponentModel.Composition;
    using System.Linq;
    using System.Reflection;
    using SimpleInjector.Advanced;

    class ImportPropertySelectionBehavior : IPropertySelectionBehavior
    {
        public bool SelectProperty(Type implementationType, PropertyInfo prop) =>
            prop.GetCustomAttributes(typeof(ImportAttribute)).Any();
    }

The previous class can be registered as follows:

.. code-block:: c#

    var container = new Container();
    container.Options.PropertySelectionBehavior = new ImportPropertySelectionBehavior();

This enables explicit property injection on all properties that are marked with the [Import] attribute and an exception will be thrown when the property cannot be injected for whatever reason.

.. container:: Note

    **Tip**: Properties injected by the container through the **IPropertySelectionBehavior** will be analyzed by the :doc:`Diagnostic Services <diagnostics>`.

.. container:: Note

    **Note**: The **IPropertySelectionBehavior** extension mechanism can also be used to implement implicit property injection. There's `an example of this <https://github.com/simpleinjector/SimpleInjector/blob/master/src/SimpleInjector.CodeSamples/ImplicitPropertyInjectionExtensions.cs>`_ in the source code. Doing so, however, is not encouraged because of the reasons given above.

.. _Covariance-Contravariance:

Covariance and Contravariance
=============================

Since version 4.0 of the .NET framework, the type system allows `Covariance and Contravariance in Generics <https://msdn.microsoft.com/en-us/library/dd799517.aspx>`_ (especially interfaces and delegates). This allows, for instance, to use a *IEnumerable<string>* as an *IEnumerable<object>* (covariance), or to use an *Action<object>* as an *Action<string>* (contravariance).

In some circumstances, the application design can benefit from the use of covariance and contravariance (or *variance* for short) and it would be beneficial if the container returned services that were 'compatible' with the requested service, even when the requested service type itself is not explicitly registered. To stick with the previous example, the container could return an *IEnumerable<string>* even when an *IEnumerable<object>* is requested.

When resolving a collection, Simple Injector will resolve all assignable (variant) implementations of the requested service type as part of the requested collection.

Take a look at the following application design around the *IEventHandler<in TEvent>* interface:

.. code-block:: c#

    public interface IEventHandler<in TEvent>
    {
        void Handle(TEvent e);
    }

    public class CustomerMovedEvent
    {
        public readonly Guid CustomerId;
        public CustomerMovedEvent(Guid customerId)
        {
            this.CustomerId = customerId;
        }
    }

    public class CustomerMovedAbroadEvent : CustomerMovedEvent
    {
        public CustomerMovedEvent(Guid customerId) : base(customerId) { }    
    }

    public class SendFlowersToMovedCustomer : IEventHandler<CustomerMovedEvent>
    {
        public void Handle(CustomerMovedEvent e) { ... }
    }

    public class WarnShippingDepartmentAboutMove : IEventHandler<CustomerMovedAbroadEvent>
    {
        public void Handle(CustomerMovedAbroadEvent e) { ... }
    }    

The design contains two event classes *CustomerMovedEvent* and *CustomerMovedAbroadEvent* (where *CustomerMovedAbroadEvent* inherits from *CustomerMovedEvent*) and two concrete event handlers *SendFlowersToMovedCustomer* and *WarnShippingDepartmentAboutMove*. These classes can be registered using the following registration:

.. code-block:: c#

    // Configuration
    container.Collection.Register(
        typeof(IEventHandler<>),
        typeof(IEventHandler<>).Assembly);

    // Usage
    var handlers = container.GetAllInstances<IEventHandler<CustomerMovedAbroadEvent>>();

    foreach (var handler in handlers)
    {
        Console.WriteLine(handler.GetType().Name);
    }
    
With the given classes, the code snippet above will give the following output:

.. code-block:: c#

    SendFlowersToMovedCustomer
    WarnShippingDepartmentAboutMove
    
Although we requested all registrations for `IEventHandler<CustomerMovedAbroadEvent>`, the container returned both `IEventHandler<CustomerMovedEvent>` and `IEventHandler<CustomerMovedAbroadEvent>` implementations. Simple Injector did this because the `IEventHandler<in TEvent>` interface was defined with the ***in*** keyword, which allows `IEventHandler<CustomerMovedEvent>` implementations to be part of `IEventHandler<CustomerMovedAbroadEvent>` collections—because `CustomerMovedAbroadEvent` inherits from `CustomerMovedEvent`, `SendFlowerToMovedCustomer` can also process `CustomerMovedAbroadEvent` events.

.. container:: Note

    **Tip**: If you don't want Simple Injector to resolve variant registrations remove the **in** and **out** keywords from the interface definition. i.e. the **in** and **out** keywords are the trigger for Simple Injector to apply variance.

.. container:: Note

    **Tip**: Don't mark generic-type arguments with **in** and **out** keywords by default, even if Resharper tells you to. Most of the generic abstractions you define will *always* have exactly one non-generic implementation but marking the interface with **in** and **out** keywords communicates that variance is expected and there could, therefore, be multiple applicable implementations. This will confuse the reader of your code. Only apply these keywords *if* variance is actually required. You should typically not use variance when defining `ICommandHandler<TCommand>` or `IQueryHandler<TQuery, TResult>`, but it might make sense for `IEventHandler<in TEvent>` and `IValidator<in T>`.
    
.. container:: Note
    
    **Note**: Simple Injector only resolves variant implementations for collections that are registered using the *Collection.Register* overloads. In case you are resolving a single instance using *GetInstance<T>* then Simple Injector will not return an assignable type, even if the exact type is not registered, because this could easily lead to ambiguity—Simple Injector will not know which implementation to select.

.. _Plugins:

Registering plugins dynamically
===============================

Applications with a plugin architecture often allow plugin assemblies to be dropped in a special folder and to be picked up by the application, without the need of a recompile. Although Simple Injector has no out-of-the-box support for this, registering plugins from dynamically loaded assemblies can be implemented in a few lines of code. Here is an example:

.. code-block:: c#

    string pluginDirectory =
        Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Plugins");

    var pluginAssemblies =
        from file in new DirectoryInfo(pluginDirectory).GetFiles()
        where file.Extension.ToLower() == ".dll"
        select Assembly.Load(AssemblyName.GetAssemblyName(file.FullName));

    container.Collection.Register<IPlugin>(pluginAssemblies);

The given example makes use of an *IPlugin* interface that is known to the application, and probably located in a shared assembly. The dynamically loaded plugin .dll files can contain multiple classes that implement *IPlugin*, and all concrete, non-generic types that implement *IPlugin* (and are neither a composite nor decorator) will be registered using the **Collection.Register** method and can get resolved using the default auto-wiring behavior of the container, meaning that the plugin must have a single public constructor and all constructor arguments must be resolvable by the container. The plugins can get resolved using *container.GetAllInstances<IPlugin>()* or by adding an *IEnumerable<IPlugin>* argument to a constructor.

.. container:: Note

    **Note**: Collections in Simple Injector behave as **streams**. Please see the section about :ref:`collection types <Collection-types>` for more information.
