=============================
ASP.NET MVC Integration Guide
=============================

Simple Injector contains `Simple Injector MVC Integration Quick Start NuGet package <https://nuget.org/packages/SimpleInjector.MVC3>`_.

.. container:: Note

    **Warning**: If you are starting from an Empty MVC project template (File | New | Project | MVC 4 | Empty Project Template) you have to manually setup *System.Web.Mvc* binding redirects, or reference System.Web.Mvc from the GAC.

The following code snippet shows how to use the integration package (note that the quick start package injects this code into your Visual Studio MVC project).

.. code-block:: c#

    // You'll need to include the following namespaces
    using System.Web.Mvc;
    using SimpleInjector;
    using SimpleInjector.Integration.Web;
    using SimpleInjector.Integration.Web.Mvc;

    // This is the Application_Start event from the Global.asax file.
    protected void Application_Start(object sender, EventArgs e) {
        // Create the container as usual.
        var container = new Container();
        container.Options.DefaultScopedLifestyle = new WebRequestLifestyle();
        
        // Register your types, for instance:
        container.Register<IUserRepository, SqlUserRepository>(Lifestyle.Scoped);

        // This is an extension method from the integration package.
        container.RegisterMvcControllers(Assembly.GetExecutingAssembly());
        
        container.Verify();
        
        DependencyResolver.SetResolver(new SimpleInjectorDependencyResolver(container));
    }
