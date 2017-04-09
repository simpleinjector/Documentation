=================================================================
Compiler Error: 'InjectionConsumerInfo.ServiceType' is deprecated
=================================================================

With Simple Injector v4, the properties **InjectionConsumerInfo.ServiceType** and **ExpressionBuildingEventArgs.RegisteredServiceType** have been marked obsolete and an exception will be thrown when these properties are called at runtime. 

When using these properties the C# compiler will emit one of the following compiler errors:

.. container:: Note

    Error CS0619 'InjectionConsumerInfo.ServiceType' is obsolete: 'This property has been removed. Please use ImplementationType instead.

.. container:: Note

    Error CS0619 'ExpressionBuildingEventArgs.RegisteredServiceType' is obsolete: 'This property has been removed. Please use KnownImplementationType instead.

What's the problem?
===================

The **InjectionConsumerInfo** and **ExpressionBuildingEventArgs** classes are used at a point in the pipeline where only the given implementation type is known. Although in some cases the actual service type could be determined correctly, in other cases it just contained a wrong value (of a different registration).

**InjectionConsumerInfo** and **ExpressionBuildingEventArgs** are used by **Registration** instances. A **Registration** instance is responsible for creating and caching a specific implementation, but it has no notion of the abstraction/service for which it is registered. This is deliberate, since a **Registration** can be reused by multiple **InstanceProducer** instances. **InstanceProducer** instances are responsible of the mapping from an abstraction to the implementation provided by a **Registration**.

The following example shows multiple registrations for the same implementation:

.. code-block:: c#

    container.Register<IFoo, FooBar>(Lifestyle.Singleton);
    container.Register<IBar, FooBar>(Lifestyle.Singleton);

These registrations result in two separate **InstanceProducer** instances (one for *IFoo* and one for *IBar*), but both use the same **Registration** instance for *FooBar*. This ensures that a single instance of *FooBar* will exist within that **Container** instance.

The result of this is that when *FooBar* is built, there are multiple possible abstractions. However, since a **Registration** is only built once, it could only be aware of the first service type it is built for, which could be either *IFoo* or *IBar*. 

Since the use of these properties was ambiguous and could lead to fragile configurations, they needed to be removed.

So what should I do instead?
============================

In general, try to use the **ImplementationType** or **KnownImplementationType** properties instead. If required, you can extract the actual service type from the implementation type using the new **IsClosedTypeOf**, **GetClosedTypeOf** and **GetClosedTypesOf** extension methods.

The following snippet shows how to use the **GetClosedTypeOf** method:

.. code-block:: c#

    container.RegisterConditional(typeof(IRepository<,>), typeof(ReadOnlyRepo<>), context =>
    {
        var implementation = context.Consumer.ImplementationType;
        var serviceType = implementation.GetClosedTypeOf(typeof(IRepository<>));
        var entityType = serviceType.GetGenericArguments()[0];
        return typeof(IReadOnlyEntity).IsAssignableFrom(entityType);
    });

The **GetClosedTypeOf** will throw an exception when the **ImplementationType** implements more than one closed-generic version of the supplied open-generic type. In case multiple closed-generic abstractions are expected, **GetClosedTypesOf** can be used. It returns a *Type* array.