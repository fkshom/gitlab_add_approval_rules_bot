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
    def apply(config_filename=nil, dry_run=true)
      config_filename = "config.yml" if config_filename.nil?
      config = YAML.load_file(config_filename)
      project_id = ENV['PROJECT_ID'] or ENV['CI_PROJECT_ID']
      merge_request_iid = ENV['MERGE_REQUEST_IID'] or ENV['CI_MERGE_REQUEST_IID']

      config['rules'].each do |rule|
        options = {
          name: rule['name'],
          approvals_required: rule['approvals_required'],
          user_ids: [],
          group_ids: [],
        }
        if rule.has_key? 'approval_project_rule_id'
          options[:approval_project_rule_id] = rule['approval_project_rule_id']
        end
        if rule.has_key? 'user_ids'
          options[:user_ids] = rule['user_ids']
        end
        if rule.has_key? 'group_ids'
          options[:group_ids] = rule['group_ids']
        end
        if rule.has_key? 'usernames'
          rule['usernames'].each do |username|
            user = Gitlab.users(options: {username: username})&.first
            pp user
            options[:user_ids] << user['id'] unless user.nil?
          end
        end
        if rule.has_key? 'groupnames'
          rule['groupnames'].each do |groupname|
            group = Gitlab.groups(options: {groupname: groupname})&.first
            pp group
            options[:group_ids] << group['id'] unless group.nil?
          end
        end
        puts "project_id: #{project_id}"
        puts "merge_request_iid: #{merge_request_iid}"
        puts "options: #{options}"
        if dry_run
          puts "THIS IS DRY RUN MODE!!"
        else
          Gitlab.create_merge_request_level_rule(project_id, merge_request_iid, options)
        end
      end
    end
  end
end
