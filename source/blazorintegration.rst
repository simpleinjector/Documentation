=============================
Blazor Server App Integration
=============================

.. container:: Note

    **WARNING**: This integration guide is an evolving document. It gets updated any time we find better ways to integrate Simple Injector with Blazor, and any time Microsoft makes improvement that simplify integration. Integrating with Blazor is currently quite verbose, but this will improve over time. If you run into any limitations, other than the ones already mentioned below, help us in improving this guidance by reporting this on `our forum <https://simpleinjector.org/forum>`_.

This integration guide has the following prerequisites:

* .NET >= 5.0
* `Simple Injector <nuget.org/packages/Simpleinjector>`_ core library >= v5.3
* `Simple Injector Service Collection Integration <https://www.nuget.org/packages/SimpleInjector.Integration.ServiceCollection/>`_ >= v5.3

.. container:: Note

    **TIP**: Even though the Service Collection integration package take a dependency on the Simple Injector core library, prefer installing the `the core library <https://nuget.org/packages/SimpleInjector>`_ explicitly into your startup project. The core library uses an independent versioning and release cycle. Installing the core library explicitly, therefore, gives you the newest, latest release (instead of the lowest compatible release), and allows the NuGet package manager to inform you about new minor and patch releases in the future.

Please be aware that due to current state of Microsoft Blazor, integration with Simple Injector contains the following limitations:

* **@inject:** The `@inject` Razor directive will not work on Simple Injector registrations. You should instead place dependencies as properties inside a component's `@code` block and mark them with custom attribute, for instance using a `[Dependency]` attribute, as demonstrated below.
* **Base class:** Razor components must inherit from a custom base class to allow page `@on{EVENT}` (e.g. `@onclick`) to run inside a Simple Injector scope. The example razor page below demonstrates this.

.. container:: Note

    **WARNING**: Please be aware that when it comes to scoping, Microsoft decided to implement a very different model compared to the rest of the web stack. This scoping model is more similar to desktop applications; a single scope lives for the duration of a single user's component, which can be up to hours. Such single scope can be executed in parallel by multiple incoming events. This means that any `Transient` and `Scoped` services **must be thread-safe**. For that reason, services that aren't thread-safe (such as `DbContext`) should not be dependencies of Razor Components. For more information on this topic, please read `the official Microsoft Documentation <https://docs.microsoft.com/en-us/aspnet/core/blazor/blazor-server-ef-core#database-access-5x>`_. Note that this Simple Injector integration guide currently follows this behavior, which means that this warning also holds for Simple Injector-injected components.
    
Using the integration code shown further down on this page, your razor components will look similar to the following example:
    
.. code-block:: razor

    @inherits MyBlazorApplication.BaseComponent
    @page "/fetchdata"

    <h1>Weather forecast</h1>

    <button @onclick="Navigate">Navigate home</button>

    @code {
        [Dependency] WeatherForecastService ForecastService { get; set; }
        [Dependency] NavigationManager NavigationManager { get; set; }

        protected override async Task OnInitializedAsync()
        {
            forecasts = await ForecastService.GetForecastAsync(DateTime.Now);
        }

        void Navigate()
        {
            this.NavigationManager1.NavigateTo("", true);
        }
    }

So note the following deviations from the examples from the Microsoft documentation:

* This razor component derives from a `BaseComponent` base class. This is required to have functioning Razor event handlers.
* `@inject` directives are not used.
* Dependencies are implemented as properties by marking them with the `[Dependency]` attribute.

To integrate Simple Injector with Blazor, please follow the following steps:

* Add a new Blazor project to your Visual Studio solution using the "Blazor Server App" template for .NET 5.0 (or newer).
* Add the SimpleInjector and SimpleInjector.Integration.ServiceCollection packages to the project as noted on the top of this page.
* Replace the template's added `Startup` class with the following code:

