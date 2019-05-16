=================
How to Contribute
=================

For any contributions to be accepted you first need to print, sign, scan and email a copy of the `CLA <https://github.com/simpleinjector/SimpleInjector/raw/master/Simple%20Injector%20Contributor%20License%20Agreement.pdf>`_ to `mailto:cla@simpleinjector.org <mailto:cla@simpleinjector.org>`_

We request that changes are only made after a `discussion <https://simpleinjector.org/community>`_ and that each change has a related and assigned issue. Changes that do not relate to an approved issue may not be accepted. A feature or bugfix branch will be assigned to the issue. Pull requests on an unrelated branch (such as the `master` branch) will not be accepted.

Once you have completed your changes:

#. Follow `10 tips for better Pull Requests <https://blog.ploeh.dk/2015/01/15/10-tips-for-better-pull-requests/>`_.
#. Make sure all existing and new unit tests pass.
#. Unit tests must conform to `Roy Osherove's Naming Standards for Unit Tests <https://osherove.com/blog/2005/4/3/naming-standards-for-unit-tests.html>`_ and the `AAA pattern <https://c2.com/cgi/wiki?ArrangeActAssert>`_ must be documented explicitly in each test.
#. Make sure it compiles in both Debug and Release mode (xml comments are only checked in the release build). 
#. Make sure there are no `StyleCop <https://visualstudiogallery.msdn.microsoft.com/cac2a05b-6eb6-4fa2-95b9-1f8d011e6cae>`_ warnings {Ctrl + Shift + Y}
#. Our maximum line width for code files is 110 characters.
#. Make sure the project can be built using the **build.bat**.
#. Submit one or multiple pull requests (see the above 10 tips)