=================================================
Windows Presentation Foundation Integration Guide
=================================================

Simple Injector can build up *Window* classes with their dependencies. Use the following steps as a how-to guide:

Step 1:
-------

Change the App.xaml markup by removing the *StartUri* property:

.. code-block:: xml

    <Application x:Class="SimpleInjectorWPF.App"
                 xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
        <!-- Remove the StartupUri property, start the application from OnStartup method -->
        <Application.Resources>
        </Application.Resources>
    </Application>
    
Step 2:
-------

Cahange the *App.xaml.cs* file to be the entry point for the application:

.. code-block:: c#

    using SimpleInjector;

    /// <summary>
    /// Interaction logic for App.xaml
    /// </summary>
    public partial class App : Application
    {
        private readonly Container container = CreateContainer();

        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            
            base.MainWindow = container.GetInstance<MainWindow>();
            base.MainWindow.Show();
        }

        protected override void OnExit(ExitEventArgs e)
        {
            base.OnExit(e);
            container.Dispose();
        }

        private static Container CreateContainer()
        {
            // Create the container as usual.
            var container = new Container();

            // Register services
            container.Register<ILogger, Logger>(Lifestyle.Singleton);
            container.Register<IUserRepository, UserRepository>();

            // Register windows and view models:
            container.Register<MainWindow>();
            container.Register<MainWindowViewModel>();

            container.Verify();

            return container;
        }
    }

Usage
-----

Constructor injection can now be used in any window (e.g. *MainWindow*) and view model:

.. code-block:: c#

    using System.Windows;

    public partial class MainWindow : Window 
    {
        public MainWindow(MainWindowViewModel viewModel) 
        {
            InitializeComponent();

            // Assign to the data context so binding can be used.
            base.DataContext = viewModel;
        }
    }

    public class MainWindowViewModel
    {
        private readonly IUserRepository userContext;
        
        public MainWindowViewModel(IUserRepository userContext)
        {
            this.userContext = userContext;
        }

        public IEnumerable<User> Users
        {
            get { return this.userContext.GetUsers(); }
        }
    }
