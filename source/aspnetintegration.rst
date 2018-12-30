==================================
ASP.NET Core MVC Integration Guide
==================================

Simple Injector offers the `Simple Injector ASP.NET Core MVC Integration NuGet package <https://www.nuget.org/packages/SimpleInjector.Integration.AspNetCore.Mvc>`_.

.. container:: Note

    **NOTE**: Starting with v4.1, Simple Injector's ASP.NET Core integration packages are available for ASP.NET Core v2.0 and up only. For ASP.NET Core v1.x, please use v4.0.

The following code snippet shows how to use the integration package to apply Simple Injector to your web application's `Startup` class.

.. code-block:: c#

    // You'll need to include the following namespaces
    using Microsoft.AspNetCore.Builder;
    using Microsoft.AspNetCore.Hosting;
    using Microsoft.AspNetCore.Mvc.Controllers;
    using Microsoft.AspNetCore.Mvc.ViewComponents;
    using Microsoft.Extensions.Configuration;
    using Microsoft.Extensions.DependencyInjection;
    using Microsoft.Extensions.Logging;
    using Microsoft.AspNetCore.Http;

    using SimpleInjector;
    using SimpleInjector.Lifestyles;
    using SimpleInjector.Integration.AspNetCore.Mvc;
    using System.Threading.Tasks;

    public class Startup
    {
        private Container container = new Container();
        
        public Startup(IHostingEnvironment env) {
            // ASP.NET default stuff here
        }

        // This method gets called by the runtime.
        public void ConfigureServices(IServiceCollection services) {
            // ASP.NET default stuff here
            services.AddMvc();

            // Add custom IHostedServiceAdapter
            services.AddSingleton<IHostedService>(new SimpleInjectorJobProcessorHostedService(container));

            IntegrateSimpleInjector(services);
        }
        
        private void IntegrateSimpleInjector(IServiceCollection services) {
            container.Options.DefaultScopedLifestyle = new AsyncScopedLifestyle();
        
            services.AddSingleton<IHttpContextAccessor, HttpContextAccessor>();
        
            services.AddSingleton<IControllerActivator>(
                new SimpleInjectorControllerActivator(container));
            services.AddSingleton<IViewComponentActivator>(
                new SimpleInjectorViewComponentActivator(container));
        
            services.EnableSimpleInjectorCrossWiring(container);
            services.UseSimpleInjectorAspNetRequestScoping(container);
        }
        
        // Configure is called after ConfigureServices is called.
        public void Configure(IApplicationBuilder app, IHostingEnvironment env) {
            InitializeContainer(app);
        
            // Add custom middleware
            app.UseMiddleware<CustomMiddleware1>(container);
            app.UseMiddleware<CustomMiddleware2>(container);
            
            container.Verify();
            
            // ASP.NET default stuff here
            app.UseMvc(routes =>
            {
                routes.MapRoute(
                    name: "default",
                    template: "{controller=Home}/{action=Index}/{id?}");
            });
        }
        
        private void InitializeContainer(IApplicationBuilder app) {
            // Add application presentation components:
            container.RegisterMvcControllers(app);
            container.RegisterMvcViewComponents(app);
            
            // Add application services. For instance: 
            container.Register<IUserService, UserService>(Lifestyle.Scoped);
            
            // Allow Simple Injector to resolve services from ASP.NET Core.
            container.AutoCrossWireAspNetComponents(app);
        }
    }
    
.. container:: Note

    **NOTE**: Please note that when integrating Simple Injector in ASP.NET Core, you do **not** replace ASP.NET's built-in container, as advised by `the Microsoft documentation <https://docs.microsoft.com/en-us/aspnet/core/fundamentals/dependency-injection#replacing-the-default-services-container>`_. The practice with Simple Injector is to use Simple Injector to build up object graphs of your *application components* and let the built-in container build framework and third-party components, as shown in the previous code snippet. To understand the rationale around this, please read `this article <https://simpleinjector.org/blog/2016/06/whats-wrong-with-the-asp-net-core-di-abstraction/>`_.

    
