require 'xcodeproj'
require 'fileutils'
require 'pathname'

module A2OBrew

  REFERENCE_FRAMEWORKS = %w(UIKit Security ImageIO GoogleMobileAds CoreGraphics)
  LINK_FRAMEWORKS = %w(UIKit Security ImageIO AudioToolbox CommonCrypto SystemConfiguration CoreGraphics QuartzCore AppKit CFNetwork OpenGLES Onyx2D CoreText Social AVFoundation)

  class Xcode2Ninja
    def initialize(xcodeproj_path)
      self.xcodeproj_path = xcodeproj_path
    end

    def xcode2ninja(output_dir, target_name = nil, build_config_name = nil)
      unless @xcodeproj_path
        fail Informative, 'Please specify Xcode project.'
      end

      gen_paths = []

      xcodeproj.targets.each do |target|
        next if target_name and target.name != target_name
        target.build_configurations.each do |build_config|
          next if build_config_name and build_config.name != build_config_name
          gen_path = generate_ninja_build(output_dir, xcodeproj, target, build_config)
          gen_paths << gen_path
        end
      end

      gen_paths
    end

    private

    def xcodeproj_path
      unless @xcodeproj_path
        fail Informative, 'Please specify Xcode project.'
      end
      @xcodeproj_path
    end

    def xcodeproj_dir
      unless @xcodeproj_dir
        fail Informative, 'Please specify Xcode project.'
      end
      @xcodeproj_dir
    end

    def xcodeproj_path=(path)
      @xcodeproj_path = path && Pathname.new(path).expand_path
      @xcodeproj_dir = File.dirname(@xcodeproj_path)
    end

    def xcodeproj
      @xcodeproj ||= Xcodeproj::Project.open(xcodeproj_path)
    end

    def generate_ninja_build(output_dir, xcodeproj, target, build_config)
      builds = generate_build_rules(xcodeproj, target, build_config)
      write_ninja_build(output_dir, target, build_config, builds)
    end

    def generate_build_rules(xcodeproj, target, build_config)
      target.build_phases.map do |phase|
        case phase
        when Xcodeproj::Project::Object::PBXResourcesBuildPhase
          resources_build_phase(xcodeproj, target, build_config, phase)
        when Xcodeproj::Project::Object::PBXSourcesBuildPhase
          sources_build_phase(xcodeproj, target, build_config, phase)
        when Xcodeproj::Project::Object::PBXFrameworksBuildPhase
          frameworks_build_phase(xcodeproj, target, build_config, phase)
        when Xcodeproj::Project::Object::PBXShellScriptBuildPhase
          shell_script_build_phase(xcodeproj, target, build_config, phase)
        else
          fail Informative, "Don't support the phase #{phase.class.name}."
        end
      end.flatten.compact
    end

    def write_ninja_build(output_dir, target, build_config, builds)
      unless File.directory?(output_dir)
        FileUtils.mkdir_p(output_dir)
      end

      path = File.join(output_dir, "#{target.name}.#{build_config.name}.ninja.build")
      File.open(path, 'w:UTF-8') do |f|
        f.puts rules(target, build_config)
        f.puts ''
        builds.each do |b|
          f.puts "build #{b[:outputs].join(' ')}: #{b[:rule_name]} #{b[:inputs].join(' ')}"
          variables = b[:variables] || []
          variables.each do |k, v|
            f.puts "  #{k} = #{v}"
          end
          f.puts ''
        end
      end

      path
    end

    def rules(target, build_config)
      # TODO: extract minimum-deployment-target from xcodeproj
      r = <<RULES
rule ibtool_compile
  description = ibtool compile ${out}
  command = ibtool --errors --warnings --notices --module #{target.product_name} --target-device iphone --minimum-deployment-target 9.0 --output-format human-readable-text --compilation-directory `dirname ${out}` ${in}

rule ibtool_link
  description = ibtool link ${out}
  command = ibtool --errors --warnings --notices --module #{target.product_name} --target-device iphone --minimum-deployment-target 9.0 --output-format human-readable-text --link #{resources_dir(target, build_config)} ${in}

rule cc
  description = compile ${source} to ${out}
  command = a2o ${cflags} -c ${source} -o ${out}

rule link
  description = link to ${out}
  command = llvm-link -o ${out} ${in}

rule cp_r
  description = cp -r from ${in} to ${out}
  command = cp -r ${in} ${out}

rule rm
  description = remove {$out}
  command = rm ${out}

rule file_packager
  description = execute emscripten's file packager to ${target}
  command = python #{ENV['EMSCRIPTEN']}/tools/file_packager.py ${target} --preload #{packager_target_dir(target, build_config)}@/ --js-output=${js_output}

