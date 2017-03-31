===========================
Aspect-Oriented Programming
===========================

The `SOLID <https://en.wikipedia.org/wiki/SOLID>`_ principles give us important guidance when it comes to writing maintainable software. The 'O' of the 'SOLID' acronym stands for the `Open/closed Principle <https://en.wikipedia.org/wiki/Open/closed_principle>`_ which states that classes should be open for extension, but closed for modification. Designing systems around the Open/closed principle means that new behavior can be plugged into the system, without the need to change any existing parts, making the chance of breaking existing code much smaller and prevent having to make sweeping changes throughout the code base. This way of working is often referred to as Aspect-oriented programming.

Aspect-oriented programming (AOP) is a programming paradigm that aims to increase modularity by allowing the separation of cross-cutting concerns. It allows new behavior to be plugged in or changed, without having to change or even recompile existing code. Simple Injector's main support for AOP is by the use of decorators. Besides decorators, one can also plugin interception using a dynamic proxy framework.

This chapter discusses the following subjects:

* :ref:`Decoration <Decoration>`
* :ref:`Interception using Dynamic Proxies <Interception-using-Dynamic-Proxies>`

.. _Decoration:

Decoration
==========

The best way to add new functionality (such as `cross-cutting concerns <https://en.wikipedia.org/wiki/Cross-cutting_concern>`_) to classes is by the use of the `decorator pattern <https://en.wikipedia.org/wiki/Decorator_pattern>`_. The decorator pattern can be used to extend (decorate) the functionality of a certain object at run-time. Especially when using generic interfaces, the concept of decorators gets really powerful. Take for instance the examples given in the :ref:`Registration of open generic types <Registration-Of-Open-Generic-Types>` section or for instance the use of an generic *ICommandHandler<TCommand>* interface.

.. container:: Note

    **Tip**: `This article <https://cuttingedge.it/blogs/steven/pivot/entry.php?id=91>`_ describes an architecture based on the use of the *ICommandHandler<TCommand>* interface.

Take the plausible scenario where we want to validate all commands that get executed by an *ICommandHandler<TCommand>* implementation. The Open/Closed principle states that we want to do this, without having to alter each and every implementation. We can do this using a (single) decorator:

.. code-block:: c#

    public class ValidationCommandHandlerDecorator<TCommand> : ICommandHandler<TCommand> {
        private readonly IValidator validator;
        private readonly ICommandHandler<TCommand> decoratee;

        public ValidationCommandHandlerDecorator(IValidator validator, 
            ICommandHandler<TCommand> decoratee) {
            this.validator = validator;
            this.decoratee = decoratee;
        }

        void ICommandHandler<TCommand>.Handle(TCommand command) {
            // validate the supplied command (throws when invalid).
            this.validator.ValidateObject(command);
            
            // forward the (valid) command to the real command handler.
            this.decoratee.Handle(command);
        }
    }

The *ValidationCommandHandlerDecorator<TCommand>* class is an implementation of the *ICommandHandler<TCommand>* interface, but it also wraps / decorates an *ICommandHandler<TCommand>* instance. Instead of injecting the real implementation directly into a consumer, we can (let Simple Injector) inject a validator decorator that wraps the real implementation.

The *ValidationCommandHandlerDecorator<TCommand>* depends on an *IValidator* interface. An implementation that used Microsoft Data Annotations might look like this:

.. code-block:: c#

    using System.ComponentModel.DataAnnotations;

    public class DataAnnotationsValidator : IValidator {       
        void IValidator.ValidateObject(object instance) {
            var context = new ValidationContext(instance, null, null);

            // Throws an exception when instance is invalid.
            Validator.ValidateObject(instance, context, validateAllProperties: true);
        }
    }

The implementations of the *ICommandHandler<T>* interface can be registered using the **Register** method overload that takes in a list of assemblies:

