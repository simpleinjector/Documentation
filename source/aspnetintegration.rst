===================================================
ASP.NET Core and ASP.NET Core MVC Integration Guide
===================================================

Simple Injector offers the `Simple Injector ASP.NET Core MVC Integration NuGet package <https://www.nuget.org/packages/SimpleInjector.Integration.AspNetCore.Mvc>`_ for integration with ASP.NET Core MVC.

.. container:: Note

    **IMPORTANT**: This page is specific to the integration packages for Simple Injector v4.6 and up. In case you are using an older version of Simple Injector, please see the :doc:`old integration page <aspnetintegration_45>`.

The following code snippet shows how to use the integration package to apply Simple Injector to your web application's `Startup` class.

.. code-block:: c#

    using Microsoft.AspNetCore.Builder;
    using Microsoft.AspNetCore.Hosting;
    using Microsoft.AspNetCore.Http;
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.Extensions.Configuration;
    using Microsoft.Extensions.DependencyInjection;
    using SimpleInjector;

    public class Startup
    {
        private Container container = new Container();
        
        public Startup(IHostingEnvironment env)
        {
            // ASP.NET default stuff here
        }

        public void ConfigureServices(IServiceCollection services)
        {
            // ASP.NET default stuff here
            services.AddMvc();

            services.AddLogging();
            services.AddLocalization(options => options.ResourcesPath = "Resources");

            services.AddSimpleInjector(container, options =>
            {
                // AddAspNetCore() wraps web requests in a Simple Injector scope.
                options.AddAspNetCore()
                    // Ensure activation of a specific framework type to be created by
                    // Simple Injector instead of the built-in configuration system.
                    .AddControllerActivation()
                    .AddViewComponentActivation()
                    .AddPageModelActivation()
                    .AddTagHelperActivation();
            });
        }
        
        public void Configure(IApplicationBuilder app, IHostingEnvironment env)
        {
            // UseSimpleInjector() enables framework services to be injected into
            // application components, resolved by Simple Injector.
            app.UseSimpleInjector(container, options =>
            {
                // Add custom Simple Injector-created middleware to the ASP.NET pipeline.
                options.UseMiddleware<CustomMiddleware1>(app);
                options.UseMiddleware<CustomMiddleware2>(app);
                
                // Optionally, allow application components to depend on the
                // non-generic Microsoft.Extensions.Logging.ILogger 
                // or Microsoft.Extensions.Localization.IStringLocalizer abstractions.
                options.UseLogging();
                options.UseLocalization();
            });
            
            InitializeContainer();
            
            // Always verify the container
            container.Verify();
            
            // ASP.NET default stuff here
            app.UseMvc(routes => ...);
        }
        
        private void InitializeContainer()
        {
            // Add application services. For instance: 
            container.Register<IUserService, UserService>(Lifestyle.Scoped);
        }
    }
    
.. container:: Note

    **NOTE**: Please note that when integrating Simple Injector in ASP.NET Core, you do **not** replace ASP.NET's built-in container, as advised by `the Microsoft documentation <https://docs.microsoft.com/en-us/aspnet/core/fundamentals/dependency-injection#replacing-the-default-services-container>`_. The practice with Simple Injector is to use Simple Injector to build up object graphs of your *application components* and let the built-in container build framework and third-party components, as shown in the previous code snippet. To understand the rationale around this, please read `this article <https://simpleinjector.org/blog/2016/06/whats-wrong-with-the-asp-net-core-di-abstraction/>`_.


.. _core-integration-packages:
    
Available integration packages
==============================

In case you need more fine-grained control over the number of Microsoft packages that get included in your application, you can decide to use one of the other available ASP.NET Core integration packages. The following table lists the relevant integration packages sorted from most complete to most basic integration:
 
