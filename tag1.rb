#!/usr/bin/ruby

require 'find'
require 'json'
require 'xcodeproj'

#Check if root path exist
unless ARGV[0]
    puts "Missing project location path."
    exit
end
root_path = ARGV[0]

#Find projects & schemes
project_paths_schemes = []
Find.find("#{root_path}") do |p|
    if File.extname(p) == ".xcodeproj"
        project = Xcodeproj::Project.open(p)
        project.recreate_user_schemes
        paths_schemes = {}
        paths_schemes["path"] = p
        paths_schemes["schemes"] = Xcodeproj::Project.schemes(p)
        project_paths_schemes << paths_schemes
        Find.prune
    end
end

#Find workspaces & schemes
workspace_paths_schemes = []
Find.find("#{root_path}") do |p|
    if File.extname(p) == ".xcworkspace"
        paths_schemes = {}
        paths_schemes["path"] = p
        #schemes method of workspace doesn't find inner project schemes. example : xcodeproje inside xcodeproje
        paths_schemes["schemes"] = Xcodeproj::Workspace.new_from_xcworkspace(p).schemes.keys
        workspace_paths_schemes << paths_schemes
        Find.prune
    elsif File.extname(p) == ".xcodeproj"
        Find.prune
    end
end

#Combine
project_workspace_paths = {};
project_workspace_paths['projects'] = project_paths_schemes
project_workspace_paths['workspaces'] = workspace_paths_schemes

puts project_workspace_paths.to_json
