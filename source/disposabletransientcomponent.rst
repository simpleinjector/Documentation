====================================================
Diagnostic Warning - Disposable Transient Components
====================================================

Severity
========

Warning

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
- a framework (such as ASP.NET) guarantees disposal of the component
- not disposing is not an issue.

The warning can be suppressed on a per-registration basis as follows:
    
.. code-block:: c#

    Registration registration = container.GetRegistration(typeof(IService)).Registration;

    registration.SuppressDiagnosticWarning(DiagnosticType.DisposableTransientComponent,
        "Reason of suppression");


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

    var container = new Container();
    // Select the scoped lifestyle that is appropriate for the application
    // you are building. For instance:
    container.Options.DefaultScopedLifestyle = new AsyncScopedLifestyle();

    // DisposableService implements IDisposable
    container.Register<IService, DisposableService>(Lifestyle.Scoped);

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

Optionally you can let transient services dispose when a scope ends. Here's an example of an extension method that allows registering transient instances that are disposed when the specified scope ends:

.. code-block:: c#
    
    public static void RegisterDisposableTransient<TService, TImplementation>(
        this Container c)
        where TImplementation: class, IDisposable, TService 
        where TService : class
    {
        var scoped = Lifestyle.Scoped;
        var r = Lifestyle.Transient.CreateRegistration<TService, TImplementation>(c);
        r.SuppressDiagnosticWarning(DiagnosticType.DisposableTransientComponent, "ignore");
        c.AddRegistration(typeof(TService), r);
        c.RegisterInitializer<TImplementation>(o => scoped.RegisterForDisposal(c, o));
    }
    
The following code snippet show the usage of this extension method:
    
.. code-block:: c#
        
    var container = new Container();
    container.Options.DefaultScopedLifestyle = new AsyncScopedLifestyle();
    
    container.RegisterDisposableTransient<IService, ServiceImpl>();

This ensures that each time a *ServiceImpl* is created by the container, it is registered for disposal when the scope - a web request in this case - ends. This can of course lead to the creation and disposal of multiple *ServiceImpl* instances during a single request.

.. container:: Note

    **Note**: To be able to dispose an instance, the **RegisterForDisposal** will store the reference to that instance in the scope. This means that the instance will be kept alive for the lifetime of that scope.

.. container:: Note

    **Warning**: Be careful to not register any services for disposal that will outlive that scope (such as services registered as singleton), since a service cannot be used once it has been disposed. This would typically result in *ObjectDisposedExceptions* and this will cause your application to break.
    