rule emscripten_html
  description = generate emscripten's executable ${out}
  command = EMCC_DEBUG=1 a2o -v -s TOTAL_MEMORY=134217728 ${framework_ref_options} ${lib_options} -s NATIVE_LIBDISPATCH=1 --emrun -o ${out} ${linked_objects} --pre-js ${pre_js} -licuuc -licui18n --shell-file ManboMobile.html # --pre-js mem_check.js
RULES
      r
    end

    # paths

    def build_dir(target, build_config)
      "build/#{target.name}/#{build_config.name}"
    end

    def packager_target_dir(target, build_config)
      "#{build_dir(target, build_config)}/package"
    end

    def bundle_dir(target, build_config)
      "#{packager_target_dir(target, build_config)}/Contents"
    end

    def framework_bundle_dir(target, build_config)
      "#{packager_target_dir(target, build_config)}/frameworks"
    end

    def resources_dir(target, build_config)
      "#{bundle_dir(target, build_config)}/Resources"
    end

    def objects_dir(target, build_config)
      "#{build_dir(target, build_config)}/objects"
    end

    def data_path(target, build_config)
      "#{build_dir(target, build_config)}/#{target.product_name}.dat"
    end

    def data_js_path(target, build_config)
      "#{build_dir(target, build_config)}/#{target.product_name}Data.js"
    end

    def html_path(target, build_config)
      "#{build_dir(target, build_config)}/#{target.product_name}.html"
    end

    def binary_path(target, build_config)
      "#{build_dir(target, build_config)}/#{target.product_name}.bc"
    end

    # phases

    def resources_build_phase(_xcodeproj, target, build_config, phase)
      builds = []
      resources = []
      phase.files_references.each do |files_ref|
        case files_ref
        when Xcodeproj::Project::Object::PBXFileReference
          files = [files_ref]
        when Xcodeproj::Project::Object::PBXVariantGroup
          files = files_ref.files
        else
          fail Informative, "Don't support the file #{files_ref.class.name}."
        end

        files.each do |file|
          local_path = File.join(file.parents.map(&:path).select { |path| path }, file.path)
          remote_path = File.join(resources_dir(target, build_config), file.path)

          if File.extname(file.path) == '.storyboard'
            remote_path += 'c'
            tmp_path = File.join('tmp', remote_path)
            builds << {
              outputs: [tmp_path],
              rule_name: 'ibtool_compile',
              inputs: [local_path],
            }
            builds << {
              outputs: [remote_path],
              rule_name: 'ibtool_link',
              inputs: [tmp_path],
            }
          else
            builds << {
              outputs: [remote_path],
              rule_name: 'cp_r',
              inputs: [local_path],
            }
          end

          resources << remote_path
        end
      end

      infoplist_path = build_config.build_settings['INFOPLIST_FILE']
      if infoplist_path
        infoplist = File.join(bundle_dir(target, build_config), 'Info.plist')
        resources << infoplist

        builds << {
          outputs: [infoplist],
          rule_name: 'cp_r',
          inputs: [infoplist_path],
        }
      end

      # UIKit bundle
      framework_resources = file_recursive_copy("#{ENV['EMSCRIPTEN']}/system/frameworks/UIKit.framework/Resources/", "#{framework_bundle_dir(target, build_config)}/UIKit.framework/Resources/")
      builds += framework_resources[:builds]
      resources += framework_resources[:outputs]
      
      # ICU data_path
      icu_data_in = "#{ENV['EMSCRIPTEN']}/system/local/share/icu/54.1/icudt54l.dat"
      icu_data_out = "#{packager_target_dir(target, build_config)}/System/icu/icu.dat"
      builds << {
        outputs: [icu_data_out],
        rule_name: "cp_r",
        inputs: [icu_data_in],
      }
      resources << icu_data_out

      # file_packager
      t = data_path(target, build_config)
      j = data_js_path(target, build_config)
      builds << {
        outputs: [t, j],
        rule_name: 'file_packager',
        inputs: resources,
        variables: {
          'target' => t,
          'js_output' => j,
        }
      }

      builds
    end

    def file_recursive_copy(in_dir, out_dir)
      builds = []
      outputs = []

      in_path = Pathname(in_dir)

      in_path.find do |path|
        next unless path.file?

        rel_path = path.relative_path_from(in_path)
        output_path = File.join(out_dir, rel_path.to_s)
        builds << {
          outputs: [output_path],
          rule_name: 'cp_r',
          inputs: [path.to_s],
        }
        outputs << output_path
      end

      {
        builds: builds,
        outputs: outputs,
      }
    end

    def sources_build_phase(xcodeproj, target, build_config, phase)
      # FIXME: Implement
      builds = []
      objects = []

      header_dirs = xcodeproj.main_group.recursive_children.select { |g| g.path && File.extname(g.path) == '.h' }.map do |g|
        full_path = File.join((g.parents + [g]).map(&:path).select { |path| path })
        File.dirname(full_path)
      end.to_a.uniq

      # build settings
      bs = build_config.build_settings
      lib_dirs = expand(bs['LIBRARY_SEARCH_PATHS'], :array)
      framework_dirs = expand(bs['FRAMEWORK_SEARCH_PATHS'], :array)
      target_header_dirs = expand(bs['HEADER_SEARCH_PATHS'], :array)

      lib_options = lib_dirs.map { |dir| "-L#{dir}" }.join(' ')
      framework_dir_options = framework_dirs.map { |f| "-F#{f}" }.join(' ')
      framework_ref_options = REFERENCE_FRAMEWORKS.map { |f| "-framework #{f}" }.join(' ')
      header_options = (header_dirs + target_header_dirs).map { |dir| "-I./#{dir}" }.join(' ')

      if expand(bs['GCC_PRECOMPILE_PREFIX_HEADER'], :bool)
        prefix_pch = bs['GCC_PREFIX_HEADER']
        prefix_pch_options = "-include #{prefix_pch}"
      end

      # build sources
      phase.files_references.each do |file|
        source_path = File.join(file.parents.map(&:path).select { |path| path }, file.path)
        object = File.join(objects_dir(target, build_config), source_path.gsub(/\.[A-Za-z0-9]+$/, '.o'))

        objects << object

        settings = file.build_files[0].settings
        # TODO: set default option
        file_opt = '-s FULL_ES2=1 -O0 -DGL_GLEXT_PROTOTYPES=1 -DDEBUG=1 -DDEBUG=1 -DCD_DEBUG=1 -DCOCOS2D_DEBUG=1 -DCC_TEXTURE_ATLAS_USE_VAO=0 -s OBJC_DEBUG=1 -Wno-warn-absolute-paths '
        if settings && settings.key?('COMPILER_FLAGS')
          file_opt += expand(settings['COMPILER_FLAGS'], :array).join(' ')
        end
        file_opt += ' -fobjc-arc' unless file_opt =~ /-fno-objc-arc/

        cflags = [framework_dir_options, framework_ref_options, header_options, lib_options, prefix_pch_options, file_opt].join(' ')

        builds << {
          outputs: [object],
          rule_name: 'cc',
          inputs: [source_path, prefix_pch],
          variables: {
            'cflags' => cflags,
            'source' => source_path,
          }
        }
      end

      # stubs
      # FIXME: remove
      Dir.glob('*_dummy.m').each do |source_path|
        object = File.join(objects_dir(target, build_config), source_path.gsub(/\.[A-Za-z0-9]+$/, '.o'))
        objects << object

        cflags = [framework_dir_options, framework_ref_options, header_options, lib_options, prefix_pch_options].join(' ')

        builds << {
          outputs: [object],
          rule_name: 'cc',
          inputs: [source_path, prefix_pch],
          variables: {
            'cflags' => cflags,
            'source' => source_path,
          }
        }
      end

      # link
      builds << {
        outputs: [binary_path(target, build_config)],
        rule_name: 'link',
        inputs: objects
      }

      # executable
      builds << {
        outputs: [html_path(target, build_config)],
        rule_name: 'emscripten_html',
        inputs: [data_js_path(target, build_config), binary_path(target, build_config)],
        variables: {
          'pre_js' => data_js_path(target, build_config),
          'linked_objects' => binary_path(target, build_config),
          'framework_ref_options' => LINK_FRAMEWORKS.map { |f| "-framework #{f}" }.join(' '),
          'lib_options' => `PKG_CONFIG_LIBDIR=#{ENV['EMSCRIPTEN']}/system/lib/pkgconfig:#{ENV['EMSCRIPTEN']}/system/local/lib/pkgconfig pkg-config freetype2 --libs`.strip + ' -lcrypto',
        }
      }

      builds
    end

    def frameworks_build_phase(xcodeproj, target, build_config, phase)
      # FIXME: Implement
    end

    def shell_script_build_phase(xcodeproj, target, build_config, phase)
      # FIXME: Implement
    end

    # utils

    def expand(value, type = nil)
      if value.is_a?(Array)
        value = value.reject do |v|
          v == '$(inherited)'
        end

        value.map do |v|
          expand(v)
        end
      else
        case type
        when :bool
          value == 'YES'
        when :array
          if value.nil?
            []
          else
            [expand(value)]
          end
        else
          if value.nil?
            nil
          else
            value.gsub(/\$\([A-Za-z0-9_]+\)/) do |m|
              case m
              when '$(PROJECT_DIR)'
                xcodeproj_dir
              when '$(SDKROOT)'
                # FIXME: currently ignores
                ''
              when '$(DEVELOPER_FRAMEWORKS_DIR)'
                # FIXME: currently ignores
                ''
              else
                fail Informative, "Not support for #{m}"
              end
            end
          end
        end
      end
    end
  end
end
