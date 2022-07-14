# frozen_string_literal: true

require_relative "gitlab_add_approval_rules_bot/version"
require "gitlab"
require "yaml"
require "thor"
require "dotenv"
Dotenv.load

Gitlab.configure do |config|
  config.endpoint       = ENV['GITLAB_ENDPOINT'] || ENV['CI_API_V4_URL']
  config.private_token  = ENV['GITLAB_TOKEN']
end

module GitlabAddApprovalRulesBot
  class Error < StandardError; end
  class CLI < Thor
    class_option :help, :type => :boolean, :aliases => '-h', :desc => 'help message.'
    class_option :version, :type => :boolean, :desc => 'version'
    default_task :help

    desc "apply", "apply"
    option :dry_run, aliases: "-d", type: :boolean, desc: "dry run mode", default: false
    option :config, aliases: "-c", type: :string, desc: "config file name", default: "config.yml"
    def apply(*rulenames)
      config_filename = "config.yml" if config_filename.nil?
      config = YAML.load_file(config_filename)
      project_id = ENV['PROJECT_ID'] || ENV['CI_PROJECT_ID']
      merge_request_iid = ENV['MERGE_REQUEST_IID'] || ENV['CI_MERGE_REQUEST_IID']

      rulenames.each do |rulename|
        if not config['rules'].key? rulename
          puts "SKIP: rulename #{rulename} in not exists."
          next
        end
        rule = config['rules'][rulename]
        rule_options = {
          name: rule['name'],
          approvals_required: rule['approvals_required'],
          user_ids: [],
          group_ids: [],
        }

        rule_options[:approval_project_rule_id] = rule['approval_project_rule_id'] || nil
        rule_options[:user_ids] = rule['user_ids'] || []
        rule_options[:group_ids] = rule['group_ids'] || []

        (rule['usernames'] || []).each do |username|
          user = Gitlab.user_search(username)&.first
          pp user
          if not user.nil? and user['username'] == username.to_s
            rule_options[:user_ids] << user['id']
          end
        end

        (rule['groupnames'] || []).each do |groupname|
          group = Gitlab.group_search(groupname)&.first
          pp group
          if not group.nil? and group['groupname'] == groupname.to_s
            rule_options[:group_ids] << group['id']
          end
        end

        puts "project_id: #{project_id}"
        puts "merge_request_iid: #{merge_request_iid}"
        puts "options: #{rule_options}"
        if options[:dry_run]
          puts "THIS IS DRY RUN MODE!!"
          next
        end

        if project_id.nil?
          puts "project_id is nil"
          puts "exit"
          next
        end
        if merge_request_iid.nil?
          puts "merge_request_iid is nil"
          puts "exit"
          next
        end

        Gitlab.create_merge_request_level_rule(project_id, merge_request_iid, rule_options)
      end
    end
  end
end