.. code-block:: c#

    container.Register(
        typeof(ICommandHandler<>), 
        new[] { typeof(ICommandHandler<>).Assembly });

By using the following method, you can wrap the *ValidationCommandHandlerDecorator<TCommand>* around each and every *ICommandHandler<TCommand>* implementation:

.. code-block:: c#

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(ValidationCommandHandlerDecorator<>));

Multiple decorators can be wrapped by calling the **RegisterDecorator** method multiple times, as the following registration shows:

.. code-block:: c#

    container.Register(
        typeof(ICommandHandler<>), 
        new[] { typeof(ICommandHandler<>).Assembly });
        
    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(TransactionCommandHandlerDecorator<>));

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(DeadlockRetryCommandHandlerDecorator<>));

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(ValidationCommandHandlerDecorator<>));

The decorators are applied in the order in which they are registered, which means that the first decorator (*TransactionCommandHandlerDecorator<T>* in this case) wraps the real instance, the second decorator (*DeadlockRetryCommandHandlerDecorator<T>* in this case) wraps the first decorator, and so on.

.. _Applying-decorators-conditionally:

Applying Decorators conditionally
---------------------------------

There's an overload of the **RegisterDecorator** available that allows you to supply a predicate to determine whether that decorator should be applied to a specific service type. Using a given context you can determine whether the decorator should be applied. Here is an example:

.. code-block:: c#

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(AccessValidationCommandHandlerDecorator<>),
        context => typeof(IAccessRestricted).IsAssignableFrom(
            context.ServiceType.GetGenericArguments()[0]));

The given context contains several properties that allows you to analyze whether a decorator should be applied to a given service type, such as the current closed generic service type (using the *ServiceType* property) and the concrete type that will be created (using the *ImplementationType* property). The predicate will (under normal circumstances) be called only once per closed generic type, so there is no performance penalty for using it.

.. _Applying-decorators-conditionally-using-type-constraints:

Applying Decorators conditionally using type constraints
--------------------------------------------------------

The previous example shows the conditional registration of the *AccessValidationCommandHandlerDecorator<T>* decorator. It is applied in case the closed *TCommand* type (of *ICommandHandler<TCommand>*) implements the *IAccessRestricted* interface.

Simple Injector will automatically apply decorators conditionally based on defined `generic type constraints <https://msdn.microsoft.com/en-us/library/d5x73970.aspx>`_. We can therefore define the *AccessValidationCommandHandlerDecorator<T>* with a generic type constraint, as follows:

.. code-block:: c#

    class AccessValidationCommandHandlerDecorator<TCommand> : ICommandHandler<TCommand>
        where TCommand : IAccessRestricted
    {
        private readonly ICommandHandler<TCommand> decoratee;

        public AccessValidationCommandHandlerDecorator(ICommandHandler<TCommand> decoratee){
            this.decoratee = decoratee;
        }

        void ICommandHandler<TCommand>.Handle(TCommand command) {
            // Do access validation
            this.decoratee.Handle(command);
        }
    }
    
Since Simple Injector natively understands generic type constraints, we can reduce the previous registration to the following:
    
.. code-block:: c#

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(AccessValidationCommandHandlerDecorator<>));

The use of generic type constraints has many advantages:

* It allows constraints to be specified exactly once, in the place it often makes most obvious, i.e. the decorator itself.
* It allows constraints to be specified in the syntax you are used to the most, i.e. C#.
* It allows constraints to be specified in a very succinct manner compared to the verbose, error prone and often hard to read syntax of the reflection API (the previous examples already shown this).
* It allows decorator to be simplified, because of the added compile time support.

Obviously there are cases where these conditions can't or shouldn't be defined using generic type constraints. The following code example shows a registration that can't be expressed using generic type constraints:

.. code-block:: c#

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(AccessValidationCommandHandlerDecorator<>),
        c => c.ImplementationType.GetCustomAttributes(typeof(AccessAttribute)).Any());

