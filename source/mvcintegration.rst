=============================
ASP.NET MVC Integration Guide
=============================

Simple Injector contains `Simple Injector MVC Integration Quick Start NuGet package <https://nuget.org/packages/SimpleInjector.MVC3>`_. If you're not using NuGet, you can include the **SimpleInjector.Integration.Web.Mvc.dll** in your MVC application, which is part of the standard CodePlex download.

.. container:: Note

    **Warning**: If you are starting from an Empty MVC project template (File | New | Project | MVC 4 | Empty Project Template) you have to manually setup *System.Web.Mvc* binding redirects, or reference System.Web.Mvc from the GAC.

The following code snippet shows how to use the use the integration package (note that the quick start package this code for you).

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
    	
        // This is an extension method from the integration package as well.
        container.RegisterMvcIntegratedFilterProvider();

        container.Verify();
    	
        DependencyResolver.SetResolver(new SimpleInjectorDependencyResolver(container));
    }
	
.. container:: Note

	For an example of how to apply decorators to MVC controllers, please take a look at `this Stackoverflow question <https://stackoverflow.com/questions/32118849>`_.