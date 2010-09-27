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
  
  
  def submit_and_run!
    run_errors.clear
    success = true
    
    if job.allow_run?
      
      begin
        
        # Only continue if runner service is valid
        unless job.runner.details.service_valid?
          run_errors << "The #{job.runner.details_type.humanize} is invalid or inaccessible. Please check the settings you have registered for this Runner."
          success = false
        else        
          # Submit the job to the runner, which should begin to execute it, then get status
          job.submitted_at = Time.now
          job.job_uri = job.runner.details.submit_job(self.job)
          self.save!
          
          # Get status
          self.last_status = job.runner.details.get_job_status(job.job_uri)
          self.last_status_at = Time.now
          self.save!
        end
        
      rescue Exception => ex
        run_errors << "An exception has occurred whilst submitting and running this job: #{ex}"
        logger.error(ex)
        logger.error(ex.backtrace)
        success = false
      end
      
    else
      run_errors << "This Job has already been submitted and cannot be rerun."
      success = false;
    end
    
    return success
    
  end
  
  def refresh_status!
    begin
      if self.job_uri
        self.last_status = runner.details.get_job_status(self.job_uri)
        self.last_status_at = Time.now
        
        unless self.started_at
          self.started_at = runner.details.get_job_started_at(self.job_uri)
        end
        
        if self.finished?
          unless self.completed_at
            self.completed_at = runner.details.get_job_completed_at(self.job_uri, self.last_status)
          end
        end
        
        self.save
      end 
    rescue Exception => ex
      logger.error("ERROR occurred whilst refreshing status for job #{self.job_uri}. Exception: #{ex}")
      logger.error(ex.backtrace)
      return false
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
