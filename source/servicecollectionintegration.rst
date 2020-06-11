===================================
ServiceCollection Integration Guide
===================================

With the introduction of .NET Core, Microsoft introduced its own container-based configuration system, which the specific aim of simplifying integration of framework and third-party components. When building a Console application, however, for the most part, this configuration system can be safely ignored, as explained in the :doc:`Console Application Integration Guide <consoleintegration>`.

In some cases, however, framework and third-party components are tightly coupled to this new configuration system. Entity Framework's DbContext pooling feature is an example where this tight coupling was introduced—pooling can practically only be used by configuring it in Microsoft's `IServiceCollection`. As application developer, however, you wish to use Simple Injector to compose your application components. But those application components need to be fed with those framework and third-party services from time to time, which means framework components need to be pulled in from the .NET configuration system.

.. container:: Note

    **NOTE**: Please note that when integrating Simple Injector, you do **not** replace .NET's built-in container, as advised by `the Microsoft documentation <https://docs.microsoft.com/en-us/aspnet/core/fundamentals/dependency-injection#replacing-the-default-services-container>`_. The practice with Simple Injector is to use Simple Injector to build up object graphs of your *application components* and let the built-in container build framework and third-party components. To understand the rationale around this, please read `this article <https://simpleinjector.org/blog/2016/06/whats-wrong-with-the-asp-net-core-di-abstraction/>`_.

To combat this unfortunate tight coupling of framework and third-party components, Simple Injector introduces the `Simple Injector ServiceCollection integration package <https://www.nuget.org/packages/SimpleInjector.Integration.ServiceCollection>`_. It allows you to register your application components in Simple Injector, while keeping the necessary framework and third-party components configured in Microsoft's `ServiceCollection`, while allowing Simple Injector to inject those framework components into your application components by requesting them from the built-in configuration system on your behalf.

.. container:: Note

    **NOTE**: The *SimpleInjector.Integration.ServiceCollection* package defines the core behavior that the :doc:`.NET Generic Host Integration Guide <generichostintegration>` and :doc:`ASP.NET Core MVC Integration Guide <aspnetintegration>` build upon. If you're building a Generic Host or ASP.NET Core application, please read the documentation of those topics.

The following code snippet shows how to use the integration package to apply Simple Injector to your Console application. In this example, the application requires working with framework components that can't easily be configured without `IServiceCollection` (in this case, a pooled `DbContext`):

.. code-block:: c#

    public static void Main()
    {
        var container = new Container();
        
        var services = new ServiceCollection()
            // Add all framework components you wish to inject into application
            // components, for instance:
            .AddDbContextPool<AdventureWorksContext>(options => { /*options */ })
            
            // Integrate with Simple Injector
            .AddSimpleInjector(container);
            
        services
            // Save yourself pain and agony and always use "validateScopes: true"
            .BuildServiceProvider(validateScopes: true)
            
            // Ensures framework components can be retrieved
            .UseSimpleInjector(container); 
        
        // Register application components.
        container.Register<MainService>();
        
        // Always verify the container
        container.Verify();
        
        // Run application code
        using (AsyncScopedLifestyle.BeginScope(container))
        {
            var service = container.GetInstance<MainService>();
            service.DoAwesomeStuff();
        }
    }


.. _cross-wiring-third-party-services:

Cross wiring framework and third-party services
===============================================

When your application code needs a service which is defined by .NET Core or any third-party library, it is sometimes necessary to get such a dependency from .NET Core's built-in configuration system and inject it into your application components, which are constructed by Simple Injector. This is called *cross wiring*. Cross wiring is the process where a type is created and managed by the .NET Core configuration system and fed to Simple Injector so it can use the created instance to supply it as a dependency to your application code.

Simple Injector will automatically cross wire framework components from the framework's `IServiceProvider` in case both the **AddSimpleInjector** and **UseSimpleInjector** extension methods are called:

.. code-block:: c#

    IServiceProvider provider = services
        .AddSimpleInjector()
        .BuildServiceProvider(validateScopes: true);
        
    // Ensures framework components are cross wired.
    provider.UseSimpleInjector(container);

This provides integration with Simple Injector on top of the `IServiceProvider` abstraction.

