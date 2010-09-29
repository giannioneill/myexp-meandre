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
  
  
  def current_input_type(input_name)
    return 'none' if input_name.blank? or !self.inputs_data or self.inputs_data.empty?
    
    vals = self.inputs_data[input_name]
    
    return 'none' if vals.blank?
    
    if vals.is_a?(Array)
      return 'list'
    else
      return 'single' 
    end
  end
  
  def has_inputs?
    return self.inputs_data
  end
  
  def report
    begin
      if self.job_uri
        return runner.details.get_job_report(self.job_uri)
      else
        return nil
      end
    rescue Exception => ex
      logger.error("ERROR occurred whilst fetching report for job #{self.job_uri}. Exception: #{ex}")
      logger.error(ex.backtrace)
      return nil
    end
  end
  
  # Note: this will return outputs in a format as defined by the Runner.
  def outputs_data
    begin
      if completed?
        return runner.details.get_job_outputs(self.job_uri)
      else
        return nil
      end
    rescue Exception => ex
      logger.error("ERROR occurred whilst fetching outputs for job #{self.job_uri}. Exception: #{ex}")
      logger.error(ex.backtrace)
      return nil
    end
  end
  
  def outputs_as_xml
    begin
      if completed? and (xml_doc = runner.details.get_job_outputs_xml(self.job_uri))
        return xml_doc.to_s
      else
        return 'Error: could not retrieve outputs XML document.'
      end
    rescue Exception => ex
      logger.error("ERROR occurred whilst fetching outputs XML for job #{self.job_uri}. Exception: #{ex}")
      logger.error(ex.backtrace)
      return nil
    end
  end
  
  # Returns the size of the outputs in Bytes.
  def outputs_size
    begin
      if completed?
        return runner.details.get_job_output_size(self.job_uri)
      else
        return nil
      end
    rescue Exception => ex
      logger.error("ERROR occurred whilst getting outputs size for job #{self.job_uri}. Exception: #{ex}")
      logger.error(ex.backtrace)
      return nil
    end
  end
  
  def get_output_type(output_data)
    # Delegate out to the runner to handle it's own specific output format
    runner.get_output_type(output_data)
  end
  
  def get_output_mime_types(output_data)
    # Delegate out to the runner to handle it's own specific output format
    runner.get_output_mime_types(output_data)
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
