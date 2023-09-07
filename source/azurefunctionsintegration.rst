===========================
Azure Functions Integration
===========================

.. container:: Note

    **WARNING**: This integration guide is an evolving document. It gets updated any time we find better ways to integrate Simple Injector with Azure Functions, and any time Microsoft makes improvement that simplify integration. If you run into any limitations, other than the ones already mentioned below, help us improve this guidance by reporting this on `our forum <https://simpleinjector.org/forum>`_.

This integration guide has the following prerequisites:

* Azure Function v3 (.NET Core)
* `Simple Injector <nuget.org/packages/Simpleinjector>`_ core library >= v5.3
* `Simple Injector Service Collection Integration <https://www.nuget.org/packages/SimpleInjector.Integration.ServiceCollection/>`_ >= v5.3

.. container:: Note

    **TIP**: Even though the Service Collection integration package takes a dependency on the Simple Injector core library, prefer installing the `the core library <https://nuget.org/packages/SimpleInjector>`_ explicitly into your startup project. The core library uses an independent versioning and release cycle. Installing the core library explicitly, therefore, gives you the newest, latest release (instead of the lowest compatible release), and allows the NuGet package manager to inform you about new minor and patch releases in the future.

Please be aware that due to current state of Azure Functions, it is impossible to inject Simple Injector-registered components into an Azure Function class. Azure Function classes can only contain dependencies registered through the built-in registration API. The integration below tries to mitigate this by injecting an Adapter (the `AzureToSimpleInjectorMediator`) into the Azure Function that forwards the call to Simple Injector.

.. container:: Note

    **IMPORTANT**: This integration guide assumes you are using a command/query/CQRS-like architecture. If you're not currently using this type of design, consider refactoring your code into such style. There are a lot of online resources that can be helpful, such as `this <https://blogs.cuttingedge.it/steven/p/commands/>`_ and `this <https://blogs.cuttingedge.it/steven/p/queries/>`_ or read chapter 10 of `Dependency Injection Principles, Practices, and Patterns <https://cuttingedge.it/book/>`_. Alternatively, look at reusable libraries such as `MediatR <https://github.com/jbogard/MediatR>`_ for inspiration.

Instead of implementing business logic inside an Azure Function class, you yield better results by moving this logic out of your Azure Function class and make a Function class into a `Humble Object <https://martinfowler.com/bliki/HumbleObject.html>`_. This can be done by injecting the extracted service directly into the Azure Function's constructor -or- as shown below, by introducing a Mediator that delegates the request to an underlying handler implementation. This next code snippet demonstrates the suggested way of constructing your Azure Function classes:
    
.. code-block:: c#

    public class Function1
    {
        // Note that this IMediator interface is defined later on in this document.
        private readonly IMediator mediator;

        public Function1(IMediator mediator) => this.mediator = mediator;

        [FunctionName("Function1")]
        public async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", "post", Route = null)] HttpRequest req)
        {
            return await this.mediator.HandleAsync(new Function1Request(req));
        }
    }

The previous `Function1` class is a refactored version of the Azure Function that comes with Visual Studio's Azure Functions template. All `Function1` does is wrapping all relevant request information into a new `Function1Request` object and pass it on to the mediator. `Function1Request` is shown in the following snippet:

.. code-block:: c#

    public sealed class Function1Request : IRequest<ObjectResult>
    {
        public Function1Request(HttpRequest req) => this.Req = req;

        public HttpRequest Req { get; }
    }

All relevant logic is extracted from `Function1` into the `Function1Handler`, shown in the following listing. 

.. code-block:: c#

    using System.IO;
    using System.Threading.Tasks;
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.Extensions.Logging;
    using Newtonsoft.Json;

    public sealed class Function1Handler : IRequestHandler<Function1Request, ObjectResult>
    {
        private readonly ILogger log;

        public Function1Handler(ILogger log) => this.log = log;

        public async Task<ObjectResult> HandleAsync(Function1Request message)
        {
            // NOTE: Don't forget to add your applications root namespace to logging/logLevel
            // node of the the application's host.json. Otherwise the line below won't log.
            this.log.LogInformation("C# HTTP trigger function processed a request.");

            string name = message.Req.Query["name"];

            string requestBody = await new StreamReader(message.Req.Body).ReadToEndAsync();
            dynamic data = JsonConvert.DeserializeObject(requestBody);
            name = name ?? data?.name;

            string responseMessage = string.IsNullOrEmpty(name)
                ? "This HTTP triggered function executed successfully. Pass a name in the " +
                    "query string or in the request body for a personalized response."
                : "Hello, " + name + ". This HTTP triggered function executed successfully.";

            return new OkObjectResult(responseMessage);
        }
    }

`Function1Handler` is a plain-old C# object, which contains the code extracted from the Azure Function. It implements the application-defined `IRequestHandler<TRequest, TResult>` interface. The addition of this interface allows the `IMediator` implementation to dispatch the request to the correct underlying handler, and additionally allows cross-cutting concerns to be applied around the execution of those handlers.

The previous code samples showed usages of the `IMediator`, `IRequest<TResult>`, and `IRequestHandler<TRequest, TResult>` interfaces. The listing below shows their definitions:

