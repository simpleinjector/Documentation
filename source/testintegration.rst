=========================
Testing Integration Guide
=========================

One of the consequences of the use of Dependency Injection is that the creation of dependencies is postponed to *the last responsible moment.* This means that you push the burden of creating the dependencies up as long as possible. But somewhere in the application, those dependencies need to be created.

This place where dependencies are composed is called the `Composition Root <https://freecontent.manning.com/dependency-injection-in-net-2nd-edition-understanding-the-composition-root/>`_. For your running application, the Composition Root will likely be the application's `Main` method, or at least somewhere close the application's startup path. The :ref:`Console Integration Guide <consoleintegration>` contains examples of how your Composition Root might look like when developing a Console application.

Unit Testing Integration Guide
==============================

When writing unit tests, each unit test itself acts as a Composition Root. This means that the unit test itself (or a method it calls) is itself responsible of composition of the class that it needs to test. This means that when writing unit tests, you don't use a DI Container. Instead, you wire the required dependencies manually.

.. container:: Note

    **IMPORTANT:** Unit tests don't use a DI Container; they hand-wire the dependencies of the thing you're testing.

The following code snippet demonstrates this:

.. code-block:: c#

    [Fact]
    public void SimpleMethodToTest_Shall_ReturnPlus1()
    {
        // Arrange
        int input = 1;
        int expectedResult = 2;

        var sut = new AgentProvisioningServiceHelper(
            new FakeExcelParser(),
            new FakeSupervisorDbContext(),
            new FakeSchedulerNoTrackingDbContext());

        // Act
        var actualResult = sut.SimpleMethodToTest(input);

        // Assert
        Assert.Equal(expectedResult, actualResult);
    }

This this example, the test method is itself responsible for the creation of the so-called System Under Test (SUT) or simply "whatever thing we're testing." In the example we're testing the `AgentProvisioningServiceHelper` and the test method creates an instance manually.

This means that composition is no longer postponed, and no longer pushed up. Dependencies of the SUT are not injected into the test method nor its containing class. Although technically, some Unit Testing frameworks would allow you to intercept the way test classes are created, letting the test framework supply the dependencies often makes little sense, because the unit test itself needs to have control over the exact dependencies being created. The test not only knows what the *exact types* of the dependencies should be (i.e. typically some sort of fake implementations), but also needs to configure those (fake) dependencies or query their results to assert the correctness of the test.

This doesn't mean though, that the test method can't delegate the creation of the SUT to a helper or factory method; it certainly can and should if this means that its test class becomes more `Readable, Trustworthy, or Maintainable <https://osherove.com/blog/2009/12/31/rtm-ready-tests.html>`_.

The methods of the test class could, for instance, extract the creation of the SUT into the following factory method:

.. code-block:: c#

    private AgentProvisioningServiceHelper CreateSut(
        IExcelParser excelParser = null,
        SupervisorDbContext supervisorDbContext = null,
        SchedulerNoTrackingDbContext schedulerDbContext = null)
    {
        return new AgentProvisioningServiceHelper(
            excelParser ?? new FakeExcelParser(),
            supervisorDbContext ?? new FakeSupervisorDbContext(),
            schedulerDbContext ?? new FakeSchedulerNoTrackingDbContext());
    }

The following test method makes use of the previous `CreateSut` factory method, where it only supplies one dependency. The other two dependencies are not supplied, allowing the `CreateSut` method to create the default dependencies allowing the SUT to be created in a valid state:

.. code-block:: c#

    [Fact]
    public void Parser_should_always_be_called()
    {
        // Arrange
        var parser = new FakeExcelParser();

        AgentProvisioningServiceHelper sut = this.CreateSut(excelParser: parser);

        // Act
        sut.SimpleMethodToTest(0);

        // Assert
        Assert.IsTrue(parser.GotCalled);
    }

In this test, only the `ExcelParser` is supplied, because it is explicitly queried during the test. The other two dependencies will be supplied with a default (probably fake) implementation by the `CreateSut` method. By letting `Parser_should_always_be_called` supply only the dependencies it is interested in, you gain the following advantages:

* You remove noise from the test method, making the method more readable.
* You prevent sweeping changes through the test class in case the SUT gets another dependency. In an ideal case only the `CreateSut` factory needs to be changed, and new tests written. Existing tests don't need to be updated, thus making the test class more maintainable.

