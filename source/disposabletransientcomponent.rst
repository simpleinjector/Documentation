====================================================
Diagnostic Warning - Disposable Transient Components
====================================================

Cause
=====

A registration has been made with the Transient lifestyle for a component that implements IDisposable.

Warning Description
===================

A component that implements *IDisposable* would usually need deterministic clean-up but Simple Injector does not implicitly track and dispose components registered with the transient lifestyle.

How to Fix Violations
=====================

Register the component with the :ref:`scoped lifestyle <Scoped>` that is appropriate for the application you are working on. Scoped lifestyles ensure *Dispose* is called when an active scope ends.

When to Ignore Warnings
=======================

This warning can safely be ignored when:

- *Dispose* is called by the application code
- some manual registration ensures disposal
- not disposing is not a problem.

Example
=======

The following example shows a configuration that will trigger the warning:

.. code-block:: c#

    var container = new Container();

    // DisposableService implements IDisposable
    container.Register<IService, DisposableService>(Lifestyle.Transient);

    container.Verify();

.. image:: images/disposabletransientcomponent.png 
   :alt: Diagnostics debugger view watch window with the disposable transient component warning.

The issue can be fixed as follows:

.. code-block:: c#

    // Select the scoped lifestyle that is appropriate for the application
    // you are building. For instance:
    ScopedLifestyle scopedLifestyle = new WebRequestLifestyle();
    var container = new Container();

    // DisposableService implements IDisposable
    container.Register<IService, DisposableService>(scopedLifestyle);

    container.Verify();
   
The following example shows how to query the Diagnostic API for Disposable Transient Components:

.. code-block:: c#

    // using SimpleInjector.Diagnostics;

    var container = /* get verified container */;

    var results = Analyzer.Analyze(container)
        .OfType<DisposableTransientComponentDiagnosticResult>();
        
    foreach (var result in results) {
        Console.WriteLine(result.Description);
    }