.. _wiring-custom-middleware:
    
Wiring custom middleware
========================

The previous `Startup` snippet already showed how a custom middleware class can be used in the ASP.NET Core pipeline. The Simple Injector ASP.NET Core integration packages v4.1 and up add an **UseMiddleware** extension method on top of `IApplicationBuilder` that allows adding custom middleware. The following listing shows how a `CustomMiddleware` class is added to the pipeline.

.. code-block:: c#

    app.UseMiddleware<CustomMiddleware>(container);
    
The type supplied to **UseMiddleware** should implement `Microsoft.AspNetCore.Http.IMiddleware`. A compile-error will be given in case the middleware does not implement that interface.

.. container:: Note

    **NOTE**: The **UseMiddleware** extension method is new in v4.1.
    
This **UseMiddleware** overload ensures two particular things:

* Adds a middleware type to the application's request pipeline. The middleware will be resolved from the supplied the Simple Injector container.
* The middleware type will be added to the container for :doc:`verification <diagnostics>`.
    
The following code snippet shows how such `CustomMiddleware` might look like:

.. code-block:: c#
    
    // Example of some custom user-defined middleware component.
    public sealed class CustomMiddleware : Microsoft.AspNetCore.Http.IMiddleware {
        private readonly ILoggerFactory loggerFactory;
        private readonly IUserService userService;

        public CustomMiddleware(ILoggerFactory loggerFactory, IUserService userService) {
            this.loggerFactory = loggerFactory;
            this.userService = userService;
        }

        public async Task InvokeAsync(HttpContext context, RequestDelegate next) {
            // Do something before
            await next(context);
            // Do something after
        }
    }

Notice how the `CustomMiddleware` class contains dependencies. When the middleware is added to the pipeline using the previously shown **UseMiddleware** overload, it will be resolved from Simple Injector on each request, and its dependencies will be injected.

.. _cross-wiring:

Cross-wiring ASP.NET and third-party services
=============================================

When your application code (e.g. a `Controller`) needs a service which is defined by ASP.NET Core or any third-party library, it is sometimes necessary to get such a dependency from ASP.NET Core's built-in configuration system. This is called *cross-wiring*. Cross-wiring is the process where a type is created and managed by the ASP.NET Core configuration system and is fed to Simple Injector so it can use the created instance to supply it as a dependency to your application code.

The easiest way to use cross-wiring is to use the **AutoCrossWireAspNetComponents** extension method, as shown in the listing at the start of this page.

.. container:: Note

    **NOTE**: The **AutoCrossWireAspNetComponents** extension method is new in Simple Injector v4.1. This requires .NET Core 2.0 or up.
    
To setup cross-wiring, first you must make a call to **EnableSimpleInjectorCrossWiring** on `IServiceCollection` in the `ConfigureServices` method of your `Startup` class.

.. code-block:: c#

    public void ConfigureServices(IServiceCollection services) {
        ... 

        services.EnableSimpleInjectorCrossWiring(container);
    }

When cross-wiring is enabled, Simple Injector can be instructed to resolve missing dependencies from ASP.NET Core by calling **AutoCrossWireAspNetComponents** as part of the `Startup` class's `Configure` method:

.. code-block:: c#

    public void Configure(IApplicationBuilder app, IHostingEnvironment env) {
        ...

        container.AutoCrossWireAspNetComponents(app);
    }

This will accomplish the following:

* Anytime Simple Injector needs to resolve a dependency that is not registered, it will query the `IServiceCollection` to see whether this dependency exists in the ASP.NET Core configuration system.
* In case the dependency exists in `IServiceCollection`, Simple Injector will ensure that the dependency is resolved from ASP.NET Core anytime it is requested, by requesting it from `IApplicationBuilder`.
* In doing so, Simple Injector will preserve the dependency's lifestyle. This allows application components that depend on external services to be :doc:`diagnosed <diagnostics>` for :doc:`Lifestyle Mismatches <LifestyleMismatches>`.
* In case no suitable dependency exists in the `IServiceCollection`, Simple Injector will fall back to its default behavior. This most likely means that an expressive exception is thrown, since the object graph can't be fully composed.

