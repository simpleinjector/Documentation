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

            container.Verify();

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
            // See: https://simpleinjector.org/blog/comingsoon
        }
    }
