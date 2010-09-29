# myExperiment: app/models/meandre_job.rb
#
# Copyright (c) 2008 University of Manchester and the University of Southampton.
# See license.txt for details.

class MeandreJob < ActiveRecord::Base
  
  serialize :inputs_data

  has_one :job, :foreign_key=>'details_id'
  
  def run_errors
    @run_errors ||= [ ]
  end
  
  def has_inputs?
    return self.inputs_data
  end
  
  def save_inputs(params)
    self.inputs_data = params
  end

  #in meandre properties (inputs) have defaults, this method
  #returns the user supplied input, or the default if the
  #user supplied input is not set
  def input_value(prop)
    if self.inputs_data.nil? || self.inputs_data[prop.uri].nil?
      return prop.value
    end
    self.inputs_data[prop.uri]
  end
protected
  
end