Simple Injector's auto cross-wiring has the following limitations:

* Collections (i.e. `IEnumerable<T>`) will not be auto cross-wired because of unbridgeable differences between how Simple Injector and ASP.NET Core's configuration system handle collections. If a framework or third-party supplied collection should be injected into an application component that is constructed by Simple injector, such collection should be cross-wired manually. In that case, you must take explicit care to ensure no Lifestyle Mismatches occur—i.e. you should not make the cross-wired registration with the lifestyle equal to the shortest lifestyle of the elements of the collection.
* Cross-wiring is a one-way process. By using **AutoCrossWireAspNetComponents**, ASP.NET's configuration system will not automatically resolve its missing dependencies from Simple Injector. When an application component, composed by Simple Injector, needs to be injected into a framework or third-party component, this has to be set up manually by adding a `ServiceDescriptor` to the `IServiceCollection` that requests the dependency from Simple Injector. This practice however should be quite rare.
* Simple Injector will not be able to verify and diagnose object graphs built by the configuration system itself. Those components and their registrations are provided by Microsoft and third-party library makers—you should assume their correctness.

The **AutoCrossWireAspNetComponents** method is new in v4.1 and supersedes the old **CrossWire<TService>** method, since the latter requires every missing dependency to be cross-wired explicitly. **CrossWire<TService>** is still available for backwards compatibility and to handle corner-case scenarios.

Like **AutoCrossWireAspNetComponents**, **CrossWire<TService>** does the required plumbing such as making sure the type is registered with the same lifestyle as configured in ASP.NET Core, but with the difference of just cross-wiring that single supplied type. The following listing demonstrates its use:

.. code-block:: c#

    container.CrossWire<ILoggerFactory>(app);
    container.CrossWire<IOptions<IdentityCookieOptions>>(app);

.. container:: Note

    **NOTE**: Even though **AutoCrossWireAspNetComponents** makes cross-wiring very easy, you should still prevent letting application components depend on types provided by ASP.NET as much as possible. In most cases it not the best solution and in violation of the `Dependency Inversion Principle <https://en.wikipedia.org/wiki/Dependency_inversion_principle>`_. Instead, application components should typically depend on *application-provided abstractions*. These abstractions can be implemented by proxy and/or adapter implementations that forward the call to the framework component. In that case cross-wiring can still be used to allow the framework component to be injected into the adapter, but this isn't required.

.. _identity:
    
Working with ASP.NET Core Identity
==================================

The default Visual Studio template comes with built-in authentication through the use of ASP.NET Core Identity. The default template requires a fair amount of cross-wired dependencies. Using the new **AutoCrossWireAspNetComponents** method of version 4.1 of the Simple Injector ASP.NET Core Integration package, however, integration with ASP.NET Core Identity couldn't be more straightforward. When you followed the :ref:`cross-wire guidelines <cross-wiring>`, this is all you'll have to do to get Identity running.

.. container:: Note

    **NOTE**: It is highly advisable to refactor the `AccountController` to *not* to depend on `IOptions<IdentityCookieOptions>` and `ILoggerFactory`. See the next topic about `IOptions<T>` for more information.

.. _ioption:
.. _ioptions:
    
Working with `IOptions<T>`
==========================

ASP.NET Core contains a new configuration model based on an `IOptions<T>` abstraction. We advise against injecting `IOptions<T>` dependencies into your application components. Instead let components depend directly on configuration objects and register those objects as *Singleton*. This ensures that configuration values are read during application start up and it allows verifying them at that point in time, allowing the application to fail-fast.

