=====================
WCF Integration Guide
=====================

The `Simple Injector WCF Integration NuGet Package <https://nuget.org/packages/SimpleInjector.Integration.Wcf>`_ allows WCF services to be resolved by the container, which enables constructor injection.

After installing this NuGet package, it must be initialized in the start-up path of the application by calling the *SimpleInjectorServiceHostFactory.SetContainer* method:

.. code-block:: c#

    protected void Application_Start(object sender, EventArgs e)
    {
        // Create the container as usual.
        var container = new Container();
        
        // Register your types, for instance:
        container.Register<IUserRepository, SqlUserRepository>();
        container.RegisterPerWcfOperation<IUnitOfWork, EfUnitOfWork>();

        // Register the container to the SimpleInjectorServiceHostFactory.
        SimpleInjectorServiceHostFactory.SetContainer(container);
    }

.. container:: Note

    **Warning**: Instead of what the name of the names of the *WcfOperationLifestyle* class and the *RegisterPerWcfOperation* methods seem to imply, components that are registered with this lifestyle might actually outlive a single WCF operation. This behavior depends on how  the WCF service class is configured. WCF is in control of the lifetime of the service class and contains three lifetime types as defined by the `InstanceContextMode enumeration <https://msdn.microsoft.com/en-us/library/system.servicemodel.instancecontextmode.aspx>`_. Components that are registers *PerWcfOperation* live as long as the WCF service class they are injected into.

For each service class, you should supply a factory attribute in the .SVC file of each service class. For instance:

.. code-block:: xml

    <%@ ServiceHost
        Service="UserService" 
        CodeBehind="UserService.svc.cs" 
        Factory="SimpleInjector.Integration.Wcf.SimpleInjectorServiceHostFactory, SimpleInjector.Integration.Wcf"
    %>

.. container:: Note

    **Note**: Instead of having a WCF service layer consisting of many service classes and methods, consider a design that consists of just a single service class with a single method as explained in `this article <http://www.cuttingedge.it/blogs/steven/pivot/entry.php?id=95>`_. A design where operations are communicated through messages allows the creation of highly maintainable WCF services. With such a design, this integration package will be ​​redundant.