====================
Extensibility Points
====================

Simple Injector allows much of its default behavior to be changed or extended. This chapter describes the available extension points and shows examples of how to use them. Do note that in most cases we advice developers to stick with the default behavior, because this behavior is based on best practices.

* :ref:`Overriding Constructor Resolution Behavior <Overriding-Constructor-Resolution-Behavior>`
* :ref:`Property Injection <Overriding-Property-Injection-Behavior>`
* :ref:`Overriding Parameter Injection Behavior <Overriding-Parameter-Injection-Behavior>`
* :ref:`Resolving Unregistered Types <Resolving-Unregistered-Types>`
* :ref:`Overriding Lifestyle Selection Behavior <Overriding-Selection-Behavior>`
* :ref:`Intercepting the Creation of Types <Intercepting-the-Creation-of-Types>`
* :ref:`Building up external instances <Building-Up-External-Instances>`
* :ref:`Interception of Resolved Object Graphs <Interception-of-Resolved-Object-Graphs>`

.. _Overriding-Constructor-Resolution-Behavior:

Overriding Constructor Resolution Behavior
==========================================

Out of the box, Simple Injector only allows the creation of classes that contain a single public constructor. This behavior is chosen deliberately because `having multiple constructors is an anti-pattern <https://cuttingedge.it/blogs/steven/pivot/entry.php?id=97>`_.

There are some exceptional circumstances though, where we don't control the amount of public constructors a type has. Code generators for instance, can have this annoying side effect. Earlier versions of the `T4MVC <https://github.com/T4MVC/T4MVC>`_ template for instance did this.

In these rare cases we need to override the way Simple Injector does its constructor overload resolution. This can be done by creating custom implementation of **IConstructorResolutionBehavior**. The default behavior can be replaced by setting the *Container.Options.ConstructorResolutionBehavior* property.

.. code-block:: c#

    public interface IConstructorResolutionBehavior {
        ConstructorInfo GetConstructor(Type implementationType);
    }

Simple Injector will call into the registered **IConstructorResolutionBehavior** when the type is registered to allow the **IConstructorResolutionBehavior** implementation to verify the type. The implementation is called again when the registered type is resolved for the first time.

The following example changes the constructor resolution behavior to always select the constructor with the most parameters (the greediest constructor):

.. code-block:: c#

    // Custom constructor resolution behavior
    public class GreediestConstructorBehavior : IConstructorResolutionBehavior {
        public ConstructorInfo GetConstructor(Type implementationType) {
            return (
                from ctor in implementationType.GetConstructors()
                orderby ctor.GetParameters().Length descending
                select ctor)
                .First();
        }
    }

    // Usage
    var container = new Container();
    container.Options.ConstructorResolutionBehavior = new GreediestConstructorBehavior();

The following bit more advanced example changes the constructor resolution behavior to always select the constructor with the most parameters from the list of constructors with only resolvable parameters:

.. code-block:: c#

    public class MostResolvableParametersConstructorResolutionBehavior 
        : IConstructorResolutionBehavior {
        private readonly Container container;

        public MostResolvableParametersConstructorResolutionBehavior(Container container) {
            this.container = container;
        }

        private bool IsCalledDuringRegistrationPhase => !this.container.IsLocked();

        [DebuggerStepThrough]
        public ConstructorInfo GetConstructor(Type implementationType) {
            var constructor = this.GetConstructors(implementationType).FirstOrDefault();
            if (constructor != null) return constructor;
            throw new ActivationException(BuildExceptionMessage(implementationType));
        }

        private IEnumerable<ConstructorInfo> GetConstructors(Type implementation) =>
            from ctor in implementation.GetConstructors()
            let parameters = ctor.GetParameters()
            where this.IsCalledDuringRegistrationPhase
                || implementation.GetConstructors().Length == 1
                || ctor.GetParameters().All(this.CanBeResolved)
            orderby parameters.Length descending
            select ctor;

        private bool CanBeResolved(ParameterInfo parameter) =>
            this.GetInstanceProducerFor(new InjectionConsumerInfo(parameter)) != null;

        private InstanceProducer GetInstanceProducerFor(InjectionConsumerInfo i) =>
            this.container.Options.DependencyInjectionBehavior.GetInstanceProducer(i, false);

        private static string BuildExceptionMessage(Type type) =>
            !type.GetConstructors().Any()
                ? TypeShouldHaveAtLeastOnePublicConstructor(type)
                : TypeShouldHaveConstructorWithResolvableTypes(type);

        private static string TypeShouldHaveAtLeastOnePublicConstructor(Type type) =>
            string.Format(CultureInfo.InvariantCulture,
                "For the container to be able to create {0}, it should contain at least " +
                "one public constructor.", type.ToFriendlyName());

        private static string TypeShouldHaveConstructorWithResolvableTypes(Type type) =>
            string.Format(CultureInfo.InvariantCulture,
                "For the container to be able to create {0}, it should contain a public " +
                "constructor that only contains parameters that can be resolved.", 
                type.ToFriendlyName());
    }

    // Usage
    var container = new Container();
    container.Options.ConstructorResolutionBehavior =
        new MostResolvableConstructorBehavior(container);

