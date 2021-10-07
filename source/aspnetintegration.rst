===================================================
ASP.NET Core and ASP.NET Core MVC Integration Guide
===================================================

Simple Injector offers the `Simple Injector ASP.NET Core MVC Integration NuGet package <https://nuget.org/packages/SimpleInjector.Integration.AspNetCore.Mvc>`_ for integration with ASP.NET Core MVC.

.. container:: Note

    **TIP**: Even though the ASP.NET Core integration packages take a dependency on the Simple Injector core library, prefer installing the `the core library <https://nuget.org/packages/SimpleInjector>`_ explicitly into your startup project. The core library uses an independent versioning and release cycle. Installing the core library explicitly, therefore, gives you the newest, latest release (instead of the lowest compatible release), and allows the NuGet package manager to inform you about new minor and patch releases in the future.


The following code snippet shows how to use the integration package to apply Simple Injector to your web application's `Startup` class.

.. code-block:: c#

    using Microsoft.AspNetCore.Builder;
    using Microsoft.AspNetCore.Hosting;
    using Microsoft.Extensions.Configuration;
    using Microsoft.Extensions.DependencyInjection;
    using Microsoft.Extensions.Hosting;
    using SimpleInjector;

    public class Startup
    {
        private Container container = new SimpleInjector.Container();

        public Startup(IConfiguration configuration)
        {
            // Set to false. This will be the default in v5.x and going forward.
            container.Options.ResolveUnregisteredConcreteTypes = false;

            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        public void ConfigureServices(IServiceCollection services)
        {
            // ASP.NET default stuff here
            services.AddControllersWithViews();

            services.AddLogging();
            services.AddLocalization(options => options.ResourcesPath = "Resources");
                
            // Sets up the basic configuration that for integrating Simple Injector with
            // ASP.NET Core by setting the DefaultScopedLifestyle, and setting up auto
            // cross wiring.
            services.AddSimpleInjector(container, options =>
            {
                // AddAspNetCore() wraps web requests in a Simple Injector scope and
                // allows request-scoped framework services to be resolved.
                options.AddAspNetCore()

                    // Ensure activation of a specific framework type to be created by
                    // Simple Injector instead of the built-in configuration system.
                    // All calls are optional. You can enable what you need. For instance,
                    // ViewComponents, PageModels, and TagHelpers are not needed when you
                    // build a Web API.
                    .AddControllerActivation()
                    .AddViewComponentActivation()
                    .AddPageModelActivation()
                    .AddTagHelperActivation();

                // Optionally, allow application components to depend on the non-generic 
                // ILogger (Microsoft.Extensions.Logging) or IStringLocalizer
                // (Microsoft.Extensions.Localization) abstractions.
                options.AddLogging();
                options.AddLocalization();
            });

            InitializeContainer();
        }

        private void InitializeContainer()
        {
            // Add application services. For instance: 
            container.Register<IUserService, UserService>(Lifestyle.Singleton);
        }

        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            // UseSimpleInjector() finalizes the integration process.
            app.UseSimpleInjector(container);

            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }
            else
            {
                app.UseExceptionHandler("/Home/Error");
            }

            // Default ASP.NET middleware
            app.UseStaticFiles();
            app.UseRouting();
            app.UseAuthorization();

            // Add your custom Simple Injector-created middleware to the pipeline.
            // NOTE: these middleware classes must implement IMiddleware.
            app.UseMiddleware<CustomMiddleware1>(container);
            app.UseMiddleware<CustomMiddleware2>(container);

            // ASP.NET MVC default stuff here
            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllerRoute(
                    name: "default",
                    pattern: "{controller=Home}/{action=Index}/{id?}");
            });

            // Always verify the container
            container.Verify();
        }
    }
    
.. container:: Note

    **NOTE**: Please note that when integrating Simple Injector in ASP.NET Core, you do **not** replace ASP.NET's built-in container, as advised by `the Microsoft documentation <https://docs.microsoft.com/en-us/aspnet/core/fundamentals/dependency-injection#replacing-the-default-services-container>`_. The practice with Simple Injector is to use Simple Injector to build up object graphs of your *application components* and let the built-in container build framework and third-party components, as shown in the previous code snippet. To understand the rationale around this, please read `this article <https://simpleinjector.org/blog/2016/06/whats-wrong-with-the-asp-net-core-di-abstraction/>`_.

