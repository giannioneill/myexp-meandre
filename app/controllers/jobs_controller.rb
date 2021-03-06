# myExperiment: app/controllers/jobs_controller.rb
#
# Copyright (c) 2008 University of Manchester and the University of Southampton.
# See license.txt for details.

require 'delayed_job'

class JobsController < ApplicationController
  
  before_filter :login_required
  
  before_filter :check_runner_available, :only => [:new, :update]
  
  before_filter :find_experiment_auth
  
  before_filter :find_jobs, :only => [:index]
  before_filter :find_job_auth, :except => [:index, :new, :create]
  
  before_filter :check_runnable_supported, :only => [:new, :create]
  
  def index
    respond_to do |format|
      format.html # index.rhtml
    end
  end

  def show
    unless Authorization.is_authorized?(action_name, nil, @job.runnable, current_user)
      flash[:error] = "<p>You will not be able to submit this Job, but you can still see the details of it."
      flash[:error] = "<p>The runnable item (#{@job.runnable_type}) is not authorized - you need download priviledges to run it.</p>"
    end
    
    # TODO: check that runnable version still exists
    
    unless Authorization.is_authorized?(action_name, nil, @job, current_user)
      flash[:error] = "You will not be able to submit this Job, but you can still see the details of it." unless flash[:error]
      flash[:error] += "<p>The runner is not authorized - you need to either own it or be part of a Group that owns it.</p>"
    end
    
    @job.refresh_status!

    respond_to do |format|
      format.html {
        
        @lod_nir  = experiment_job_url(:id => @job.id, :experiment_id => @experiment.id)
        @lod_html = formatted_experiment_job_url(:id => @job.id, :experiment_id => @experiment.id, :format => 'html')
        @lod_rdf  = formatted_experiment_job_url(:id => @job.id, :experiment_id => @experiment.id, :format => 'rdf')
        @lod_xml  = formatted_experiment_job_url(:id => @job.id, :experiment_id => @experiment.id, :format => 'xml')
        
        # show.rhtml
      }

      if Conf.rdfgen_enable
        format.rdf {
          render :inline => `#{Conf.rdfgen_tool} jobs #{@job.id}`
        }
      end
    end
  end

  def new
    @job = Job.new
    @job.experiment = @experiment if @experiment
    
    # Set defaults
    @job.title = Job.default_title(current_user)
    @job.runnable_type = "Workflow"
    
    @job.runnable_id = params[:runnable_id] if params[:runnable_id]
    @job.runnable_version = params[:runnable_version] if params[:runnable_version]
    
    # Check that the runnable object is allowed.
    # At the moment: only Taverna 1 workflows are allowed.
    if params[:runnable_id] 
      runnable = Workflow.find(:first, :conditions => ["id = ?", params[:runnable_id]])
      unless runnable 
        flash[:error] = "Note that the workflow specified to run in this job does not exist. Specify a different workflow."
      end
    end
    
    respond_to do |format|
      format.html # new.rhtml
    end
  end

  def self.create_job(params, user)
    success = true
    err_msg = nil
    
    # Hard code certain values, for now.
    params[:job][:runnable_type] = 'Workflow'
    
    @job = Job.new(params[:job])
    @job.user = user

    # Check runnable is a valid and authorized one
    # (for now we can assume it's a Workflow)
    runnable = Workflow.find(:first, :conditions => ["id = ?", params[:job][:runnable_id]])
    
    if not runnable or not Authorization.is_authorized?('download', nil, runnable, user)
      success = false
      @job.errors.add(:runnable_id, "not valid or not authorized")
    else
      # Look for the specific version of that Workflow
      unless runnable.find_version(params[:job][:runnable_version])
        success = false
        @job.errors.add(:runnable_version, "not valid")
      end
    end
    
    # Check runner is a valid and authorized one
    # (for now we can assume it's a TavernaEnactor)
    runner = Runner.find(:first, :conditions => ["id = ?", params[:job][:runner_id]])
    if not runner or not Authorization.is_authorized?('execute', nil, runner, user)
      success = false
      @job.errors.add(:runner_id, "not valid or not authorized")
    end

    @job.details = runner.details.job_type.new
    
    success = update_parent_experiment(params, @job, user)
    
    return @job, success, err_msg
  end

  def create

    @job, success, err_msg = JobsController.create_job(params, current_user)

    respond_to do |format|
      if success and @job.save
        flash[:notice] = "Job successfully created."
        format.html { redirect_to job_url(@job.experiment, @job) }
      else
        flash[:error] = err_msg if err_msg
        format.html { render :action => "new" }
      end
    end
  end

  def edit
    respond_to do |format|
      format.html # edit.rhtml
    end
  end

  def update
    respond_to do |format|
      if @job.update_attributes(params[:job])
        flash[:notice] = "Job was successfully updated."
        format.html { redirect_to job_url(@experiment, @job) }
      else
        format.html { render :action => "edit" }
      end
    end
  end

  def destroy
    respond_to do |format|
      if @job.destroy
        flash[:notice] = "Job \"#{@job.title}\" has been deleted"
        format.html { redirect_to jobs_url(@experiment) }
      else
        flash[:error] = "Failed to delete Job"
        format.html { redirect_to job_url(@experiment, @job) }
      end
    end
  end
  
  def save_inputs
    @job.details.save_inputs(params)
    respond_to do |format|
      if @job.save  
        flash[:notice] = "Input data successfully saved" if flash[:error].blank?
      else
        flash[:error] = "An error has occurred whilst saving the inputs data"
      end
      
      format.html { redirect_to job_url(@experiment, @job) }
    end
  end
  
  def submit_job
    success = true
    errors_text = ''
    
    # Authorize the runnable and runner
    unless Authorization.is_authorized?(action_name, nil, @job, current_user)
      success = false;
      errors_text += "<p>The runnable item (#{@job.runnable_type}) is not authorized - you need download priviledges to run it.</p>"
    end
    
    unless Authorization.is_authorized?(action_name, nil, @job, current_user)
      success = false;
      errors_text += "<p>The runner is not authorized - you need to either own it or be part of a Group that owns it.</p>"
    end
    
    if success
      @job.queue
    end
    
    unless success
      @job.run_errors.each do |err|
        errors_text += "<p>#{err}</p>"  
      end
    end
    
    respond_to do |format|
      if success
        flash[:notice] = "Job has been successfully submitted. You can monitor progress in the 'Status' section."
        format.html { redirect_to job_url(@experiment, @job) }
      else
        flash[:error] = "Failed to submit job. Errors: " + errors_text
        format.html { redirect_to job_url(@experiment, @job) }
      end
    end
  end
  
  def refresh_status
    @job.refresh_status!
    @stop_timer = (@job.allow_run? or @job.completed?)
    logger.debug("Stop timer? - #{@stop_timer}")
    respond_to do |format|
      format.html { render :partial => "jobs/#{@job.details_type.underscore}/status_info", :locals => { :job => @job, :experiment => @experiment } }
    end
  end
  
  def refresh_outputs
    respond_to do |format|
      format.html { render :partial => "outputs", :locals => { :job => @job, :experiment => @experiment } }
    end
  end
  
  def outputs_xml
      if @job.completed?
        send_data(@job.outputs_as_xml, :filename => "Job_#{@job.id}_#{@job.title}_outputs.xml", :type => "application/xml")
      else
        respond_to do |format|
          flash[:error] = "Outputs XML unavailable - Job not completed successfully yet."
          format.html { redirect_to job_url(@experiment, @job) }
        end
      end
  end
  
  def outputs_package
    
  end
  
  def rerun
    child_job = Job.new
    
    child_job.title = Job.default_title(current_user)
    child_job.experiment = @job.experiment
    child_job.user = current_user
    child_job.runnable = @job.runnable
    child_job.runnable_version = @job.runnable_version
    child_job.runner = @job.runner
    child_job.parent_job = @job

    child_job.details = @job.details.class.new
    child_job.save!
    child_job.details.inputs_data = @job.details.inputs_data
    
    respond_to do |format|
      if child_job.save
        flash[:notice] = "Job successfully created, based on Job #{@job.title}'."
        format.html { redirect_to job_url(@experiment, child_job) }
      else
        format.html { render :action => "new" }
      end
    end
  end
  
  def render_output
    # TODO: employ some form of caching here so that we don't have to always go back to the service for the outputs data.
    respond_to do |format|
      format.html { render :partial => "output_content", :locals => { :job => @job, :output_port => params[:output_port] } }
    end
  end
  