The previous examples changed the constructor overload resolution for all registered types. This is usually not the best approach, since this promotes ambiguity in design of our classes. Since ambiguity is usually only a problem in code generation scenarios, it's best to only override the behavior for types that are affected by the code generator.

.. _Overriding-Property-Injection-Behavior:

Overriding Property Injection Behavior
======================================

Attribute based property injection and implicit property injection are not supported by Simple Injector out of the box. With attribute based property injection the container injects properties that are decorated with an attribute. With implicit property injection the container automatically injects all properties that can be mapped to a registration, but silently skips other properties. An extension point is provided to change the library's default behavior, which is to **not** inject any property at all.

Out of the box, Simple Injector does allow explicit property injection based on registration of delegates using the **RegisterInitializer** method:

.. code-block:: c#

    container.Register<ILogger, FileLogger>();
    container.RegisterInitializer<FileLogger>(instance => {
        instance.Path = "c:\logs\log.txt";
    });

This enables property injection on a per-type basis and it allows configuration errors to be spot by the C# compiler and is especially suited for injection of configuration values. Downside of this approach is that the :doc:`Diagnostic Services <diagnostics>` will not be able to analyze properties injected this way and although the **RegisterInitializer** can be called on base types and interfaces, it is cumbersome when applying property injection on a larger scale.

The Simple Injector API exposes the **IPropertySelectionBehavior** interface to change the way the library does property injection. The example below shows a custom **IPropertySelectionBehavior** implementation that enables attribute based property injection using any custom attribute:

.. code-block:: c#

    using System;
    using System.Linq;
    using System.Reflection;
    using SimpleInjector.Advanced;

    class PropertySelectionBehavior<TAttribute> : IPropertySelectionBehavior
        where TAttribute : Attribute {
        public bool SelectProperty(PropertyInfo prop) {
            return prop.GetCustomAttributes(typeof(TAttribute)).Any();
        }
    }

    // Usage:
    var container = new Container();
    container.Options.PropertySelectionBehavior = 
        new PropertySelectionBehavior<MyInjectAttribute>();

This enables explicit property injection on all properties that are marked with the supplied attribute (in this case **MyInjectAttribute**). In case a property is decorated that can't be injected, the container will throw an exception.

.. container:: Note

    **Tip**: Dependencies injected by the container through the **IPropertySelectionBehavior** will be analyzed by the :doc:`Diagnostic <diagnostics>`, just like any constructor dependency is analyzed.

Implicit property injection can be enabled by creating an **IPropertySelectionBehavior** implementation that queries the container to check whether the property's type to be registered in the container:

.. code-block:: c#

    public class ImplicitPropertyInjectionBehavior : IPropertySelectionBehavior {
        private readonly IPropertySelectionBehavior original;
        private readonly ContainerOptions options;

        internal ImplicitPropertyInjectionBehavior(Container container) {
            this.options = container.Options;
            this.original = container.Options.PropertySelectionBehavior;
        }

        public bool SelectProperty(Type t, PropertyInfo p) =>
            this.IsImplicitInjectable(t, p) || this.original.SelectProperty(t, p);

        private bool IsImplicitInjectable(Type t, PropertyInfo p) =>
            IsInjectableProperty(p) && this.CanBeResolved(t, p);

        private static bool IsInjectableProperty(PropertyInfo property) =>
            property.CanWrite && property.GetSetMethod(nonPublic: false)?.IsStatic == false;

        private bool CanBeResolved(Type t, PropertyInfo property) =>
            this.GetProducer(new InjectionConsumerInfo(t, property)) != null;

        private InstanceProducer GetProducer(InjectionConsumerInfo info) =>
            this.options.DependencyInjectionBehavior.GetInstanceProducer(info, false);
    }
    
    // Usage:
    var container = new Container();
    container.Options.PropertySelectionBehavior = 
        new ImplicitPropertyInjectionBehavior(container);

