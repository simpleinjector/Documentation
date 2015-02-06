===============================
Windows Forms Integration Guide
===============================

Doing dependency injection in Windows Forms is easy, since Windows Forms does not lay any constraints on the constructors of your Form classes. You can therefore simply use constructor injection in your form classes and let the container resolve them.

The following code snippet is an example of how to register Simple Injector container in the *Program* class:

.. code-block:: c#

    using System;
    using System.Windows.Forms;
    using SimpleInjector;

    static class Program {
        private static Container container;

        [STAThread]
        static void Main() {
        
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Bootstrap();
            Application.Run(container.GetInstance<Form1>());
        }

        private static void Bootstrap() {
            // Create the container as usual.
            container = new Container();

            // Register your types, for instance:
            container.RegisterSingle<IUserRepository, SqlUserRepository>();
            container.Register<IUserContext, WinFormsUserContext>();
	    container.Register<Form1>();	

            // Optionally verify the container.
            container.Verify();
        }
    }

With this code in place, we can now write our *Form* and *UserControl* classes as follows:

.. code-block:: c#

    public partial class Form1 : Form {
        private readonly IUserRepository userRepository;
        private readonly IUserContext userContext;

        public Form1(IUserRepository userRepository, IUserContext userContext) {
            this.userRepository = userRepository;
            this.userContext = userContext;

            InitializeComponent();
        }

        private void button1_Click(object sender, EventArgs e) {
            if (this.userContext.IsAdministrator) {
                this.userRepository.ControlSomeStuff();
            }
        }
    }
