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
          _cset(:nodeenv_with_npm, true)

          _cset(:nodeenv_script_url, 'https://raw.github.com/ekalinin/nodeenv/e85a806e21d9bb5e417f1c17080964c485332b27/nodeenv.py')
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
            File.join(release_path)
          }
          _cset(:nodeenv_options) {
            os = ""
            os << "--jobs=#{nodeenv_jobs} "
            os << "--verbose " if nodeenv_verbose
            os << "--node=#{nodeenv_version} " if nodeenv_version
            #os << "--with-npm" if nodeenv_with_npm
            #os << "--requirement=#{nodeenv_requirements_file}" if nodeenv_requirements_file
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
              nodeenv_shared_npm,
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
                cmds = ["touch #{nodeenv_requirements_file}"]
                cmds << ". #{nodeenv_shared_path}/bin/activate"
                cmds << "cat #{nodeenv_requirements_file}/package.json | python -c 'import json,sys;obj=json.load(sys.stdin);print \"\\r\\n\".join([k+\"@\"+v for k, v  in obj.get(\"dependencies\", {}).items()])' | awk '{ print \"npm install -g #{nodeenv_npm_install_options.join(' ')} \"$0}' | bash"
                cmds << "deactivate_node"
                #run( &&  && #{nodeenv_shared_npm_cmd} install -g #{nodeenv_npm_install_options.join(' ')} #{nodeenv_requirements_file}")
                invoke_command(cmds.join(' && '))

            puts("Updated requirements")
            execute = nodeenv_build_requirements.map { |package, options|
              build_options = ( options || [] )
              ". #{nodeenv_shared_path}/bin/activate && #{nodeenv_shared_npm_cmd} install -g #{nodeenv_npm_install_options.join(' ')} #{build_options.join(' ')} #{package.dump} && deactivate_node"
            }
            invoke_command(execute.join(' && ')) unless execute.empty?
          }

          task(:create_release, :except => { :no_release => true }) {
            dirs = [ File.dirname(nodeenv_release_path) ].uniq()
            cmds = [ ]
            cmds << "mkdir -p #{dirs.join(' ')}"

            # Copy nodeenv from shared to release directory
            cmds << "cp -rf #{nodeenv_shared_path} #{nodeenv_release_path}"
            cmds << "sed -i -e 's|#{nodeenv_shared_path}|#{nodeenv_release_path}|g' #{nodeenv_release_path}/bin/activate"
            invoke_command(cmds.join(' && '))
          }
        }
      }
    end
  end
end


if Capistrano::Configuration.instance
  Capistrano::Configuration.instance.extend(Capistrano::Nodeenv)
end