.. container:: Note

    **Warning**: Silently skipping properties that can't be mapped can lead to a DI configuration that can't be easily verified and can therefore result in an application that fails at runtime instead of failing when the container is verified. Prefer explicit property injection -or better- constructor injection whenever possible.

.. _Overriding-Parameter-Injection-Behavior:

Overriding Parameter Injection Behavior
=======================================

Simple Injector does not allow injecting primitive types (such as integers and string) into constructors. The **IDependencyInjectionBehavior** interface is defined by the library to change this default behavior.

The following article contains more information about changing the library's default behavior: `Primitive Dependencies with Simple Injector <https://cuttingedge.it/blogs/steven/pivot/entry.php?id=94>`_.

.. _Resolving-Unregistered-Types:

Resolving Unregistered Types
============================

Unregistered type resolution is the ability to get notified by the container when a type is requested that is currently unregistered in the container. This gives you the change of registering that type. Simple Injector supports this scenario with the `ResolveUnregisteredType <https://simpleinjector.org/ReferenceLibrary/?topic=html/E_SimpleInjector_Container_ResolveUnregisteredType.htm>`_ event. Unregistered type resolution enables many advanced scenarios. The library itself uses this event for implementing enabling support for :ref:`decorators <Decorators>`.

For more information about how to use this event, please look at the `ResolveUnregisteredType event documentation <https://simpleinjector.org/ReferenceLibrary/?topic=html/E_SimpleInjector_Container_ResolveUnregisteredType.htm>`_ in the `reference library <https://simpleinjector.org/ReferenceLibrary/>`_.

.. _Overriding-Selection-Behavior:

Overriding Lifestyle Selection Behavior
=======================================

By default, when registering a type without explicitly specifying a lifestyle, that type is registered using the **Transient** lifestyle. This behavior can be overridden and this is especially useful in batch-registration scenarios.

Here are some examples of registration calls that all register types as *Transient*:

.. code-block:: c#

    container.Register<IUserContext, AspNetUserContext>();
    container.Register<ITimeProvider>(() => new RealTimeProvider());
    container.RegisterCollection<ILogger>(new[] { typeof(SqlLogger), typeof(FileLogger) });
    container.Register(typeof(IHandler<>), new[] { typeof(IHandler<>).Assembly });
    container.RegisterDecorator(typeof(IHandler<>), typeof(LoggingHandlerDecorator<>));
    container.RegisterConditional(typeof(IValidator<>), typeof(NullVal<>), c => !c.Handled);
    container.RegisterMvcControllers();
    container.RegisterWcfServices();
    container.RegisterWebApiControllers(GlobalConfiguration.Configuration);

Most of these methods have overloads that allow supplying a different lifestyle. This works great in situations where you register a single type (using one of the **Register** method overloads for instance), and when all registrations need the same lifestyle. This is less suitable for cases where you batch-register a set of types where each type needs a different lifestyle.

In this case we need to override the way Simple Injector does lifestyle selection. There are two ways of overriding the lifestyle selection.

Overriding the lifestyle selection can done globally by changing the **Container.Options.DefaultLifestyle** property, as shown in the following example:

.. code-block:: c#

    container.Options.DefaultLifestyle = Lifestyle.Singleton;

Any registration that's not explicitly supplied with a lifestyle, will get this lifestyle. In this case all registrations will be made as **Singleton**.

A more common need is to select the lifestyle based on some context. This can be done by creating custom implementation of **ILifestyleSelectionBehavior**.

.. code-block:: c#

    public interface ILifestyleSelectionBehavior {
        Lifestyle SelectLifestyle(Type implementationType);
    }

When no lifestyle is explicitly supplied by the user, Simple Injector will call into the registered **ILifestyleSelectionBehavior** when the type is registered to allow the **ILifestyleSelectionBehavior** implementation to select the proper lifestyle. The default behavior can be replaced by setting the **Container.Options.LifestyleSelectionBehavior** property.

Simple Injector's default **ILifestyleSelectionBehavior** implementation simply forwards the call to **Container.Options.DefaultLifestyle**.