Another option is to move the responsibility of the creation of the SUT to a Mocking library and if required, Simple Injector can be configured to become an `Auto-Mocking container <https://github.com/simpleinjector/SimpleInjector/issues/290#issuecomment-243244930>`_, but even then, its the unit test that's in control over the composition of the SUT not the unit testing framework.

Unit tests verify a small unit of the code and run in high isolation. They typically only test one or a small subset of classes in the system; the rest of the code is replaced with stand ins.

This is contrast with integration testing, where a single test often touches a much larger part of the code base and where the use of your DI Container does become much more common.

Integration Testing Integration Guide
=====================================

While writing unit tests, dependencies are typically hand-wired, as shown above. When writing integration tests, on the other hand, the number of objects involved in the test is typically larger and needs to resemble the structure of objects that is composed in the production application with sometimes just a few dependencies replaced. Letting a single test method or test class recreate the complete object structure manually would often be cumbersome and error prone. A change in the application's object structure could bubble through many tests and would easily result in a maintenance nightmare.

That's why, when it comes to writing integration tests, it's common to try to reuse the same object composition logic that the running application's Composition Root uses. When you use a DI Container to compose the application's object graphs, this typically means reusing those same DI Container registrations.

An integration test would reuse the same DI Container's configuration, replace a few dependencies required for the integration test to run, resolve the class under test, and invoke one of its methods. But still, an integration test wouldn't get those dependencies injected from the outside, as it likely needs some control over what is created. The integration test is still its own Composition Root, even though it delegates part of the object composition to a DI Container.

Here's an example for an integration test:

.. code-block:: c#

    [Fact]
    public void Some_integration_test()
    {
        // Arrange
        int input = 1;
        int expectedResult = 2;

        // Mock object
        var parser = new FakeExcelParser();

        // Create a valid container to resolve object graphs from
        Container container = TestBootstrapper.BuildContainer();

        // Configure it especially for this test
        container.RegisterInstance<IExcelParser>(parser);

        // Resolve te fully initialized SUT from the DI Container
        var sut = container.GetInstance<AgentProvisioningServiceHelper>();

        // Act
        var actualResult = sut.SimpleMethodToTest(input);

        // Assert
        Assert.Equal(expectedResult, actualResult);
    }

This integration test uses a `TestBootstrapper` class that might be shared across integration tests:

.. code-block:: c#

    public static class TestBootstrapper
    {
        public static Container BuildContainer()
        {
            var container = new Container();
            
            // PERF: Disable auto-verification 
            container.Options.EnableAutoVerification = false;
        
            // Request a fully configured DI Container instance from the
            // actual application. This ensures that the integration test
            // runs using the exact same object graphs as the final application.
            RealApplication.Bootstrapper.InitializeContainer(container);

            // Replace dependencies that should never be used during the
            // integration tests.
            container.Options.AllowOverridingRegistrations = true;
            container.Register<IHardDiskFormatter, FakeDiskFormatter>();
            container.Register<ISmsSender, FakeSmsSender>();
            container.Register<IPaymentProvider, FakePaymentProvider>();

            // PERF: Don't call Verify()
            return container;
        }
    }

This is very different from running unit tests, where there is a high level of isolation. But even though an integration test runs a much larger part of the code base, you want each test to run in isolation. This typically means that each test should get its own Container instance, even though in the final application all code shares a single Container instance. The high level of isolation between tests makes them more trustworthy and makes it easier to have different tests replace different registrations.

Integration Testing Performance Considerations
==============================================

Because of the desired level of isolation, each integration test should, ideally, get its own DI Container instance. But registering components and verifying the container can take a considerable amount of time, especially when the Container contains a large set of registrations. Especially the verification process can take a considerable amount of time and resources. During verification, Simple Injector tries to resolve all registered components, which will cause the creation of expression trees, generation of Intermediate Language (IL) code, and the JIT compilation of that IL into machine code.

That's a lot of overhead in case the integration test is only interested in a small part of the application's entire object structure. Especially when your application contains a large set of integration tests and a large set of application components.

To mitigate this, container verification should be prevented when running integration tests. This can be done by:

* Disabling the container's auto-verification feature.
* Preventing any calls to `Container.Verify()`.

The previously shown `TestBootstrapper` class demonstrates this. Here's a shortened version of that again, where the most important part is the call to `Options.EnableAutoVerification`:

