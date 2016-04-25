=======================
T4MVC Integration Guide
=======================

`T4MVC <http://t4mvc.codeplex.com/>`_ is a T4 template for ASP.NET MVC apps that creates strongly typed helpers that eliminate the use of literal strings when referring the controllers, actions and views.

Besides generating strongly typed helpers, T4MVC also generates partial classes for all controllers in your project. This partial class sometimes adds a public constructor to the controller. Since Simple Injector by default only allows auto-wiring on types that contain just a single public constructor, the application will fail to start up.

To fix this you will either have to change the T4 template and remove the generation of the default constructor, or change the constructor resolution behavior of the container.

Change the constructor resolution behavior of the container can be done by implementing a custom **IConstructorResolutionBehavior** as follows:

.. code-block:: c#

    using System;
    using System.Diagnostics;
    using System.Linq;
    using System.Reflection;
    using System.Web.Mvc;

    using SimpleInjector.Advanced;

    public class T4MvcControllerConstructorResolutionBehavior
        : IConstructorResolutionBehavior {
        private IConstructorResolutionBehavior defaultBehavior;

        public T4MvcControllerConstructorResolutionBehavior(
            IConstructorResolutionBehavior defaultBehavior) {
            this.defaultBehavior = defaultBehavior;
        }

        [DebuggerStepThrough]
        public ConstructorInfo GetConstructor(Type serviceType, Type impType) {
            if (typeof(IController).IsAssignableFrom(impType)) {
                var nonDefaultConstructors =
                    from constructor in impType.GetConstructors()
                    where constructor.GetParameters().Length > 0
                    select constructor;

                if (nonDefaultConstructors.Count() == 1) {
                    return nonDefaultConstructors.Single();
                }
            }

            // fall back to the container's default behavior.
            return this.defaultBehavior.GetConstructor(serviceType, impType);
        }
    }

This class can be registered by decorating the original *Container.Options.ConstructorResolutionBehavior* as follows:

.. code-block:: c#

    var container = new Container();

    container.Options.ConstructorResolutionBehavior = 
        new T4MvcControllerConstructorResolutionBehavior(
            container.Options.ConstructorResolutionBehavior);