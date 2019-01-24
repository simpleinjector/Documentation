=================================
ASP.NET Web API Integration Guide
=================================

Simple Injector contains `Simple Injector ASP.NET Web API Integration Quick Start NuGet package for IIS-hosted applications <https://www.nuget.org/packages/SimpleInjector.Integration.WebApi.WebHost.QuickStart>`_. If you're not using NuGet, you must include the **SimpleInjector.Integration.WebApi.dll** in your Web API application, which is part of the standard download on Github.

.. container:: Note

    **Note**: To be able to run the Web API integration packages, `you need <https://stackoverflow.com/questions/22392032/are-there-any-technical-reasons-simpleinjector-cannot-support-webapi-on-net-4-0>`_ *.NET 4.5* or above.

.. _Web-API-basic-setup:
    
Basic setup
===========

The following code snippet shows how to use the integration package (note that the quick start package injects this code for you).

.. code-block:: c#

    // You'll need to include the following namespaces
    using System.Web.Http;
    using SimpleInjector;
    using SimpleInjector.Lifestyles;
    using SimpleInjector.Integration.WebApi;

    // This is the Application_Start event from the Global.asax file.
    protected void Application_Start() {
        // Create the container as usual.
        var container = new Container();
        container.Options.DefaultScopedLifestyle = new AsyncScopedLifestyle();

        // Register your types, for instance using the scoped lifestyle:
        container.Register<IUserRepository, SqlUserRepository>(Lifestyle.Scoped);

        // This is an extension method from the integration package.
        container.RegisterWebApiControllers(GlobalConfiguration.Configuration);

        container.Verify();

        GlobalConfiguration.Configuration.DependencyResolver =
            new SimpleInjectorWebApiDependencyResolver(container);

        // Here your usual Web API configuration stuff.
    }

With this configuration, ASP.NET Web API will create new *IHttpController* instances through the container. Because controllers are concrete classes, the container will be able to create them without any registration. However, to be able to :ref:`verify <Verify-Configuration>` and :doc:`diagnose <diagnostics>` the container's configuration, it is important to register all root types explicitly, which is done by calling **RegisterWebApiControllers**.

.. container:: Note

    **Note**: For Web API applications the use of the **AsyncScopedLifestyle** is advised over the **WebRequestLifestyle**. Please take a look at the :ref:`Web API Request Object Lifestyle Management wiki page <AsyncScoped-vs-WebRequest>` for more information.

Given the configuration above, an actual controller could look like this:

.. code-block:: c#

    public class UserController : ApiController {
        private readonly IUserRepository repository;

        // Use constructor injection here
        public UserController(IUserRepository repository) {
            this.repository = repository;
        }

        public IEnumerable<User> GetAllUsers() => this.repository.GetAll();

        public User GetUserById(int id) {
            try {
                return this.repository.GetById(id);
            } catch (KeyNotFoundException) {
                throw new HttpResponseException(HttpStatusCode.NotFound);
            }
        }
    }

.. _Web-API-extra-features:    
    
Extra features
==============

The basic features of the Web API integration package are the **SimpleInjectorWebApiDependencyResolver** class and the **RegisterWebApiControllers** extension method. Besides these basic features, the integration package contains extra features that can make your life easier.

.. _Getting-the-current-requests-HttpRequestMessage:

Getting the current request's HttpRequestMessage
------------------------------------------------

When working with Web API you will often find yourself wanting access to the current *HttpRequestMessage*. Simple Injector allows fetching the current *HttpRequestMessage* by calling the *container.GetCurrentHttpRequestMessage()* extension method. To be able to request the current *HttpRequestMessage* you need to explicitly enable this as follows:

.. code-block:: c#

    container.EnableHttpRequestMessageTracking(GlobalConfiguration.Configuration);

There are several ways to get the current *HttpRequestMessage* in your services, but since it is discouraged to inject the *Container* itself into any services, the best way is to define an abstraction for this. For instance:

.. code-block:: c#

    public interface IRequestMessageAccessor {
        HttpRequestMessage CurrentMessage { get; }
    }

This abstraction can be injected into your services, which can call the *CurrentMessage* property to get the *HttpRequestMessage*. Close to your DI configuration you can now create an implementation for this interface as follows:

.. code-block:: c#

    private sealed class RequestMessageAccessor : IRequestMessageAccessor {
        private readonly Container container;
        
        public RequestMessageAccessor(Container container) {
            this.container = container;
        }

        public HttpRequestMessage CurrentMessage =>
            this.container.GetCurrentHttpRequestMessage();
    }

This implementation can be implemented as follows:

