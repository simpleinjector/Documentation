=========================================================================================================================
Compiler Warning: 'SimpleInjector.SimpleInjectorMvcExtensions. RegisterMvcAttributeFilterProvider(Container)' is obsolete
=========================================================================================================================

Starting with Simple Injector 2.6 the **RegisterMvcAttributeFilterProvider** extension method will be marked as *obsolete* with the **System.ObsoleteAttribute**. This page describes why we made this decision and identifies things you should consider to mitigate the impact of it's eventual removal from the API.

What's the problem?
===================

As of release Simple Injector 2.6 the **Container.InjectProperties** method is deprecated and the **RegisterMvcAttributeFilterProvider** extension method initializes attributes by passing instances to the **InjectProperties** method. The **InjectProperties** method is an unfortunate legacy method that performs *implicit property injection* and doesn't integrate nicely with both the :doc:`Simple Injector Pipeline <pipeline>` and the :doc:`Diagnostic Services <diagnostics>`. 

.. container:: Note

    **RegisterMvcAttributeFilterProvider** is deprecated because **InjectProperties** is deprecated. Please read :doc:`this wiki page <injectproperties-is-deprecated>` for further information.

So what do you need to do?
===========================

The new **RegisterMvcIntegratedFilterProvider** extension method is provided as the preferred mechanism for property injection into MVC filter attributes. The **RegisterMvcIntegratedFilterProvider** method integrates with both the :doc:`Simple Injector Pipeline <pipeline>` and the :doc:`Diagnostic Services <diagnostics>` and is therefore considered safe to use. Any attributes that are handled by this mechanism will pass through the *Pipeline* and will be correctly initialized according to the container's configuration.

Please note that by default Simple Injector is configured to **not** do property injection as we advise developers to always prefer constructor injection. Switching to **RegisterMvcIntegratedFilterProvider** will therefore **not** automatically prompt the container to inject properties. The container needs to be explicitly configured to do property injection. 

The :ref:`IPropertySelectionBehavior extension point <Overriding-Property-Injection-Behavior>` can be used to enable property injection in a way that fully integrates with both the *Pipeline* and *Diagnostic Services*. A common solution is to apply the `ImportAttribute <https://msdn.microsoft.com/en-us/library/vstudio/system.componentmodel.composition.importattribute>`_ to the properties of attributes that need injection and register an instance of the following class with Simple Injector:

.. code-block:: c#

    using System;
    using System.ComponentModel.Composition;
    using System.Linq;
    using System.Reflection;
    using SimpleInjector.Advanced;

    class ImportPropertySelectionBehavior : IPropertySelectionBehavior {
        public bool SelectProperty(Type type, PropertyInfo prop) {
            return prop.GetCustomAttributes(typeof(ImportAttribute)).Any();
        }
    }

The previous class can be registered as follows:

.. code-block:: c#

    var container = new Container();
    container.Options.PropertySelectionBehavior = new ImportPropertySelectionBehavior();

    container.RegisterMvcIntegratedFilterProvider();

Please read the :ref:`Advanced Scenarios - Propery Injection <Property-Injection>` documentation page for more information.

.. container:: Note

    **Note**: Instead of injecting dependencies into attributes (i.e. injecting behaviour into metadata), please consider adopting a different design, one where the attribute data and the behaviours are kept separate, as outlined in `this article <https://www.cuttingedge.it/blogs/steven/pivot/entry.php?id=98>`_.