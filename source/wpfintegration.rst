=================================================
Windows Presentation Foundation Integration Guide
=================================================

WPF was not designed with dependency injection in mind. Instead of doing constructor injection, there are alternatives. The simplest thing to register the container in the *App* class, store the container in a static field and let *Window* instances request their dependencies from within their default constructor.

Here is an example of how your *App* code behind could look like:

.. code-block:: c#

    using System.Windows;
    using SimpleInjector;

    public partial class App : Application
    {
        private static Container container;

        [System.Diagnostics.DebuggerStepThrough]
        public static TService GetInstance<TService>() where TService : class {
            return container.GetInstance<TService>();
        }

        protected override void OnStartup(StartupEventArgs e) {
            base.OnStartup(e);
            Bootstrap();
        }

        private static void Bootstrap()  {
            // Create the container as usual.
            var container = new Container();

            // Register your types, for instance:
            container.RegisterSingle<IUserRepository, SqlUserRepository>();
            container.Register<IUserContext, WpfUserContext>();

            // Optionally verify the container.
            container.Verify();

            // Store the container for use by the application.
            App.container = container;
        }
    }

With the static *App.GetInstance<T>* method, we can request instances from our *Window* constructors:

.. code-block:: c#

    using System.Windows;

    public partial class MainWindow : Window {
        private readonly IUserRepository userRepository;
        private readonly IUserContext userContext;

        public MainWindow() {
            this.userRepository = App.GetInstance<IUserRepository>();
            this.userContext = App.GetInstance<IUserContext>();

            InitializeComponent();
        }
    }