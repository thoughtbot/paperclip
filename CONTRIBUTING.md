Contributing
============

We love pull requests. Here's a quick guide:

1. Fork the repo.

2. Run the tests. We only take pull requests with passing tests, and it's great
to know that you have a clean slate: `bundle && rake`

3. Add a test for your change. Only refactoring and documentation changes
require no new tests. If you are adding functionality or fixing a bug, we need
a test!

4. Make the test pass.

5. Push to your fork and submit a pull request.

At this point you're waiting on us. We like to at least comment on, if not
accept, pull requests within three business days (and, typically, one business
day). We may suggest some changes or improvements or alternatives.

Some things that will increase the chance that your pull request is accepted,
taken straight from the Ruby on Rails guide:

* Use Rails idioms and helpers
* Include tests that fail without your code, and pass with it
* Update the documentation, the surrounding one, examples elsewhere, guides,
  whatever is affected by your contribution

Running Tests
-------------

Paperclip uses [Appraisal](https://github.com/thoughtbot/appraisal) to aid
testing against multiple version of Ruby on Rails. This helps us to make sure
that Paperclip performs correctly with them.

### Bootstrapping your test suite:

    bundle install
    bundle exec rake appraisal:install

This will install all the required gems that requires to test against each
version of Rails, which defined in `gemfiles/*.gemfile`.

### To run a full test suite:

    bundle exec rake

This will run Test::Unit and Cucumber against all version of Rails

### To run single Test::Unit or Cucumber test

You need to specify a `BUNDLE_GEMFILE` pointing to the gemfile before running
the normal test command:

    BUNDLE_GEMFILE=gemfiles/3.2.gemfile ruby -Itest test/schema_test.rb
    BUNDLE_GEMFILE=gemfiles/3.2.gemfile cucumber features/basic_integration.feature

Syntax
------

* Two spaces, no tabs.
* No trailing whitespace. Blank lines should not have any space.
* Prefer &&/|| over and/or.
* MyClass.my_method(my_arg) not my_method( my_arg ) or my_method my_arg.
* a = b and not a=b.
* Follow the conventions you see used in the source already.

And in case we didn't emphasize it enough: we love tests!
