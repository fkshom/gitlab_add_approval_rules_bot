# frozen_string_literal: true

require_relative "gitlab_add_approval_rules_bot/version"
require "gitlab"
require "yaml"
require "thor"
require "dotenv"
Dotenv.load

Gitlab.configure do |config|
  config.endpoint       = ENV['GITLAB_ENDPOINT']
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
    def apply(config_filename=nil)
      config_filename = "config.yml" if config_filename.nil?
      config = YAML.load_file(config_filename)
      project_id = ENV['PROJECT_ID'] or ENV['CI_PROJECT_ID']
      merge_request_iid = ENV['MERGE_REQUEST_IID'] or ENV['CI_MERGE_REQUEST_IID']

      config['rules'].each do |rule|
        rule_options = {
          name: rule['name'],
          approvals_required: rule['approvals_required'],
          user_ids: [],
          group_ids: [],
        }
        if rule.has_key? 'approval_project_rule_id'
          rule_options[:approval_project_rule_id] = rule['approval_project_rule_id']
        end
        if rule.has_key? 'user_ids'
          rule_options[:user_ids] = rule['user_ids']
        end
        if rule.has_key? 'group_ids'
          rule_options[:group_ids] = rule['group_ids']
        end
        if rule.has_key? 'usernames'
          rule['usernames'].each do |username|
            user = Gitlab.user_search(username)&.first
            pp user
            if not user.nil? and user['username'] == username
              rule_options[:user_ids] << user['id'] unless user.nil?
            end
          end
        end
        if rule.has_key? 'groupnames'
          rule['groupnames'].each do |groupname|
            group = Gitlab.group_search(groupname)&.first
            pp group
            if not group.nil? and group['groupname'] == groupname
              rule_options[:group_ids] << group['id'] unless group.nil?
            end

          end
        end
        puts "project_id: #{project_id}"
        puts "merge_request_iid: #{merge_request_iid}"
        puts "options: #{rule_options}"
        if options[:dry_run]
          puts "THIS IS DRY RUN MODE!!"
        else
          # Gitlab.create_merge_request_level_rule(project_id, merge_request_iid, rule_options)
        end
      end
    end
  end
end