The following example changes the lifestyle selection behavior to always register those instances as singleton:

.. code-block:: c#

    using System;
    using SimpleInjector;
    using SimpleInjector.Advanced;

    // Custom lifestyle selection behavior
    public class SingletonLifestyleSelectionBehavior : ILifestyleSelectionBehavior {
        public Lifestyle SelectLifestyle(Type implementationType) {
            return Lifestyle.Singleton;
        }
    }

    // Usage
    var container = new Container();
    container.Options.LifestyleSelectionBehavior = new SingletonLifestyleSelectionBehavior();

In case there is always a single default lifestyle, a much easier to set the **Container.Options.DefaultLifestyle** property:

.. code-block:: c#

    container.Options.DefaultLifestyle = Lifestyle.Singleton;

The default **Container.Options.LifestyleSelectionBehavior** implementation simply returns the configured **Container.Options.DefaultLifestyle**.

It gets more interesting when the lifestyle changes on the given type. The following example changes the lifestyle selection behavior to pick the lifestyle based on an attribute:

.. code-block:: c#

    using System;
    using System.Reflection;
    using SimpleInjector.Advanced;

    // Attribute for use by the application
    public enum CreationPolicy { Transient, Scoped, Singleton }

    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Interface,
        Inherited = false, AllowMultiple = false)]
    public sealed class CreationPolicyAttribute : Attribute {
        public CreationPolicyAttribute(CreationPolicy policy) {
            this.Policy = policy;
        }

        public CreationPolicy Policy { get; }
    }

    // Custom lifestyle selection behavior
    public class AttributeBasedLifestyleSelectionBehavior : ILifestyleSelectionBehavior {
        private const CreationPolicy DefaultPolicy = CreationPolicy.Transient;

        public Lifestyle SelectLifestyle(Type type) => ToLifestyle(GetPolicy(type));

        private static Lifestyle ToLifestyle(CreationPolicy policy) =>
            policy == CreationPolicy.Singleton ? Lifestyle.Singleton :
            policy == CreationPolicy.Scoped ? Lifestyle.Scoped :
            Lifestyle.Transient;

        private static CreationPolicy GetPolicy(Type type) =>
            type.GetCustomAttribute<CreationPolicyAttribute>()?.Policy ?? DefaultPolicy;
    }

    // Usage
    var container = new Container();
    container.Options.DefaultScopedLifestyle = new WebRequestLifestyle();

    container.Options.LifestyleSelectionBehavior =
        new AttributeBasedLifestyleSelectionBehavior();
        
    container.Register<IUserContext, AspNetUserContext>();

    // Usage in application
    [CreationPolicy(CreationPolicy.Scoped)]
    public class AspNetUserContext : IUserContext {
        // etc
    }

.. _Intercepting-the-Creation-of-Types:

Intercepting the Creation of Types
==================================

Intercepting the creation of types allows registrations to be modified. This enables all sorts of advanced scenarios where the creation of a single type or whole object graphs gets altered. Simple Injector contains two events that allow altering the type's creation: `ExpressionBuilding <https://simpleinjector.org/ReferenceLibrary/?topic=html/E_SimpleInjector_Container_ExpressionBuilding.htm>`_ and `ExpressionBuilt <https://simpleinjector.org/ReferenceLibrary/?topic=html/E_SimpleInjector_Container_ExpressionBuilding.htm>`_. Both events are quite similar but are called in different stages of the :ref:`building pipeline <Resolve-Pipeline>`. 

The **ExpressionBuilding** event gets called just after the registration's expression has been created that new up a new instance of that type, but before any lifestyle caching has been applied. This event can for instance be used for :ref:`Context based injection <Context-Based-Injection>`.

The **ExpressionBuilt** event gets called after the lifestyle caching has been applied. After lifestyle caching is applied much of the information that was available about the creation of that registration during the time **ExpressionBuilding** was called, is gone. While **ExpressionBuilding** is especially suited for changing the relationship between the resolved type and its dependencies, **ExpressionBuilt** is especially useful for applying decorators or :ref:`applying interceptors <Interception>`.

Note that Simple Injector has built-in support for :ref:`applying decorators <Decorators>` using the `RegisterDecorator <https://simpleinjector.org/ReferenceLibrary/?topic=html/Overload_SimpleInjector_Extensions_DecoratorExtensions_RegisterDecorator.htm>`_ extension methods. These methods internally use the **ExpressionBuilt** event.