In the case where the *SimpleInjector.Integration.AspNetCore* package is used in an ASP.NET Core application, there is an identical **UseSimpleInjector** extension method on top of `IApplicationBuilder`, which can be called as part of the `Startup`'s `Configure` method:

.. code-block:: c#

    public void Configure(IApplicationBuilder app, IHostingEnvironment env)
    {
        // Ensures framework components are cross wired.
        app.UseSimpleInjector(container);
        
        ...
    }
    
When auto cross wiring is enabled, it accomplishes the following:

* Anytime Simple Injector needs to resolve a dependency that is not registered, it queries the framework's `IServiceCollection` to see whether this dependency exists in the ASP.NET Core configuration system.
* In case the dependency exists in `IServiceCollection`, Simple Injector ensures that the dependency is resolved from the .NET Core configuration system anytime it is requested—in other words, by requesting it from the `IServiceProvider`.
* In doing so, Simple Injector preserves the framework dependency's lifestyle. This allows application components that depend on external services to be :doc:`diagnosed <diagnostics>` for :doc:`Lifestyle Mismatches <LifestyleMismatches>`.
* In case no suitable dependency exists in the `IServiceCollection`, Simple Injector falls back to its default behavior. This most likely means that an expressive exception is thrown, because the object graph can't be fully composed.

Simple Injector's auto cross wiring has the following limitations:

* Collections (e.g. `IEnumerable<T>`) are not auto cross wired because of unbridgeable differences between how Simple Injector and .NET Core's configuration system handle collections. If a framework or third-party supplied collection needs to be injected into an application component that is constructed by Simple injector, such collection should be cross wired manually. In that case, you must take explicit care to ensure no Lifestyle Mismatches occur—i.e. you should make the cross-wired registration with the lifestyle equal to the shortest lifestyle of the elements of the collection.
* Cross wiring is a one-way process. .NET's configuration system will not automatically resolve its missing dependencies from Simple Injector. When an application component, composed by Simple Injector, needs to be injected into a framework or third-party component, this has to be set up manually by adding a `ServiceDescriptor` to the `IServiceCollection` that requests the dependency from Simple Injector. This practice, however, should be quite rare.
* Simple Injector will not be able to verify and diagnose object graphs built by the configuration system itself. Those components and their registrations are provided by Microsoft and third-party library makers—you should assume their correctness.
* Simple Injector's verification can give false positives when cross wiring Transient framework or third-party components. This caused by differences in what 'Transient' means. Simple Injector sees a `Transient` component as something that is *short lived*. This is why a Transient components can't be injected into a Scoped or Singleton consumer. .NET Core, on the other hand, views a Transient component as something that is *stateless*. This is why .NET Core would allow such Transient to be injected into a Scoped and—in case the Transient does not have any Scoped dependencies—even into Singleton consumers. To err on the side of safety, Simple Injector still warns when it injects Transient framework components into your non-Transient application components. To fix this, you can make your consumer Transient, or suppress the warning, as explained in the :doc:`Lifestyle Mismatches <LifestyleMismatches>` documentation guide.

In case the automatic cross wiring of framework components is not desired, it can be disabled by setting **AutoCrossWireFrameworkComponents** to `false`:

.. code-block:: c#

    services.AddSimpleInjector(options =>
    {
        options.AutoCrossWireFrameworkComponents = false;
    });

    IServiceProvider provider = services.BuildServiceProvider(validateScopes: true);
        
    provider.UseSimpleInjector(container);


Or more specifically for ASP.NET Core:
    
.. code-block:: c#

    public void ConfigureServices(IServiceCollection services)
    {
        ...
        
        services.AddSimpleInjector(container, options =>
        {
            options.AutoCrossWireFrameworkComponents = false;
        });
        
        ...
    }

    public void Configure(IApplicationBuilder app, IHostingEnvironment env)
    {
        app.UseSimpleInjector(container);
        
        ...
    }
    
When auto cross wiring is disabled, individual framework components can still be cross wired, using the **CrossWire<T>** extension method:

.. code-block:: c#

    services.AddSimpleInjector(container, options =>
    {
        options.AutoCrossWireFrameworkComponents = false;
        
        // Cross wires ILoggerFactory
        options.CrossWire<ILoggerFactory>();
    });

