===================================
.NET Generic Host Integration Guide
===================================

Simple Injector offers the `Simple Injector Generic Host Integration NuGet package <https://www.nuget.org/packages/SimpleInjector.Integration.GenericHost>`_ for integration with .NET Core 2.1 Generic Host applications.

.. container:: Note

    **WARNING**: Due to breaking changes in ASP.NET Core 3, it is currently impossible to use the `AddHostedService` extension methods with the new `Microsoft.Extensions.Hosting.Host` class. If you want to resolve hosted services from Simple Injector while using ASP.NET Core 3, please revert to using `Microsoft.AspNetCore.WebHost` in your `Program` class until we have a fix.

The following code snippet shows how to use the integration package to apply Simple Injector to your Console application's `Main` method:

.. code-block:: c#

    public static async Task Main(string[] args)
    {
        var container = new Container();

        IHost host = new HostBuilder()
            .ConfigureHostConfiguration(configHost => { ... })
            .ConfigureAppConfiguration((hostContext, configApp) => { ... })
            .ConfigureServices((hostContext, services) =>
            {
                services.AddLocalization(options => options.ResourcesPath = "Resources");

                services.AddSimpleInjector(container, options =>
                {
                    // Hooks hosted services into the Generic Host pipeline
                    // while resolving them through Simple Injector
                    options.AddHostedService<MyHostedService>();
                });
            })
            .ConfigureLogging((hostContext, configLogging) => { ... })
            .UseConsoleLifetime()
            .Build()
            .UseSimpleInjector(container, options =>
            {
                // Allows injection of ILogger & IStringLocalizer dependencies into
                // application components.
                options.UseLogging();
                options.UseLocalization();
            });
            
        // Register application components.
        container.Register<MainService>();

        container.Verify();

        await host.RunAsync();
    }

The integration consists of two methods, namely **AddSimpleInjector** and **UseSimpleInjector**, that need to be called at certain stages in the startup phase:

* **AddSimpleInjector** is an extension on `IServiceCollection` and sets up the ground work for the next method to complete.
* **UseSimpleInjector** is an extension on `IHost` and allows Simple Injector to resolve framework components from the underlying `IServiceProvider`. This process is called cross wiring and is described in more detail :ref:`here <cross-wiring-third-party-services>`.

Both **AddSimpleInjector** and **UseSimpleInjector** methods can be enriched by supplying a delegate that enables extra integration features. For instance:

* The **AddHostedService<T>** method can be used inside the **AddSimpleInjector** method to hook Hosted Services to the Generic Host pipeline, as discussed below.
* The **UseLogging** method can be used inside the **UseSimpleInjector** method to allow application components to be injected with `Microsoft.Extensions.Logging.ILogger`. For more information, see :ref:`the Microsoft Logging integration section <microsoft-logging>`.
* The **UseLocalization** method can be used inside the **UseSimpleInjector** method to allow application components to be injected with `Microsoft.Extensions.Localization.IStringLocalizer`. For more information, see :ref:`the Microsoft Logging integration section <microsoft-localization>`.

.. _using-hosted-services:

Using Hosted Services
=====================

.. container:: Note

    **WARNING**: Due to breaking changes in ASP.NET Core 3, it is currently impossible to use the `AddHostedService` extension methods with the new `Microsoft.Extensions.Hosting.Host` class. If you want to resolve hosted services from Simple Injector while using ASP.NET Core 3, please revert to using `Microsoft.AspNetCore.WebHost` in your `Program` class until we have a fix.

A Hosted Service is a background task running in an ASP.NET Core service or Console application. A Hosted Service implements the `IHostedService` interface and can run at certain intervals. When added to the Generic Host or ASP.NET Core pipeline, a Hosted Service instance will be referenced indefinitely by the host. This means that your Hosted Service implementation is effectively a **Singleton** and, therefore, will be configured as such by Simple Injector when you call Simple Injector's **AddHostedService<THostedService>** method:

.. code-block:: c#

    services.AddSimpleInjector(container, options =>
    {
        options.AddHostedService<TimedHostedService>();
    });

In case your Hosted Service needs to run repeatedly at certain intervals, it becomes important to start the service's operation in a **Scope**. This allows instances with **Transient** and **Scoped** lifestyles to be resolved.
    
In case you require multiple Hosted Services that need to run at specific intervals, at can be beneficial to create a wrapper implementation that takes care of the most important plumbing. The `TimedHostedService<TService>` below defines such reusable wrapper:

.. code-block:: c#

    using System;
    using System.Threading;
    using System.Threading.Tasks;
    using Microsoft.Extensions.Hosting;
    using Microsoft.Extensions.Logging;
    using SimpleInjector;
    using SimpleInjector.Lifestyles;

    public class TimedHostedService<TService> : IHostedService, IDisposable
        where TService : class
    {
        private readonly Container container;
        private readonly Settings settings;
        private readonly ILogger logger;
        private readonly Timer timer;

        public TimedHostedService(Container container, Settings settings, ILogger logger)
        {
            this.container = container;
            this.settings = settings;
            this.logger = logger;
            this.timer = new Timer(callback: _ => this.DoWork());
        }

        public Task StartAsync(CancellationToken cancellationToken)
        {
            // Verify that TService can be resolved
            this.container.GetRegistration(typeof(TService), true);
            // Start the timer
            this.timer.Change(dueTime: TimeSpan.Zero, period: this.settings.Interval);
            return Task.CompletedTask;
        }

        private void DoWork()
        {
            try
            {
                using (AsyncScopedLifestyle.BeginScope(this.container))
                {
                    var service = this.container.GetInstance<TService>();
                    this.settings.Action(service);
                }
            }
            catch (Exception ex)
            {
                this.logger.LogError(ex, ex.Message);
            }
        }

        public Task StopAsync(CancellationToken cancellationToken)
        {
            this.timer.Change(Timeout.Infinite, 0);
            return Task.CompletedTask;
        }

        public void Dispose() => this.timer.Dispose();
        
        public class Settings
        {
            public readonly TimeSpan Interval;
            public readonly Action<TService> Action;
            
            public Settings(TimeSpan interval, Action<TService> action)
            {
                this.Interval = interval;
                this.Action = action;
            }
        }
    }

This reusable `TimedHostedService<TService>` allows a given service to be resolved and executed within a new **AsyncScopedLifestyle**, while ensuring that any errors are logged.

The following code snippet shows how this `TimedHostedService<TService>` can be configured for an `IProcessor` service:

.. code-block:: c#

    services.AddSimpleInjector(container, options =>
    {
        options.AddHostedService<TimedHostedService<IProcessor>>();
        container.RegisterInstance(new TimedHostedService<IProcessor>.Settings(
            interval: TimeSpan.FromSeconds(10),
            action: service => service.DoSomeWork()));        
        container.Register<IProcessor, ProcessorImpl>();
    });
        
The previous snippet uses Simple Injector's **AddHostedService<T>** method to register the `TimedHostedService<IProcessor>` in Simple Injector and adds it to the Generic Host pipeline. This class requires a `TimedHostedService<TService>.Settings` object in its constructor, which is configured using the second line. The settings specifies the interval and the action to execute—in this case the action on `IProcessor`.