# myExperiment: app/models/job.rb
#
# Copyright (c) 2008 University of Manchester and the University of Southampton.
# See license.txt for details.

class Job < ActiveRecord::Base
  
  @details = nil
  before_save :save_details

  belongs_to :runnable, :polymorphic => true
  validates_presence_of :runnable
  validates_presence_of :runnable_version
  
  belongs_to :runner
  validates_presence_of :runner
  
  belongs_to :experiment
  validates_presence_of :experiment
  
  belongs_to :user
  validates_presence_of :user
  
  belongs_to :parent_job, :class_name => "Job", :foreign_key => "parent_job_id"
  
  has_many :child_jobs, :class_name => "Job", :foreign_key => "parent_job_id"
  
  format_attribute :description
  
  validates_presence_of :title
  
  serialize :inputs_data


  def self.default_title(user)
    s = "Job_#{Time.now.strftime('%Y%m%d-%H%M')}"
    s = s + "_#{user.name}" if user
    return s
  end

  def details=(d)
    @details = d
  end

  def details
    @details ||= Kernel.const_get(self.details_type).find_by_id(details_id)
  end
  
  def last_status
    if self[:last_status].nil?
      return "not yet submitted"
    else
      return self[:last_status]
    end
  end
  
  def run_errors
    @run_errors ||= [ ]
  end
  
  def allow_run?
    self.job_uri.blank? and self.submitted_at.blank?
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
        
        if self.completed?
          unless self.outputs_uri
            self.outputs_uri = runner.details.get_job_outputs_uri(self.job_uri)
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
    if allow_run?
      self[:inputs_data] = data
    end
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
  
  def completed?
    return runner.details.verify_job_completed?(self.last_status)
  end
  
  def finished?
    return runner.details.verify_job_finished?(self.last_status)
  end

  def save_details
    self.details.save!
    self.details_type = details.class.to_s
    self.details_id = details.id
  end
  
protected
  
end
