=================================================
Windows Presentation Foundation Integration Guide
=================================================

To allow Simple Injector to build up *Window* classes with their dependencies, please follow the given steps below.

Step 1:
-------

Change the App.xaml markup by removing the *StartUri* property:

.. code-block:: xml

    <Application x:Class="SimpleInjectorWPF.App"
                 xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
        <!-- Remove the StartupUri property, start the application from a static Main -->
        <Application.Resources>
        </Application.Resources>
    </Application>
    
Step 2:
-------

Add a *Program.cs* file to your project as entry point of the application:

.. code-block:: c#

    using System;
    using System.Windows;
    using SimpleInjector;

    static class Program
    {
        [STAThread]
        static void Main() {
            var container = Bootstrap();

            // Possible other configuration, e.g. of your desired MVVM toolkit.

            RunApplication(container);
        }

        private static Container Bootstrap() {
            // Create the container as usual.
            var container = new Container();

            // Register your types, for instance:
            container.RegisterSingle<IQueryProcessor, QueryProcessor>();
            container.Register<IUserContext, WpfUserContext>();

            // Register your windows and view models:
            container.Register<MainWindow>();
            container.Register<MainWindowViewModel>();

            container.Verify();

            return container;
        }

        private static void RunApplication(Container container) {
            try {
                var app = new App();
                var mainWindow = container.GetInstance<MainWindow>();
                app.Run(mainWindow);
            } catch (Exception ex) {
                //Log the exception and exit
            }
        }
    }

Step 3:
-------

In the properties of your project, change the 'Startup object' to the newly added *Program* class, as shown in the following screen shot:

.. image:: images/wpfstartupobject.png
   :alt: 'Startup object' settings in the application's properties

Usage
-----

After performing the previous steps, constructor injection can be used on the *MainWindow* and any other windows and their view models. Example:

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
        private readonly IQueryProcessor queryProcessor;
        private readonly IUserContext userContext;

        public MainWindowViewModel(IQueryProcessor queryProcessor,
            IUserContext userContext) {
            this.queryProcessor = queryProcessor;
            this.userContext = userContext;
        }

        public IEnumerable<IUser> Users {
            get { return this.queryProcessor.Execute(new GetAllUsers()); }
        }
    }