This registration applies the decorator conditionally based on an attribute on the (initially) decorated handler type. There is obviously no way to express this using generic type constraints, so we will have to fallback to the predicate syntax.
        
.. _Decorators-with-Func-factories:

Decorators with Func<T> decoratee factories
-------------------------------------------

There are certain scenarios where it is necessary to postpone the building of part of an object graph. For instance when a service needs to control the lifetime of a dependency, needs multiple instances, when instances need to be :ref:`executed on a different thread <Multi-Threaded-Applications>`, or when instances need to be created within a certain :ref:`scope <Scoped>` or context (e.g. security).

You can easily delay the building of part of the graph by depending on a factory; the factory allows building that part of the object graph to be postponed until the moment the type is actually required. However, when working with decorators, injecting a factory to postpone the creation of the decorated instance will not work. This is best demonstrated with an example.

Take for instance an *AsyncCommandHandlerDecorator<T>* that executes a command handler on a different thread. We could let the *AsyncCommandHandlerDecorator<T>* depend on a *CommandHandlerFactory<T>*, and let this factory call back into the container to retrieve a new *ICommandHandler<T>* but this would fail, since requesting an *ICommandHandler<T>* would again wrap the new instance with a *AsyncCommandHandlerDecorator<T>* and we'd end up recursively creating the same instance type again and again resulting in an endless loop.

This particular scenario is really hard to solve without library support and as such Simple Injector allows injecting a *Func<T>* delegate into registered decorators. This delegate functions as a factory for the creation of the decorated instance and avoids the recursive decoration explained above.

Taking the same *AsyncCommandHandlerDecorator<T>* as an example, it could be implemented as follows:

.. code-block:: c#

    public class AsyncCommandHandlerDecorator<T> : ICommandHandler<T> {
        private readonly Func<ICommandHandler<T>> decorateeFactory;

        public AsyncCommandHandlerDecorator(Func<ICommandHandler<T>> decorateeFactory) {
            this.decorateeFactory = decorateeFactory;
        }
        
        public void Handle(T command) {
            // Execute on different thread.
            ThreadPool.QueueUserWorkItem(state => {
                try {
                    // Create new handler in this thread.
                    ICommandHandler<T> handler = this.decorateeFactory.Invoke();
                    handler.Handle(command);
                } catch (Exception ex) {
                    // log the exception
                }            
            });
        }
    }

This special decorator is registered just as any other decorator:

.. code-block:: c#

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(AsyncCommandHandlerDecorator<>),
        c => c.ImplementationType.Name.StartsWith("Async"));

The *AsyncCommandHandlerDecorator<T>* however, has only singleton dependencies (the *Func<T>* is a singleton) and the *Func<ICommandHandler<T>>* factory always calls back into the container to register a decorated instance conforming the decoratee's lifestyle, each time it's called. If for instance the decoratee is registered as transient, each call to the factory will result in a new instance. It is therefore safe to register this decorator as a singleton:

.. code-block:: c#

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(AsyncCommandHandlerDecorator<>),
        Lifestyle.Singleton,
        c => c.ImplementationType.Name.StartsWith("Async"));

When mixing this decorator with other (synchronous) decorators, you'll get an extremely powerful and pluggable system:

.. code-block:: c#

    container.Register(
        typeof(ICommandHandler<>), 
        new[] { typeof(ICommandHandler<>).Assembly });
        
    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(TransactionCommandHandlerDecorator<>));

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(DeadlockRetryCommandHandlerDecorator<>));

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(AsyncCommandHandlerDecorator<>),
        Lifestyle.Singleton,
        c => c.ImplementationType.Name.StartsWith("Async"));
        
    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(ValidationCommandHandlerDecorator<>));

This configuration has an interesting mix of decorator registrations.