+-----------------------------------------------------------------------------------+--------------------------------------------------------------------------------+
| Integration Package                                                               | Description                                                                    |
+===================================================================================+================================================================================+
| `SimpleInjector.Integration.AspNetCore.Mvc                                        | Adds **Tag Helper** and **Page Model** integration for ASP.NET Core MVC.       |
| <https://www.nuget.org/packages/SimpleInjector.Integration.AspNetCore.Mvc>`_      | The features of this package are described on his page.                        |
|                                                                                   |                                                                                |
|                                                                                   | This package contains the following dependencies:                              |
|                                                                                   |                                                                                |
|                                                                                   | * SimpleInjector.Integration.AspNetCore.Mvc.Core                               |
|                                                                                   | * Microsoft.AspNetCore.Mvc.Razor                                               |
|                                                                                   | * Microsoft.AspNetCore.Mvc.RazorPages                                          |
+-----------------------------------------------------------------------------------+--------------------------------------------------------------------------------+
| `SimpleInjector.Integration.AspNetCore.Mvc.Core                                   | Adds **Controller** and **View Component** integration for ASP.NET Core MVC.   |
| <https://www.nuget.org/packages/SimpleInjector.Integration.AspNetCore.Mvc.Core>`_ | The features of this package are described on his page.                        |
|                                                                                   |                                                                                |
|                                                                                   | This package contains the following dependencies:                              |
|                                                                                   |                                                                                |
|                                                                                   | * SimpleInjector.Integration .AspNetCore                                       |
|                                                                                   | * Microsoft.AspNetCore.Mvc.Core                                                |
|                                                                                   | * Microsoft.AspNetCore.Mvc.ViewFeatures                                        |
+-----------------------------------------------------------------------------------+--------------------------------------------------------------------------------+
| `SimpleInjector.Integration.AspNetCore                                            | Adds **request scoping** and **middleware** integration ASP.NET Core.          |
| <https://www.nuget.org/packages/SimpleInjector.Integration.AspNetCore>`_          | The features of this package are described on his page.                        |
|                                                                                   |                                                                                |
|                                                                                   | This package contains the following dependencies:                              |
|                                                                                   |                                                                                |
|                                                                                   | * SimpleInjector.Integration.ServiceCollection                                 |
|                                                                                   | * Microsoft.AspNetCore.Http                                                    |
|                                                                                   | * Microsoft.Extensions.Hosting.Abstractions                                    |
+-----------------------------------------------------------------------------------+--------------------------------------------------------------------------------+
| `SimpleInjector.Integration.GenericHost                                           | Adds .NET Core 2.1 **Hosted Service** integration and integration on top of    |
| <https://www.nuget.org/packages/SimpleInjector.Integration.GenericHost>`_         | IHost.                                                                         |
|                                                                                   | The features of this package are discussed in the                              |
|                                                                                   | :doc:`.NET Generic Host Integration Guide  <generichostintegration>`.          |
|                                                                                   |                                                                                |
|                                                                                   | This package contains the following dependencies:                              |
|                                                                                   |                                                                                |
|                                                                                   | * SimpleInjector.Integration .ServiceCollection                                |
|                                                                                   | * Microsoft.Extensions.Hosting .Abstractions                                   |
+-----------------------------------------------------------------------------------+--------------------------------------------------------------------------------+
| `SimpleInjector.Integration.ServiceCollection                                     | Adds integration with .NET Core's configuration system (i.e.                   |
| <https://www.nuget.org/packages/SimpleInjector.Integration.ServiceCollection>`_   | *IServiceCollection*) by allowing framework configured services to be          |
|                                                                                   | injected into Simple Injector-managed components. Furthermore, simplifies      |
|                                                                                   | integration with .NET Core's logging infrastructure.                           |
|                                                                                   | The features of this package are discussed in the                              |
|                                                                                   | :doc:`ServiceCollection Integration Guide <servicecollectionintegration>`.     |
|                                                                                   |                                                                                |
|                                                                                   | This package contains the following dependencies:                              |
|                                                                                   |                                                                                |
|                                                                                   | * SimpleInjector (core library)                                                |
|                                                                                   | * Microsoft.Extensions .DependencyInjection.Abstractions                       |
|                                                                                   | * Microsoft.Extensions.Logging.Abstractions                                    |
+-----------------------------------------------------------------------------------+--------------------------------------------------------------------------------+

    
.. _wiring-custom-middleware:
    
