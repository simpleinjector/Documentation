=====================================
Console Application Integration Guide
=====================================

Simple Injector contains several integration packages that simplify plugging-in Simple Injector into a wide variety of frameworks. These packages allow you to hook Simple Injector onto the framework's integration point.

When it comes to writing Console applications however, there are no integration packages. That's because Console applications are not backed by a particular framework. .NET just does the bare minimum when a Console application is started and there are no integration hooks that you can use. This means that you are in complete control over the application.

When a Console application is short-lived, and runs just a single operation and exits, the application could have a structure similar to the following:

.. code-block:: c#

    using SimpleInjector;
    
    static class Program
    {
        static readonly Container container;
    
        static Program()
        {
            container = new Container();
            
            container.Register<IUserRepository, SqlUserRepository>();
            container.Register<MyRootType>();
            
            container.Verify();
        }

        static void Main() 
        {
            var service = container.GetInstance<MyRootType>();
            service.DoSomething();
        }
    }

Console applications can also be built to be long running, just like Windows services and web services are. In that case such Console application will typically handle many 'requests'.

The term 'request' is used loosely here. It could be an incoming request over the network, an action triggered by a message on an incoming queue, or an action triggered by timer or scheduler. Either way, a request is something that should typically run in a certain amount of isolation. It might for instance have its own set of state, specific to that request. An Entity Framework *DbContext* for instance, is typically an object that is particular to a single request.

In the absence of any framework code, you are yourself responsible to tell Simple Injector that certain code must run in isolation. This can be done with Scoping. There are two types of scoped lifestyles that can be used. :ref:`LifetimeScopeLifestyle <PerLifetimeScope>` allows wrapping code that runs on a single thread in a scope, where :ref:`ExecutionContextScopeLifestyle <PerExecutionContextScope>` allows wrapping a block of code that flows asynchronously (using async await).

The following example demonstrates a simple Console application that runs indefinitely, and executes a request every second. The request is wrapped in a scope:
    
.. code-block:: c#
   
    using SimpleInjector;
    using SimpleInjector.Extensions.LifetimeScoping;
   
    static class Program
    {
        static readonly Container container;
    
        static Program()
        {
            container = new Container();
            container.Options.DefaultScopedLifestyle = new LifetimeScopeLifestyle();
            
            container.Register<IUserRepository, SqlUserRepository>(Lifestyle.Scoped);
            container.Register<MyRootType>();
            
            container.Verify();
        }
    
        static void Main() 
        {
            while (true)
            {
                using (container.BeginLifetimeScope())
                {
                    var service = container.GetInstance<MyRootType>();

                    service.DoSomething();
                }
                
                Thread.Sleep(TimeSpan.FromSeconds(1));
            }
        }
    }