.. container:: Note

    **TIP**: By using **AddSimpleInjector**, you allow the Simple Injector **Container** to be automatically disposed when the application shuts down. To override this behavior, please see :ref:`this <disposing-the-container>`.


.. _core-integration-packages:
    
Available integration packages
==============================

The `SimpleInjector.Integration.AspNetCore.Mvc <https://nuget.org/packages/SimpleInjector.Integration.AspNetCore.Mvc>`_ NuGet package is the umbrella package that pulls in all integration functionality. The downside is that it also pulls in many ASP.NET Core packages that you might not need, or might not want. In case you need more fine-grained control over the number of Microsoft packages that get included in your application, you can decide to use one of the other available ASP.NET Core integration packages. The following table lists the relevant integration packages sorted from most complete to most basic integration:
 
+--------------------------------------------------------------------------------------+--------------------------------------------------------------------------------+
| Integration Package                                                                  | Description                                                                    |
+======================================================================================+================================================================================+
| `SimpleInjector.Integration .AspNetCore.Mvc                                          | Adds **Tag Helper** and **Page Model** integration for ASP.NET Core MVC.       |
| <https://nuget.org/packages/SimpleInjector.Integration.AspNetCore.Mvc>`_             |                                                                                |
|                                                                                      | Main extension methods:                                                        |
|                                                                                      |                                                                                |
|                                                                                      | * .AddPageModelActivation()                                                    |
|                                                                                      | * .AddTagHelperActivation()                                                    |
|                                                                                      |                                                                                |
|                                                                                      | The previous code example demonstrates the use of these extension methods.     |
|                                                                                      |                                                                                |
|                                                                                      | This package contains the following dependencies:                              |
|                                                                                      |                                                                                |
|                                                                                      | * SimpleInjector.Integration .AspNetCore.Mvc.ViewFeatures                      |
|                                                                                      | * Microsoft.AspNetCore.Mvc.Razor                                               |
|                                                                                      | * Microsoft.AspNetCore.Mvc.RazorPages                                          |
+--------------------------------------------------------------------------------------+--------------------------------------------------------------------------------+
| `SimpleInjector.Integration .AspNetCore.Mvc.ViewFeatures                             | Adds `View Component                                                           |
| <https://nuget.org/packages/SimpleInjector.Integration.AspNetCore.Mvc.ViewFeatures>`_| <https://docs.microsoft.com/en-us/aspnet/core/mvc/views/view-components>`_     |
|                                                                                      | integration for ASP.NET Core MVC.                                              |
|                                                                                      |                                                                                |
|                                                                                      | Main extension methods:                                                        |
|                                                                                      |                                                                                |
|                                                                                      | * .AddViewComponentActivation()                                                |
|                                                                                      |                                                                                |
|                                                                                      | This package contains the following dependencies:                              |
|                                                                                      |                                                                                |
|                                                                                      | * SimpleInjector.Integration .AspNetCore.Mvc.Core                              |
|                                                                                      | * Microsoft.AspNetCore.Mvc.ViewFeatures                                        |
+--------------------------------------------------------------------------------------+--------------------------------------------------------------------------------+
| `SimpleInjector.Integration .AspNetCore.Mvc.Core                                     | Adds **Controller** integration for ASP.NET Core MVC (and Web API).            |
| <https://nuget.org/packages/SimpleInjector.Integration.AspNetCore.Mvc.Core>`_        |                                                                                |
|                                                                                      | Main extension methods:                                                        |
|                                                                                      |                                                                                |
|                                                                                      | * .AddControllerActivation()                                                   |
|                                                                                      | * .AddControllerActivation(Lifestyle)                                          |
|                                                                                      |                                                                                |
|                                                                                      | This page'ss initial code example demonstrates the use of this extension       |
|                                                                                      | method.                                                                        |
|                                                                                      |                                                                                |
|                                                                                      | This package contains the following dependencies:                              |
|                                                                                      |                                                                                |
|                                                                                      | * SimpleInjector.Integration .AspNetCore                                       |
|                                                                                      | * Microsoft.AspNetCore.Mvc.Core                                                |
+--------------------------------------------------------------------------------------+--------------------------------------------------------------------------------+
| `SimpleInjector.Integration .AspNetCore                                              | Adds **request scoping** and **middleware** integration ASP.NET Core.          |
| <https://nuget.org/packages/SimpleInjector.Integration.AspNetCore>`_                 | The features of this package are described on this page.                       |
|                                                                                      |                                                                                |
|                                                                                      | Main extension methods:                                                        |
|                                                                                      |                                                                                |
|                                                                                      | * .AddAspNetCore()                                                             |
|                                                                                      | * .UseMiddleware()                                                             |
|                                                                                      | * .UseSimpleInjector()                                                         |
|                                                                                      |                                                                                |
|                                                                                      | This package contains the following dependencies:                              |
|                                                                                      |                                                                                |
|                                                                                      | * SimpleInjector.Integration .GenericHost                                      |
|                                                                                      | * SimpleInjector.Integration .ServiceCollection                                |
|                                                                                      | * Microsoft.AspNetCore.Abstractions                                            |
|                                                                                      | * Microsoft.AspNetCore.Http                                                    |
|                                                                                      | * Microsoft.AspNetCore.Http.Abstractions                                       |
|                                                                                      | * Microsoft.Extensions.Hosting.Abstractions                                    |
+--------------------------------------------------------------------------------------+--------------------------------------------------------------------------------+
| `SimpleInjector.Integration .GenericHost                                             | Adds  **Hosted Service** integration and integration on top of IHost.          |
| <https://nuget.org/packages/SimpleInjector.Integration.GenericHost>`_                | The features of this package are discussed in the                              |
|                                                                                      | :doc:`.NET Generic Host Integration Guide  <generichostintegration>`.          |
|                                                                                      |                                                                                |
|                                                                                      | Main extension methods:                                                        |
|                                                                                      |                                                                                |
|                                                                                      | * .AddHostedService()                                                          |
|                                                                                      | * .UseSimpleInjector()                                                         |
|                                                                                      |                                                                                |
|                                                                                      | This package contains the following dependencies:                              |
|                                                                                      |                                                                                |
|                                                                                      | * SimpleInjector.Integration .ServiceCollection                                |
|                                                                                      | * Microsoft.Extensions .DependencyInjection.Abstractions                       |
|                                                                                      | * Microsoft.Extensions.Hosting .Abstractions                                   |
+--------------------------------------------------------------------------------------+--------------------------------------------------------------------------------+
| `SimpleInjector.Integration .ServiceCollection                                       | Adds integration with .NET Core's configuration system (i.e.                   |
| <https://nuget.org/packages/SimpleInjector.Integration.ServiceCollection>`_          | *IServiceCollection*) by allowing framework-configured services to be          |
|                                                                                      | injected into Simple Injector-managed components. It, furthermore, simplifies  |
|                                                                                      | integration with .NET Core's logging infrastructure.                           |
|                                                                                      | The features of this package are discussed in the                              |
|                                                                                      | :doc:`ServiceCollection Integration Guide <servicecollectionintegration>`.     |
|                                                                                      |                                                                                |
|                                                                                      | Main extension methods:                                                        |
|                                                                                      |                                                                                |
|                                                                                      | * .AddSimpleInjector()                                                         |
|                                                                                      | * .AddLogging()                                                                |
|                                                                                      | * .AddLocalization()                                                           |
|                                                                                      | * .CrossWire()                                                                 |
|                                                                                      | * .UseSimpleInjector()                                                         |
|                                                                                      |                                                                                |
|                                                                                      | This package contains the following dependencies:                              |
|                                                                                      |                                                                                |
|                                                                                      | * SimpleInjector (core library)                                                |
|                                                                                      | * Microsoft.Extensions .DependencyInjection.Abstractions                       |
|                                                                                      | * Microsoft.Extensions.Hosting.Abstractions                                    |
|                                                                                      | * Microsoft.Extensions.Localization.Abstractions                               |
|                                                                                      | * Microsoft.Extensions.Logging.Abstractions                                    |
+--------------------------------------------------------------------------------------+--------------------------------------------------------------------------------+

    
.. _wiring-custom-middleware:
    
