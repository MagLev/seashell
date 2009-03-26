#
# SeaShell
#
# Capistrano deployment recipes for seaside platforms
#
# Author: Andreas Brodbeck, mindclue gmbh, www.mindclue.ch
# Licence: MIT (see LICENSE file)
#

#
# Tasks for deployment
#

namespace :deploy do


  # Loads the version +monticello_file+ from the repository
  def install_monticello_version(monticello_file)

    monticello_load_script = <<-SMALLTALK
      | httpRepository version rg |
      MCPlatformSupport autoMigrate: true.
      httpRepository := MCHttpRepository
          location: '#{monticello_repository_url}'
          user: '#{monticello_repository_user}'
          password: '#{monticello_repository_password}'.
      "pick up the repository if it's already
       in default repository group"
      MCRepositoryGroup default repositoriesDo: [:rep |
          rep = httpRepository ifTrue: [ httpRepository := rep ]].
      version := httpRepository loadVersionFromFileNamed: '#{monticello_file}'.
      version load.
      rg := version workingCopy repositoryGroup.
      rg addRepository: httpRepository.
      System commitTransaction.
    SMALLTALK

    # Debug: Show the script:
    # Capistrano::CLI.ui.say(monticello_load_script)

    if Capistrano::CLI.ui.agree("Really load version #{monticello_file}?")
      run_gs(monticello_load_script)
      say "Version #{monticello_file} loaded"
    else
      say "Loading aborted"
    end
  end

  desc 'Deploy a version from monticello'
  task :default do
    # Ask for Monticello version (show only latest 50)
    monticello_file = Capistrano::CLI.ui.choose(*get_monticello_versions[0..50])
    install_monticello_version(monticello_file)
  end
  
  desc 'Deploy the latest version from monticello repository'
  task :latest do
    monticello_file = get_monticello_versions.first
    install_monticello_version(monticello_file)
  end


  desc 'Deploys the static files from your seaside FileLibrary to disk'
  task :write_file_libraries_to_disk do
    # TODO
    # WAFileLibrary deployFiles.
  end

  desc 'Switches the application to deployment Mode'
  task :set_deployment_mode do
                 
    script = <<-SMALLTALK
      (WADispatcher default entryPointAt: 'busana') preferenceAt: #deploymentMode put: true.
    SMALLTALK
    
    run_gs(script)
  end

  # Tasks related to setting up the environment
  namespace :setup do

    desc 'Sets up the folder structure for the project'
    task :default do
      create_folders
      copy_initial_repository
      create_switch_script
    end

    # Create used folders
    task :create_folders do
      run "mkdir -p #{path_application} #{path_data} #{path_data}/backups #{path_application}/logs #{path_application}/web_root"
      run "mkdir -p /etc/lighttpd/seaside_applications"
    end

    task :copy_initial_repository do
      run "cp -n /opt/gemstone/product/bin/extent0.seaside.dbf #{path_data}/extent0.dbf"
    end

    # Creates convenience shell script for switching projects when working on the server
    task :create_switch_script do
      switch_shell_script = ''
      for key, value in default_environment
        switch_shell_script << "export #{key}=\"#{value}\"\n"
      end

      put switch_shell_script, "#{path_application}/switch_environment"
    end

    desc 'Checks all kind of stuff on the server, to ensure things will work.'
    task :check do
      # TODO, check that:
      # - SHR_PAGE_CACHE_SIZE_KB should be half of the RAM, but never bigger! see in /opt/gemstone/product/seaside/data/system.conf
      # - Line GEMS="9001 9002 9003" still in runSeasideGems?
      # - Check that lighty is configured to include the vhost-configs (include_shell "cat seaside_applications/*.conf")
    end

  end

  desc 'Copy files to the server.'
  task :upload do
    files = (ENV["FILES"] || "").split(",").map { |f| Dir[f.strip] }.flatten
    abort "Please specify at least one file or directory to update (via the FILES environment variable)" if files.empty?

    files.each { |file| top.upload(file, File.join(path_application, file)) }
  end

end