#. The registration of the *AsyncCommandHandlerDecorator<T>* allows (a subset of) command handlers to be executed in the background (while any command handler with a name that does not start with 'Async' will execute synchronously)
#. Prior to this point all commands are validated synchronously (to allow communicating validation errors to the caller)
#. All handlers (sync and async) are executed in a transaction and the operation is retried when the database rolled back because of a deadlock

.. container:: Note

    **Warning**: Please note that the previous example is just meant for educational purposes. In practice, you don't want your commands to be processed this way, since it could lead to message loss. Instead you want to use a durable queue.

Another useful application for *Func<T>* decoratee factories is when a command needs to be executed in an isolated fashion, e.g. to prevent sharing the unit of work with the request that triggered the execution of that command. This can be achieved by creating a proxy that starts a new thread-specific scope, as follows:

.. code-block:: c#

    using SimpleInjector.Lifestyles;

    public class ThreadScopedCommandHandlerProxy<T> : ICommandHandler<T> {
        private readonly Container container;
        private readonly Func<ICommandHandler<T>> decorateeFactory;

        public ThreadScopedCommandHandlerProxy(Container container,
            Func<ICommandHandler<T>> decorateeFactory) {
            this.container = container;
            this.decorateeFactory = decorateeFactory;
        }

        public void Handle(T command) {
            // Start a new scope.
            using (ThreadScopedLifestyle.BeginScope(container)) {
                // Create the decorateeFactory within the scope.
                ICommandHandler<T> handler = this.decorateeFactory.Invoke();
                handler.Handle(command);
            };
        }
    }
    
This proxy class starts a new :ref:`thread scoped lifestyle <ThreadScoped>` and resolves the decoratee within that new scope using the factory. The use of the factory ensures that the decoratee is resolved according to its lifestyle, independent of the lifestyle of our proxy class. The proxy can be registered as follows:

.. code-block:: c#

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(ThreadScopedCommandHandlerProxy<>),
        Lifestyle.Singleton);

.. container:: Note

    **Note**: Since the *ThreadScopedCommandHandlerProxy<T>* only depends on singletons (both the *Container* and the *Func<ICommandHandler<T>>* are singletons), it too can safely be registered as singleton.
        
Since a typical application will not use the thread scoped lifestyle, but would prefer a scope specific to the application type, a special :ref:`hybrid lifestyle <Hybrid>` needs to be defined that allows object graphs to be resolved in this mixed-request scenario:

.. code-block:: c#

    container.Options.DefaultScopedLifestyle = Lifestyle.CreateHybrid(
        defaultLifestyle = new ThreadScopedLifestyle(),
        fallbackLifestyle: new WebRequestLifestyle());

    container.Register<IUnitOfWork, DbUnitOfWork>(Lifestyle.Scoped);

Obviously, if you run (part of) your commands on a background thread and also use registrations with a :ref:`scoped lifestyle <Scoped>` you will have a use both the *ThreadScopedCommandHandlerProxy<T>* and *AsyncCommandHandlerDecorator<T>* together which can be seen in the following configuration:

.. code-block:: c#

    container.Options.DefaultScopedLifestyle = Lifestyle.CreateHybrid(
        defaultLifestyle = new ThreadScopedLifestyle(),
        fallbackLifestyle: new WebRequestLifestyle());

    container.Options.DefaultScopedLifestyle = scopedLifestyle;

    container.Register<IUnitOfWork, DbUnitOfWork>(Lifestyle.Scoped);
    container.Register<IRepository<User>, UserRepository>(Lifestyle.Scoped);
        
    container.Register(
        typeof(ICommandHandler<>), 
        new[] { typeof(ICommandHandler<>).Assembly });

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(ThreadScopedCommandHandlerProxy<>),
        Lifestyle.Singleton);
        
    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(AsyncCommandHandlerDecorator<>),
        Lifestyle.Singleton,
        c => c.ImplementationType.Name.StartsWith("Async"));

With this configuration all commands are executed in an isolated context and some are also executed on a background thread.

.. _Decorated-Collections:

