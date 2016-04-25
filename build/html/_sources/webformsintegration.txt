===================================
ASP.NET Web Forms Integration Guide
===================================

ASP.NET Web Forms was never designed with dependency injection in mind. Although using constructor injection in our **Page** classes, user controls and HTTP handlers would be preferable, it is unfortunately not possible, because ASP.NET expects those types to have a default constructor.

Instead of doing constructor injection, there are alternatives. The simplest thing to do is to fall back to property injection and initialize the page in the constructor.

.. code-block:: c#

    using System;
    using System.ComponentModel.Composition;
    using System.Linq;
    using System.Reflection;
    using System.Web;
    using System.Web.Compilation;
    using System.Web.UI;
    using Microsoft.Web.Infrastructure.DynamicModuleHelper;
    using SimpleInjector;
    using SimpleInjector.Advanced;

    [assembly: PreApplicationStartMethod(
        typeof(MyWebApplication.PageInitializerModule),
        "Initialize")]

    namespace MyWebApplication
    {
        public sealed class PageInitializerModule : IHttpModule {
            public static void Initialize() {
                DynamicModuleUtility.RegisterModule(typeof(PageInitializerModule));
            }

            void IHttpModule.Init(HttpApplication context) {
                context.PreRequestHandlerExecute += (sender, e) => {
                    var handler = context.Context.CurrentHandler;
                    if (handler != null) {
                        string name = handler.GetType().Assembly.FullName;
                        if (!name.StartsWith("System.Web") &&
                            !name.StartsWith("Microsoft")) {
                            Global.InitializeHandler(handler);
                        }
                    }
                };
            }

            void IHttpModule.Dispose() { }
        }

        public class Global : HttpApplication {
            private static Container container;

            public static void InitializeHandler(IHttpHandler handler) {
                container.GetRegistration(handler.GetType(), true).Registration
                    .InitializeInstance(handler);
            }

            protected void Application_Start(object sender, EventArgs e) {
                Bootstrap();
            }

            private static void Bootstrap() {
                // 1. Create a new Simple Injector container.
                var container = new Container();

                // Register a custom PropertySelectionBehavior to enable property injection.
                container.Options.PropertySelectionBehavior =
                    new ImportAttributePropertySelectionBehavior();

                // 2. Configure the container (register)
                container.Register<IUserRepository, SqlUserRepository>();
                container.RegisterPerWebRequest<IUserContext, AspNetUserContext>();

                // Register your Page classes to allow them to be verified and diagnosed.
                RegisterWebPages(container);

                // 3. Store the container for use by Page classes.
                Global.container = container;

                // 3. Verify the container's configuration.
                container.Verify();
            }

            private static void RegisterWebPages(Container container) {
                var pageTypes =
                    from assembly in BuildManager.GetReferencedAssemblies().Cast<Assembly>()
                    where !assembly.IsDynamic
                    where !assembly.GlobalAssemblyCache
                    from type in assembly.GetExportedTypes()
                    where type.IsSubclassOf(typeof(Page))
                    where !type.IsAbstract && !type.IsGenericType
                    select type;

                foreach (Type type in pageTypes) {
                    var registration = Lifestyle.Transient.CreateRegistration(type, container);
                    registration.SuppressDiagnosticWarning(
                        DiagnosticType.DisposableTransientComponent,
                        "ASP.NET creates and disposes page classes for us.");
                    container.AddRegistration(type, registration);
                }                
            }

            class ImportAttributePropertySelectionBehavior : IPropertySelectionBehavior {
                public bool SelectProperty(Type serviceType, PropertyInfo propertyInfo) {
                    // Makes use of the System.ComponentModel.Composition assembly
                    return typeof(Page).IsAssignableFrom(serviceType) &&
                        propertyInfo.GetCustomAttributes<ImportAttribute>().Any();
                }
            }
        }
    }

With this code in place, we can now write our page classes as follows:

.. code-block:: c#

    public partial class Default : Page {
        [Import] public IUserRepository UserRepository { get; set; }
        [Import] public IUserContext UserContext { get; set; }

        protected void Page_Load(object sender, EventArgs e) {
            if (this.UserContext.IsAdministrator) {
                this.UserRepository.DoSomeStuff();
            }
        }
    }