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
    using SimpleInjector.Extensions.ExecutionContextScoping;

    public void Configuration(IAppBuilder app) {
        app.Use(async (context, next) => {
            using (container.BeginExecutionContextScope()) {
                await next();
            }
        });
    }

Scoped instances need to be registered with the `ExecutionContextScope` lifestyle:

.. code-block:: c#

    var scopedLifestyle = new ExecutionContextScopeLifestyle();
 
    container.Register<IUnitOfWork, MyUnitOfWork>(scopedLifestyle);
    
.. _OWIN-extra-features:    
    
Extra features
==============

Besides this basic integration, other tips and tricks can be applied to integrate Simple Injector with OWIN.

.. _Getting-the-current-requests-IOwinContext:

Getting the current request's IOwinContext
------------------------------------------

When working with OWIN you will occasionally find yourself wanting access to the current *IOwinContext*. Retrieving the current *IOwinContext* is easy as using the following code snippet:

.. code-block:: c#

    public interface IOwinContextProvider {
        IOwinContext CurrentContext { get; }
    }
     
    public class CallContextOwinContextProvider : IOwinContextProvider {
        public IOwinContext CurrentContext { 
            get { return (IOwinContext)CallContext.LogicalGetData("IOwinContext"); }
        }
    }

The code snippet above defines an *IOwinContextProvider* and an implementation. Consumers can depend on the *IOwinContextProvider* and can call its *CurrentContext* property to get the request's current *IOwinContext*.

The following code snippet can be used to register this *IOwinContextProvider* and its implementation:
    
.. code-block:: c#

    app.Use(async (context, next) => {
        CallContext.LogicalSetData("IOwinContext", context);
        await next();
    });
    
    container.RegisterSingle<IOwinContextProvider>(new CallContextOwinContextProvider());