Wiring custom middleware
========================

The previous `Startup` snippet already showed how a custom middleware class can be used in the ASP.NET Core pipeline. The Simple Injector ASP.NET Core integration packages add an **UseMiddleware** extension method that allows adding custom middleware. The following listing shows how a `CustomMiddleware` class is added to the pipeline.

.. code-block:: c#

    public void Configure(IApplicationBuilder app, IHostingEnvironment env)
    {
        app.UseSimpleInjector(container, options =>
        {
            options.UseMiddleware<CustomMiddleware>(app);
        });
        
        ...
    }    
    
The type supplied to **UseMiddleware<T>** should implement the `IMiddleware` interface from the `Microsoft.AspNetCore.Http` namespace. A compile error will be given in case the middleware does not implement that interface.
    
This **UseMiddleware** overload ensures two particular things:

* Adds a middleware type to the application's request pipeline. The middleware will be resolved from the supplied the Simple Injector container.
* The middleware type will be added to the container as **Singleton** for :doc:`verification <diagnostics>`.
    
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

Simple Injector simplifies integration of Hosted Services into ASP.NET Core. For this, you need to include the `SimpleInjector.Integration.GenericHost <https://www.nuget.org/packages/SimpleInjector.Integration.GenericHost>`_ NuGet package. For more information on how to integrate Hosted Services into your ASP.NET Core web application, please read the :ref:`Using Hosted Services <using-hosted-services>` section of the :doc:`.NET Generic Host Integration Guide <generichostintegration>`.


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

Simple Injector :ref:`promotes <Push-developers-into-best-practices>` best practices, and because of downsides described above, we consider the use of the `[FromServices]` attribute *not* to be a best practice. This is why we choose not to provide out-of-the-box support for injecting Simple Injector registered dependencies into controller actions. 

In case you still feel method injection is the best option for you, you can plug in a custom `IModelBinderProvider` implementation returning a custom `IModelBinder` that resolves instances from Simple Injector.


.. _resolving-from-validationcontext:

Resolving services from MVC's ValidationContext
===============================================

ASP.NET Core MVC allows you to implement custom validation logic inside model classes using the `IValidatableObject` interface. Although there is nothing inherently wrong with placing validation logic inside the model object itself, problems start to appear when that validation logic requires services to work. By default this will not work with Simple Injector, as the `ValidationContext.GetService` method forwards the call to the built-in configuration system—not to Simple Injector.

In general, you should prevent calling `GetService` or similar methods from within application code, such as MVC model classes. This leads to the Service Locator anti-pattern.

Instead, follow the advice given in `this Stack Overflow answer <https://stackoverflow.com/a/55846598/264697>`_.


.. _razor-pages:

Using Razor Pages
=================

ASP.NET Core 2.0 introduced an MVVM-like model, called `Razor Pages <https://docs.microsoft.com/en-us/aspnet/core/razor-pages/>`_. A Razor Page combines both data and behavior in a single class.

Integration for Razor Pages is part of the *SimpleInjector.Integration.AspNetCore.Mvc* integration package. This integration comes in the form of the **AddPageModelActivation** extension method. This extension method should be used in the **ConfigureServices** method of your `Startup` class:

.. code-block:: c#

    // This method gets called by the runtime.
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



.. _identity:
    
Working with ASP.NET Core Identity
==================================

The default Visual Studio template comes with built-in authentication through the use of ASP.NET Core Identity. The default template requires a fair amount of cross wired dependencies. When auto cross wiring is enabled (when calling **UseSimpleInjector**) integration with ASP.NET Core Identity couldn't be more straightforward. When you followed the :ref:`cross wire guidelines <cross-wiring>`, this is all you'll have to do to get Identity running.

.. container:: Note

    **NOTE**: It is highly advisable to refactor the `AccountController` to *not* to depend on `IOptions<IdentityCookieOptions>` and `ILoggerFactory`. See :ref:`the topic about IOptions\<T\> <ioptions>` for more information.