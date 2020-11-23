===============================
Windows Forms Integration Guide
===============================

Windows Forms does not lay any constraints on the constructors of your Form classes, which allows you to resolve them with ease. You can, therefore, use constructor injection in your form classes and let the container resolve them.

The following code snippet is an example of how to register Simple Injector container in the *Program* class:

.. code-block:: c#

    using System;
    using System.Windows.Forms;
    using SimpleInjector;
    using SimpleInjector.Diagnostics;

    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.SetHighDpiMode(HighDpiMode.SystemAware);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            var container = Bootstrap();

            Application.Run(container.GetInstance<Form1>());
        }

        private static Container Bootstrap()
        {
            // Create the container as usual.
            var container = new Container();

            // Register your types, for instance:
            container.Register<IUserRepository, SqlUserRepository>(Lifestyle.Singleton);
            container.Register<IUserContext, WinFormsUserContext>();

            AutoRegisterWindowsForms(container);

            container.Verify();

            return container;
        }

        private static void AutoRegisterWindowsForms(Container container)
        {
            var types = container.GetTypesToRegister<Form>(typeof(Program).Assembly);

            foreach (var type in types)
            {
                var registration =
                    Lifestyle.Transient.CreateRegistration(type, container);

                registration.SuppressDiagnosticWarning(
                    DiagnosticType.DisposableTransientComponent,
                    "Forms should be disposed by app code; not by the container.");

                container.AddRegistration(type, registration);
            }
        }
    }


With this code in place, you can now write our *Form* classes as follows:

.. code-block:: c#

    public partial class Form1 : Form
    {
        private readonly IUserRepository userRepository;
        private readonly IUserContext userContext;

        public Form1(IUserRepository userRepository, IUserContext userContext)
        {
            this.userRepository = userRepository;
            this.userContext = userContext;

            InitializeComponent();
        }

        private void button1_Click(object sender, EventArgs e)
        {
            if (this.userContext.IsAdministrator)
            {
                this.userRepository.ControlSomeStuff();
            }
        }
    }

.. container:: Note

    **Tip**: This example only shows the creation of the main form. Other forms are typically created from within methods of the main forms. Those sub forms can be resolved from the `Container` directly or, more elegantly, by injecting an abstraction that allows creation of forms. Take a look, for instance, at Ric's Stack Overflow answers on this topic `here <https://stackoverflow.com/a/38421425/>`_ and `here <https://stackoverflow.com/a/64902218/>`_.

.. container:: Note

    **Note**: It is not possible to use *Constructor Injection* in *User Controls*. *User Controls* are required to have a default constructor. Instead, pass on dependencies to your *User Controls* using :ref:`Property Injection <property-injection>`.
