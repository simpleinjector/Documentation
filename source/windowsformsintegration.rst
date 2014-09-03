===============================
Windows Forms Integration Guide
===============================

Windows Forms was never designed with dependency injection in mind. Although it is possible to use constructor injection on the **Form** classes that are manually created in the **Main** method, code for the **UserControl** instances that are used in our forms is generated and will therefore need a default constructor.

Instead of doing constructor injection, there are alternatives. The simplest thing is to store the container in the **Program** class and let the default constructors of your form classes request the dependencies it needs..

The following code snippet is an example of how to register *Simple Injector* container in the **Program** class:

.. code-block:: c#

    using System;
    using System.Windows.Forms;
    using SimpleInjector;

    static class Program
    {
        private static Container container;

        [System.Diagnostics.DebuggerStepThrough]
        public static TService GetInstance<TService>() where TService : class
        {
            return container.GetInstance<TService>();
        }

        [STAThread]
        static void Main()
        {
            Bootstrap();

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new Form1());
        }

        private static void Bootstrap()
        {
            // Create the container as usual.
            container = new Container();

            // Register your types, for instance:
            container.RegisterSingle<IUserRepository, SqlUserRepository>();
            container.Register<IUserContext, WinFormsUserContext>();

            // Register the Container class.
            Program.container = container;
        }
    }

With this code in place, we can now write our **Form** and **UserControl** classes as follows:

.. code-block:: c#

    public partial class Form1 : Form
    {
        private readonly IUserRepository userRepository;
        private readonly IUserContext userContext;

        public Form1()
        {
            this.userRepository = Program.GetInstance<IUserRepository>();
            this.userContext = Program.GetInstance<IUserContext>();

            InitializeComponent();
        }

        private void button1_Click(object sender, EventArgs e)
        {
            if (this.UserContext.IsAdministrator)
            {
                this.UserRepository.ControlSomeStuff();
            }
        }
    }