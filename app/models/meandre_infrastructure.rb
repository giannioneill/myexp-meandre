# myExperiment: app/models/meandre_infrastructure.rb
#
# Copyright (c) 2008 University of Manchester and the University of Southampton.
# See license.txt for details.

require 'acts_as_runner'
require 'enactor/client'
require 'document/data'
require 'document/report'
require 'curb'

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

  def get_remote_runnable_uri(runnable_type, runnable_id, runnable_version)
    'http://www.example.org/flow/test/1'
  end

  def submit_job(remote_uri, inputs_uri) 
    'http://www.example.org/execution/test/1'
  end

  def get_job_status(remote_uri)
    'running'
  end
  
end