.. code-block:: c#

    container.RegisterInstance<IRequestMessageAccessor>(
        new RequestMessageAccessor(container));

.. _Injecting-dependencies-into-Web-API-filter-attributes:
    
Injecting dependencies into Web API filter attributes
-----------------------------------------------------

Web API caches filter attribute instances indefinitely per action, effectively making them singletons. This makes them unsuited for dependency injection, since the attribute's dependencies will be accidentally promoted to singleton as well, which can cause all sorts of concurrency issues. This problem is commonly referred to as `Captive Dependencies <https://blog.ploeh.dk/2014/06/02/captive-dependency/>`_ and although Simple Injector tries to detect ref:`find those issues <LifestyleMismatches>`, it will be unable to do so in this this case.

Since dependency injection is not an option here, an other mechanism is advised. There are basically two options here. Which one is best depends on the amount of filter attributes your application needs. If the number of attributes is limited (to a few), the simplest solution is to revert to the Service Locator (anti-)pattern within your attributes. If the number of attributes is larger, it might be better to make attributes passive.

Reverting to Service Locator means that you need to do the following:

* Extract all the attribute's logic -with its dependencies- into a new service class.
* Resolve this service from within the filter attribute's `OnActionExecXXX` methods (but prevent storing the resolved service in a private field as that could lead to undetectable Captive Dependencies).
* Call the service's method.

The following example visualizes this:

.. code-block:: c#

    public class MinimumAgeActionFilter : FilterAttribute {
        public readonly int MinimumAge;

        public MinimumAgeActionFilter(int minimumAge) {
            this.MinimumAge = minimumAge;
        }

        public override Task OnActionExecutingAsync(HttpActionContext actionContext,
            CancellationToken cancellationToken)
        {
            var checker = GlobalConfiguration.Configuration.DependencyResolver
                .GetService(typeof(IMinimumAgeChecker)) as IMinimumAgeChecker;

            checker.VerifyCurrentUserAge(this.MinimumAge);

            return TaskHelpers.Completed();
        }
    }

By moving all the logic and dependencies out of the attribute, the attribute becomes a small infrastructural piece of code; a humble object that simply forwards the call to the real service.
    
If the number of required filter attributes grows, a different model might be in place. In that case you might want to make your attributes `passive <https://blog.ploeh.dk/2014/06/13/passive-attributes/>`_ as explained `here <https://www.cuttingedge.it/blogs/steven/pivot/entry.php?id=98>`_.

.. _Injecting-dependencies-into-Web-API-message-handlers:

Injecting dependencies into Web API message handlers
----------------------------------------------------

The default mechanism in Web API to use HTTP Message Handlers to 'decorate' requests is by adding them to the global *MessageHandlers* collection as shown here:

.. code-block:: c#

    GlobalConfiguration.Configuration.MessageHandlers.Add(new MessageHandler1());

The problem with this approach is that this effectively hooks in the *MessageHandler1* into the Web API pipeline as a singleton. This is fine when the handler itself has no state and no dependencies, but in a system that is based on the SOLID design principles, it's very likely that those handlers will have dependencies of their own and its very likely that some of those dependencies need a lifetime that is shorter than singleton.

If that's the case, such message handler should not be created as singleton, since in general, a component should never have a lifetime that is longer than the lifetime of its dependencies.

The solution is to define a proxy class that sits in between. Since Web API lacks that functionality, we need to build this ourselves as follows:

.. code-block:: c#

    public sealed class DelegatingHandlerProxy<THandler> : DelegatingHandler
        where THandler : DelegatingHandler {
        private readonly Container container;

        public DelegatingHandlerProxy(Container container) {
            this.container = container;
        }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken) {

            // Important: Trigger the creation of the scope.
            request.GetDependencyScope();

            var handler = this.container.GetInstance<THandler>();

            if (!object.ReferenceEquals(handler.InnerHandler, this.InnerHandler)) {
                handler.InnerHandler = this.InnerHandler;
            }

            var invoker = new HttpMessageInvoker(handler);
        
            return invoker.SendAsync(request, cancellationToken);
        }
    }
    
This *DelegatingHandlerProxy<THandler>* can be added as singleton to the global *MessageHandlers* collection, and it will resolve the given *THandler* on each request, allowing it to be resolved according to its lifestyle.

The *DelegatingHandlerProxy<THandler>* can be used as follows:

.. code-block:: c#

    container.Register<MessageHandler1>();

    GlobalConfiguration.Configuration.MessageHandlers.Add(
        new DelegatingHandlerProxy<MessageHandler1>(container));
