==================================
ASP.NET Core MVC Integration Guide
==================================

Simple Injector offers the `Simple Injector ASP.NET Core MVC Integration NuGet package <https://www.nuget.org/packages/SimpleInjector.Integration.AspNetCore.Mvc>`_.

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
    
    using SimpleInjector;
    using SimpleInjector.Integration.AspNetCore;
    using SimpleInjector.Integration.AspNetCore.Mvc;
    
    public class Startup
    {
        private Container container = new Container();
        
        public Startup(IHostingEnvironment env) 
        {
            // ASP.NET default stuff here
        }

        // This method gets called by the runtime.
        public void ConfigureServices(IServiceCollection services) 
        {
            // ASP.NET default stuff here

            services.AddSingleton<IControllerActivator>(
                new SimpleInjectorControllerActivator(container));
            services.AddSingleton<IViewComponentActivator>(
                new SimpleInjectorViewComponentActivator(container));
        }

        // Configure is called after ConfigureServices is called.
        public void Configure(IApplicationBuilder app, IHostingEnvironment env, ILoggerFactory fac) 
        {
            app.UseSimpleInjectorAspNetRequestScoping(container);

            container.Options.DefaultScopedLifestyle = new AspNetRequestLifestyle();
            
            InitializeContainer(app);
			
            container.Register<CustomMiddleware>();

            container.Verify();
			
            // Add custom middleware
            app.Use(async (context, next) =>
            {
                await container.GetInstance<CustomMiddleware>().Invoke(context, next);
            });

            // ASP.NET default stuff here
        }

        private void InitializeContainer(IApplicationBuilder app) 
        {
            // Add application presentation components:
            container.RegisterMvcControllers(app);
            container.RegisterMvcViewComponents(app);
        
            // Add application services. For instance: 
            container.Register<IUserRepository, SqlUserRepository>(Lifestyle.Scoped);
            
            // Cross-wire ASP.NET services (if any). For instance:
            container.RegisterSingleton(app.ApplicationServices.GetService<ILoggerFactory>());
            // NOTE: Prevent cross-wired instances as much as possible. 
            // See: https://simpleinjector.org/blog/2016/07/
        }
    }
	
Wiring custom middleware
========================

The previous `Startup` snippet already showed how a custom middleware class can be used in the ASP.NET Core pipeline. The following code snippet shows how such `CustomMiddleware` might look like:

.. code-block:: c#
	
    // Example of some custom user-defined middleware component.
    public sealed class CustomMiddleware
    {
        private readonly ILoggerFactory loggerFactory;
        private readonly IUserService userService;

        public CustomMiddleware(ILoggerFactory loggerFactory, IUserService userService)
        {
            this.loggerFactory = loggerFactory;
            this.userService = userService;
        }

        public async Task Invoke(HttpContext context, Func<Task> next)
        {
            // Do something before
            await next();
            // Do something after
        }
    }

Notice how the `CustomMiddleware` class contains dependencies. Since the `CustomMiddleware` class is resolved from Simple Injector for each request.

In contrast to what the official ASP.NET Core documentation `advises <https://docs.microsoft.com/en-us/aspnet/core/fundamentals/middleware#writing-middleware>`_, the `RequestDelegate` or `Func<Task> next` delegate can best be passed in using Method Injection (through the `Invoke` method), instead of by using Constructor Injection. Reason for this is that this delegate is runtime data and runtime data should `not be passed in through the constructor <https://www.cuttingedge.it/blogs/steven/pivot/entry.php?id=99>`_. Moving it to the `Invoke` method makes it possible to reliably verify the application's DI configuration and simplifies your configuration.