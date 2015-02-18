=====================
WCF Integration Guide
=====================

The `Simple Injector WCF Integration NuGet Package <https://nuget.org/packages/SimpleInjector.Integration.Wcf>`_ allows WCF services to be resolved by the container, which enables constructor injection.

After installing this NuGet package, it must be initialized in the start-up path of the application by calling the **SimpleInjectorServiceHostFactory.SetContainer** method:

.. code-block:: c#

    protected void Application_Start(object sender, EventArgs e) {
        // Create the container as usual.
        var container = new Container();
        
        // Register your types, for instance:
        container.Register<IUserRepository, SqlUserRepository>();
        container.RegisterPerWcfOperation<IUnitOfWork, EfUnitOfWork>();

        // Register the container to the SimpleInjectorServiceHostFactory.
        SimpleInjectorServiceHostFactory.SetContainer(container);
    }

.. container:: Note

    **Warning**: Instead of what the name of the **WcfOperationLifestyle** class and the **RegisterPerWcfOperation** methods seem to imply, components that are registered with this lifestyle might actually outlive a single WCF operation. This behavior depends on how the WCF service class is configured. WCF is in control of the lifetime of the service class and contains three lifetime types as defined by the `InstanceContextMode enumeration <https://msdn.microsoft.com/en-us/library/system.servicemodel.instancecontextmode.aspx>`_. Components that are registered *PerWcfOperation* live as long as the WCF service class they are injected into.

For each service class, you should supply a factory attribute in the .SVC file of each service class. For instance:

.. code-block:: xml

    <%@ ServiceHost
        Service="UserService" 
        CodeBehind="UserService.svc.cs" 
        Factory="SimpleInjector.Integration.Wcf.SimpleInjectorServiceHostFactory,
            SimpleInjector.Integration.Wcf"
    %>

.. container:: Note

    **Note**: Instead of having a WCF service layer consisting of many service classes and methods, consider a design that consists of just a single service class with a single method as explained in `this article <http://www.cuttingedge.it/blogs/steven/pivot/entry.php?id=95>`_. A design where operations are communicated through messages allows the creation of highly maintainable WCF services. With such a design, this integration package will be ??redundant.
    
WAS Hosting and Non-HTTP Activation
===================================

When hosting WCF Services in WAS (Windows Activation Service), you are not given an opportunity to build your container in the Application_Start event defined in your Global.asax because WAS doesn't use the standard ASP.NET pipeline. A workaround for this is to move the container initialization to a static constructor

.. code-block:: c#

    public static class Bootstrapper {
        public static readonly Container Container;
     
        static Bootstrapper() {
            var container = new Container();
     
            // register all your components with the container here:
            // container.Register<IService1, Service1>()
            // container.RegisterLifetimeScope<IDataContext,DataContext>();
     
            container.Verify();
     
            Container = container;
        }
    }
 
Your custom *ServiceHostFactory* can no use the static **Bootstrapper.Container** field:
 
.. code-block:: c#
 
    public class WcfServiceFactory : SimpleInjectorServiceHostFactory {
        protected override ServiceHost CreateServiceHost(Type serviceType,
            Uri[] baseAddresses) {
            return new SimpleInjectorServiceHost(
                Bootstrapper.Container, 
                serviceType, 
                baseAddresses);
        }
    }

Optionally, you can apply your custom service behaviors and contract behaviors to the service host:
	
.. code-block:: c#
     
    public class WcfServiceFactory : SimpleInjectorServiceHostFactory {
        protected override ServiceHost CreateServiceHost(Type serviceType,
            Uri[] baseAddresses) {
            var host = new SimpleInjectorServiceHost(
                Bootstrapper.Container, 
                serviceType, 
                baseAddresses);
     
            // This is all optional
            this.ApplyServiceBehaviors(host);
            this.ApplyContractBehaviors(host);
     
            return host;
        }
     
        private void ApplyServiceBehaviors(ServiceHost host) {
            foreach (var behavior in this.container.GetAllInstances<IServiceBehavior>()) {
                host.Description.Behaviors.Add(behavior);
            }
        }
     
        private void ApplyContractBehaviors(SimpleInjectorServiceHost host) {
            foreach (var behavior in this.container.GetAllInstances<IContractBehavior>()) {
                foreach (var contract in host.GetImplementedContracts()) {
                    contract.Behaviors.Add(behavior);
                }
            }
        }
    }

For each service class, you should supply a factory attribute in the .SVC file of each service class. For instance:

.. code-block:: xml

    <%@ ServiceHost
        Service="UserService" 
        CodeBehind="UserService.svc.cs" 
        Factory="SimpleInjector.Integration.Wcf.SimpleInjectorServiceHostFactory,
            SimpleInjector.Integration.Wcf"
    %>

.. container:: Note

    **Note**: Instead of having a WCF service layer consisting of many service classes and methods, consider a design that consists of just a single service class with a single method as explained in `this article <http://www.cuttingedge.it/blogs/steven/pivot/entry.php?id=95>`_. A design where operations are communicated through messages allows the creation of highly maintainable WCF services. With such a design, this integration package will be ??redundant.