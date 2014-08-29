=================
Integration Guide
=================

The *Simple Injector* library can be used in a wide range of .NET technologies, both server side as client side. Jump directly to to the integration page for the application framework of your choice. When the framework of your choice is not listed, doesn't mean it isn't supported, but just that we didn't have the time write it :-)

.. toctree::
    :maxdepth: 1

	ASP.NET MVC <mvcintegration>
	ASP.NET Web API <webapiintegration>
	ASP.NET Web Forms <webformsintegration>
	Windows Forms <windowsformsintegration>
	WCF <wcfintegration>
	WPF and Silverlight <wpfintegration>

Besides integration with standard .NET technologies, Simple Injector can be integrated with a wide range of other technologies. Here are a few links to help you get started quickly:

.. toctree::
    :maxdepth: 1

	RavenDB <https://stackoverflow.com/questions/10940988/how-to-configure-simple-injector-ioc-to-use-ravendb>
	SignalR <https://stackoverflow.com/questions/10555791/using-simpleinjector-with-signalr>
	Fluent Validations <https://stackoverflow.com/questions/9984144/what-is-the-correct-way-to-register-fluentvalidation-with-simpleinjector>
	PetaPoco <https://simpleinjector.codeplex.com/discussions/283850>
	T4MVC <t4mvc>
	Quartz.NET <https://stackoverflow.com/questions/14562176/constructor-injection-with-quartz-net-and-simple-injector>
	Membus <https://stackoverflow.com/questions/16123641/membus-and-ioc-simpleinjector-wiring-command-handlers-automatically-by-interfa>
	Web Forms MVP <https://stackoverflow.com/questions/15123515/pass-runtime-value-to-constructor-using-simpleinjector>
	Nancy <https://simpleinjector.codeplex.com/discussions/541398>
	Castle DynamicProxy Interception <https://stackoverflow.com/questions/24513530/using-simple-injector-with-castle-proxy-interceptor>

Here is guidance about some general patterns:

.. toctree::
    :maxdepth: 1

	Unit of Work pattern <https://stackoverflow.com/questions/10585478>
	Multi-tenant applications <https://simpleinjector.codeplex.com/discussions/434951>