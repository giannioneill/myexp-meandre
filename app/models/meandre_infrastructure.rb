# myExperiment: app/models/meandre_infrastructure.rb
#
# Copyright (c) 2008 University of Manchester and the University of Southampton.
# See license.txt for details.

require 'acts_as_runner'
require 'enactor/client'
require 'document/data'
require 'document/report'
require 'curb'
require 'zip/zip'
require 'json'

class MeandreInfrastructure < ActiveRecord::Base
  
  acts_as_runner
  
  validates_presence_of :username
  validates_presence_of :crypted_password
  validates_presence_of :url
  
  encrypts :password, :mode => :symmetric, :key => Conf.sym_encryption_key
  
 
  def update_details(details)
    self.url = details[:url] if details[:url]
    self.username = details[:username] if details[:username]
    self.password = details[:password] if details[:password]
  end

  def verify_job_completed?(last_update)
    false
  end

  def service_valid?
    c = Curl::Easy.new(self.url+'public/services/ping.txt');
    c.perform
    c.body_str.include?('pong')
  end

  def upload_flow(workflow)
    pwdstring = 'admin:admin' #TODO: get this from DB
    url = self.url 
    c = Curl::Easy.new("#{url}services/repository/add.json")
    c.userpwd = "#{username}:#{crypted_password.decrypt}"
    c.multipart_form_post = true
    flow_file = Tempfile.new('flow')
    flow_file.write(workflow.content_blob.data)
    flow_file.close(false)

    fields = []
    files = []
    zip = Zip::ZipFile.open(flow_file.path)
    repo_content = ''
    details = nil
    urls = ''
    details = nil
    Zip::ZipFile.foreach(flow_file.path) do |file|
      if file.name == 'repository/repository.ttl'
        #for some reason Curb segfaults when we use a block
        #so we use a Tempfile as a workaround
        parser = MeandreParser.new(zip.read(file))
        details = parser.find_details()
        t = Tempfile.new('repo')
        t.write(parser.get_ttl())
        t.close(false)
        fields << Curl::PostField.file('repository', t.path, t.path.hash.to_s)
        files << t
      elsif file.name.ends_with?('.jar')
        t = Tempfile.new('component')
        t.write(zip.read(file))
        t.close(false)
        fields << Curl::PostField.file('context', t.path, t.path.hash.to_s)
        files << t 
      end
      fields << Curl::PostField.content('overwrite','true')
    end
    begin
      c.http_post(*fields)
    rescue
      return nil
    end
    details.uri
  end

  def find_remote_flow(workflow)
    parser = MeandreParser.new(workflow.content_blob.data)
    details = parser.find_details
    workflow_uri = details.uri
    c = Curl::Easy.new("#{url}services/repository/list_flows.json")
    c.userpwd = "#{username}:#{crypted_password.decrypt}"
    c.perform
    remote_workflows = JSON.parse(c.body_str)
    remote_workflows.each do |remote_workflow|
      return workflow_uri if remote_workflow['meandre_uri'] == workflow_uri
    end
    nil
  end

  def get_remote_runnable_uri(runnable_type, runnable_id, runnable_version)
    workflow = Workflow.find(:first, :conditions => {:id => runnable_id})
    unless workflow
      return nil
    end 
    if workflow.processor_class == WorkflowProcessors::Meandre
      return upload_flow(workflow)
    elsif workflow.processor_class == WorkflowProcessors::MeandreTtl
      return find_remote_flow(workflow)
    end
    nil
  end

  def submit_job(job) 
    remote_uri = get_remote_runnable_uri(job.runnable_type, job.runnable_id, job.runnable_version)
    c = Curl::Easy.new("#{url}services/execute/flow.txt?uri=#{remote_uri}")
    c.userpwd = "#{username}:#{crypted_password.decrypt}"
    body_str = ''
    c.on_body do |data|
      body_str += data
      flow_id = /Unique flow ID: (.*)$/.match(body_str)
      if flow_id
        return flow_id[1]
      end
      data.length
    end
    c.perform
  end

  def get_job_status(remote_uri)
    c = Curl::Easy.new("#{url}services/jobs/list_jobs_statuses.json")
    c.userpwd = "#{username}:#{crypted_password.decrypt}"
    c.perform
    statuses = JSON.parse(c.body_str)
    statuses.each do |status|
      if status['job_id'] == remote_uri
        if status['status'] == 'R'
          return 'running'
        else
          return 'complete'
        end
      end
    end
    'unknown'
  end

  def get_job_report(remote_uri)
    nil
  end
  
  def job_type
    MeandreJob
  end
  
end