Like auto cross wiring, **CrossWire<TService>** does the required plumbing such as making sure the type is registered with the same lifestyle as configured in .NET Core, but with the difference of just cross wiring that single supplied type. The following listing demonstrates its use:

.. code-block:: c#

    options.CrossWire<ILoggerFactory>();
    options.CrossWire<IOptions<IdentityCookieOptions>>();

.. container:: Note

    **NOTE**: Even though auto cross wiring makes cross wiring very easy, you should still prevent letting application components depend on types provided by application frameworks such as ASP.NET as much as possible. In most cases it not the best solution and in violation of the `Dependency Inversion Principle <https://en.wikipedia.org/wiki/Dependency_inversion_principle>`_. Instead, application components should typically depend on *application-provided abstractions*. These abstractions can be implemented by proxy and/or adapter implementations that forward the call to the framework component. In that case cross wiring can still be used to allow the framework component to be injected into the adapter, but this isn't required.

.. _disposing-the-container:

Disposing the Container
=======================

The Simple Injector **Container** class implements `IDisposable`, which allows any disposable singletons to be disposed off. You can call **Container.Dispose** when the application shuts down. In the case of an ASP.NET Core application, dispose would typically have to be called from inside an `IHostApplicationLifetime` event.

Fortunately, the **AddSimpleInjector** extension method ensures the Simple Injector **Container** is disposed of when the framework's root `IServiceProvider` is disposed of. In an ASP.NET Core application, this typically means on application shutdown. The following code snippet demonstrates this:

.. code-block:: c#

    var container = new Container();

    var services = new ServiceCollection()
        // Ensures the container gets disposed
        .AddSimpleInjector(container);

    ServiceProvider provider = services
        .BuildServiceProvider(validateScopes: true);

    provider.UseSimpleInjector(container);

    provider.Dispose();


This behavior, however, can be configured by setting the **SimpleInjectorAddOptions**'s **DisposeContainerWithServiceProvider** property to false:

.. code-block:: c#

    services.AddSimpleInjector(container, options =>
    {
        options.DisposeContainerWithServiceProvider = false;
    });

By setting **DisposeContainerWithServiceProvider** to false prevents the container from being disposed when `ServiceProvider` is being disposed of. This allows you to control if and when the **Container** is disposed of.

.. _microsoft-logging:

Integrating with Microsoft Logging
==================================

The *SimpleInjector.Integration.ServiceCollection* package simplifies integration with Microsoft's `Microsoft.Extensions.Logging.ILogger` by introducing an **AddLogging** extension method:

.. code-block:: c#

    .AddSimpleInjector(container, options =>
    {
        options.AddLogging();
    });

Calling **AddLogging()** allows application components to depend on the (non-generic) `Microsoft.Extensions.Logging.ILogger` abstraction, as shown in the following listing:

.. code-block:: c#

    public class CancelOrderHandler : IHandler<CancelOrder>
    {
        private readonly ILogger logger;
        
        public CancelOrderHandler(ILogger logger)
        {
            this.logger = logger;
        }
    
        public void Handle(CancelOrder command)
        {
            this.logger.LogDebug("Handler called");
        }
    }

When resolved, Simple Injector ensures that `CancelOrderHandler` gets injected with a logger specific for its usage. In practice this means the injected logger is a `Logger<CancelOrderHandler>`.

.. container:: Note

    **IMPORTANT**: Opposite to Microsoft's guidance to use `ILogger<T>`, with Simple Injector you do not let `CancelOrderHandler` depend on `ILogger<CancelOrderHandler>`, but simply on `ILogger`. This makes your code simpler, easier to test, and less error prone. The sole reason the existence of this guidance is because of limitations of the built-in configuration system. As Simple Injector is more advanced, Microsoft's guidance can safely be ignored.
    
.. _microsoft-localization:

Integrating with Microsoft Localization
=======================================

The *SimpleInjector.Integration.ServiceCollection* package simplifies integration with Microsoft's `Microsoft.Extensions.Localization.IStringLocalizer` by introducing an **AddLocalization** extension method:

