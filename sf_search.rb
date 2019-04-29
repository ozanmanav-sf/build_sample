require 'find'
require 'json'
require 'xcodeproj'

#Check if root path exist
unless ARGV[0]
    puts "Missing project location path."
    exit 1
end
root_path = ARGV[0]

#Find targets
def get_launchable_target(project)
    project.native_targets.each do |target|
        if target.launchable_target_type?
            return target
        end
    end
    
    return nil
end

def get_bundle_identifier(target)
    return target.build_configuration_list.build_settings(target.build_configuration_list.default_configuration_name)["PRODUCT_BUNDLE_IDENTIFIER"]
end

def get_embedded_and_watch_targets(project, launchable_target)
    targets = []
    embedded_targets = project.embedded_targets_in_native_target(launchable_target)
    embedded_targets.each do |embedded|
        if embedded.extension_target_type?
            targets.push({"name" => embedded,"bundleidentifier" => get_bundle_identifier(embedded)})
            #Watch App
        elsif embedded.product_type.match(/com.apple.product-type.application.watchapp/)
            targets.push({"name" => embedded,"bundleidentifier" => get_bundle_identifier(embedded)})
            embedded_watch_targets = project.embedded_targets_in_native_target(embedded)
            embedded_watch_targets.each do |embedded_watch|
                if embedded_watch.extension_target_type?
                    targets.push({"name" => embedded_watch,"bundleidentifier" => get_bundle_identifier(embedded_watch)})
                end
            end
        end
    end
    
    return targets
end

#Find projects & schemes
project_paths_schemes = []
Find.find("#{root_path}") do |p|
    if File.extname(p) == ".xcodeproj"
        project = Xcodeproj::Project.open(p)
        project.recreate_user_schemes
        paths_schemes = {}
        paths_schemes["path"] = p.split(root_path)[1]
        launchable_target = get_launchable_target(project)
        paths_schemes["bundleidentifier"] = get_bundle_identifier(launchable_target)
        paths_schemes["extensions"] = get_embedded_and_watch_targets(project,launchable_target)
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
        paths_schemes["path"] = p.split(root_path)[1]
        #schemes method of workspace doesn't find inner project schemes. example : xcodeproje inside xcodeproje
        workspace = Xcodeproj::Workspace.new_from_xcworkspace(p)
        workspace.load_schemes(p)
        projects = []
        workspace.file_references.each do |file|
             projects.push(file.path)
        end
        paths_schemes["projects"] = projects
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

puts "$$return_value#{project_workspace_paths.to_json}"
exit 0