.. code-block:: c#

    public static class TestBootstrapper
    {
        public static Container BuildContainer()
        {
            var container = new Container();
            
            // PERF: Disable auto-verification 
            container.Options.EnableAutoVerification = false;
        
            RealApplication.Bootstrapper.InitializeContainer(container);

            ...
            
            // PERF: Don't call Verify()
            return container;
        }
    }

For very large applications, the possibility exists that just disabling auto-verification is not enough to get a high-enough Throughput on your tests. In those cases, there are other options to consider, such as:

* Construct a per-test Container instance that contains a subset of that of the full application
* Use a single, global Container instance, used by all integration tests

Both options have their own set of disadvantages, and are typically tricky to implement. Below we'll give a proof-of-concept example for both, but keep in mind that in practice these solutions might be cumbersome to maintain.

That means that before using either of these approaches, also consider the following solutions:

* Differentiate unit tests from integration tests, so that developers can typically run just the unit tests, and only run all integration tests before a commit.
* Run integration tests on multiple threads. Many testing frameworks allow tests to be run on all the machine's processors, which can considerably shorten the amount of time required to run those tests.
* Run integration tests on a build server.
* Split integration tests into groups that can be ran simultaneously on multiple machines.
* Split the application itself into multiple smaller parts; a more micro service-oriented approach. This reduces the number of integration tests per service and reduces the time to run that subset of tests.

**Construct a per-test Container instance that contains a subset of that of the full application**

The application's bootstrapper can define a list of application features, for instance using an `ApplicationFeatures` enum class:

.. code-block:: c#

    public enum ApplicationFeature
    {
        FeatureA,
        FeatureB,
        FeatureC,
        ..
        FeatureN
    }

This allows an integration test to supply the features for which container should be built:

.. code-block:: c#

    [Fact]
    public void Some_integration_test()
    {
        var container = TestBootstrapper.BuildContainer(ApplicationFeature.FeatureA);

        var sut = container.GetInstance<AgentProvisioningServiceHelper>();

        ...
    }

The application's `InitializeContainer` method could in this case look like this:

.. code-block:: c#

    public static void InitializeContainer(
        Container container, params ApplicationFeature[] features)
    {
        AddCoreDependencies(container);
        
        if (features.Contains(ApplicationFeature.FeatureA))
            AddFeatureA(container);
        if (features.Contains(ApplicationFeature.FeatureB))
            AddFeatureB(container);
        ...
        
        AddCrossCuttingConcerns(container);
    }

There are, however, a few consequences or downsides to this approach:

* It can be hard to split the Composition Root in a set of distinct features.
* Even if you can define a set of features, filtering out classes of other parts can be difficult, especially when you're using :ref:`Batch Registration <Automatic-Batch-registration>`, and even so, it might cause quite a big refactoring effort. What you can do, for instance, is mark classes with a `[Feature(ApplicationFeature.FeatureA)]` attribute to allow them to be registered or skipped. Or place a class in namespace named after the feature, such as `MyApplication.BusinessLayer.Commands.FeatureA`.

**Use a single, global Container instance, used by all integration tests**

When there is too much overhead in creating a Container instance per test, one global Container instance for all tests to reuse, similar to how the final application is using a single Container instance. Although this can give a considerable performance boost, in practice this can be quite tricky, especially when separate tests require different fake dependencies. As you can see from the code samples below, this can take a considerable amount of adjustments to the test suite and the Composition Root.

At the very least it requires scoped proxy implementations that can be configured to forward calls to test-specific fake implementations. The Container's `Scope` can be used as holder for test-specific fakes.

For instance, an integration test could use a specially crafted version of the `TestBootstrapper` to allow reusing the same container instance. The following code sample demonstrates this:

.. code-block:: c#

    [Fact]
    public void Some_integration_test()
    {
        // Arrange
        int input = 1;
        int expectedResult = 2;

        // Mock object
        var parser = new FakeExcelParser();
        var sender = new FakeSmsSender();

        // Create a valid scope to resolve object graphs from
        using (var scope = TestBootstrapper.BuildContainer(new DependencyReplacer()
            .With<IExcelParser>(parser)
            .With<ISmsSender>(sender)))
        {
            // Resolve the SUT from the DI Container
            var sut = scope.GetInstance<AgentProvisioningServiceHelper>();

            // Act
            var actualResult = sut.SimpleMethodToTest(input);

            // Assert
            Assert.Equal(expectedResult, actualResult);
        }
    }
    
The following code listing demonstrates a possible implementation of the `TestBootstrapper`:
    