Wiring custom middleware
========================

The previous `Startup` snippet already showed how a custom middleware class can be used in the ASP.NET Core pipeline. The Simple Injector ASP.NET Core integration packages add an **UseMiddleware** extension method that allows adding custom middleware. The following listing shows how a `CustomMiddleware` class is added to the pipeline.

.. code-block:: c#

    public void Configure(IApplicationBuilder app, IHostingEnvironment env)
    {
        app.UseSimpleInjector(container);
 
        app.UseMiddleware<CustomMiddleware>(container);
  
        ...
    }
    
.. code-block:: c#

    public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
    {
        // UseSimpleInjector() enables framework services to be injected into
        // application components, resolved by Simple Injector.
        app.UseSimpleInjector(container);

        if (env.IsDevelopment())
        {
            app.UseDeveloperExceptionPage();
        }
        else
        {
            app.UseExceptionHandler("/Home/Error");
        }

        app.UseStaticFiles();

        app.UseRouting();

        app.UseAuthorization();

        // In ASP.NET Core, middleware is applied in the order of registration.
        // (opposite to how decorators are applied in Simple Injector). This means
        // that the following two custom middleware components are wrapped inside
        // the authorization middleware, which is typically what you'd want.
        app.UseMiddleware<CustomMiddleware1>(container);
        app.UseMiddleware<CustomMiddleware2>(container);

        app.UseEndpoints(endpoints =>
        {
            endpoints.MapControllerRoute(
                name: "default",
                pattern: "{controller=Home}/{action=Index}/{id?}");
        });
        
        // Always verify the container
        container.Verify();
    }
    