Decorated collections
---------------------

When registering a decorator, Simple Injector will automatically decorate any collection with elements of that service type:

.. code-block:: c#

    container.RegisterCollection<IEventHandler<CustomerMovedEvent>>(new[] {
        typeof(CustomerMovedEventHandler),
        typeof(NotifyStaffWhenCustomerMovedEventHandler)
    });
        
    container.RegisterDecorator(
        typeof(IEventHandler<>),
        typeof(TransactionEventHandlerDecorator<>),
        c => SomeCondition);

The previous registration registers a collection of *IEventHandler<CustomerMovedEvent>* services. Those services are decorated with a *TransactionEventHandlerDecorator<TEvent>* when the supplied predicate holds.

For collections of elements that are created by the container (container controlled), the predicate is checked for each element in the collection. For collections of uncontrolled elements (a list of items that is not created by the container), the predicate is checked once for the whole collection. This means that controlled collections can be partially decorated. Taking the previous example for instance, you could let the *CustomerMovedEventHandler* be decorated, while leaving the *NotifyStaffWhenCustomerMovedEventHandler* undecorated (determined by the supplied predicate).

When a collection is uncontrolled, it means that the lifetime of its elements are unknown to the container. The following registration is an example of an uncontrolled collection:

.. code-block:: c#

    IEnumerable<IEventHandler<CustomerMovedEvent>> handlers =
        new IEventHandler<CustomerMovedEvent>[] {
            new CustomerMovedEventHandler(),
            new NotifyStaffWhenCustomerMovedEventHandler(),
        };

    container.RegisterCollection<IEventHandler<CustomerMovedEvent>>(handlers);

Although this registration contains a list of singletons, the container has no way of knowing this. The collection could easily have been a dynamic (an ever changing) collection. In this case, the container calls the registered predicate once (and supplies the predicate with the *IEventHandler<CusotmerMovedEvent>* type) and if the predicate returns true, each element in the collection is decorated with a decorator instance.

.. container:: Note

    **Warning**: In general you should prevent registering uncontrolled collections. The container knows nothing about them, and can't help you in doing :doc:`diagnostics <diagnostics>`. Since the lifetime of those items is unknown, the container will be unable to wrap a decorator with a lifestyle other than transient. Best practice is to register container-controlled collections which is done by using one of the **RegisterCollection** overloads that take a collection of *System.Type* instances.

.. _Using-contextual-information-inside-decorators:

Using contextual information inside decorators
----------------------------------------------

As we shown before, you can apply a decorator conditionally based on a predicate you can supply to the **RegisterDecorator** overloads:

.. code-block:: c#

    container.RegisterDecorator(
        typeof(ICommandHandler<>),
        typeof(AsyncCommandHandlerDecorator<>),
        c => c.ImplementationType.Name.StartsWith("Async"));

Sometimes however you might want to apply a decorator unconditionally, but let the decorator act at runtime based on this contextual information. You can do this by injecting the **DecoratorContext** into the decorator's constructor as can be seem in the following example:

.. code-block:: c#

    public class TransactionCommandHandlerDecorator<T> : ICommandHandler<T> {
        private readonly ITransactionBuilder builder;
        private readonly ICommandHandler<T> decoratee;
        private readonly TransactionType transactionType;

        public TransactionCommandHandlerDecorator(DecoratorContext decoratorContext,
            ITransactionBuilder builder, ICommandHandler<T> decoratee) {
            this.builder = builder;
            this.decoratee = decoratee;
            this.transactionType = decoratorContext.ImplementationType
                .GetCustomAttribute<TransactionAttribute>()
                .TransactionType;
        }
        
        public void Handle(T command) {
            using (var ta = this.builder.BeginTransaction(this.transactionType)) {
                this.decoratee.Handle(command);
                ta.Complete();
            }
        }
    }
    