.. code-block:: c#

    using System;
    using System.Linq;
    using System.Reflection;
    using System.Threading.Tasks;
    using Microsoft.AspNetCore.Builder;
    using Microsoft.AspNetCore.Components;
    using Microsoft.AspNetCore.Hosting;
    using Microsoft.AspNetCore.SignalR;
    using Microsoft.Extensions.Configuration;
    using Microsoft.Extensions.DependencyInjection;
    using Microsoft.Extensions.Hosting;
    using SimpleInjector;
    using SimpleInjector.Advanced;
    using SimpleInjector.Diagnostics;
    using SimpleInjector.Integration.ServiceCollection;
    using SimpleInjector.Lifestyles;

    [AttributeUsage(AttributeTargets.Property, Inherited = true, AllowMultiple = false)]
    public sealed class DependencyAttribute : Attribute { }

    public class Startup
    {
        private Container container = new SimpleInjector.Container();

        class DependencyAttributePropertySelectionBehavior : IPropertySelectionBehavior
        {
            public bool SelectProperty(Type type, PropertyInfo prop) =>
                prop.GetCustomAttributes(typeof(DependencyAttribute)).Any();
        }

        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;

            container.Options.PropertySelectionBehavior =
                new DependencyAttributePropertySelectionBehavior();
        }

        public IConfiguration Configuration { get; }

        public void ConfigureServices(IServiceCollection services)
        {
            services.AddRazorPages();
            services.AddServerSideBlazor();

            services.AddSimpleInjector(container, options =>
            {
                options.AddServerSideBlazor(options, this.GetType().Assembly);
            });

            InitializeContainer();
        }

        private void InitializeContainer()
        {
            // Make your Simple Injector registrations here.
            container.RegisterSingleton<WeatherForecastService>();
        }

        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            app.ApplicationServices.UseSimpleInjector(container);

            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }
            else
            {
                app.UseExceptionHandler("/Error");
            }

            app.UseStaticFiles();

            app.UseRouting();

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapBlazorHub();
                endpoints.MapFallbackToPage("/_Host");
            });

            container.Verify();
        }
    }

    public sealed class ScopeAccessor : IAsyncDisposable, IDisposable
    {
        public Scope Scope { get; set; }
        public ValueTask DisposeAsync() => this.Scope?.DisposeAsync() ?? default;
        public void Dispose() => this.Scope?.Dispose();
    }

    public static class BlazorExtensions
    {
        public static void AddServerSideBlazor(
            this SimpleInjectorAddOptions options, params Assembly[] assemblies)
        {
            var services = options.Services;

            // Unfortunate nasty hack. We reported this with Microsoft.
            services.AddTransient(
                typeof(Microsoft.AspNetCore.Components.Server.CircuitOptions)
                    .Assembly.GetTypes().First(
                    t => t.FullName ==
                        "Microsoft.AspNetCore.Components.Server.ComponentHub"));

            services.AddScoped(
                typeof(IHubActivator<>), typeof(SimpleInjectorBlazorHubActivator<>));
            services.AddScoped<IComponentActivator, SimpleInjectorComponentActivator>();

            RegisterBlazorComponents(options, assemblies);

            services.AddScoped<ScopeAccessor>();
            services.AddTransient<ServiceScopeApplier>();
        }

        private static void RegisterBlazorComponents(
            SimpleInjectorAddOptions options, Assembly[] assemblies)
        {
            var container = options.Container;
            var types = container.GetTypesToRegister<IComponent>(
                assemblies,
                new TypesToRegisterOptions { IncludeGenericTypeDefinitions = true });

            foreach (Type type in types.Where(t => !t.IsGenericTypeDefinition))
            {
                var registration =
                    Lifestyle.Transient.CreateRegistration(type, container);

                registration.SuppressDiagnosticWarning(
                    DiagnosticType.DisposableTransientComponent,
                    "Blazor will dispose components.");

                container.AddRegistration(type, registration);
            }

            foreach (Type type in types.Where(t => t.IsGenericTypeDefinition))
            {
                container.Register(type, type, Lifestyle.Transient);
            }
        }
    }

    public sealed class SimpleInjectorComponentActivator : IComponentActivator
    {
        private readonly ServiceScopeApplier applier;
        private readonly Container container;

        public SimpleInjectorComponentActivator(
            ServiceScopeApplier applier, Container container)
        {
            this.applier = applier;
            this.container = container;
        }

        public IComponent CreateInstance(Type type)
        {
            this.applier.ApplyServiceScope();

            IServiceProvider provider = this.container;
            var component = provider.GetService(type) ?? Activator.CreateInstance(type);
            return (IComponent)component;
        }
    }

    public sealed class SimpleInjectorBlazorHubActivator<T>
        : IHubActivator<T> where T : Hub
    {
        private readonly ServiceScopeApplier applier;
        private readonly Container container;

        public SimpleInjectorBlazorHubActivator(
            ServiceScopeApplier applier, Container container)
        {
            this.applier = applier;
            this.container = container;
        }

        public T Create()
        {
            this.applier.ApplyServiceScope();
            return this.container.GetInstance<T>();
        }

        public void Release(T hub) { }
    }

    public sealed class ServiceScopeApplier
    {
        private static AsyncScopedLifestyle lifestyle = new AsyncScopedLifestyle();

        private readonly IServiceScope serviceScope;
        private readonly ScopeAccessor accessor;
        private readonly Container container;

        public ServiceScopeApplier(
            IServiceProvider requestServices, ScopeAccessor accessor, Container container)
        {
            this.serviceScope = (IServiceScope)requestServices;
            this.accessor = accessor;
            this.container = container;
        }

        public void ApplyServiceScope()
        {
            if (this.accessor.Scope is null)
            {
                var scope = AsyncScopedLifestyle.BeginScope(this.container);

                this.accessor.Scope = scope;

                scope.GetInstance<ServiceScopeProvider>().ServiceScope = this.serviceScope;
            }
            else
            {
                lifestyle.SetCurrentScope(this.accessor.Scope);
            }
        }
    }

    public abstract class BaseComponent : ComponentBase, IHandleEvent
    {
        [Dependency] public ServiceScopeApplier Applier { get; set; }

        Task IHandleEvent.HandleEventAsync(EventCallbackWorkItem callback, object arg)
        {
            this.Applier.ApplyServiceScope();

            var task = callback.InvokeAsync(arg);
            var shouldAwaitTask = task.Status != TaskStatus.RanToCompletion &&
                task.Status != TaskStatus.Canceled;

            StateHasChanged();

            return shouldAwaitTask ?
                CallStateHasChangedOnAsyncCompletion(task) :
                Task.CompletedTask;
        }

        private async Task CallStateHasChangedOnAsyncCompletion(Task task)
        {
            try
            {
                await task;
            }
            catch
            {
                if (task.IsCanceled) return;
                
                throw;
            }

            base.StateHasChanged();
        }
    }

Yes, we know, this is a lot of code. Don't worry, you're living on the bleeding edge today. Everything will be better tomorrow.