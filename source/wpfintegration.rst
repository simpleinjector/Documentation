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

    </Application>
    
Step 2:
-------

Change the *App.xaml.cs* file to be the entry point for the application:

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
            
            var viewModel = container.GetInstance<MainViewModel>();
            base.MainWindow = new MainWindow()
            {
                DataContext = viewModel
            };
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
    
            // Register your types, for instance:
            container.Register<IQueryProcessor, QueryProcessor>(Lifestyle.Singleton);
            container.Register<ILogger, FileSystemLogger>(Lifestyle.Singleton);
            container.Register<IUserContext, SqlUserContext>();
    
            /*
                views and viewmodels:
                Usually, views and viewmodels are concrete types, so you don't have to register them, 
                unless you want to set their Lifrstyle.
                For example:
            */
            container.Register<SomeInfoView>(Lifestyle.Singleton);
            container.Register<SomeInfoViewModel>(Lifestyle.Singleton);
    
            container.Verify();
    
            return container;
        }
    }

Usage
-----

Constructor injection can now be used in any window and view model (e.g. *MainViewModel*) :

.. code-block:: c#

    public class MainViewModel
    {
        private readonly ILogger logger;
        private readonly IQueryProcessor queryProcessor;
    
        public MainWindowViewModel(IQueryProcessor queryProcessor, ILogger logger)
        {
            this.queryProcessor = queryProcessor;
            this.logger = logger;
            logger.Log("XYZ");
        }
    
        public IEnumerable<User> Users
        {
            // Remark: You can read here about IQueryProcessor pattern
            // https://www.cuttingedge.it/blogs/steven/pivot/entry.php?id=92
            get { return this.queryProcessor.Execute(new GetAllUsers()); }
        }
    }
