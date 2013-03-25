# capistrano-virtualenv

a capistrano recipe to deploy python apps with [nodeenv](http://pypi.python.org/pypi/nodeenv).

## Installation

Add this line to your application's Gemfile:

    gem 'capistrano-nodeenv'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install capistrano-nodeenv

## Usage

This recipe will create 2 kind of nodeenv during `deploy` task.

* shared nodeenv
  * created in `shared_path` after `deploy:setup`
  * common libraries are installed here.
* release nodeenv
  * created in `release_path` after `deploy:finalize_update`
  * per-release nodeenv that can be rolled back.

To deploy your application with `nodeenv`, add following in you `config/deploy.rb`.

    # in "config/deploy.rb"
    require 'capistrano-nodeenv'

Following options are available to manage your nodeenv.

 * `:nodeenv_bootstrap_python` - the python executable which will be used to craete nodeenv. by default "python".
 * `:nodeenv_current_path` - nodeenv path under `:current_path`.
 * `:nodeenv_current_node` - node path under `:nodeenv_current_path`.
 * `:nodeenv_npm_options` - options for `npm`.
 * `:nodeenv_install_packages` - apt packages dependencies for python.
 * `:nodeenv_npm_install_options` - options for `pip install`.
 * `:nodeenv_release_path` - nodeenv path under `:release_path`.
 * `:nodeenv_release_python` - python path under `:nodeenv_release_path`.

 * `:nodeenv_requirements_file` - the path to the directory that include package.json with dependencies.
 * `:nodeenv_script_url` - the download URL of `nodeenv.py`.
 * `:nodeenv_shared_path` - nodeenv path under `:shared_path`.
 * `:nodeenv_shared_node` - node path under `:nodeenv_shared_path`

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Author

Authors of capistrano-virtualenv:
- YAMASHITA Yuu (https://github.com/yyuu)
- Geisha Tokyo Entertainment Inc. (http://www.geishatokyo.com/)

capistrano-nodeenv:
- Alexandr Lispython (http://github.com/Lispython)

## License

MIT
