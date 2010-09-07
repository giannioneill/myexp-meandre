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
    
    if allow_run?
      
      begin
        
        # Only continue if runner service is valid
        unless runner.details.service_valid?
          run_errors << "The #{runner.details_type.humanize} is invalid or inaccessible. Please check the settings you have registered for this Runner."
          success = false
        else        
          # Ask the runner for the uri for the runnable object on the service
          # (should submit the object to the service if required)
          remote_runnable_uri = runner.details.get_remote_runnable_uri(self.runnable_type, self.runnable_id, self.runnable_version)
          
          if remote_runnable_uri
            # Submit the job to the runner, which should begin to execute it, then get status
            self.submitted_at = Time.now
            self.job_uri = runner.details.submit_job(remote_runnable_uri, self.inputs_uri)
            self.save!
            
            # Get status
            self.last_status = runner.details.get_job_status(self.job_uri)
            self.last_status_at = Time.now
            self.save!
          else
            run_errors << "Failed to submit the runnable item to the runner service. The item might not exist anymore or access may have been denied at the service."
            success = false
          end
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
  
protected
  
end
