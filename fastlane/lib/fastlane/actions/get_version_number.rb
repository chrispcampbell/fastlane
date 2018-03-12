module Fastlane
  module Actions
    class GetVersionNumberAction < Action
      require 'shellwords'

      def self.run(params)
        # More information about how to set up your project and how it works:
        # https://developer.apple.com/library/ios/qa/qa1827/_index.html

        folder = params[:xcodeproj] ? File.join(params[:xcodeproj], '..') : '.'

        command_prefix = [
          'cd',
          File.expand_path(folder).shellescape,
          '&&'
        ].join(' ')

        command = [
          command_prefix,
          'agvtool',
          'what-marketing-version',
          '-terse'
        ].join(' ')

        resolved_version_number = ""
        scheme = params[:scheme] || ""
        target = params[:target] || ""
        results = []

        # Creates a map with target as key and plist absolute file path as value
        # Used for comparing passed in target
        target_plist_map = generate_target_plist_mapping(folder)

        # Using `` instead of Actions.sh since agvtools needs to actually run during tests
        results = `#{command}`.split("\n")

        if target.empty? && scheme.empty?
          # Sometimes the results array contains nonsense as the first element
          # This iteration finds the first 'real' result and returns that
          # emulating the actual behavior or the -terse1 flag correctly
          project_string = ".xcodeproj"
          results.any? do |result|
            plist_path = result.partition('=').first
            version_number = result.partition('=').last

            if plist_path.include?(project_string)
              resolved_version_number = version_number
              break
            end
          end
        else
          # This iteration finds the first folder structure or info plist
          # matching the specified target
          scheme_string = "/#{scheme}"
          target_string = "/#{target}/"
          plist_target_string = "/#{target}-"

          results.any? do |result|
            relative_plist_path = result.partition('=').first
            version_number = result.partition('=').last

            # Remove quotes from path string and make absolute
            # for map comparision (if needed)
            clean_plist_path = relative_plist_path.tr('"', '')
            plist_path = File.absolute_path(clean_plist_path)

            if !target.empty?
              if plist_path.include?(target_string)
                resolved_version_number = version_number
                break
              elsif plist_path.include?(plist_target_string)
                resolved_version_number = version_number
                break
              elsif target_plist_map[target] == plist_path
                resolved_version_number = version_number
                break
              end
            else
              if plist_path.include?(scheme_string)
                resolved_version_number = version_number
                break
              end
            end
          end
        end

        # version_number = line.partition('=').last

        # Store the number in the shared hash
        Actions.lane_context[SharedValues::VERSION_NUMBER] = resolved_version_number

        # Return the version number because Swift might need this return value
        return resolved_version_number
      rescue => ex
        UI.error('Before being able to increment and read the version number from your Xcode project, you first need to setup your project properly. Please follow the guide at https://developer.apple.com/library/content/qa/qa1827/_index.html')
        raise ex
      end

      def self.generate_target_plist_mapping(folder)
        map = {}

        require 'xcodeproj'
        project_path = Dir.glob("#{folder}/*.xcodeproj").first
        if project_path
          project = Xcodeproj::Project.open(project_path)
          map = project.targets.each_with_object(map) do |target, map|
            info_plist_file = target.common_resolved_build_setting("INFOPLIST_FILE")
            map[target.name] = File.absolute_path(info_plist_file)
          end
        else
          UI.verbose("Unable to create find Xcode project in folder: #{folder}")
        end

        map
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Get the version number of your project"
      end

      def self.details
        [
          "This action will return the current version number set on your project.",
          "You first have to set up your Xcode project, if you haven't done it already:",
          "https://developer.apple.com/library/ios/qa/qa1827/_index.html"
        ].join(' ')
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :xcodeproj,
                             env_name: "FL_VERSION_NUMBER_PROJECT",
                             description: "optional, you must specify the path to your main Xcode project if it is not in the project root directory",
                             optional: true,
                             verify_block: proc do |value|
                               UI.user_error!("Please pass the path to the project, not the workspace") if value.end_with?(".xcworkspace")
                               UI.user_error!("Could not find Xcode project at path '#{File.expand_path(value)}'") if !File.exist?(value) and !Helper.test?
                             end),
          FastlaneCore::ConfigItem.new(key: :scheme,
                             env_name: "FL_VERSION_NUMBER_SCHEME",
                             description: "Specify a specific scheme if you have multiple per project, optional. " \
                                          "This parameter is deprecated and will be removed in a future release. " \
                                          "Please use the 'target' parameter instead. The behavior of this parameter " \
                                          "is currently undefined if your scheme name doesn't match your target name",
                             optional: true,
                             deprecated: true),
          FastlaneCore::ConfigItem.new(key: :target,
                             env_name: "FL_VERSION_NUMBER_TARGET",
                             description: "Specify a specific target if you have multiple per project, optional",
                             optional: true)
        ]
      end

      def self.output
        [
          ['VERSION_NUMBER', 'The version number']
        ]
      end

      def self.authors
        ["Liquidsoul"]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end

      def self.example_code
        [
          'version = get_version_number(xcodeproj: "Project.xcodeproj")'
        ]
      end

      def self.return_type
        :string
      end

      def self.category
        :project
      end
    end
  end
end
