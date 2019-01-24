.. _principles:

=================
Design Principles
=================

While designing Simple Injector we defined a set of rules that formed the foundation for development. These rules still keep us focused today and continue to help us decide how to implement a feature and which features **not** to implement. In the section below you'll find details of the design principles of Simple Injector.

The design principles:

* :ref:`Make simple use cases easy, make complex use cases possible <Make-simple-use-cases-easy>`
* :ref:`Push developers into best practices <Push-developers-into-best-practices>`
* :ref:`Fast by default <Fast-by-default>`
* :ref:`Don't force vendor lock-in <Vendor-lock-in>`
* :ref:`Never fail silently <Never-fail-silently>`
* :ref:`Features should be intuitive <Features-should-be-intuitive>`
* :ref:`Communicate errors clearly and describe how to solve them <Communicate-errors-clearly>`

.. _Make-simple-use-cases-easy:

Make simple use cases easy, make complex use cases possible
===========================================================

This guideline comes directly from the `Framework Design Guidelines <https://www.amazon.com/Framework-Design-Guidelines-Conventions-Libraries/dp/0321545613>`_ and is an important guidance for us. Commonly used features should be easy to implement, even for a new user, but the library must be flexible and extensible enough to support complex scenarios.

.. _Push-developers-into-best-practices:

Push developers into best practices
===================================

We believe in good design and best practices. When it comes to Dependency Injection, we believe that we know quite a bit about applying design patterns correctly and also how to prevent applying patterns incorrectly. We have designed Simple Injector in a way that promotes these best practices. Occasional we may explicitly choose to **not** implement certain features because they don't steer the developer in the right direction. Our intention has always been to build a library that makes it difficult to shoot yourself in the foot!

.. _Fast-by-default:

Fast by default
===============

For most applications the performance of the DI library is not an issue; I/O is usually the bottleneck. You will find, however, that certain DI libraries are very sensitive to different configurations and you will need to monitor the container for potential performance problems. Most performance problems can be fixed by changing the configuration (changing registrations to singleton, adding caching, etc), no matter which library you use. At that point however it can get really complicated to configure certain libraries.

Making Simple Injector fast by default removes any concerns regarding the performance of the construction of object graphs. Instead of having to monitor Simple Injector's performance and make ugly tweaks to the configuration when object construction is too slow, the developer is free to worry about more important things.

**Fast by default** means that the performance of object instantiation from any of the registration features that the library supplies out-of-the-box will be comparable to the performance of hard-wired object instantiation.

.. _Vendor-lock-in:

Don't force vendor lock-in
==========================

The Dependency injection pattern promotes the use of loosely coupled components. -When done right- loosely coupled code can be much more maintainable. When building a library that promotes this pattern it would be ironic if that same library was to ask you to take a dependency on the library. The truth is many 3rd party library providers do want you to use certain abstractions and attributes from their offering and thereby force you to create a hard dependency to their code.

When we build applications ourselves, we try to prevent any vendor lock-in (even to Simple Injector), so why should we force you to get locked into Simple Injector? We don't want to do this. We want you to get hooked to Simple Injector, but we want this to be through the compelling vision and competing features; not by vendor lock-in. If Simple Injector doesn't suit your needs you should be able to easily swap it for another competing product, just as you would want to replace your logging library without it affecting your entire code base.

.. _Never-fail-silently:

Never fail silently
===================

We all hate the hunt for bugs in our code. It can be made even worse when we discover a library or framework we have chosen to use is hiding these bugs by ignoring them and failing to report them to us. A good example is logging libraries - many of us have been frustrated when we discover our logging libraries continue to run without logging, because we misconfigured it, but didn't bother to inform us. This frustration can lead to real world costs and a lack of trust in the tools we use.

We decided that Simple Injector should by default never fail silently. If you make a configuration error then Simple Injector should tell you as soon as reasonably possible. We want Simple Injector to fail fast!

.. _Features-should-be-intuitive:

Features should be intuitive
============================

This means that features should be easy to use and do the right thing by default.

.. _Communicate-errors-clearly:

Communicate errors clearly and describe how to solve them
=========================================================

In our day jobs we regularly encounter exception messages that aren't helpful or, even worse, are misleading (we have all seen the *NullReferenceException*). It frustrates us, takes time to track down and therefore costs money. We don't want to put any developer in that position and therefore defined an explicit design rule stating that Simple Injector should always communicate errors as clearly as possible. And, not only should it describe the problem, it should offer details on the options for solving the problem.

If you encounter a scenario where we fail to do this, please let us know. We are serious about this and we will fix it!