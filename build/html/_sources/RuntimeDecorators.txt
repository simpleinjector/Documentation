==================
Runtime Decorators
==================

**Applying decorators at runtime using Simple Injector.**

The *RegisterDecorator* extension methods contain overloads that allow you to apply a predicate (delegate) that allows you to conditionally apply a decorator.

This predicate is meant to conditionally apply a decorator based on constant information. This can be compile time information such as type names, namespaces, configuration values etc. Because of this this predicate only be called once (or at most a few times) per closed generic type. Whether or not the decorator should be applied is after that point compiled in the delegate.

Sometimes however, decorators must be applied based on some runtime conditions. Take for instance a authorization decorator that must conditionally be applied based on the role of the current user.

The following example shows an extension method that allows registering a decorator using a runtime predicate:

.. code-block:: c#

    using System;
    using System.Linq.Expressions;
    using System.Threading;
    using SimpleInjector.Extensions;

    public static class RuntimeDecoratorExtensions
    {
        public static void RegisterRuntimeDecorator(this Container container, Type serviceType, 
            Type decoratorType, Predicate<DecoratorPredicateContext> runtimePredicate)
        {
            container.RegisterRuntimeDecorator(serviceType, decoratorType, Lifestyle.Transient,
                runtimePredicate);
        }

        public static void RegisterRuntimeDecorator(this Container container, Type serviceType, 
            Type decoratorType, Lifestyle lifestyle,
            Predicate<DecoratorPredicateContext> runtimePredicate,
            Predicate<DecoratorPredicateContext> compileTimePredicate = null)
        {
            var localContext = new ThreadLocal<DecoratorPredicateContext>();

            compileTimePredicate = compileTimePredicate ?? (context => true);

            container.RegisterDecorator(serviceType, decoratorType, lifestyle, c =>
            {
                bool mustDecorate = compileTimePredicate(c);
                localContext.Value = mustDecorate ? c : null;
                return mustDecorate;
            });

            container.ExpressionBuilt += (s, e) =>
            {
                bool isDecorated = localContext.Value != null;

                if (isDecorated)
                {
                    Expression decorator = e.Expression;
                    Expression original = localContext.Value.Expression;

                    Expression shouldDecorate = Expression.Invoke(
                        Expression.Constant(runtimePredicate),
                        Expression.Constant(localContext.Value));

                    e.Expression = Expression.Condition(shouldDecorate,
                        Expression.Convert(decorator, e.RegisteredServiceType),
                        Expression.Convert(original, e.RegisteredServiceType));

                    localContext.Value = null;
                }
            };
        }
    }

The following line shows an example of how to use this extension method:

.. code-block:: c#

    container.RegisterRuntimeDecorator(
        typeof(ICommandHandler<>),
        typeof(AuthorizationHandlerDecorator<>), context =>
        {
            var userContext =
                container.GetInstance<IUserContext>();
            return !userContext.UserInRole("Admin");
        });