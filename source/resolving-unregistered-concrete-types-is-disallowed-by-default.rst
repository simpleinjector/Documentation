==============================================================
Resolving unregistered concrete types is disallowed by default
==============================================================

Starting with v5.0, Simple Injector will no long resolve unregistered concrete types for you by default. This means that if you resolve a concrete type (e.g. by calling `container.GetInstance<MyConcrete>()`) or have an unregistered concrete type as dependency of some other type, Simple Injector will throw a message similar to the following:

.. container:: Note

    No registration for type {type} could be found. Make sure {type} is registered, for instance by calling 'Container.Register<{type}>();' during the registration phase. An implicit registration could not be made because Container.Options.ResolveUnregisteredConcreteTypes is set to 'false', which is now the default setting in v5. This disallows the container to construct this unregistered concrete type. For more information on why resolving unregistered concrete types is now disallowed by default, and what possible fixes you can apply, see https://simpleinjector.org/ructd.

What's the problem?
===================

Earlier versions of Simple Injector allowed resolving and injecting concrete types even if they weren't registered in the container. Although this is convenient in several cases, it also leads to errors. Forgetting to register root types, for instance, causes the type to be skipped by verification. This gave a false sense of security. Other issues arise when accidentally resolving a concrete type, where the registered interface should've been resolved. Although the concrete type might be resolved correctly, Simple Injector will not be able to apply any decorators, which are generally applied on the interface.

Because of these pitfalls, not allowing unregistered concrete types to be resolved is a much more sensible default.

So what do you need to do?
===========================

There are multiple possible solutions you can apply.

* In case you are accidentally injecting or requesting a concrete type, where you should have requested its (registered) interface, the solution is to inject or request the interface instead. Example:

  .. code-block:: c#

      // Component with interface
      public class TimeProvider : ITimeProvider { ... }
      
      // Registration
      container.Register<ITimeProvider, TimeProvider>();

      // Causes error:
      public class MyController
      {
          // Accidental use of concrete dependency
          public MyController(TimeProvider timeProvider) { ... }
      }
      
      // Depend on interface instead
      public class MyController
      {
          // Change to depending on interface instead
          public MyController(ITimeProvider timeProvider) { ... }
      }    


* If you need the concrete type to be injected or requested, you should register that concrete type in the container.

  .. code-block:: c#
  
      // This registration already existed
      container.Register<ITimeProvider, TimeProvider>();
      
      // Add the concrete registration as well.
      container.Register<TimeProvider>();
      
      // This allows consumers to depend on this concrete type:
      public class MyController
      {
          public MyController(TimeProvider timeProvider) { ... }
      }
      
      // And this allows the concrete class to be requested directly:
      container.GetInstance<TimeProvider>();

* In case your application depends on Simple Injector's old behavior where unregistered concrete types could be resolved, and you can't easily fix this by registering all concrete types, you can switch to the legacy behavior by setting **Container.Options.ResolveUnregisteredConcreteTypes = true**:

  .. code-block:: c#
  
      var container = new Container();
      
      // Reverting to the pre-v5 behavior
      container.Options.ResolveUnregisteredConcreteTypes = true;
      
      // This allows you to resolve any unregistered concrete type:
      container.GetInstance<TimeProvider>();
    
* In case the concrete types can't be registered, because they don't exist at compile time, you can create **InstanceProducer** instances and resolve from them.
  
  ASP.NET Web Forms, for instance, generates `Page` classes that derive from classes you wrote. Those generated classes, however, are generated at runtime and, therefore, can't be registered. Still, the runtime might request for these generated sub classes instead.
  
  For scenarios like the previous, Simple Injector allows for the just-in-time registration of root types, which is a more sensible setting compared to reverting to the old `ResolveUnregisteredConcreteTypes` behavior completely. The following code snippet shows how InstanceProducers can be used to achieve this:

  .. code-block:: c#
  
      private readonly ConcurrentDictionary<Type, InstanceProducer> producers =
          new ConcurrentDictionary<Type, InstanceProducer>();
          
      private readonly Container container;
      
      public object GetPage(Type pageType)
      {
          InstanceProducer producer = this.producers.GetOrAdd(pageType, this.CreateProducer);
          return producer.GetInstance();
      }
      
      private InstanceProducer CreateProducer(Type pageType) =>
          Lifestyle.Transient.CreateProducer(pageType, pageType, this.container);

  In the previous code snippet, the `GetPage` method functions as factory method, which delegates the creation of instances back to Simple Injector. It does so by creating (and caching) `InstanceProducer` instances. Because `GetPage` could be called by multiple threads simultaniously, a `ConcurrentDictionary` is used as cache. Caching of `InstanceProducer` instances is important, because there is a lot of overhead in the creation `InstanceProducer` and every first call to `InstanceProducer.GetInstance`.
