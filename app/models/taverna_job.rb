# myExperiment: app/models/taverna_job.rb
#
# Copyright (c) 2008 University of Manchester and the University of Southampton.
# See license.txt for details.

class TavernaJob < ActiveRecord::Base
  
  serialize :inputs_data

  has_one :job, :foreign_key=>'details_id'
  
  
  def inputs_data=(data)
    if job.allow_run?
      self[:inputs_data] = data
    end
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
  
  def update_outputs
    unless self.outputs_uri
      self.outputs_uri = runner.details.get_job_outputs_uri(self.job_uri)
    end
  end
  
  def save_inputs(params)
    inputs_hash = { }
    
    input_ports = @job.runnable.get_input_ports(@job.runnable_version)
    
    input_ports.each do |i|
      case params["#{i.name}_input_type".to_sym]
      when "none"
        inputs_hash[i.name] = nil
      when "single"
        inputs_hash[i.name] = params["#{i.name}_single_input".to_sym]
      when "list"
        h = params["#{i.name}_list_input".to_sym]
        if h and h.is_a?(Hash)
          # Need to sort because we need to assume that order is important!
          h = h.sort {|a,b| a[0]<=>b[0]}
          vals = [ ]
          h.each do |v|
            vals << v[1]
          end
          inputs_hash[i.name] = vals
        else
          flash[:error] += "Failed to read list of inputs for port: #{i.name}. "
        end
      when "file"
        inputs_hash[i.name] = params["#{i.name}_file_input".to_sym].read
      end
    end
    
    @job.details.inputs_data = inputs_hash
  end
protected
  
end
