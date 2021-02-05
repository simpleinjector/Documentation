===================================
.NET Generic Host Integration Guide
===================================

Simple Injector offers the `Simple Injector Generic Host Integration NuGet package <https://www.nuget.org/packages/SimpleInjector.Integration.GenericHost>`_ for integration with .NET Core 2.1 Generic Host applications.

.. container:: Note

    **TIP**: Even though this integration packages take a dependency on the Simple Injector core library, prefer installing the `the core library <https://nuget.org/packages/SimpleInjector>`_ explicitly into your startup project. The core library uses an independent versioning and release cycle. Installing the core library explicitly, therefore, gives you the newest, latest release (instead of the lowest compatible release), and allows the NuGet package manager to inform you about new minor and patch releases in the future.

The following code snippet shows how to use the integration package to apply Simple Injector to your Console application's `Main` method:

.. code-block:: c#

    public static async Task Main()
    {
        var container = new Container();

        IHost host = new HostBuilder()
            .ConfigureHostConfiguration(configHost => { ... })
            .ConfigureAppConfiguration((hostContext, configApp) => { ... })
            .ConfigureServices((hostContext, services) =>
            {
                services.AddLogging();
                services.AddLocalization(options => options.ResourcesPath = "Resources");

                services.AddSimpleInjector(container, options =>
                {
                    // Hooks hosted services into the Generic Host pipeline
                    // while resolving them through Simple Injector
                    options.AddHostedService<MyHostedService>();
                    
                    // Allows injection of ILogger & IStringLocalizer dependencies into
                    // application components.
                    options.AddLogging();
                    options.AddLocalization();
                });
            })
            .ConfigureLogging((hostContext, configLogging) => { ... })
            .UseConsoleLifetime()
            .Build()
            .UseSimpleInjector(container);
            
        // Register application components.
        container.Register<MainService>();

        container.Verify();

        await host.RunAsync();
    }

The integration consists of two methods, namely **AddSimpleInjector** and **UseSimpleInjector**, that need to be called at certain stages in the startup phase:

* **AddSimpleInjector** is an extension on `IServiceCollection` and allows the cross wiring of several framework services, such as hosted services, logging, and localization. This cross-wiring process is described in more details :ref:`here <cross-wiring-third-party-services>`.
* **UseSimpleInjector** is an extension on `IHost` and finalizes the integration process. It is a mandatory last step that tells Simple Injector which `IServiceProvider` it can use to load cross-wired framework services from. This allows Simple Injector to resolve framework components from the underlying `IServiceProvider`.

The **AddSimpleInjector** method can be enriched by supplying a delegate that enables extra integration features. For instance:

* The **AddHostedService<T>** method allows hooking Hosted Services to the Generic Host pipeline, as discussed below.
* The **AddLogging** method allows application components to be injected with `Microsoft.Extensions.Logging.ILogger`. For more information, see :ref:`the Microsoft Logging integration section <microsoft-logging>`.
* The **AddLocalization** method allows application components to be injected with `Microsoft.Extensions.Localization.IStringLocalizer`. For more information, see :ref:`the Microsoft Logging integration section <microsoft-localization>`.

.. _using-hosted-services:

Using Hosted Services
=====================

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
        // Registers the hosted service as singleton in Simple Injector
        // and hooks it onto the .NET Core Generic Host pipeline.
        options.AddHostedService<TimedHostedService<IProcessor>>();
    });
    
    // Registers the hosted service's settings object to define a specific schedule.
    container.RegisterInstance(new TimedHostedService<IProcessor>.Settings(
        interval: TimeSpan.FromSeconds(10),
        action: processor => processor.DoSomeWork()));        
        
    container.Register<IProcessor, ProcessorImpl>();
    
        
The previous snippet uses Simple Injector's **AddHostedService<T>** method to register the `TimedHostedService<IProcessor>` in Simple Injector and adds it to the Generic Host pipeline. This class requires a `TimedHostedService<TService>.Settings` object in its constructor, which is configured using the second registration. The settings specifies the interval and the action to execute—in this case the action on `IProcessor`.
