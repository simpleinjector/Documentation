=============================
Silverlight Integration Guide
=============================

Configuring Simple Injector to build up *Page* classes with their dependencies is simply a matter of adding a *Bootstrap()* method to the *App* class and resolving the *MainPage* during *Application_Startup*:

.. code-block:: c#

    using System;
    using System.Windows;
    using SimpleInjector;

    public partial class App : Application
    {
        public App() {
            this.Startup += this.Application_Startup;
            this.Exit += this.Application_Exit;
            this.UnhandledException += this.Application_UnhandledException;

            InitializeComponent();
        }

        private void Application_Startup(object sender, StartupEventArgs e) {
            var container = Bootstrap();

            this.RootVisual = container.GetInstance<MainPage>();
        }

        public static Container Bootstrap() {
            // Create the container as usual.
            var container = new Container();

            // Register your pages and view models:
            container.Register<MainPage>();
            container.Register<MainPageViewModel>();

            container.Verify();

            return container;
        }

        // Rest of the code
    }

Usage
-----

Constructor injection can now be used in any pages (e.g. *MainPage*) and view models:

.. code-block:: c#

    using System.Windows;

    public partial class MainPage : Page {
        public MainPage(MainPageViewModel viewModel) {
            InitializeComponent();

            // Assign to the data context so binding can be used.
            base.DataContext = viewModel;
        }
    }

    public class MainPageViewModel {
        private readonly IQueryProcessor queryProcessor;
        private readonly IUserContext userContext;

        public MainPageViewModel(IQueryProcessor queryProcessor,
            IUserContext userContext) {
            this.queryProcessor = queryProcessor;
            this.userContext = userContext;
        }

        public IEnumerable<IUser> Users {
            get { return this.queryProcessor.Execute(new GetAllUsers()); }
        }
    }
