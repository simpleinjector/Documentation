=================================
ASP.NET Web API Integration Guide
=================================

Simple Injector contains `Simple Injector ASP.NET Web API Integration Quick Start NuGet package for IIS-hosted applications <https://www.nuget.org/packages/SimpleInjector.Integration.WebApi.WebHost.QuickStart>`_. If you're not using NuGet, you must include both the **SimpleInjector.Integration.WebApi.dll** and **SimpleInjector.Extensions.ExecutionContextScoping.dll** in your Web API application, which is part of the standard CodePlex download.

.. container:: Note

    **Note**: To be able to run the Web API integration packages, `you need <https://stackoverflow.com/questions/22392032/are-there-any-technical-reasons-simpleinjector-cannot-support-webapi-on-net-4-0>`_ *.NET 4.5* or above.

.. _Web-API-basic-setup:
	
Basic setup
===========

The following code snippet shows how to use the use the integration package (note that the quick start package injects this code for you).

.. code-block:: c#

    // You'll need to include the following namespaces
    using System.Web.Http;
    using SimpleInjector;
    using SimpleInjector.Integration.WebApi;

    // This is the Application_Start event from the Global.asax file.
    protected void Application_Start() {
        // Create the container as usual.
        var container = new Container();

        // Register your types, for instance using the RegisterWebApiRequest
        // extension from the integration package:
        container.RegisterWebApiRequest<IUserRepository, SqlUserRepository>();

        // This is an extension method from the integration package.
        container.RegisterWebApiControllers(GlobalConfiguration.Configuration);

        container.Verify();

        GlobalConfiguration.Configuration.DependencyResolver =
            new SimpleInjectorWebApiDependencyResolver(container);

        // Here your usual Web API configuration stuff.
    }

With this configuration, ASP.NET Web API will create new *IHttpController* instances through the container. Because controllers are concrete classes, the container will be able to create them without any registration. However, to be able to :doc:`diagnose <diagnostics>` and :ref:`verify <Verify-Configuration>` the container's configuration, it is important to register all root types explicitly.

.. container:: Note

    **Note**: For Web API applications the use of the **WebApiRequestLifestyle** is advised over the **WebRequestLifestyle**. Please take a look at the :ref:`Web API Request Object Lifestyle Management wiki page <WebAPIRequest-vs-WebRequest>` for more information.

Given the configuration above, an actual controller could look like this:

.. code-block:: c#

    public class UserController : ApiController {
        private readonly IUserRepository repository;

        // Use constructor injection here
        public UserController(IUserRepository repository) {
            this.repository = repository;
        }

        public IEnumerable<User> GetAllUsers() {
            return this.repository.GetAll();
        }

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

The basic features of the Web API integration package are the **SimpleInjectorWebApiDependencyResolver** class and the **WebApiRequestLifestyle** with its **RegisterWebApiRequest** extension methods. Besides these basic features, the integration package contains extra features that can make your life easier.

.. _Getting-the-current-requests-HttpRequestMessage:

Getting the current request's HttpRequestMessage
------------------------------------------------

When working with Web API you will often find yourself wanting access to the current *HttpRequestMessage*. Simple Injector allows fetching the current *HttpRequestMessage* by calling the *container.GetCurrentHttpRequestMessage()* extension method. To be able to request the current *HttpRequestMessage* you need to explicitly enable this as follows:

.. code-block:: c#

    container.EnableHttpRequestMessageTracking(GlobalConfiguration.Configuration);

There are several ways to get the current *HttpRequestMessage* in your services, but since it is discouraged to inject the *Container* itself into any services, the best way is to define an abstraction for this. For instance:

.. code-block:: c#

    public interface IRequestMessageProvider {
        HttpRequestMessage CurrentMessage { get; }
    }

This abstraction can be injected into your services, which can call the *CurrentMessage* property to get the *HttpRequestMessage*. Close to your DI configuration you can now create an implementation for this interface as follows:

.. code-block:: c#

    // Register this class per Web API request
    private sealed class RequestMessageProvider : IRequestMessageProvider {
        private readonly Lazy<HttpRequestMessage> message;
        
        public RequestMessageProvider(Container container) {
            this.message = new Lazy<HttpRequestMessage>(
                () => container.GetCurrentHttpRequestMessage());
        }

        public HttpRequestMessage CurrentMessage {
            get { return this.message.Value; }
        }
    }

This implementation can be implemented as follows:

.. code-block:: c#

    container.RegisterWebApiRequest<IRequestMessageProvider, RequestMessageProvider>();

.. _Injecting-dependencies-into-Web-API-filter-attributes:
	
Injecting dependencies into Web API filter attributes
-----------------------------------------------------

Simple Injector allows integrating Web API filter attributes with the Simple Injector pipeline. This means that Simple Injector can inject properties into those attributes and allow any registered initializer delegates to be applied to those attributes. Constructor injection however is out of the picture. Since it is the reflection API of the CLR that is responsible for creating attributes, it's impossible to inject dependencies into the attribute's constructor.

To allow attributes to be integrated into the Simple Injector pipeline, you have to register a custom filter provider as follows:

.. code-block:: c#

    container.RegisterWebApiFilterProvider(GlobalConfiguration.Configuration);

This ensures that attributes are initialized by Simple Injector according to the container's configuration. This by itself however, doesn't do much, since Simple Injector will not inject any properties by default. By registering a custom **IPropertySelectionBehavior** however, you can property injection to take place on attributes. An example of such custom behavior is given :ref:`here <ImportPropertySelectionBehavior>` in the advanced sections of the wiki.

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

            handler.InnerHandler = this.InnerHandler;

            var invoker = new HttpMessageInvoker(handler);
        
            return invoker.SendAsync(request, cancellationToken);
        }
    }
	
This *DelegatingHandlerProxy<THandler>* can be added as singleton to the global *MessageHandlers* collection, and it will resolve the given *THandler* on each request, allowing it to be resolved according to its lifestyle. 

.. container:: Note

	**Warning**: Prevent registering any *THandler* with a lifestyle longer than the request, since message handlers are **not** thread-safe (just look at the assignment of *InnerHandler* in the *SendAsync* method and you'll understand why).

The *DelegatingHandlerProxy<THandler>* can be used as follows:

.. code-block:: c#

    container.Register<MessageHandler1>();

    GlobalConfiguration.Configuration.MessageHandlers.Add(
        new DelegatingHandlerProxy<MessageHandler1>(container));