protected

  def self.update_parent_experiment(params, job, user)
    if params[:change_experiment]
      if params[:change_experiment] == 'new'
        job.experiment = Experiment.new(:title => Experiment.default_title(user), :contributor => user)
      elsif params[:change_experiment] == 'existing'
        experiment = Experiment.find(params[:change_experiment_id])
        if experiment and Authorization.is_authorized?('edit', nil, experiment, user)
          job.experiment = experiment
        else
          flash[:error] = "Job could not be created because could not assign the parent Experiment."
          return false
        end
      end
    else
      job.experiment = @experiment
    end
    
    return true
  end
  
  def check_runner_available
    if Runner.for_user(current_user).empty?
      flash[:error] = "You cannot create a job until you have access to an enactment service registered as a runner here."
      respond_to do |format|
        format.html { redirect_to new_runner_url }
      end
    end
  end

  def find_experiment_auth
    experiment = Experiment.find(:first, :conditions => ["id = ?", params[:experiment_id]])
    
    if experiment and Authorization.is_authorized?(action_name, nil, experiment, current_user)
      @experiment = experiment
    else
      # New and Create actions are allowed to run outside of the context of an Experiment
      unless ['new', 'create'].include?(action_name.downcase)
        error("The Experiment that this Job belongs to could not be found or the action is not authorized", "is invalid (not authorized)")
      end
    end
  end
  
  def find_jobs
    @jobs = Job.find(:all, :conditions => ["experiment_id = ?", params[:experiment_id]])
  end

  def find_job_auth
    job = Job.find(:first, :conditions => ["id = ?", params[:id]])
      
    if job and job.experiment.id == @experiment.id and Authorization.is_authorized?(action_name, nil, job, current_user)
      @job = job
    else
      error("Job not found or action not authorized", "is invalid (not authorized)")
    end
  end
  
  def check_runnable_supported
    # TODO: move all checks for the runnable object here!
  end
  
private

  def error(notice, message, attr=:id)
    flash[:error] = notice
    (err = Job.new.errors).add(attr, message)
    
    respond_to do |format|
      format.html { redirect_to jobs_url(params[:experiment_id]) }
    end
  end
end
