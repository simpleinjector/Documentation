.. _unusedconditionalregistrations:

=====================================================
Diagnostic Warning - Unused conditional registrations
=====================================================

Severity
========

Information

Cause
=====

A conditional registration was made but there is no component that is injected with this registration.

Warning Description
===================

When applications grow, so do their composition root. It's easy to loose track of registrations that are never used. This could be because the registration is simply never needed but was forgotten to be removed.

With conditional registrations it's easy to misconfig them so that they are by accident never used. This warning helps detect these issues.

How to Fix Violations
=====================

Remove the registration or fix the condition such that the conditional registration is selected.


When to Ignore Warnings
=======================

There are many reasons to ignore this warning. In case the registration is solely resolved directly from the container, the analyzer will think the registration is unused. Another common reason for a registration to be unused, is when its consumers are skipped being registered due to a certain configuration setting. Although skipping the conditional would generally be desirable, this is not always easy.

Example
=======

The following example shows a configuration that will trigger the warning:

.. code-block:: c#

    var container = new Container();

	// ServiceImpl depends on IServiceDependency
    container.Register<IService, ServiceImpl>();
    container.RegisterConditional<IServiceDependency, Dependency1>(c => true);
	container.RegisterConditional<IServiceDependency, Dependency2>(c => false);

    container.Verify();

	var results = SimpleInjector.Diagnostics.Analyzer.Analyze(container);

Both the *Dependency1* and *Dependency2* components are registered conditionally. However, *Dependency2* is never selected as its predicate always returns false. Because the severity this diagnostic warning is 'Information', the call to *Verify()* succeeds. This warning type can be seen by hovering over the container after the call to *Verify()* in the debugger, or by calling *Analyzer.Analyze* as the example shows.
