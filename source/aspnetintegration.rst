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
    
    public class Startup {
        private Container container = new Container();
        
        public Startup(IHostingEnvironment env) {
            // ASP.NET default stuff here
        }

        // This method gets called by the runtime.
        public void ConfigureServices(IServiceCollection services) {
            // ASP.NET default stuff here

            services.AddSingleton<IControllerActivator>(
                new SimpleInjectorControllerActivator(container));
            services.AddSingleton<IViewComponentActivator>(
                new SimpleInjectorViewComponentActivator(container));
        }

        // Configure is called after ConfigureServices is called.
        public void Configure(IApplicationBuilder app, IHostingEnvironment env,
            ILoggerFactory factory) {
            app.UseSimpleInjectorAspNetRequestScoping(container);

            container.Options.DefaultScopedLifestyle = new AspNetRequestLifestyle();
            
            InitializeContainer(app);
            
            container.Register<CustomMiddleware>();

            container.Verify();
            
            // Add custom middleware
            app.Use(async (context, next) => {
                await container.GetInstance<CustomMiddleware>().Invoke(context, next);
            });

            // ASP.NET default stuff here
        }

        private void InitializeContainer(IApplicationBuilder app) {
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
    public sealed class CustomMiddleware {
        private readonly ILoggerFactory loggerFactory;
        private readonly IUserService userService;

        public CustomMiddleware(ILoggerFactory loggerFactory, IUserService userService) {
            this.loggerFactory = loggerFactory;
            this.userService = userService;
        }

        public async Task Invoke(HttpContext context, Func<Task> next) {
            // Do something before
            await next();
            // Do something after
        }
    }

Notice how the `CustomMiddleware` class contains dependencies. Since the `CustomMiddleware` class is resolved from Simple Injector for each request.

In contrast to what the official ASP.NET Core documentation `advises <https://docs.microsoft.com/en-us/aspnet/core/fundamentals/middleware#writing-middleware>`_, the `RequestDelegate` or `Func<Task> next` delegate can best be passed in using Method Injection (through the `Invoke` method), instead of by using Constructor Injection. Reason for this is that this delegate is runtime data and runtime data should `not be passed in through the constructor <https://www.cuttingedge.it/blogs/steven/pivot/entry.php?id=99>`_. Moving it to the `Invoke` method makes it possible to reliably verify the application's DI configuration and it simplifies your configuration.

Working with `IOption<T>`
=========================

ASP.NET Core contains a new configuration model based on an `IOption<T>` abstraction. We advise against injecting `IOption<T>` dependencies into your application components. Instead let components depend directly on configuration objects and register them as *Singleton*. This ensures that configuration values are read during application start up and it allows verifying them at that point in time, allowing the application to fail-fast.

Letting application components depend on `IOptions<T>` has some unfortunate downsides. First of all, it causes application code to take an unnecessary dependency on a framework abstraction. This is a violation of the Dependency Injection Principle that prescribes the use of application-tailored abstractions. Injecting an `IOptions<T>` into an application component only makes this component more difficult to test, while providing no benefits. Application components should instead depend directly on the configuration values they require.

`IOptions<T>` configuration values are read lazily. Although the configuration file might be read upon application start up, the required configuration object is only created when `IOptions<T>.Value` is called for the first time. When deserialization fails, because of application misconfiguration, such error will only be appear after the call to `IOptions<T>.Value`. This can cause misconfigurations to keep undetected for much longer than required. By reading -and verifying- configuration values at application start up, this problem can be prevented. Configuration values can be injected as singletons into the component that requires them.

To make things worse, in case you forget to configure a particular section (by omitting a call to `services.Configure<T>`) or when you make a typo while retrieving the configuration section (by supplying the wrong name to `Configuration.GetSection(name)`), the configuration system will simply supply the application with a default and empty object instead of throwing an exception! This may make sense in some cases but it will easily lead to fragile applications./

Since you want to verify the configuration at start-up, it makes no sense to delay reading it, and that makes injecting IOption<T> into your components plain wrong. Depending on `IOptions<T>` might still be useful when bootstrapping the application, but not as a dependency anywhere else.

Once you have a correctly read and verified configuration object, registration of the component that requires the configuration object is as simple as this:

.. code-block:: c#

    MyMailSettings mailSettings =
        config.GetSection("Root:SectionName").Get<MyMailSettings>();

    // Verify mailSettings here (if required)

    container.Register<IMessageSender>(() => new MailMessageSender(mailSettings));
