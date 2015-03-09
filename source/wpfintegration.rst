=================================================
Windows Presentation Foundation Integration Guide
=================================================

WPF accepts constructor parameters by default. Therefore dependency injection can be done
quite simple. By making some tiny adjustments to the Visual Studio default template
Simple Injector is up and running in no time.

The first step is to properly configure the *App.xaml* markup:

.. code-block:: xaml

    <Application x:Class="SimpleInjectorWPF.App"
                 xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
        <!-- Remove the StartupUri property, start the application from a static void Main -->
        <Application.Resources>
         
        </Application.Resources>
    </Application>

Then add a *Program.cs* file to your project as entry point for the application:

.. code-block:: c#

    using System;
    using System.Windows;
    using SimpleInjector;

    static class Program
    {
        [STAThread]
        static void Main()
        {
            // Create a simple injector container and do needed registrations
            // before we start the application
            // Starting the application before calling `Verify()` on the container
            // will result in directly stopping the application due to default
            // behaviour of the System.Windows.Application class
            var container = Bootstrap();

            // possible other configuration, e.g. of your desired MVVM toolkit

            RunApplication(container);
        }

        private static Container Bootstrap()
        {
            // Create the container as usual.
            var container = new Container();

            // Register your types, for instance:
            container.RegisterSingle<IUserRepository, SqlUserRepository>();
            container.Register<IUserContext, WpfUserContext>();

            // Register your windows and viewmodels:
            container.Register<MainWindow>();
            container.Register<MainWindowViewModel>();

            // Optionally verify the container.
            container.Verify();

            return container;
        }

        private static void RunApplication(Container container)
        {
            try
            {
                var app = new App();
                app.Run(container.GetInstance<MainWindow>());
            }
            catch (Exception ex)
            {
                //Log the exception and exit
            }
        }
    }
    
In the properties of your project, change the 'Startup object' to the newly added *Program* class.

Constructor injection can be used as normal on the *MainWindow* and any other windows or viewmodels:

.. code-block:: c#

    using System.Windows;

    public partial class MainWindow : Window {
        public MainWindow(MainWindowViewModel viewModel) {
            InitializeComponent();

            // Assign to the data context so binding can be used.
            base.DataContext = viewModel;
        }
    }

    public class MainWindowViewModel {
        private readonly IUserRepository userRepository;
        private readonly IUserContext userContext;

        public MainWindowViewModel(IUserRepository userRepository, IUserContext userContext) {
            this.userRepository = userRepository;
            this.userContext = userContext;
        }
        
        public IEnumerable<IUser> Users {
            get { return userRepository.GetAll(); }
        }
    }
