=================================================
Windows Presentation Foundation Integration Guide
=================================================

The first step is to properly configure the *App.xaml* markup:

.. code-block:: xaml

    <Application x:Class="SimpleInjectorWPF.App"
                 xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                 Startup="Application_Startup">
        <!-- Remove the StartupUri property, replace with Startup event handler -->
        <Application.Resources>
         
        </Application.Resources>
    </Application>

Then *App.xaml.cs* will need to be modified to allow for registration:

.. code-block:: c#

    using System.Windows;
    using SimpleInjector;

    public partial class App : Application {
        private static Container container;

        private void Application_Startup(object sender, StartupEventArgs e) {
            Bootstrap();
            
            var window = container.GetInstance<MainWindow>();
            
            // Initialize window here, or register an initializer in the 'Bootstrap' method.
            //
            
            window.Show();
        }

        private static void Bootstrap() {
            // Create the container as usual.
            var container = new Container();

            // Register your types, for instance:
            container.RegisterSingle<IUserRepository, SqlUserRepository>();
            container.Register<IUserContext, WpfUserContext>();

            // Optionally verify the container.
            container.Verify();
        }
    }
    
Constructor injection can be used as normal on the *MainWindow* and any other windows:

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
        private IUserRepository userRepository;
        private IUserContext userContext;

        public IEnumerable<IUser> Users {
            get { return userRepository.GetAll(); }
        }

        public MainWindowViewModel(IUserRepository userRepository, IUserContext userContext) {
            this.userRepository = userRepository;
            this.userContext = userContext;
        }
    }
