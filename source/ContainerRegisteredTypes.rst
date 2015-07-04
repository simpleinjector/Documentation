===============================================
Diagnostic Warning - Container-registered Types
===============================================

Cause
=====

A concrete type that was not registered explicitly and was not resolved using unregistered type resolution, but was created by the container using the default lifestyle.

Warning Description
===================

The *Container-Registered Types* warning shows all concrete types that weren't registered explicitly, but registered by the container as transient for you, because they were referenced by another component's constructor or were resolved through a direct call to *container.GetIntance<T>()* (inside a `RegisterInitializer <https://simpleinjector.org/ReferenceLibrary/?topic=html/M_SimpleInjector_Container_RegisterInitializer__1.htm>`_ registered delegate for instance).

This warning deserves your attention, since it might indicate that you program to implementations, instead of abstractions. Although the :doc:`Potential Lifestyle Mismatches <PotentialLifestyleMismatches>` and :doc:`Short Circuited Dependencies <ShortCircuitedDependencies>` warnings are a very strong signal of a configuration problem, this *Container-Registered Types* warnings is just a point of attention. 

How to Fix Violations
=====================

Let components depend on an interface that described the contract that this concrete type implements and register that concrete type in the container by that interface.

When to Ignore Warnings
=======================

If your intention is to resolve those types as transient and don't depend directly on their concrete types, this warning can in general be ignored safely.

The warning can be suppressed on a per-registration basis as follows:
	
.. code-block:: c#

    var registration = container.GetRegistration(typeof(HomeController)).Registration;

    registration.SuppressDiagnosticWarning(DiagnosticType.ContainerRegisteredComponent);


Example
=======

.. code-block:: c#

	var container = new Container();

	container.Register<HomeController>();

	container.Verify();

	// Definition of HomeController
	public class HomeController : Controller {
	    private readonly SqlUserRepository repository;

	    public HomeController(SqlUserRepository repository) {
	        this.repository = repository;
	    }
	}

The given example registers a *HomeController* class that depends on an unregistered *SqlUserRepository* class. Injecting a concrete type can lead to problems, such as:

* It makes the *HomeController* hard to test, since concrete types are often hard to fake (or when using a mocking framework that fixes this, would still result in unit tests that contain a lot of configuration for the mocking framework, instead of pure test logic) making the unit tests hard to read and hard to maintain.
* It makes it harder to reuse the class, since it expects a certain implementation of its dependency.
* It makes it harder to add cross-cutting concerns (such as logging, audit trailing and authorization) to the system, because this must now either be added directly in the *SqlUserRepository* class (which will make this class hard to test and hard to maintain) or all constructors of classes that depend on *SqlUserRepository* must be changed to allow injecting a type that adds these cross-cutting concerns.

Instead of depending directly on *SqlUserRepository*, *HomeController* can better depend on an *IUserRepository* abstraction:

.. code-block:: c#

	var container = new Container();

	container.Register<IUserRepository, SqlUserRepository>();
	container.Register<HomeController>();

	container.Verify();

	// Definition of HomeController
	public class HomeController : Controller {
	    private readonly IUserRepository repository;

	    public HomeController(IUserRepository repository) {
	        this.repository = repository;
	    }
	}

.. container:: Note

    **Tip**: It would probably be better to define a generic *IRepository<T>* abstraction. This makes easy to :ref:`batch registration <Batch-Registration>` implementations and allows cross-cutting concerns to be added using :ref:`decorators <Decorators>`.