The previous code snippet shows a decorator that applies a transaction behavior to command handlers. The decorator is injected with the **DecoratorContext** class which supplies the decorator with contextual information about the other decorators in the chain and the actual implementation type. In this example the decorator expects a *TransactionAttribute* to be applied to the wrapped command handler implementation and it starts the correct transaction type based on this information. The following code snippet shows a possible command handler implementation:

.. code-block:: c#

    [Transaction(TransactionType.ReadCommitted)]
    public class ShipOrderHandler : ICommandHandler<ShipOrder> {
        public void Handle(ShipOrder command) {
            // Business logic here
        }
    }

If the attribute was applied to the command class instead of the command handler, this decorator would been able to gather this information without the use of the **DecoratorContext**. This would however leak implementation details into the command, since which type of transaction a handler should run is clearly an implementation detail and is of no concern to the consumer of that command. Placing that attribute on the handler instead of the command is therefore a much more reasonable thing to do.

The decorator would also be able to get the attribute by using the injected decoratee, but this would only work when the decorator would directly wrap the handler. This would make the system quite fragile, since it would break once you start placing other decorator in between this decorator and the handler, which is a very likely thing to happen.

.. _Applying-decorators-conditionally-based-on-consumer:

Applying decorators conditionally based on consumer
---------------------------------------------------

The previous examples showed how to apply a decorator conditionally based on information about its dependencies, such as the decorators that it wraps and the wrapped real implementation. Another option is to make decisions based on the consuming components; the components the decorator is injected into.

Although the **RegisterDecorator** methods don't have any built-in support for this, this behavior can be achieved by using the **RegisterConditional** methods. For instance:

.. code-block:: c#

    container.RegisterConditional<IMailSender, AsyncMailSenderDecorator>(
        c => c.Consumer.ImplementationType == typeof(UserController));
    container.RegisterConditional<IMailSender, BufferedMailSenderDecorator>(
        c => c.Consumer.ImplementationType == typeof(EmailBatchProcessor));

    container.RegisterConditional<IMailSender, SmtpMailSender>(c => !c.Handled);

Here we use **RegisterConditional** to register two decorators. Both decorator will wrap the *SmtpMailSender* that is registered last. The *AsyncMailSenderDecorator* is wrapped around the *SmtpMailSender* in case it is injected into the *UserController*, while the *BufferedMailSenderDecorator* is wrapped when injected into the *EmailBatchProcessor*. Note that the *SmtpMailSender* is registered as conditional as well, and is registered as fallback registration using **!c.Handled**, which basically means that in case no other registration applies, that registration is used.
    
    
.. _Decorator-registration-factories:

Decorator registration factories
--------------------------------

In some advanced scenarios, it can be useful to depend the actual decorator type based on some contextual information. There is a **RegisterDecorator** overload that accepts a factory delegate that allows building the exact decorator type based on the actual type being decorated.

Take the following registration for instance:

.. code-block:: c#

    container.RegisterDecorator(
        typeof(IEventHandler<>),
        factoryContext => typeof(LoggingEventHandlerDecorator<,>).MakeGenericType(
            typeof(LoggingEventHandler<,>).GetGenericArguments().First(),
            factoryContext.ImplementationType),
        Lifestyle.Transient,
        predicateContext => true);

This example registers the *LoggingEventHandlerDecorator<TEvent, TLogTarget>* decorator for the *IEventHandler<TEvent>* abstraction. The supplied factory delegate builds up a partially-closed generic type by filling in the *TLogTarget* argument, where the *TEvent* is left 'open'. This is done by requesting the first generic type argument (the *TEvent*) from the open-generic *LoggingEventHandler<,>* type itself and using the **ImplementationType** as second argument. This means that when this decorator is wrapped around a type called *CustomerMovedEventHandler*, the factory method will create the type *LoggingEventHandler<TEvent, CustomerMovedEventHandler>*. In other words, the second argument is a concrete type (and thus closed), while the first argument is still a blank.