The type supplied to **UseMiddleware<T>** should implement the `IMiddleware` interface from the `Microsoft.AspNetCore.Http` namespace.

.. container:: Note

    **IMPORTANT**: Besides implementing the `IMiddleware` interface, ASP.NET Core supports the notion of `convention-based middleware <https://docs.microsoft.com/en-us/aspnet/core/fundamentals/middleware/extensibility>`_—i.e. middleware that doesn't implement the `IMiddleware` interface. Simple Injector, however, does *not* support convention-based middleware because it doesn't follow Simple Injector's best practices. To integrate with Simple Injector, you need to implement ASP.NET Core's `IMiddleware` interface on your middleware classes.
    
This **UseMiddleware** overload ensures two particular things:

* Adds a middleware type to the application's request pipeline. The middleware will be resolved from the supplied the Simple Injector container.
* The middleware type will be added to the container for :doc:`verification <diagnostics>`. This means that you should call **container.Verify()** after the calls to **UseMiddleware** to ensure that your middleware components are verified.
    
The following code snippet shows how such `CustomMiddleware` class might look like:

.. code-block:: c#
    
    // Example of some custom user-defined middleware component.
    public sealed class CustomMiddleware : Microsoft.AspNetCore.Http.IMiddleware
    {
        private readonly IUserService userService;

        public CustomMiddleware(IUserService userService)
        {
            this.userService = userService;
        }

        public async Task InvokeAsync(HttpContext context, RequestDelegate next)
        {
            // Do something before
            await next(context);
            // Do something after
        }
    }

Notice how the `CustomMiddleware` class contains dependencies. When the middleware is added to the pipeline using the previously shown **UseMiddleware** overload, it will be resolved from Simple Injector on each request, and its dependencies will be injected.


.. _cross-wiring:

Cross wiring ASP.NET and third-party services
=============================================

This topic has been moved. Please go :ref:`here <cross-wiring-third-party-services>`.


.. _ioption:
.. _ioptions:
    
Working with `IOptions<T>`
==========================

This topic has been moved. Please go :ref:`here <working-with-ioptions>`.


.. _hosted-services:

Using Hosted Services
=====================

Simple Injector simplifies integration of Hosted Services into ASP.NET Core. For this, you need to include the `SimpleInjector.Integration.GenericHost <https://nuget.org/packages/SimpleInjector.Integration.GenericHost>`_ NuGet package. For more information on how to integrate Hosted Services into your ASP.NET Core web application, please read the :ref:`Using Hosted Services <using-hosted-services>` section of the :doc:`.NET Generic Host Integration Guide <generichostintegration>`.


.. _fromservices:

Using [FromServices] in ASP.NET Core MVC Controllers
====================================================

Besides injecting dependencies into a controller's constructor, ASP.NET Core MVC allows injecting dependencies `directly into action methods <https://docs.microsoft.com/en-us/aspnet/core/mvc/controllers/dependency-injection?view=aspnetcore-2.1#action-injection-with-fromservices>`_ using method injection. This is done by marking a corresponding action method argument with the `[FromServices]` attribute.