.. code-block:: c#

    public interface IMediator
    {
        Task<TResult> HandleAsync<TResult>(IRequest<TResult> message);
    }
    
    public interface IRequest<TResult> { }
    
    public interface IRequestHandler<TRequest, TResult> where TRequest : IRequest<TResult>
    {       
        Task<TResult> HandleAsync(TRequest message);
    }
    

.. container:: Note

    **TIP**: The three previous interfaces are just for demonstrative purposes. Depending on your architectural style and application, you might structure these interfaces differently, or have separate interfaces for commands and queries. Prefer not letting third-party libraries dictate the shape of these interfaces for you; pick the design that works best for your application.

To start, your Azure Functions application requires a bootstrapper that ties everything together. The following `Startup` class demonstrates how to tie Simple Injector in with the Azure Functions eco system:

.. code-block:: c#

    using System;
    using Microsoft.Azure.Functions.Extensions.DependencyInjection;
    using Microsoft.Extensions.DependencyInjection;
    using SimpleInjector;

    [assembly: FunctionsStartup(typeof(MyAzureFunctionsApp.Startup))]
    namespace MyAzureFunctionsApp
    {
        public class Startup : FunctionsStartup
        {
            private readonly Container container = new Container();

            public void ConfigureServices(IServiceCollection services)
            {
                services.AddSingleton(this);
                services.AddSingleton<Completion>();
                services.AddScoped(typeof(IMediator), typeof(AzureToSimpleInjectorMediator));

                services.AddSimpleInjector(container, options =>
                {
                    // Prevent the use of hosted services (not supported by Azure Functions).
                    options.EnableHostedServiceResolution = false;

                    // Allow injecting ILogger into application components
                    options.AddLogging();
                });

                InitializeContainer();
            }

            private void InitializeContainer()
            {
                // Batch-register all your request handlers.
                container.Register(typeof(IRequestHandler<,>), this.GetType().Assembly);
                // TODO: Add your registrations here.
            }

            public void Configure(IServiceProvider app)
            {
                // Complete the Simple Injector integration (enables cross wiring).
                app.UseSimpleInjector(container);

                container.Verify();
            }

            public override void Configure(IFunctionsHostBuilder builder) =>
                this.ConfigureServices(builder.Services);

            // HACK: Triggers the completion of the Simple Injector integration
            public sealed class Completion
            {
                public Completion(Startup s, IServiceProvider app) => s.Configure(app);
            }
        }
    }

The only part missing from the equation is the `IMediator` implementation, which is given in this last listing:

.. code-block:: c#

    using System;
    using System.Threading.Tasks;
    using Microsoft.Extensions.DependencyInjection;
    using SimpleInjector;
    using SimpleInjector.Integration.ServiceCollection;
    using SimpleInjector.Lifestyles;

    public sealed class AzureToSimpleInjectorMediator : IMediator
    {
        private readonly Container container;
        private readonly IServiceProvider serviceProvider;

        public AzureToSimpleInjectorMediator(
            // NOTE: Do note remove the Completion dependency. Its resolution triggers the
            // finalization of the Simple Injector integration.
            Startup.Completion completor, Container container, IServiceProvider provider)
        {
            this.container = container;
            this.serviceProvider = provider;
        }

        private interface IRequestHandler<TResult>
        {
            Task<TResult> HandleAsync(IRequest<TResult> message);
        }

        // NOTE: There seems to be no support for async disposal for framework types in AF3,
        // but using the code below, atleast Simple Injector-registered components will get
        // disposed asynchronously.
        public async Task<TResult> HandleAsync<TResult>(IRequest<TResult> message)
        {
            // Wrap the operation in a Simple Injector scope
            await using (AsyncScopedLifestyle.BeginScope(this.container))
            {
                // Allow Simple Injector to cross wire framework dependencies.
                this.container.GetInstance<ServiceScopeProvider>().ServiceScope =
                    new ServiceScope(this.serviceProvider);

                return await this.HandleCoreAsync(message);
            }
        }

        private async Task<TResult> HandleCoreAsync<TResult>(IRequest<TResult> message) =>
            await this.GetHandler(message).HandleAsync(message);

        private IRequestHandler<TResult> GetHandler<TResult>(IRequest<TResult> message)
        {
            var handlerType = typeof(IRequestHandler<,>)
                .MakeGenericType(message.GetType(), typeof(TResult));
            var wrapperType = typeof(RequestHandlerWrapper<,>)
                .MakeGenericType(message.GetType(), typeof(TResult));

            return (IRequestHandler<TResult>)Activator.CreateInstance(
                wrapperType, container.GetInstance(handlerType));
        }

        private class RequestHandlerWrapper<TRequest, TResult> : IRequestHandler<TResult>
            where TRequest : IRequest<TResult>
        {
            public RequestHandlerWrapper(IRequestHandler<TRequest, TResult> handler) =>
                this.Handler = handler;

            public IRequestHandler<TRequest, TResult> Handler { get; }

            public Task<TResult> HandleAsync(IRequest<TResult> message) =>
                this.Handler.HandleAsync((TRequest)message);
        }

        private sealed class ServiceScope : IServiceScope
        {
            public ServiceScope(IServiceProvider serviceProvider) =>
                this.ServiceProvider = serviceProvider;

            public IServiceProvider ServiceProvider { get; }

            public void Dispose() { }
        }
    }

The presented code provides you with a template for a working Azure Functions application. Using this template, you can now start adding your own functions, requests, and handlers to start building your own awesome Azure Functions application.