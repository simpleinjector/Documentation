======================
How to Contribute Code
======================

For any contributions to be accepted you first need to print, sign, scan and email a copy of the `file:CLA <Simple Injector Contributor License Agreement.pdf>`_ to `mailto:cla@simpleinjector.org <mailto:cla@simpleinjector.org>`_

For the moment we request that changes are only made after a `discussion <https://simpleinjector.codeplex.com/discussions>`_ and that each change has a related and approved `issue <https://simpleinjector.codeplex.com/workitem/list/basic>`_. Changes that do not relate to an approved issue may not be accepted.

Once you have completed your changes:

#. Make sure all existing and new unit tests pass.
#. Unit tests must conform to `Roy Osherove's Naming Standards for Unit Tests <http://osherove.com/blog/2005/4/3/naming-standards-for-unit-tests.html>`_ and the  `AAA pattern <http://c2.com/cgi/wiki?ArrangeActAssert>`_ must be documented explicitly in each test.
#. Make sure it compiles in both Debug and Release mode (xml comments are only checked in the release build). 
#. Make sure there are no `StyleCop <https://stylecop.codeplex.com/>`_ warnings {Ctrl + Shift + Y} 
#. Make sure the project can be built using the **build.bat**.
#. Submit a pull request