.. code-block:: c#

    public static class TestBootstrapper
    {
        private static Container container;
        
        // Static ctor ensures only one container is created
        static TestBootstrapper()
        {
            container = new Container();
            container.Options.DefaultScopedLifestyle = new AsyncScopedLifestyle();
            
            RealApplication.Bootstrapper.InitializeContainer(container);
            
            container.Options.AllowOverridingRegistrations = true;
            
            // All replaceable dependencies must be scoped.
            container.Register<ISmsSender, SmsSenderProxy>(Lifestyle.Scoped);
            // ...
            
            container.Verify();
        }
        
        public static ContainerScope BuildContainer(
            DependencyReplacer replacer = null)
        {
            replacer = replacer ?? new DependencyReplacer();
        
            var scope = AsyncScopedLifestyle.BeginScope(container);
            
            replacer.Apply(container);
        
            return new ContainerScope(container, scope);
        }
    }

The `TestBootstrapper` creates only one `Container` instance inside its static constructor. This instance is cached indefinitely. All dependencies that need to be mocked inside integration tests will be replaced with a proxy implementation as shown with the `SmsSenderProxy`. These proxies need to be scoped to be replaced on a per-test basis. Each integration test will run in its own `Scope`, just like how a web request will get its own scope.

The `BuildContainer` method can be supplied with a `DependencyReplacer`. This is a list of all the dependencies that must be replaced. The following listing shows `DependencyReplacer`:

 .. code-block:: c#
       
    public class DependencyReplacer
    {
        private List<(Type ServiceType, object Instance)> Dependencies = new();

        public DependencyReplacer With<T>(T instance)
        {
            this.Dependencies.Add((typeof(T), instance));
            return this;
        }

        public void Apply(Container container)
        {
            foreach (var dependency in this.Dependencies)
            {
                var reg = container.GetRegistration(dependency.ServiceType, true);

                object instance = reg.GetInstance();

                var proxy = instance as IDependencyProxy;

                if (proxy is null) Assert.Fail(
                    $"{instance} does not implement IDependencyProxy");

                if (reg.Lifestyle != Lifestyle.Scoped) Assert.Fail(
                    "{instance} is not registered as scoped.");

                proxy.Set(dependency.Instance);
            }
        }
    }
    
The `BuildContainer` method returns a `ContainerScope` helper method. This is a wrapper around the Simple Injector `Container` and its active `Scope` for that test. It allows resolving from the container, while also disposing of the scope at the end of the test:
    
 .. code-block:: c#
    
    public sealed class ContainerScope : IDisposable
    {
        public readonly Container Container;
        public readonly Scope Scope;
    
        public ContainerScope(Container container, Scope scope)
        {
            this.Container = container;
            this.Scope = scope;
        }
        
        public T GetInstance<T>() where T : class =>
            this.Container.GetInstance<T>();
        
        public void Dispose() => this.Scope.Dispose();
    }

In the example an `ISmsSender` is registered with an `SmsSenderProxy` implementation. The `DependencyReplacer` code snippet shows as custom `IDependencyProxy` interface that proxy classes must implement for an integration test to supply its own dependencies. Below is the `IDependencyProxy` definition and the `SmsSenderProxy` implementation:

.. code-block:: c#

    public interface IDependencyProxy
    {
        void Set(object instance);
    }
    
    public sealed class SmsSenderProxy : ISmsSender, IDependencyProxy
    {
        private ISmsSender realSender = new FakeSmsSender();
        
        void ISmsSender.Send(string message) =>
            this.realSender.Send(message);
            
        void IDependencyProxy.Set(object sender) =>
            this.realSender = (ISmsSender)sender;
    }

The main function of the proxy class is to forward an incoming call to a default stub/fake dependency, which can be replaced by an interested integration test with a fake implementation of its bidding. Because the `realSender` property contains the `SmsSenderProxy`'s state, it's important for this proxy to be registered as `Scoped`.

A refactoring to the use of a single Container instance can have quite some impact on the application. Using the previous code as an example, let's say that in the production setting `ISmsSender` and its consumers are configured as `Singleton`, and the consumers are singletons because of the state they contain. In this new model, `SmsSenderProxy`, through the registration for `ISmsSender` must be `Scoped` and, therefore, also the consumers of `ISmsSender`. This might impact their design, because of their statefulness. In other words, care must be taken if this route of one single test container is pursued.
