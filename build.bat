@ECHO OFF

del build\html\.buildinfo /f
del build\doctrees\*.doctree /f

del source\conf.py
copy source\conf.py.local source\conf.py

REM Command file for Sphinx documentation

if "%SPHINXBUILD%" == "" (
	set SPHINXBUILD=sphinx-build
)
set BUILDDIR=build
set ALLSPHINXOPTS=-d %BUILDDIR%/doctrees %SPHINXOPTS% source
set I18NSPHINXOPTS=%SPHINXOPTS% source
if NOT "%PAPER%" == "" (
	set ALLSPHINXOPTS=-D latex_paper_size=%PAPER% %ALLSPHINXOPTS%
	set I18NSPHINXOPTS=-D latex_paper_size=%PAPER% %I18NSPHINXOPTS%
)

%SPHINXBUILD% -b html %ALLSPHINXOPTS% %BUILDDIR%/html
if errorlevel 1 exit /b 1
echo.
echo.Html build finished. The HTML pages are in %BUILDDIR%/html.

del source\conf.py
copy source\conf.py.master source\conf.py