.. code-block:: c#

    .AddSimpleInjector(container, options =>
    {
        options.AddLocalization();
    });

Calling **AddLocalization()** allows application components to depend on the (non-generic) `Microsoft.Extensions.Localization.IStringLocalizer` abstraction, as shown in the following listing:

.. code-block:: c#

    [Route("api/[controller]")]
    public class AboutController : Controller
    {
        private readonly IStringLocalizer localizer;

        public AboutController(IStringLocalizer localizer)
        {
            this.localizer = localizer;
        }

        [HttpGet]
        public string Get()
        {
            return this.localizer["About Title"];
        }
    }

When resolved, Simple Injector ensures that `AboutController` gets injected with a IStringLocalizer specific for its usage. In practice this means the injected StringLocalizer is a `StringLocalizer<AboutController>`.

.. container:: Note

    **IMPORTANT**: Opposite to Microsoft's guidance to use `IStringLocalizer<T>`, with Simple Injector you do not let `AboutController` depend on `IStringLocalizer<AboutController>`, but simply on `IStringLocalizer`. This makes your code simpler, easier to test, and less error prone. The sole reason the existence of this guidance is because of limitations of the built-in configuration system. As Simple Injector is more advanced, Microsoft's guidance can safely be ignored.
    
.. container:: Note

    **IMPORTANT**: **AddLocalization** provides only integration for the IStringLocalizer with Simple Injector. The `Microsoft.AspNetCore.Mvc.Localization.IHtmlLocalizer` abstraction is not part of this integration option.

.. _working-with-ioptions:
    
Working with `IOptions<T>`
==========================

.NET Core contains a new configuration model based on an `IOptions<T>` abstraction. We advise against injecting `IOptions<T>` dependencies into your *application components*. Instead let components depend directly on configuration objects and register those objects as *instances* (using `RegisterInstance`). This ensures that configuration values are read during application start up and it allows verifying them at that point in time, allowing the application to fail fast.

Letting application components depend on `IOptions<T>` has some unfortunate downsides. First of all, it causes application code to take an unnecessary dependency on a framework abstraction. This is a violation of the Dependency Inversion Principle, which prescribes the use of application-tailored abstractions. Injecting an `IOptions<T>` into an application component makes such component more difficult to test, while providing no additional benefits for that component. Application components should instead depend directly on the configuration values they require.

Second, `IOptions<T>` configuration values are read lazily. Although the configuration file might be read upon application start up, the required configuration object is only created when `IOptions<T>.Value` is called for the first time. When deserialization fails, because of application misconfiguration for instance, such error will only be appear after the call to `IOptions<T>.Value`. This can cause misconfigurations to stay undetected for much longer than required. By reading—and verifying—configuration values at application start up, this problem can be prevented. Configuration values can be injected as singletons into the component that requires them.

To make things worse, in case you forget to configure a particular section (by omitting a call to `services.Configure<T>`) or when you make a typo while retrieving the configuration section (e.g. by supplying the wrong name to `Configuration.GetSection(name)`), the configuration system will simply supply the application with a default and empty object instead of throwing an exception! This may make sense when building framework or third-party components, but not so much for application development, as it easily leads to fragile applications.

Because you want to verify the configuration at start-up, it makes no sense to delay reading it, and that makes injecting `IOptions<T>` into your application components plain wrong. Depending on `IOptions<T>` might still be useful when bootstrapping the application, but not as a dependency anywhere else in your application. The `IOptions<T>` architecture is designed for the framework and its components, and makes sense in that particular context—it does not make sense in the context of line-of-business applications.

Once you have a correctly read and verified configuration object, registration of the component that requires the configuration object is as simple as this:

.. code-block:: c#

    MyMailSettings mailSettings =
        config.GetSection("Root:SectionName").Get<MyMailSettings>();

    // Verify mailSettings here (if required)

    // Supply mailSettings as constructor argument to a type that requires it,
    container.Register<IMessageSender>(() => new MailMessageSender(mailSettings));

    // or register MailSettings as singleton in the container.
    container.RegisterInstance<MyMailSettings>(mailSettings);
    container.Register<IMessageSender, MailMessageSender>();