While the use of `[FromServices]` works for services registered in ASP.NET Core's built-in configuration system (i.e. `IServiceCollection`), the Simple Injector integration package, however, does not integrate with `[FromServices]` out of the box. This is by design and adheres to our :doc:`design guidelines <principles>`, as explained below.

.. container:: Note

    **IMPORTANT**: Simple Injector's ASP.NET Core integration packages do not allow any Simple Injector registered dependencies to be injected into ASP.NET Core MVC controller action methods using the `[FromServices]` attribute.

The use of method injection, as the `[FromServices]` attribute allows, has a few considerate downsides that should be prevented.

Compared to constructor injection, the use of method injection in action methods hides the relationship between the controller and its dependencies from the container. This allows a controller to be created by Simple Injector (or ASP.NET Core's built-in container for that matter), while the invocation of an individual action might fail, because of the absence of a dependency or a misconfiguration in the dependency's object graph. This can cause configuration errors to stay undetected longer :ref:`than strictly required <Never-fail-silently>`. Especially when using Simple Injector, it blinds its :doc:`diagnostic abilities <diagnostics>` which allow you to verify the correctness at application start-up or as part of a unit test.

You might be tempted to apply method injection to prevent the controller’s constructor from becoming too large. But big constructors are actually an indication that the controller itself is too big. It is a common code smell named `Constructor over-injection <https://blog.ploeh.dk/2018/08/27/on-constructor-over-injection/>`_. This is typically an indication that the class violates the `Single Responsibility Principle <https://en.wikipedia.org/wiki/Single_responsibility_principle>`_ meaning that the class is too complex and will be hard to maintain.

A typical solution to this problem is to split up the class into multiple smaller classes. At first this might seem problematic for controller classes, because they can act as gateway to the business layer and the API signature follows the naming of controllers and their actions. Do note, however, that this one-to-one mapping between controller names and the route of your application is not a requirement. ASP.NET Core has a very flexible `routing system <https://docs.microsoft.com/en-us/aspnet/core/fundamentals/routing>`_ that allows you to completely change how routes map to controller names and even action names. This allows you to split controllers into very small chunks with a very limited number of constructor dependencies and without the need to fall back to method injection using `[FromServices]`.

Simple Injector :ref:`promotes best practices<Push-developers-into-best-practices>`, and because of downsides described above, we consider the use of the `[FromServices]` attribute *not* to be a best practice. This is why we choose not to provide out-of-the-box support for injecting Simple Injector registered dependencies into controller actions. 

In case you still feel method injection is the best option for you, you can plug in a custom `IModelBinderProvider` implementation returning a custom `IModelBinder` that resolves instances from Simple Injector.


.. _resolving-from-validationcontext:

Resolving services from MVC's ValidationContext
===============================================

ASP.NET Core MVC allows you to implement custom validation logic inside model classes using the `IValidatableObject` interface. Although there is nothing inherently wrong with placing validation logic inside the model object itself, problems start to appear when that validation logic requires services to work. By default this will not work with Simple Injector, as the `ValidationContext.GetService` method forwards the call to the built-in configuration system—not to Simple Injector.

In general, you should prevent calling `GetService` or similar methods from within application code, such as MVC model classes. This leads to the `Service Locator anti-pattern <https://mng.bz/WaQw>`_.

Instead, follow the advice given in `this Stack Overflow answer <https://stackoverflow.com/a/55846598/264697>`_.


.. _razor-pages:

Using Razor Pages
=================

ASP.NET Core 2.0 introduced an MVVM-like model, called `Razor Pages <https://docs.microsoft.com/en-us/aspnet/core/razor-pages/>`_. A Razor Page combines both data and behavior in a single class.

Integration for Razor Pages is part of the *SimpleInjector.Integration.AspNetCore.Mvc* integration package. This integration comes in the form of the **AddPageModelActivation** extension method. This extension method should be used in the **ConfigureServices** method of your `Startup` class:

.. code-block:: c#

    public void ConfigureServices(IServiceCollection services)
    {
        ...

        services.AddSimpleInjector(container, options =>
        {
            options.AddAspNetCore()
                .AddPageModelActivation();
        });
    }

This is all that is required to integrate Simple Injector with ASP.NET Core Razor Pages.

When working with Razor Components, however, it can be useful to override the integration's `IServiceScope` reuse behavior, which is discussed next.

.. _service-scope-reuse behavior:

Overriding the default IServiceScope Reuse Behavior
===================================================

In order to allow framework services to be cross wired, Simple Injector's basic :doc:`ServiceCollection Integration <servicecollectionintegration>` manages the framework's `IServiceScope` instances within its own **Scope**. This means that, with the basic integration, every Simple Injector **Scope** gets its own new `IServiceScope`.

This behavior, however, is overridden by Simple Injector's ASP.NET Core integration. It ensures that, within the context of a single web request, the request's original `IServiceScope` implementation is used. Not reusing that `IServiceScope` would cause scoped framework components to lose request information, which is supplied by the ASP.NET Core framework at the beginning of the request.

This behavior is typically preferable, because it would otherwise force you to add quite some infrastructural code to get this data back. On the other hand, it does mean, that even if you start a nested **Scope** within a web request, you are still getting the same cross-wired scoped framework services. For instance, in case you inject a cross-wired `DbContext` (registered through `services.AddDbContext<T>()`), you get the same `DbContext` instance, even within that nested scope—this might not be the behavior you want, and this behavior can be overridden.

Especially when building a Razor Page application, overriding the default can be important. Razor Pages tend to reuse the same `IServiceCollection` for the same user as long as they stay on the same page (because the SignalR pipeline is kept open). This reuse can have rather problematic consequences, especially because the user can cause server requests to happen in parallel (by clicking a button multiple times within a short time span). This causes problems, because `DbContext`, for instance, is not thread safe. This is also a case where you might want to override the default behavior.

The following code snippet demonstrates how this behavior can be overridden:

.. code-block:: c#

    public void ConfigureServices(IServiceCollection services)
    {
        ...

        services.AddSimpleInjector(container, options =>
        {
            options.AddAspNetCore(ServiceScopeReuseBehavior.OnePerRequest)
                .AddPageModelActivation();
        });
    }

.. container:: Note

    **NOTE**: This **AddAspNetCore** overload is new in **v5.1** of the SimpleInjector.Integration.AspNetCore integration package.

The **AddAspNetCore** method contains an overload that accepts an **ServiceScopeReuseBehavior** enum. This enum has the following options:

* **OnePerRequest**: Within the context of a web request (or SignalR connection), Simple Injector will reuse the same `IServiceScope` instance, irregardless of how many Simple Injector **Scope** instances are created. Outside the context of a (web) request (i.e. `IHttpContextAccessor.HttpContext` returns `null`), this behavior falls back to the **Unchanged** behavior as discussed below.
* **OnePerNestedScope**: Within the context of a web request (or SignalR connection), Simple Injector will use the request's `IServiceScope` within its root scope. Within a nested scope or outside the context of a (web) request, this behavior falls back to **Unchanged**.
* **Unchanged**: This leaves the original configured **SimpleInjectorAddOptions.ServiceProviderAccessor** as-is. If **ServiceProviderAccessor** is not replaced, the default value, as returned by **AddSimpleInjector**, ensures the creation of a new .NET Core `IServiceScope` instance, for every Simple Injector **Scope**. The `IServiceScope` is *scoped* to that Simple Injector **Scope**. The ASP.NET Core's request `IServiceScope` will **NEVER** be used. Instead Simple Injector creates a new one for the request (and one for each nested scope). This disallows accessing ASP.NET Core services that depend on or return request-specific data. Setting the **ServiceScopeReuseBehavior** to **Unchanged** in a web application might force you to provide request-specific data to services using ASP.NET Middleware.

.. _identity:
    
Working with ASP.NET Core Identity
==================================

The default Visual Studio template comes with built-in authentication through the use of ASP.NET Core Identity. The default template requires a fair amount of cross-wired dependencies. When auto cross wiring is enabled (when calling **AddSimpleInjector**) integration with ASP.NET Core Identity couldn't be more straightforward. When you followed the :ref:`cross wire guidelines <cross-wiring-third-party-services>`, this is all you'll have to do to get Identity running.

.. container:: Note

    **NOTE**: It is highly advisable to refactor the `AccountController` to *not* to depend on `IOptions<IdentityCookieOptions>` and `ILoggerFactory`. See :ref:`the topic about IOptions\<T\> <ioptions>` for more information.
