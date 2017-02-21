=======================================================
Resolution conflicts caused by dynamic assembly loading
=======================================================

Simple Injector can sometimes throw an exception message similar to the following when batch-registration is mixed with dynamic loading of assemblies:

.. container:: Note

    Type {type name} is a member of the assembly {assembly name} which seems to have been loaded more than once. The CLR believes the second instance of the assembly is a different assembly to the first. It is this multiple loading of assemblies that is causing this issue. The most likely cause is that the same assembly has been loaded from different locations within different contexts.

What's the problem?
===================
    
This exception is thrown by Simple Injector when trying to resolve a type for which it does not have an exact registration, but finds a registration for a different type with the exact same type name.

The problem is usually caused by incorrect assembly loading: the same assembly has been loaded multiple times, leading the common language runtime to believe that the multiple instances of the assembly are different assemblies. Although both assemblies contain the same type, as far as the runtime is concerned there are two different types, and they are completely unrelated. Simple Injector cannot automatically fix this problem - the runtime sees the types as unrelated and Simple Injector cannot implement an automatic conversion. Instead, Simple Injector will halt the resolution process and throw an exception.

A common reason leading to this situation is through the use of *Assembly.LoadFile*, instead of using `Assembly.Load <https://msdn.microsoft.com/en-us/library/x4cw969y(v=vs.110).aspx>`_ or in an ASP.NET environment `BuildManager.GetReferencedAssemblies() <https://msdn.microsoft.com/en-us/library/system.web.compilation.buildmanager.getreferencedassemblies(v=vs.110).aspx>`_. *Assembly.Load* returns an already loaded assembly even if a different path is specified, *Assembly.LoadFile* does not (depending on the current assembly loading context), it loads a duplicate instance.

So what do you need to do?
===========================

Avoid using *Assembly.LoadFile* and use *Assembly.Load* as shown in the following example:

.. code-block:: c#

    Assembly assembly = Assembly.Load(AssemblyName.GetAssemblyName("c:\..."));
    
For an ASP.NET application use *BuildManager.GetReferencedAssemblies* as shown in the following example:

.. code-block:: c#

    var assemblies = BuildManager.GetReferencedAssemblies().Cast<Assembly>();
                  
The *GetReferencedAssemblies* method will load all referenced assemblies located within the web application's /bin folder of the ASP.NET temp directory where the referenced assemblies are shadow copied by default.
