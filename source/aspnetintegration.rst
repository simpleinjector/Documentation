======================================
ASP.NET Core Integration Guide (beta!)
======================================

Simple Injector now offers the `Simple Injector ASP.NET Core Integration NuGet package <https://www.nuget.org/packages/SimpleInjector.Integration.AspNet>`_.

The following code snippet shows how to use the integration package to apply Simple Injector to your web application's `Startup` class.

.. code-block:: c#

    // You'll need to include the following namespaces
    using SimpleInjector;
    using SimpleInjector.Extensions.ExecutionContextScoping;
    using SimpleInjector.Integration.AspNet;

    public class Startup
    {
        public Startup(IHostingEnvironment env) 
        {
            // ASP.NET default stuff here
        }

        private Container container = new Container();
        
        // This method gets called by the runtime.
        public void ConfigureServices(IServiceCollection services) 
        {
            // ASP.NET default stuff here

            services.AddInstance<IControllerActivator>(
                new SimpleInjectorControllerActivator(container));
            services.AddInstance<IViewComponentInvokerFactory>(
                new SimpleInjectorViewComponentInvokerFactory(container));
        }

        // Configure is called after ConfigureServices is called.
        public void Configure(IApplicationBuilder app, IHostingEnvironment env, ILoggerFactory fac) 
        {
            container.Options.DefaultScopedLifestyle = new AspNetRequestLifestyle();
        
            app.UseSimpleInjectorAspNetRequestScoping(container);
            
            InitializeContainer(app);

            container.RegisterAspNetControllers(app);
            container.RegisterAspNetViewComponents(app);
        
            container.Verify();

            // ASP.NET default stuff here
        }

        private void InitializeContainer(IApplicationBuilder app) 
        {
            // Add application services. For instance: 
            container.Register<IUserRepository, SqlUserRepository>(Lifestyle.Scoped);
            
            // Cross-wire ASP.NET services (if any). For instance:
            container.CrossWire<ILoggerFactory>(app);
        }
    }

Working with the default Visual Studio 2015 ASP.NET Core template
=================================================================

The default Visual Studio 2015 template for ASP.NET Core injects a lot of code into your project: classes such as a `HomeController`, `AccountController` and empty `AuthMessageSender` and `AuthMessageSender` classes. You will have to make some adjustments to the default template to get it to work with Simple Injector.

**Add application services.**

The default template adds registrations for the `IEmailSender` and `ISmsSender` abstractions to the built-in ASP.NET configuration system but these abstractions are application services and no framework component depends on them (the application components `AccountController` and `ManageController` depend on them). These 2 registrations should be added to Simple Injector.

Remove the two calls to `AddTransient` from the `ConfigureServices` method and replace them with the following registrations in the `InitializeContainer` method:

.. code-block:: c#

    container.Register<IEmailSender, AuthMessageSender>();
    container.Register<ISmsSender, AuthMessageSender>();
    
**Cross-wire required framework services.**

To adhere to the Dependency Inversion Principle (DIP) you should minimize the dependencies your code has on framework supplied abstractions and classes. The Visual Studio template doesn't follow the DIP and lets the generated classes depend on several framework and third party classes and abstractions. To be able to resolve the `AccountController` and `ManageController` from Simple Injector certain framework types need to be cross-wired into Simple Injector. Cross-wiring means that Simple Injector can forward the request for that type to the built-in ASP.NET configuration system. Add the following lines to the `InitializeContainer` method:

.. code-block:: c#

    container.CrossWire<UserManager<ApplicationUser>>(app);
    container.CrossWire<SignInManager<ApplicationUser>>(app);
    container.CrossWire<ILoggerFactory>(app);
    
**Working around a bug in Identity Framework.**

The previous registrations would normally be enough but due to a `bug <https://github.com/aspnet/Identity/issues/674>`_ in the beta's of Identity Framework, Simple Injector's verification will fail when checking the cross-wired `SignInManager<T>` because the `SignInManager<T>`'s constructor incorrectly throws an exception when there's no `HttpContext` available (which is obviously the case when the `SignInManger<T>` is created during application start-up). This bug should be fixed in 3.0.0-rc2 of Identity framework, but in the meantime we need to register a custom `IHttpContextAccessor` to work around the issue:

.. code-block:: c#

    public class NeverNullHttpContextAccessor : IHttpContextAccessor
    {
        AsyncLocal<HttpContext> context = new AsyncLocal<HttpContext>();

        public HttpContext HttpContext
        {
            get { return this.context.Value ?? new DefaultHttpContext(); }
            set { this.context.Value = value; }
        }
    }
    
This class can replace the framework's original implementation by making the following registration in the `ConfigureServices` method:

.. code-block:: c#

    // Work around for a Identity Framework bug inside the SignInManager<T> class.
    services.Add(ServiceDescriptor.Instance<IHttpContextAccessor>(
        new NeverNullHttpContextAccessor()));
	    
**Everything together**

When we put the given adjustments together, we get the following composition root:
	
.. code-block:: c#

    // You'll need to include the following namespaces
    using SimpleInjector;
    using SimpleInjector.Extensions.ExecutionContextScoping;
    using SimpleInjector.Integration.AspNet;

    public class Startup
    {
        public Startup(IHostingEnvironment env)
        {
            // ASP.NET default stuff here
        }

        private Container container = new Container();

        // This method gets called by the runtime.
        public void ConfigureServices(IServiceCollection services)
        {
            // ASP.NET default stuff here

            services.AddInstance<IControllerActivator>(
                new SimpleInjectorControllerActivator(container));
            services.AddInstance<IViewComponentInvokerFactory>(
                new SimpleInjectorViewComponentInvokerFactory(container));
                
            // Work around for a Identity Framework bug inside the SignInManager<T> class.
            services.Add(ServiceDescriptor.Instance<IHttpContextAccessor>(
                new NeverNullHttpContextAccessor()));
        }

        // Configure is called after ConfigureServices is called.
        public void Configure(IApplicationBuilder app, IHostingEnvironment env, ILoggerFactory fac)
        {
            container.Options.DefaultScopedLifestyle = new AspNetRequestLifestyle();

            app.UseSimpleInjectorAspNetRequestScoping(container);

            InitializeContainer(app);

            container.RegisterAspNetControllers(app);
			container.RegisterAspNetViewComponents(app);

            container.Verify();

            // ASP.NET default stuff here
        }

        private void InitializeContainer(IApplicationBuilder app)
        {
            // Add application services. For instance:
            container.Register<IEmailSender, AuthMessageSender>();
            container.Register<ISmsSender, AuthMessageSender>();
            
            container.Register<IUserRepository, SqlUserRepository>(Lifestyle.Scoped);

            // Cross-wire ASP.NET services (if any). For instance:
            container.CrossWire<UserManager<ApplicationUser>>(app);
            container.CrossWire<SignInManager<ApplicationUser>>(app);
            container.CrossWire<ILoggerFactory>(app);
        }
        
        private sealed class NeverNullHttpContextAccessor : IHttpContextAccessor
        {
            private readonly AsyncLocal<HttpContext> context = new AsyncLocal<HttpContext>();

            public HttpContext HttpContext
            {
                get { return this.context.Value ?? new DefaultHttpContext(); }
                set { this.context.Value = value; }
            }
        }
    }