.. _Building-Up-External-Instances:

Building up External Instances
==============================

Some frameworks insist in creating some of the classes we write and want to manage their lifetime. A notorious example of this is ASP.NET Web Forms. One of the symptoms we often see with those frameworks is that the classes that the framework creates need to have a default constructor.

This disallows Simple Injector to create those instances and inject dependencies into their constructor. But Simple Injector can still be asked to initialize such instance according the container's configuration. This is especially useful when overriding the default :ref:`property injection behavior <Overriding-Property-Injection-Behavior>`.

The following code snippet shows how an external instance can be initialized:

.. code-block:: c#
    
    public static BuildUp(Page page) {
        InstanceProducer producer =
            container.GetRegistration(page.GetType(), throwOnFailure: true);
        Registration registration = producer.Registration;
        registration.InitializeInstance(page);
    }

This allows any properties and initializers to be applied, but obviously doesn't allow the lifestyle to be changed, or any decorators to be applied.
    
By calling the **GetRegistration** method, the container will create and cache an *InstanceProducer* instance that is normally used to create the instance. Note however, that the **GetRegistration** method restricts the shape of the type to initialize. Since **GetRegistration** is used in cases where Simple Injector creates types for you, Simple Injector will therefore check whether it can create that type. This means that if this type has a constructor with arguments that Simple Injector can't inject (for instance because there are primitive type arguments in there), an exception will be thrown.

In that particular case, instead of requesting an *InstanceProducer* from the container, you need to create a *Registration* class using the *Lifestyle* class:

.. code-block:: c#
    
    Registration registration =
        Lifestyle.Transient.CreateRegistration(page.GetType(), container);
    registration.InitializeInstance(page);
    
Do note however that if you create *Registration* instances manually, make sure you cache them. *Registration* instances generate expression trees and compile them down to a delegate. This is a time -and memory- consuming operation. But every second time you call **InitializeInstance** on the same *Registration* instance, it will be fast as hell.

.. _Interception-of-Resolved-Object-Graphs:

Interception of Resolved Object Graphs
======================================

Simple Injector allows registering a delegate that will be called every time an instance is resolved directly from the container. This allows executing code just before and after an object graph gets resolved. This allows plugging in monitoring or diagnosing the container.

The `Glimpse plugin for Simple Injector <https://www.nuget.org/packages/Glimpse.SimpleInjector/>`_ for instance, makes use of this hook to allow displaying information about which objects where resolved during a web request.

The following example shows the **Options.RegisterResolveInterceptor** method in action:

.. code-block:: c#
    
    container.Options.RegisterResolveInterceptor(CollectResolvedInstance, c => true);
        
    private static object CollectResolvedInstance(InitializationContext context, 
        Func<object> instanceProducer)
    {
        // Invoke the delegate that calls into Simple Injector to get the requested service.
        object instance = instanceProducer();
        
        // Collect request specific data for display to the user.
        List<InstanceInitializationData> list = GetListForCurrentRequest(ResolvedInstances);
        list.Add(new InstanceInitializationData(context, instance));
            
        // Return the resolve instance.
        return instance;
    }

The example above shows the registration code from the Glimpse plugin component. It registers an interception delegate to the *CollectResolvedInstance* method by calling *container.Options.RegisterResolveInterceptor*. The *c => true* lambda informs Simple Injector that the *CollectResolvedInstance* method should always be applied for every service that is being resolved. This makes sense for the Glimpse plugin, because the user would want to get a complete view of what is being resolved during that request.

When a user calls **Container.GetInstance** or **InstanceProducer.GetInstance**, instead of creating the requested instance, Simple Injector will call the *CollectResolvedInstance* method and supplies to that method:

#. An **InitializationContext** that contains information about the service that is requested.
#. An *Func<object>* delegate that allows the requested instance to be created.

The **InitializationContext** allows access to the **InstanceProducer** and **Registration** instances that describe the service's registration. These two types enable detailed analysis of the resolved service, if required.

An **InstanceProducer** instance is responsible of caching the compiled factory delegate that allows the creation of new instances (according to their lifestyle) that is created. This factory delegate is a *Func<object>*. In case a *resolve interceptor* gets applied to an **InstanceProducer**, instead of calling that *Func<object>*, the **InstanceProducer** will call the resolve interceptor, while supplying that original *Func<object>* to the interceptor.