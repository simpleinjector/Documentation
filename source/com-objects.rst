===============================
COM objects can't be registered
===============================

When registering a COM object, Simple Injector will throw an exception message similar to the following:

.. container:: Note

    You are trying to register COM object __ComObject, which not supported.
    
What's the problem?
===================

Simple Injector does not support registering COM objects. While we attempted to to add support for registering and injecting COM objects in the past, these attempts failed due to limitations in System.Linq.Expressions. Internally, Simple Injector has a strong dependency on System.Linq.Expressions to turn expression trees into executable code.

While registering COM objects worked in some cases with older versions of Simple Injector, most of the times they did not. To prevent confusion, Simple Injector v6 now completely blocks registration of COM objects. This means, for instance, that the following registration will result in the mentioned exception:

.. code-block:: c#

    container.RegisterInstance(new Excel.Application());

So what do you need to do?
===========================

Avoid registering COM objects directly and instead create a wrapper class for your COM object. The wrapper class can be registered with the container and injected into constructors of your application classes.

The following code snippet demonstrates the registration of a *ExcelApplicationProvider* wrapper class, wrapping the Excel *Application* COM object. The *ExcelApplicationProvider* is registered in the container.

.. code-block:: c#

    container.RegisterInstance(
        new ExcelApplicationProvider { CurrentApplication = new Excel.Application() });

The wrapper class is defined as follows:

.. code-block:: c#

    public class ExcelApplicationProvider
    {
        public Excel.Application CurrentApplication { get; set; }
    }

The *ExcelApplicationProvider* can now safely be injected into consumers that require access to the 

.. code-block:: c#

    public class ApplyIntegralHandler(ExcelApplicationProvider provider)
        : ICommandHandler<ApplyIntegral>
    {
        public void Handle(ApplyIntegral command)
        {
            Workbook workbook = provider.CurrentApplication.ActiveWorkbook;
            ...
        }
    }
