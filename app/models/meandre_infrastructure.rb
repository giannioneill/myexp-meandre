# myExperiment: app/models/meandre_infrastructure.rb
#
# Copyright (c) 2008 University of Manchester and the University of Southampton.
# See license.txt for details.

require 'acts_as_runner'
require 'enactor/client'
require 'document/data'
require 'document/report'

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
  
end
