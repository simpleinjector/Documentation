======================
OWIN Integration Guide
======================

.. _OWIN-basic-setup:
    
Basic setup
===========

To allow scoped instances to be resolved during an OWIN request, the following registration needs to be added to the *IAppBuilder* instance:

.. code-block:: c#

    // You'll need to include the following namespaces
    using Owin;
    using SimpleInjector;
    using SimpleInjector.Lifestyles;

    public void Configuration(IAppBuilder app) {
        app.Use(async (context, next) => {
            using (AsyncScopedLifestyle.BeginScope(container)) {
                await next();
            }
        });
    }

Scoped instances need to be registered with the `AsyncScopedLifestyle` lifestyle:

.. code-block:: c#

    var container = new Container();
    container.Options.DefaultScopedLifestyle = new AsyncScopedLifestyle();
    
    container.Register<IUnitOfWork, MyUnitOfWork>(Lifestyle.Scoped);
    
.. _OWIN-extra-features:    
    
Extra features
==============

Besides this basic integration, other tips and tricks can be applied to integrate Simple Injector with OWIN.

.. _Getting-the-current-requests-IOwinContext:

Getting the current request's IOwinContext
------------------------------------------

When working with OWIN you will occasionally find yourself wanting access to the current *IOwinContext*. Retrieving the current *IOwinContext* is easy as using the following code snippet:

.. code-block:: c#

    public interface IOwinContextAccessor {
        IOwinContext CurrentContext { get; }
    }
     
    public class CallContextOwinContextAccessor : IOwinContextAccessor {
        public static AsyncLocal<IOwinContext> OwinContext = new AsyncLocal<IOwinContext>();
        public IOwinContext CurrentContext => OwinContext.Value;
    }

The code snippet above defines an *IOwinContextAccessor* and an implementation. Consumers can depend on the *IOwinContextAccessor* and can call its *CurrentContext* property to get the request's current *IOwinContext*.

The following code snippet can be used to register this *IOwinContextAccessor* and its implementation:
    
.. code-block:: c#

    app.Use(async (context, next) => {
        CallContextOwinContextAccessor.OwinContext.Value = context;
        await next();
    });
    
    container.RegisterInstance<IOwinContextAccessor>(new CallContextOwinContextAccessor());