When a closed version of *IEventHandler<TEvent>* is requested later on, Simple Injector will know how to fill in the blank with the correct type for this *TEvent* argument.

.. container:: Note

    **Tip**: Simple Injector doesn't care in which order you define your generic type arguments, nor how you name them; it will be able to figure out the correct type to build any way.

.. container:: Note

    **Note**: The type factory delegate is typically called once per closed-type and the result is burned in the compiled object graph. You can't use this delegate to make runtime decisions.

.. _Interception-using-Dynamic-Proxies:

Interception using Dynamic Proxies
==================================

Interception is the ability to intercept a call from a consumer to a service, and add or change behavior. The `decorator pattern <https://en.wikipedia.org/wiki/Decorator_pattern>`_ describes a form of interception, but when it comes to applying cross-cutting concerns, you might end up writing decorators for many service interfaces, but with the exact same code. If this is happening, it's time to take a close look at your design. If for what ever reason, it's impossible for you to make the required improvements to your design, your second best bet is to explore the possibilities of interception through dynamic proxies.

.. container:: Note

    **Warning**: Simple Injector has :ref:`no out-of-the-box support for interception <No-interception>` because the use of interception is an indication of a sub optimal design and we are keen on pushing developers into best practices. Whenever possible, choose to improve your design to make decoration possible.    

Using the :doc:`Interception extensions <InterceptionExtensions>` code snippets, you can add the ability to do interception with Simple Injector. Using the given code, you can for instance define a *MonitoringInterceptor* that allows logging the execution time of the called service method:

.. code-block:: c#

    private class MonitoringInterceptor : IInterceptor {
        private readonly ILogger logger;

        // Using constructor injection on the interceptor
        public MonitoringInterceptor(ILogger logger) {
            this.logger = logger;
        }

        public void Intercept(IInvocation invocation) {
            var watch = Stopwatch.StartNew();

            // Calls the decorated instance.
            invocation.Proceed();

            var decoratedType = invocation.InvocationTarget.GetType();
            
            this.logger.Log(string.Format("{0} executed in {1} ms.",
                decoratedType.Name, watch.ElapsedMiliseconds));
        }
    }

This interceptor can be registered to be wrapped around a concrete implementation. Using the given extension methods, this can be done as follows:

.. code-block:: c#

    container.InterceptWith<MonitoringInterceptor>(type => type == typeof(IUserRepository));

This registration ensures that every time an *IUserRepository* interface is requested, an interception proxy is returned that wraps that instance and uses the *MonitoringInterceptor* to extend the behavior.

The current example doesn't add much compared to simply using a decorator. When having many interface service types that need to be decorated with the same behavior however, it gets different:

.. code-block:: c#

    container.InterceptWith<MonitoringInterceptor>(t => t.Name.EndsWith("Repository"));

.. container:: Note

    **Note**: The :doc:`Interception extensions <InterceptionExtensions>` code snippets use .NET's *System.Runtime.Remoting.Proxies.RealProxy* class to generate interception proxies. The *RealProxy* only allows to proxy interfaces.

.. container:: Note

    **Note**: the interfaces in the given :doc:`Interception extensions <InterceptionExtensions>` code snippets are a simplified version of the Castle Project interception facility. If you need to create lots different interceptors, you might benefit from using the interception abilities of the Castle Project. Also please note that the given snippets use dynamic proxies to do the interception, while Castle uses lightweight code generation (LCG). LCG allows much better performance than the use of dynamic proxies. Please see `this stackoverflow q/a <https://stackoverflow.com/questions/24513530/using-simple-injector-with-castle-proxy-interceptor>`_ for an implementation for Castle Windsor.

.. container:: Note

    **Note**: Don't use interception for intercepting types that all implement the same generic interface, such as *ICommandHandler<T>* or *IValidator<T>*. Try using decorator classes instead, as shown in the :ref:`Decoration <decoration>` section on this page.