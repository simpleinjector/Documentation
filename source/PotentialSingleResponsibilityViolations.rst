===============================================================
Diagnostic Warning - Potential Single Responsibility Violations
===============================================================

Severity
========

Information

Cause
=====

The component depends on too many services.

Warning Description
===================

Psychological studies show that the human mind has difficulty dealing with more than seven things at once. This is related to the concept of `High Fan In - Low Fan Out <https://it.toolbox.com/blogs/enterprise-solutions/design-principles-fanin-vs-fanout-16088>`_. Lowering the number of dependencies (fan out) that a class has can therefore reduce complexity and increase maintainability of such class.

So in general, components should only depend on a few other components. When a component depends on many other components (usually caused by constructor over-injection), it might indicate that the component has too many responsibilities. In other words it might be a sign that the component violates the `Single Responsibility Principle <https://en.wikipedia.org/wiki/Single_responsibility_principle>`_ (SRP). Violations of the SRP will often lead to maintainability issues later on in the application lifecycle.

The general consensus is that a constructor with more than 4 or 5 dependencies is a code smell. To prevent too many false positives, the threshold for the Diagnostic Services is 7 dependencies, so you'll start to see warnings on types with 8 or more dependencies.

How to Fix Violations
=====================

The article `Dealing with constructor over-injection <https://deals.manningpublications.com/DependencyInjectioninNET.pdf>`_, Mark Seemann goes into detail how to about fixing the root cause of constructor over-injection. Two solutions in particular come to mind.

Note that moving dependencies out of the constructor and into properties might solve the constructor over-injection code smell, but does not solve a violation of the SRP, since the number of dependencies doesn't decrease.

Moving those properties to a base class also doesn't solve the SRP violation. Often derived types will still use the dependencies of the base class making them still violating the SRP and even if they don't, the base class itself will probably violate the SRP or have a high fan out.

Those base classes will often just be helpers to implement all kinds of cross-cutting concerns. Instead of using base classes, a better way to implementing cross-cutting concerns is through :ref:`decorators <Decoration>`.

When to Ignore Warnings
=======================

This warning can safely be ignored when the type in question does not violate the SRP and the number of dependencies is stable (does not change often).

The warning can be suppressed on a per-registration basis as follows:
    
.. code-block:: c#

    Registration registration = container.GetRegistration(typeof(IFoo)).Registration;

    registration.SuppressDiagnosticWarning(DiagnosticType.SingleResponsibilityViolation);

    
Example
=======

.. code-block:: c#

    public class Foo : IFoo
    {
        public Foo(
            IUnitOfWorkFactory uowFactory,
            CurrencyProvider currencyProvider,
            IFooPolicy fooPolicy,
            IBarService barService,
            ICoffeeMaker coffeeMaker,
            IKitchenSink kitchenSink,
            IIceCubeProducer iceCubeProducer,
            IWaterCooker waterCooker)
        {
        }
    }

The **Foo** class has 8 dependencies and when it is registered in the container, it will result in the warning. Here is an example of this warning in the watch window:

.. image:: images/srp.png 
   :alt: Debugger watch window showing the SRP violation

The following example shows how to query the Diagnostic API for possible Single Responsibility Violations:

.. code-block:: c#

    // using SimpleInjector.Diagnostics;

    var container = /* get verified container */;

    var results = Analyzer.Analyze(container)
        .OfType<SingleResponsibilityViolationDiagnosticResult>();
        
    foreach (var result in results)
    {
        Console.WriteLine(result.ImplementationType.Name + 
            " has " + result.Dependencies.Count + " dependencies.");
    }
