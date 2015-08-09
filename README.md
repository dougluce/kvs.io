Version 0.1

Requires zeromq. To install on OSX:

    brew install zeromq

Development also expects growlnotify to be available:

    brew install Caskroom/cask/growlnotify

You can then run tests with:

    npm test

Nodemon will re-run tests whenever it detects a change in a source file:

    npm run testmon

Running individual LiveScript utilities requires that you put the lsc
binary on your path:

    export PATH=$(npm bin):$PATH

When running without specifying a value for NODE_ENV (the default),
tests are run locally and in isolation: an in-memory fake Riak is
used.  When running with NODE_ENV=test, the tests attempt to use a
locally-run Riak server listening on the standard port.  Any fixtures
that are required are loaded before test run.

All tests should be sure to clean up after themselves.

