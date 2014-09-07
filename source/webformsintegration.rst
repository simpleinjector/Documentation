===================================
ASP.NET Web Forms Integration Guide
===================================

ASP.NET Web Forms was never designed with dependency injection in mind. Although using constructor injection in our **Page** classes, user controls and http handlers would be preferable, it is unfortunately not possible, because ASP.NET expects those types to have a default constructor.

.. container:: Note

    **Note**: `This blog post <https://cuttingedge.it/blogs/steven/pivot/entry.php?id=81>`_ shows how to do constructor injection in pages and user controls, but please keep in mind that this will fail when trying to run the application in partial trust. Besides, it still doesn't work for *IHttpHandlers*.

Instead of doing constructor injection, there are alternatives. The simplest thing to do is to fall back to property injection and initialize the page in the constructor.

.. code-block:: c#

    using System;
    using System.ComponentModel.Composition;
    using System.Linq;
    using System.Reflection;
    using System.Web;
    using System.Web.Compilation;
    using System.Web.UI;
    using SimpleInjector;
    using SimpleInjector.Advanced;

    public abstract class BasePage : Page {
        public BasePage() {
            Global.Initialize(this);
        }
    }

    public class Global : HttpApplication {
        private static Container container;

        public static void Initialize(Page page) {
            container.GetRegistration(page.GetType().BaseType, true).Registration
                .InitializeInstance(page);
        }

        protected void Application_Start(object sender, EventArgs e) {
            Bootstrap();
        }

        private static void Bootstrap() {
            // 1. Create a new Simple Injector container.
            var container = new Container();

            // Registere a custom PropertySelectionBehavior to enable property injection.
            container.Options.PropertySelectionBehavior = 
                new ImportAttributePropertySelectionBehavior();

            // 2. Configure the container (register)
            container.Register<IUserRepository, SqlUserRepository>();
            container.RegisterPerWebRequest<IUserContext, AspNetUserContext>();

            // 3. Store the container for use by Page classes.
            Global.container = container;

            // 4. Optionally verify the container's configuration.
            //    Did you know the container can diagnose your configuration? 
            //    For more information, go to: https://bit.ly/YE8OJj.
            container.Verify();
            VerifyPages(container);
        }

        // This method tests if each Page class can be created. Because Page classes 
        // manually call Global.Initialize in their ctor, we want to test on application 
        // startup if all pages can be initialized, to prevent having to go through 
        // each page in the application during testing.
        private static void VerifyPages(Container container) {
            var assemblies = BuildManager.GetReferencedAssemblies().Cast<Assembly>();

            var pageTypes =
                from assembly in assemblies
                from type in assembly.GetExportedTypes()
                where typeof(Page).IsAssignableFrom(type) && !type.IsAbstract
                select type;

            foreach (Type pageType in pageTypes) {
                container.GetInstance(pageType);
            }
        }

        private class ImportAttributePropertySelectionBehavior : IPropertySelectionBehavior {
            public bool SelectProperty(Type serviceType, PropertyInfo propertyInfo) {
                // Makes use of the System.ComponentModel.Composition assembly
                return typeof(Page).IsAssignableFrom(serviceType) &&
                    propertyInfo.GetCustomAttributes<ImportAttribute>().Any();
            }
        }
    }

With this code in place, we can now write our page classes as follows:

.. code-block:: c#

    public partial class Default : BasePage {
        [Import] public IUserRepository UserRepository { get; set; }
        [Import] public IUserContext UserContext { get; set; }

        protected void Page_Load(object sender, EventArgs e) {
            if (this.UserContext.IsAdministrator) {
                this.UserRepository.DoSomeStuff();
            }
        }
    }