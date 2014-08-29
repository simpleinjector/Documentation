=================================
ASP.NET Web API Integration Guide
=================================

.. container:: Note

    **Note**: this wiki page is specific for *Simple Injector version 2.5* and up. Look `here <https://simpleinjector.codeplex.com/wikipage?title=Web API Integration&version=8>`_ for documentation for earlier versions.

Simple Injector contains `Simple Injector ASP.NET Web API Integration Quick Start NuGet package for IIS-hosted applications <https://www.nuget.org/packages/SimpleInjector.Integration.WebApi.WebHost.QuickStart>`_. If you're not using NuGet, you must include both the *SimpleInjector.Integration.WebApi.dll* and *SimpleInjector.Extensions.ExecutionContextScoping.dll* in your Web API application, which is part of the standard CodePlex download.

.. container:: Note

    **Note**: To be able to run the Web API integration packages, `you need <https://stackoverflow.com/questions/22392032/are-there-any-technical-reasons-simpleinjector-cannot-support-webapi-on-net-4-0>`_ *.NET 4.5* or above.

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

With this configuration, ASP.NET Web API will create new **IHttpController** instances through the container. Because controllers are concrete classes, the container will be able to create them without any registration. However, to be able to :doc:`diagnose <diagnostics>` and :ref:`verify <Verify-Configuration>` the container's configuration, it is important to register all root types explicitly.

.. container:: Note

    **Note**: For Web API applications the use of the *WebApiRequestLifestyle* is adviced over the *WebRequestLifestyle*. Please take a look at the :ref:`Web API Request Object Lifestyle Management wiki page <WebAPIRequest_vs_WebRequest>` for more information.

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
            }
            catch (KeyNotFoundException) {
                throw new HttpResponseException(HttpStatusCode.NotFound);
            }
        }
    }

Extra features
==============

The basic features of the Web API integration package are the *SimpleInjectorWebApiDependencyResolver* class and the *WebApiRequestLifestyle* with its *RegisterWebApiRequest* extension methods. Besides these basic features, the integration package contains extra features that can make your life easier.

Getting the current request's HttpRequestMessage
------------------------------------------------

When working with Web API you will often find yourself wanting access to the current **HttpRequestMessage_. Simple Injector allows fetching the current **HttpRequestMessage** by calling the **container.GetCurrentHttpRequestMessage()** extension method. To be able to request the current **HttpRequestMessage** you need to explicitly enable this as follows:

.. code-block:: c#

    container.EnableHttpRequestMessageTracking(GlobalConfiguration.Configuration);

There are several ways to get the current **HttpRequestMessage** in your services, but since it is discouraged to inject the **Container** itself into any services, the best way is to define an abstraction for this. For instance:

.. code-block:: c#

    public interface IRequestMessageProvider {
        HttpRequestMessage CurrentMessage { get; }
    }

This abstraction can be injected into your services, which can call the **CurrentMessage** property to get the **HttpRequestMessage**. Close to your DI configuration you can now create an implementation for this interface as follows:

.. code-block:: c#

    // Register this class per Web API request
    private sealed class RequestMessageProvider
        : IRequestMessageProvider {
        private readonly Container container;
        private readonly Lazy<HttpRequestMessage> message;
        
        public RequestMessageProvider(Container container) {
            this.container = container;
            this.message = new Lazy<HttpRequestMessage>(
                () => container.GetCurrentHttpRequestMessage();
        }

        public HttpRequestMessage CurrentMessage {
            get { return this.message.Value; }
        }
    }

This implementation can be implemented as follows:

.. code-block:: c#

    container.RegisterWebApiRequest<IRequestMessageProvider, RequestMessageProvider>();

Injecting dependencies into Web API filter attributes
-----------------------------------------------------

Simple Injector allows integrating Web API filter attributes with the Simple Injector pipeline. This means that Simple Injector can inject properties into those attributes and allow any registered initializer delegates to be applied to those attributes. Constructor injection however is out of the picture. Since it is the reflection API of the CLR that is responsible for creating attributes, it's impossible to inject dependencies into the attribute's constructor.

To allow attributes to be integrated into the Simple Injector pipeline, you have to register a custom filter provider as follows:

.. code-block:: c#

    container.RegisterWebApiFilterProvider(GlobalConfiguration.Configuration);

This ensures that attributes are initialized by Simple Injector according to the container's configuration. This by itself however, doesn't do much, since Simple Injector will not inject any properties by default. By registering a custom *IPropertySelectionBehavior* however, you can property injection to take place on attributes. An example of such custom behavior is given :ref:`here <ImportPropertySelectionBehavior>` in the advanced sections of the wiki.