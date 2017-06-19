# frozen_string_literal: true

require 'xcodeproj'

module Xcodeproj
  class Workspace
    def library_to_targert_map
      map = {}
      file_references.map do |file_ref|
        project = Xcodeproj::Project.open(file_ref.path)
        map.merge!(project.library_to_targert_map)
      end
      map
    end

    def find_target(project_name, target_name)
      projects.each do |project|
        if project.root_object.name == project_name
          target = project.find_target(target_name)
          return target if target
        end
      end
      nil
    end

    def projects
      file_references.map do |file_ref|
        project = Xcodeproj::Project.open(file_ref.path)
        project.workspace = self
        project
      end
    end
  end

  class Project
    attr_accessor :workspace

    def library_to_targert_map
      map = {}
      targets.each do |target|
        if target.isa == 'PBXNativeTarget' && target.product_type == 'com.apple.product-type.library.static'
          product = target.product_reference
          map[product.path] = target
        end
      end
      # root_object.project_references.each { |remote_project_ref|
      #   remote_project = Project.open(remote_project_ref[:project_ref].real_path)
      #   map.merge!(remote_project.library_to_targert_map)
      # }
      map
    end

    def find_target(target_name)
      targets.find { |target| target.name == target_name }
    end

    HEADER_EXTENSIONS = %w[.h .hpp].freeze
    def header_files
      main_group.recursive_children.select { |g| g.path && HEADER_EXTENSIONS.include?(File.extname(g.path)) }
    end

    module Object
      class AbstractTarget
        def dependent_targets(workspace)
          deps = Set.new
          dependencies.each do |dependency|
            proxy = dependency.target_proxy
            remote_target = proxy.proxied_object
            deps << remote_target
            deps += remote_target.dependent_targets(workspace)
          end
          deps
        end
      end

      class PBXNativeTarget
        def dependent_targets(workspace)
          deps = super(workspace)

          if workspace
            phase = frameworks_build_phase
            phase.files_references.each do |file|
              next unless file.source_tree == 'BUILT_PRODUCTS_DIR'
              target = workspace.library_to_targert_map[file.path]
              if target
                deps << target
                deps += target.dependent_targets(workspace)
              end
            end
          end

          deps
        end

        def unique_name
          "#{project.root_object.name}-#{name}"
        end
      end

      class PBXContainerItemProxy
        def remote_target
          container_portal_object.targets.find { |target| target.product_reference == proxied_object }
        end
      end
    end
  end
end