Letting application components depend on `IOptions<T>` has some unfortunate downsides. First of all, it causes application code to take an unnecessary dependency on a framework abstraction. This is a violation of the Dependency Inversion Principle, which prescribes the use of application-tailored abstractions. Injecting an `IOptions<T>` into an application component only makes this component more difficult to test, while providing no additional benefits. Application components should instead depend directly on the configuration values they require.

`IOptions<T>` configuration values are read lazily. Although the configuration file might be read upon application start up, the required configuration object is only created when `IOptions<T>.Value` is called for the first time. When deserialization fails, because of application misconfiguration, such error will only be appear after the call to `IOptions<T>.Value`. This can cause misconfigurations to keep undetected for much longer than required. By reading—and verifying—configuration values at application start up, this problem can be prevented. Configuration values can be injected as singletons into the component that requires them.

To make things worse, in case you forget to configure a particular section (by omitting a call to `services.Configure<T>`) or when you make a typo while retrieving the configuration section (e.g. by supplying the wrong name to `Configuration.GetSection(name)`), the configuration system will simply supply the application with a default and empty object instead of throwing an exception! This may make sense in some cases but it will easily lead to fragile applications.

Since you want to verify the configuration at start-up, it makes no sense to delay reading it, and that makes injecting `IOptions<T>` into your components plain wrong. Depending on `IOptions<T>` might still be useful when bootstrapping the application, but not as a dependency anywhere else.

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

Using [FromServices] in ASP.NET Core Controllers
================================================

Besides injecting dependencies into a controller's constructor, ASP.NET Core allows injecting dependencies `directly into action methods <https://docs.microsoft.com/en-us/aspnet/core/mvc/controllers/dependency-injection?view=aspnetcore-2.1#action-injection-with-fromservices>`_ using method injection. This is done by marking a corresponding action method argument with the `[FromServices]` attribute.

While the use of `[FromServices]` works for services registered in ASP.NET Core's built-in configuration system (i.e. `IServiceCollection`), the Simple Injector integration package, however, does not integrate with `[FromServices]` out of the box. This is by design and adheres to our :doc:`design guidelines <principles>`, as explained below.

.. container:: Note

    **IMPORTANT**: Simple Injector's ASP.NET Core integration packages do not allow any Simple Injector registered dependencies to be injected into ASP.NET Core controller action methods using the `[FromServices]` attribute.

The use of method injection, as the `[FromServices]` attribute allows, has a few considerate downsides that should be prevented.

