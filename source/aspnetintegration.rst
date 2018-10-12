﻿==================================
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

    **NOTE**: Please note that when integrating Simple Injector in ASP.NET Core, you do **not** replace ASP.NET's built-in container, as advised by `the Microsoft documentation <https://docs.microsoft.com/en-us/aspnet/core/fundamentals/dependency-injection#replacing-the-default-services-container>`_. The practice with Simple Injector is to use Simple Injector to build up object graphs of your *application components* and let the built-in container build framework and third-party components, as shown in the previous code snippet. To understand the rational around this, please read `this article <https://simpleinjector.org/blog/2016/06/whats-wrong-with-the-asp-net-core-di-abstraction/>`_.
    
    **NOTE**: Simple Injector **does not** support out of the box `action injection with FromServices attribute <https://docs.microsoft.com/en-us/aspnet/core/mvc/controllers/dependency-injection?view=aspnetcore-2.1#action-injection-with-fromservices/>`_.

    
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
* In doing so, Simple Injector will preserve the dependency's lifestyle. This allows application components that depend on external services to be :doc:`diagnosed <diagnostics>` for :doc:`Lifestyle Mismatches <LifestyleMismatched>`.
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

The default Visual Studio template comes with built-in authentication through the use of ASP.NET Core Identity. The default template requires a fair amount of cross-wired dependencies. Using the new **AutoCrossWireAspNetComponents** method of version 4.1 of the Simple Injector ASP.NET Core Integration package, however, integration with ASP.NET Core Identity couldn't be more straightforward. When you followed the :ref:`cross-wire guidelines <_cross-wiring>`, this is all you'll have to do to get Identity running.

.. container:: Note

    **NOTE**: It is highly advisable to refactor the `AccountController` to *not* to depend on `IOptions<IdentityCookieOptions>` and `ILoggerFactory`. See the next topic about `IOptions<T>` for more information.

.. _ioption:
.. _ioptions:
    
Working with `IOptions<T>`
=========================

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
