===================================
Diagnostic Warning - Torn Lifestyle
===================================

Severity
========

Warning

Cause
=====

Multiple registrations with the same lifestyle map to the same component.

Warning Description
===================

When multiple **Registration** instances with the same lifestyle map to the same component, the component is said to have a torn lifestyle. The component is considered torn because each **Registration** instance will have its own cache of the given component, which can potentially result in multiple instances of the component within a single :ref:`scope <Scoped>`. When the registrations are torn the application may be wired incorrectly which could lead to unexpected behavior.

.. container:: Note

    **Note**: With the introduction of Simple Injector 4, the container will prevent the creation of multiple **Registration** instances for the same concrete type in most cases. This warning type should therefore be extremely rare. Torn lifestyles will only happen when a custom lifestyle circumvents the caching behavior of the **Lifestyle.CreateRegistration** overloads.

How to Fix Violations
=====================

Make sure the creation of **Registration** instances of your custom lifestyle goes through the **Lifestyle.CreateRegistration** method instead directly to **Lifestyle.CreateRegistrationCore**.

When to Ignore Warnings
=======================

This warning most likely signals a bug in a custom **Lifestyle** implementation, so warnings should typically not be ignored.

The warning can be suppressed on a per-registration basis as follows:
    
.. code-block:: c#

    var fooRegistration = container.GetRegistration(typeof(IFoo)).Registration;
    var barRegistration = container.GetRegistration(typeof(IBar)).Registration;
    fooRegistration.SuppressDiagnosticWarning(DiagnosticType.TornLifestyle);
    barRegistration.SuppressDiagnosticWarning(DiagnosticType.TornLifestyle);
