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
    using Microsoft.AspNetCore.Http; 
    
    using SimpleInjector;
    using SimpleInjector.Lifestyles;
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
        public void Configure(IApplicationBuilder app, IHostingEnvironment env,
            ILoggerFactory factory) {
            
            InitializeContainer(app);
            
            container.Register<CustomMiddleware1>();
            container.Register<CustomMiddleware2>();

            container.Verify();
            
            // Add custom middleware
            app.Use((c, next) => container.GetInstance<CustomMiddleware1>().Invoke(c, next));
            app.Use((c, next) => container.GetInstance<CustomMiddleware2>().Invoke(c, next));
            
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
            
            // Cross-wire ASP.NET services (if any). For instance:
            container.CrossWire<ILoggerFactory>(app);
               
            // NOTE: Do prevent cross-wired instances as much as possible. 
            // See: https://simpleinjector.org/blog/2016/07/
        }
    }
    
.. _wiring-custom-middleware:
    
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

Notice how the `CustomMiddleware` class contains dependencies. Because of this, the `CustomMiddleware` class is resolved from Simple Injector on each request.

In contrast to what the official ASP.NET Core documentation `advises <https://docs.microsoft.com/en-us/aspnet/core/fundamentals/middleware#writing-middleware>`_, the `RequestDelegate` or `Func<Task> next` delegate can best be passed in using **Method Injection** (through the `Invoke` method), instead of by using Constructor Injection. Reason for this is that this delegate is runtime data and runtime data should `not be passed in through the constructor <https://www.cuttingedge.it/blogs/steven/pivot/entry.php?id=99>`_. Moving it to the `Invoke` method makes it possible to reliably verify the application's DI configuration and it simplifies your configuration.

.. _cross-wiring:

Cross-wiring ASP.NET and third party services
=============================================

When your application code (i.e. a `Controller`) needs a service which integrates with the ASP.NET Core configuration system it is sometimes necessary to cross-wire these dependencies. Cross-wiring is the process where a type is created and maintained by the ASP.NET Core configuration system and is fed to Simple Injector so Simple Injector can use the created instance to supply it as a dependency to your application code.

To use this feature, Simple Injector contains the **CrossWire<TService>** extension method. This method does the required blumbing such as making sure the type is registered with the same lifestyle as configured in ASP.NET Core.

To setup cross-wiring first you must make a call to **EnableSimpleInjectorCrossWiring** on `IServiceCollection` in the `ConfigureServices` method of your `Startup` class.

.. code-block:: c#

    services.EnableSimpleInjectorCrossWiring(container);

When cross-wiring is enabled cross-wiring is as simple as:

.. code-block:: c#

    container.CrossWire<ILoggerFactory>(app);

.. container:: Note

    **NOTE**: Do prevent the use of cross-wiring as much as possible. In most cases cross-wiring is not the best solution and is a violation of the `Dependency Inversion Principle <https://en.wikipedia.org/wiki/Dependency_inversion_principle>`_. Don't depend directly upon Framework components and instead create application specific proxy and/or adapter implementations.

.. _identity:
    
Working with ASP.NET Core Identity
==================================

The default Visual Studio template comes with built-in authentication through the use of ASP.NET Core Identity. To get the code from the template working only a few services from Identity need to be cross-wired.

You can use this code snippet to get things working quickly

.. code-block:: c#

    public class Startup
    {
        private readonly Container container = new Container();

        public Startup(IHostingEnvironment env) { 
            // ASP.NET default stuff here
        }

        // This method gets called by the runtime. 
        public void ConfigureServices(IServiceCollection services) {
            // Add framework services for Identity.
            services.AddDbContext<ApplicationDbContext>(options =>
                options.UseSqlServer(Configuration.GetConnectionString("DefaultConnection")));
            
            services.AddIdentity<ApplicationUser, IdentityRole>()
                .AddEntityFrameworkStores<ApplicationDbContext>()
                .AddDefaultTokenProviders();

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
        public void Configure(IApplicationBuilder app, IHostingEnvironment env,
            ILoggerFactory loggerFactory) {
            
            InitializeContainer(app);
            
            container.Verify();

            // ASP.NET default stuff here
            // Add Identity middleware
            app.UseIdentity();

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

            // Add application services for AccountController
            container.RegisterSingleton<IEmailSender, AuthMessageSender>();
            container.RegisterSingleton<ISmsSender, AuthMessageSender>();

            // Cross wire Identity services
            container.CrossWire<UserManager<ApplicationUser>>(app);
            container.CrossWire<SignInManager<ApplicationUser>>(app);
            
            // Cross wire other AccountController dependencies
            container.CrossWire<ILoggerFactory>(app);
            container.CrossWire<IOptions<IdentityCookieOptions>>(app);

            // NOTE: It is highly advisable to refactor the AccountController
            // and NOT to depend on IOptions<IdentityCookieOptions> and ILoggerFactory
            // See: https://simpleinjector.org/aspnetcore#working-with-ioption-t
        }
    }

.. _ioption:
    
Working with `IOption<T>`
=========================

ASP.NET Core contains a new configuration model based on an `IOption<T>` abstraction. We advise against injecting `IOption<T>` dependencies into your application components. Instead let components depend directly on configuration objects and register them as *Singleton*. This ensures that configuration values are read during application start up and it allows verifying them at that point in time, allowing the application to fail-fast.

Letting application components depend on `IOptions<T>` has some unfortunate downsides. First of all, it causes application code to take an unnecessary dependency on a framework abstraction. This is a violation of the Dependency Injection Principle that prescribes the use of application-tailored abstractions. Injecting an `IOptions<T>` into an application component only makes this component more difficult to test, while providing no benefits. Application components should instead depend directly on the configuration values they require.

`IOptions<T>` configuration values are read lazily. Although the configuration file might be read upon application start up, the required configuration object is only created when `IOptions<T>.Value` is called for the first time. When deserialization fails, because of application misconfiguration, such error will only be appear after the call to `IOptions<T>.Value`. This can cause misconfigurations to keep undetected for much longer than required. By reading -and verifying- configuration values at application start up, this problem can be prevented. Configuration values can be injected as singletons into the component that requires them.

To make things worse, in case you forget to configure a particular section (by omitting a call to `services.Configure<T>`) or when you make a typo while retrieving the configuration section (by supplying the wrong name to `Configuration.GetSection(name)`), the configuration system will simply supply the application with a default and empty object instead of throwing an exception! This may make sense in some cases but it will easily lead to fragile applications.

Since you want to verify the configuration at start-up, it makes no sense to delay reading it, and that makes injecting IOption<T> into your components plain wrong. Depending on `IOptions<T>` might still be useful when bootstrapping the application, but not as a dependency anywhere else.

Once you have a correctly read and verified configuration object, registration of the component that requires the configuration object is as simple as this:

.. code-block:: c#

    MyMailSettings mailSettings =
        config.GetSection("Root:SectionName").Get<MyMailSettings>();

    // Verify mailSettings here (if required)

    // Supply mailSettings as constructor argument to a type that requires it,
    container.Register<IMessageSender>(() => new MailMessageSender(mailSettings));

    // or register MailSettings as singleton in the container.
    container.RegisterSingleton<MyMailSettings>(mailSettings);
    container.Register<IMessageSender, MailMessageSender>();