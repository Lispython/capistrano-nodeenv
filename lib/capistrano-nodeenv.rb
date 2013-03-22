require "capistrano-nodeenv/version"
require "capistrano/configuration/actions/file_transfer_ext"
require "uri"


module Capistrano
  module Nodeenv
    # Your code goes here...
        def self.extended(configuration)
      configuration.load {
        namespace(:nodeenv) {
          _cset(:nodeenv_version, nil)
          _cset(:nodeenv_jobs, 4)
          _cset(:nodeenv_verbose, true)
          _cset(:nodeenv_use_system, false) # controls whether nodeenv should be use system packages or not.

          _cset(:nodeenv_script_url, 'https://raw.github.com/ekalinin/nodeenv/master/nodeenv.py')
          _cset(:nodeenv_script_file) {
            File.join(shared_path, 'nodeenv', File.basename(URI.parse(nodeenv_script_url).path))
          }
          _cset(:nodeenv_bootstrap_python, 'python') # the python executable which will be used to craete nodeenv

          # Make installation command
          # execute downloaded nodeenv.py
          _cset(:nodeenv_cmd) {
            [
              nodeenv_bootstrap_python,
              nodeenv_script_file,
              nodeenv_options,
            ].flatten.join(' ')
          }

          _cset(:nodeenv_requirements_file) { # secondary package list
            File.join(release_path, 'node_requirements.txt')
          }
          _cset(:nodeenv_options) {
            os = ""
            os << "--jobs=#{nodeenv_jobs}"
            os << "--verbose" if nodeenv_verbose
            os << "--node=#{nodeenv_version}" if nodeenv_version
            os << "--requirement=#{nodeenv_requirements_file}" if nodeenv_requeirements_file
            os
          }
          _cset(:nodeenv_npm_options, "")
          _cset(:nodeenv_npm_install_options, [])
          _cset(:nodeenv_npm_package, 'npm')
          _cset(:nodeenv_requirements, []) # primary package list

          _cset(:nodeenv_build_requirements, {})
          _cset(:nodeenv_install_packages, []) # apt packages

          ## shared nodeenv:
          ## - created in shared_path
          ## - to be used to share libs between releases
          _cset(:nodeenv_shared_path) {
            File.join(shared_path, 'nodeenv', 'shared')
          }
          _cset(:nodeenv_shared_node) {
            File.join(nodeenv_shared_path, 'bin', 'node')
          }
          _cset(:nodeenv_shared_npm) {
            File.join(nodeenv_shared_path, 'bin', 'npm')
          }

          _cset(:nodeenv_shared_npm_cmd) {
            [
              nodeenv_shared_node,
              nodeenv_share_npm,
              nodeenv_npm_options,
            ].flatten.join(' ')
          }

          ## release nodeenv
          ## - created in release_path
          ## - common libs are copied from shared nodeenv
          ## - will be used for running application
          _cset(:nodeenv_release_path) { # the path where runtime nodeenv will be created
            File.join(release_path, 'vendor', 'nodeenv')
          }
          _cset(:nodeenv_release_node) { # the python executable within nodeenv
            File.join(nodeenv_release_path, 'bin', 'node')
          }
          _cset(:nodeenv_release_npm) {
            File.join(nodeenv_release_path, 'bin', 'npm')
          }
          _cset(:nodeenv_release_npm_cmd) {
            [
              nodeenv_release_node,
              nodeenv_release_npm,
              nodeenv_npm_options,
            ].flatten.join(' ')
          }

          ## current nodeenv
          ## - placed in current_path
          ## - nodeenv of currently running application
          _cset(:nodeenv_current_path) {
            File.join(current_path, 'vendor', 'nodeenv')
          }
          _cset(:nodeenv_current_node) {
            File.join(nodeenv_current_path, 'bin', 'node')
          }

          _cset(:nodeenv_current_npm) {
            File.join(nodeenv_current_path, 'bin', 'npm')
          }
          _cset(:nodeenv_current_npm_cmd) {
            [
              nodeenv_current_python,
              nodeenv_current_npm,
              nodeenv_npm_options,
            ].flatten.join(' ')
          }

          desc("Setup nodeenv.")
          task(:setup, :except => { :no_release => true }) {
            transaction {
              install
              create_shared
            }
          }
          after 'deploy:setup', 'nodeenv:setup'

          desc("Install nodeenv.")
          task(:install, :except => { :no_release => true }) {
            #run("#{sudo} apt-get install #{nodeenv_install_packages.join(' ')}") unless nodeenv_install_packages.empty?
            # Download nodeenv.py file
            dirs = [ File.dirname(nodeenv_script_file) ].uniq()
            run("mkdir -p #{dirs.join(' ')} && ( test -f #{nodeenv_script_file} || wget --no-verbose -O #{nodeenv_script_file} #{nodeenv_script_url} )")
          }

          desc("Uninstall nodeenv.")
          task(:uninstall, :except => { :no_release => true }) {
            run("rm -f #{nodeenv_script_file}")
          }

          task(:create_shared, :except => { :no_release => true }) {
            dirs = [ File.dirname(nodeenv_shared_path) ].uniq()
            cmds = [ ]
            cmds << "mkdir -p #{dirs.join(' ')}"
            cmds << "( test -d #{nodeenv_shared_path} || #{nodeenv_cmd} #{nodeenv_shared_path} )"
            cmds << "#{nodeenv_shared_node} --version && #{nodeenv_shared_npm_cmd} --version"
            run(cmds.join(' && '))
          }

          task(:destroy_shared, :except => { :no_release => true }) {
            run("rm -rf #{nodeenv_shared_path}")
          }

          desc("Update nodeenv for project.")
          task(:update, :except => { :no_release => true }) {
            transaction {
              update_shared
              create_release
            }
          }
          after 'deploy:finalize_update', 'nodeenv:update'

          task(:update_shared, :except => { :no_release => true }) {
            unless nodeenv_requirements.empty?
              top.safe_put(nodeenv_requirements.join("\n"), nodeenv_requirements_file, :place => :if_modified)
            end
            run("touch #{nodeenv_requirements_file} && #{nodeenv_shared_npm_cmd} install #{nodeenv_npm_install_options.join(' ')} -r #{nodeenv_requirements_file}")

            execute = nodeenv_build_requirements.map { |package, options|
              build_options = ( options || [] )
              "#{nodeenv_shared_npm_cmd} install #{nodeenv_npm_install_options.join(' ')} #{build_options.join(' ')} #{package.dump}"
            }
            run(execute.join(' && ')) unless execute.empty?
          }

          task(:create_release, :except => { :no_release => true }) {
            dirs = [ File.dirname(nodeenv_release_path) ].uniq()
            cmds = [ ]
            cmds << "mkdir -p #{dirs.join(' ')}"
            # TODO: turn :nodeenv_use_relocatable true if it will be an official features.
            # `nodeenv --relocatable` does not work expectedly as of nodeenv 1.7.2.
            if fetch(:nodeenv_use_relocatable, false)
              #cmds << "#{nodeenv_cmd} --relocatable #{nodeenv_shared_path}"
              cmds << "cp -RPp #{nodeenv_shared_path} #{nodeenv_release_path}"
            else
              cmds << "( test -d #{nodeenv_release_path} || #{nodeenv_cmd} #{nodeenv_release_path} )"
              cmds << "( test -x #{nodeenv_release_npm} || #{nodeenv_release_easy_install_cmd} #{nodeenv_npm_package} )"
              cmds << "#{nodeenv_release_node} --version && #{nodeenv_release_npm_cmd} --version"
              cmds << "rsync -lrpt -u #{nodeenv_shared_path}/bin/ #{nodeenv_release_path}/bin/" # copy binaries and scripts from shared nodeenv
              cmds << "sed -i -e 's|^#!#{nodeenv_shared_path}/bin/node.*$|#!#{nodeenv_release_path}/bin/node|' #{nodeenv_release_path}/bin/*"
              cmds << "rsync -lrpt #{nodeenv_shared_path}/lib/ #{nodeenv_release_path}/lib/" # copy libraries from shared nodeenv
            end
            run(cmds.join(' && '))
          }
        }
      }
    end
  end
end


if Capistrano::Configuration.instance
  Capistrano::Configuration.instance.extend(Capistrano::Nodeenv)
end