Compared to constructor injection, the use of method injection in action methods hides the relationship between the controller and its dependencies from the container. This allows a controller to be created by Simple Injector (or ASP.NET Core's built-in container for that matter), while the invocation of an individual action might fail, because of the absence of a dependency or a misconfiguration of the dependency's object graph. This can cause configuration errors to stay undetected longer :ref:`than strictly necessary <Never-fail-silently>`. Especially when using Simple Injector, it blinds its :doc:`diagnostic abilities <diagnostics>` which allow you to verify the correctness at application start-up or as part of a unit test.

You might be tempted to apply method injection to prevent the controller’s constructor from becoming too large. But big constructors are actually an indication that the controller itself is too big. It is a common code smell named `Constructor over-injection <https://blog.ploeh.dk/2018/08/27/on-constructor-over-injection/>`_. This is typically an indication that the class violates the `Single Responsibility Principle <https://en.wikipedia.org/wiki/Single_responsibility_principle>`_ meaning that the class is too complex and will be hard to maintain.

A typical solution to this problem is to split up the class into multiple smaller classes. At first this might seem problematic for controller classes, because they can act as gateway to the business layer and the API signature follows the naming of controllers and their actions. Do note, however, that this one-to-one mapping between controller names and the route of your application is not a requirement. ASP.NET Core has a very flexible `routing system <https://docs.microsoft.com/en-us/aspnet/core/fundamentals/routing?view=aspnetcore-2.1>`_ that allows you to completely change how routes map to controller names and even action names. This allows you to split controllers into very small chunks with a very limited number of constructor dependencies and without the need to fall back to method injection using `[FromServices]`.

Simple Injector :ref:`promotes <Push-developers-into-best-practices>` best practices, and because of downsides described above, we consider the use of the `[FromServices]` attribute *not* to be a best practice. This is why we choose not to provide out-of-the-box support for injecting Simple Injector registered dependencies into controller actions. 

In case you still feel method injection is the best option for you, you can plug in a custom `IModelBinderProvider` implementation returning a custom `IModelBinder` that resolves instances from Simple Injector.

.. _using-simpleinjector-with-aspnetcore-ihostedservices:

Using Simple Injector with ASP.NET Core 2.0 IHostedServices
===========================================================

There are multiple ways to integrate Simple Injector with IHostedServices.  The easiest approach is to cross-wire the hosted service with the ASP.NET core configuration system so that it resolves the hosted service implementation from Simple Injector.  That would look something like this:

.. code-block:: c#

    public class MyHostedService : IHostedService, IDisposable
    {
        private readonly ISettingsObject _settingsObj;
        private readonly ILogger _logger;
        private Timer _timer;

        //The Simple Injector container will resolve this instance so it can have application-specific dependencies
        public MyHostedService(ISettingsObject settings, ILogger logger)
        {
            _settingsObj = settings;
            _logger = logger;
        }

        public Task StartAsync(CancellationToken cancellationToken)
        {
            _timer = new Timer(this.DoWork, null, TimeSpan.Zero, TimeSpan.FromSeconds(_settingsObj.TimerInterval));
            return Task.CompletedTask;
        }

        private void DoWork(object state)
        {
            //Do some work here...
        }

        public Task StopAsync(CancellationToken cancellationToken)
        {
            _timer?.Change(Timeout.Infinite, 0);
            return Task.CompletedTask;
        }

        public void Dispose() => _timer?.Dispose();
    }

    public class Startup
    {
        private Container container = new Container();

        //...Other startup initialization code here...

        public void ConfigureServices(IServiceCollection services)
        {
            //...ASP.NET default stuff here...

            // Cross-wire TimedService with the ASP.NET Core configuration system
            //The delegate will be called after the container has been configured.
            services.AddSingleton<IHostedService>(
                c => container.GetInstance<MyHostedService>());

            IntegrateSimpleInjector(services);
        }

        //...Other configuration code...

        private void InitializeContainer(IApplicationBuilder app)
        {
            // Add application presentation components:
            container.RegisterMvcControllers(app);
            container.RegisterMvcViewComponents(app);

            // Add application services.
            //Register dependent services for the MyHostedService.  They will have to be singletons
            //since hosted services are singletons in the ASP.NET Core configuration system.
            container.Register<ISettingsObject, MySettingsObject>(Lifestyle.Singleton);
            container.Register<ILogger, MyLogger>(Lifestyle.Singleton);

            // Register MyHostedService in Simple Injector as Singleton
            container.RegisterSingleton<MyHostedService>();

            // Allow Simple Injector to resolve services from ASP.NET Core.
            container.AutoCrossWireAspNetComponents(app);
        }
    }


.. container:: Note

    **NOTE**: The `documentation for hosted services <https://docs.microsoft.com/en-us/aspnet/core/fundamentals/host/hosted-services/>`_ says to register these services with the services.AddHostedService<T> extension method but that extension method doesn't give a way to provide either an instance or a factory.  Internally, the AddHostedService<T> extension method just calls the AddTransient<IHostedService, THostedService>() method. Later on, all of the IHostedService implementations are added as a dependency to HostedServiceExecuter which itself is added as a singleton. So, adding the hosted service implementations as singletons to the ASP.NET Core configuration system is an equivalent (and much clearer) way to add hosted services to the ASP.NET Core configuration system.

The approach that will be laid out next is the preferred approach and it involves creating an adapter implementation that gets registered with the ASP.NET Core configuration system and forwards the calls to Simple Injector with the application-specific abstraction.

The main idea with this approach is to have an application specific abstraction or abstractions which define the functionality to be performed in the IHostedService.  As an example, let's call this application-specific abstraction "IMyJob".  The implementation of IHostedService then becomes a simple adapter which can be used by ASP.NET Core to run application-specific dependencies in a hosted service similar to the way that the IControllerActivator abstraction implemented by SimpleInjectorControllerActivator provides an adapter for ASP.NET Core to be able to create Controllers with dependencies resolved by the Container.

Given that, the IHostedService adapter might look like this:

.. code-block:: c#

    public class SimpleInjectorJobProcessorHostedService : IHostedService, IDisposable
    {
        private readonly Container _container;
        private Timer _timer;

        //Depending on how this adapter gets registered with the ASP.NET Core configuration system, this
        //constructor may be called before all of the registrations have been added to the container.
        public SimpleInjectorJobProcessorHostedService(Container container) => _container = container;

        public Task StartAsync(CancellationToken cancellationToken)
        {
            /*
             * Now the adapter can resolve things from the container.
             * For example, we could get a settings object from the container:
             * ISettingsObj settings = _containter.GetInstance<ISettingsObj>();
             * _timer = new Timer(this.DoWork, null, TimeSpan.Zero, TimeSpan.FromSeconds(settings.TimerInterval));
             */
            _timer = new Timer(this.DoWork, null, TimeSpan.Zero, TimeSpan.FromSeconds(5));
            return Task.CompletedTask;
        }

        private void DoWork(object state)
        {
            // Run operation in a scope
            using (AsyncScopedLifestyle.BeginScope(_container))
            {
                // Resolve the collection of IMyJob application-specific implementations and run them all
                foreach (var service in _container.GetAllInstances<IMyJob>())
                {
                    service.DoWork();
                }
            }
        }

        public Task StopAsync(CancellationToken cancellationToken)
        {
            _timer?.Change(Timeout.Infinite, 0);
            return Task.CompletedTask;
        }

        public void Dispose() => _timer?.Dispose();
    }

Then the IHostedService adapter would get registered in the Startup class in the following way (for the rest of the Simple Injector-specific code see the Startup snippet above):

.. code-block:: c#

    public class Startup
    {
        private Container container = new Container();

        //...Other startup initialization code here...

        public void ConfigureServices(IServiceCollection services)
        {
            // ASP.NET default stuff here

            services.AddSingleton<IHostedService>(new SimpleInjectorJobProcessorHostedService(container));

            IntegrateSimpleInjector(services);
        }

        //...Configuration code here...
    }

This approach allows the application-specific code to remain oblivious of ASP.NET's implementation details, such as IHostedService.  For example, an IMyJob implementation might look like this:

.. code-block:: c#

    public class DoSomethingJob : IMyJob
    {
        private readonly IJobRepository _repo;
        private readonly ILogger _logger;

        //No knowledge of ASP.NET Core dependencies is needed.
        public DoSomethingJob(IJobRepository repo, ILogger logger)
        {
            _repo = repo;
            _logger = logger;
        }

        public void DoWork() => ...do something here...
    }

The IMyJob implementations can be registered with SimpleInjector as usual:

.. code-block:: c#

    public class Startup
    {
        private Container container = new Container();

        //...Other startup initialization and configuration code here...

        private void InitializeContainer(IApplicationBuilder app)
        {
            // Add application presentation components:
            container.RegisterMvcControllers(app);
            container.RegisterMvcViewComponents(app);
            
            // Add application services. For instance: 
            container.Register<IUserService, UserService>(Lifestyle.Scoped);
            container.Register<ISettingsObj, MySettingsObj>();

            // NOTE: Simple Injector v4.3 API
            container.Collection.Register<IMyJob>(typeof(IMyJob).Assembly);
            
            // Allow Simple Injector to resolve services from ASP.NET Core.
            container.AutoCrossWireAspNetComponents(app);
        }
    }
