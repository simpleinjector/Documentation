=============================
ASP.NET MVC Integration Guide
=============================

.. container:: Note

    **Warning**: This documentation describes integration with the *old* ASP.NET 'classic' MVC framework, which was first released by Microsoft on 13 March 2009 for .NET 3, and which is *no longer maintained* by Microsoft. If you're looking for the new, and actively maintained ASP.NET *Core* (MVC) framework, the integration guide can be found :doc:`here <aspnetintegration>`.

Simple Injector offers the `Simple Injector MVC Integration Quick Start NuGet package <https://nuget.org/packages/SimpleInjector.MVC3>`_ for integration in MVC 3 and up.

.. container:: Note

    **Warning**: If you are starting from an Empty MVC project template (File | New | Project | MVC 4 | Empty Project Template) you have to manually setup *System.Web.Mvc* binding redirects, or reference System.Web.Mvc from the GAC.

.. container:: Note

    **TIP**: Even though this integration packages take a dependency on the Simple Injector core library, prefer installing the `the core library <https://nuget.org/packages/SimpleInjector>`_ explicitly into your startup project. The core library uses an independent versioning and release cycle. Installing the core library explicitly, therefore, gives you the newest, latest release (instead of the lowest compatible release), and allows the NuGet package manager to inform you about new minor and patch releases in the future.

The following code snippet shows how to use the integration package (note that the quick start package injects this code into your Visual Studio MVC project).

.. code-block:: c#

    // You'll need to include the following namespaces
    using System.Web.Mvc;
    using SimpleInjector;
    using SimpleInjector.Integration.Web;
    using SimpleInjector.Integration.Web.Mvc;

    // This is the Application_Start event from the Global.asax file.
    protected void Application_Start(object sender, EventArgs e)
    {
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
