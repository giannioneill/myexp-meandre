# myExperiment: app/controllers/application.rb
#
# Copyright (c) 2007 University of Manchester and the University of Southampton.
# See license.txt for details.

# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base

  filter_parameter_logging :password
  
  WhiteListHelper.tags.merge %w(table tr td th div span)
  
  before_filter :set_configuration

  include AuthenticatedSystem
  before_filter :login_from_cookie
  
  include ActionView::Helpers::NumberHelper

  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_m2_session_id'
  
  def base_host
    request.host_with_port
  end
  
  
  # if "referer" in the HTTP header contains "myexperiment", we know
  # that current action was accessed from myExperiment website; if
  # referer is not set OR doesn't contain the search string, access
  # was initiated from other location 
  def accessed_from_website?
    res = false
    
    referer = request.env['HTTP_REFERER']
    unless referer.nil? || referer.match("^#{Conf.base_uri}").nil?
      res = true
    end
    
    return res
  end

  def set_configuration
    Conf.set_configuration(request, session)
  end

  def formatted_timespan(time_period)
    # Takes a period of time in seconds and returns it in human-readable form (down to minutes)
    # from (http://www.postal-code.com/binarycode/category/devruby/)
    out_str = ""
        
    interval_array = [ [:weeks, 604800], [:days, 86400], [:hours, 3600], [:minutes, 60] ]
    interval_array.each do |sub|
      if time_period >= sub[1]
        time_val, time_period = time_period.divmod(sub[1])
            
        time_val == 1 ? name = sub[0].to_s.singularize : name = sub[0].to_s
              
        ( sub[0] != :minutes ? out_str += ", " : out_str += " and " ) if out_str != ''
        out_str += time_val.to_s + " #{name}"
      end
    end
   
    return out_str  
  end
  
  
  # this method is only intended to check if entry
  # in "viewings" or "downloads" table needs to be
  # created for current access - and this is *only*
  # supposed to be working for *contributables*
  #
  # NB! The input parameter is the actual contributable OR
  # the version of it (currently only workflows are versioned)
  def allow_statistics_logging(contributable_or_version)
    
    # check if the current viewing/download is to be logged
    # (i.e. request is sent not by a bot and is legitimate)
    allow_logging = true
    Conf.bot_ignore_list.each do |pattern|
      if request.env['HTTP_USER_AGENT'] and request.env['HTTP_USER_AGENT'].match(pattern)
        allow_logging = false
        break
      end
    end
    
    # disallow logging of events referring to contributables / versions of them
    # that have been uploaded by current user; 
    #
    # however, if there are newer versions of contributable (uploaded not by the original uploader),
    # we do want to record viewings/downloads of this newer version by the original uploader  
    if allow_logging && current_user != 0
      allow_logging = false if (contributable_or_version.contributor_type == "User" && contributable_or_version.contributor_id == current_user.id)
    end
    
    return allow_logging
  end
  
  
  # Safe HTML - http://www.anyexample.com/webdev/rails/how_to_allow_some_safe_html_in_rails_projects.xml
  # Note: should only be used for text that doesn't need updating later.
  def ae_some_html(s)
    return '' if s.nil?    
    
    # converting newlines
    s.gsub!(/\r\n?/, "\n")
 
    # escaping HTML to entities
    s = s.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
 
    # blockquote tag support
    s.gsub!(/\n?&lt;blockquote&gt;\n*(.+?)\n*&lt;\/blockquote&gt;/im, "<blockquote>\\1</blockquote>")
 
    # other tags: b, i, em, strong, u
    %w(b i em strong u).each { |x|
         s.gsub!(Regexp.new('&lt;(' + x + ')&gt;(.+?)&lt;/('+x+')&gt;',
                 Regexp::MULTILINE|Regexp::IGNORECASE), 
                 "<\\1>\\2</\\1>")
        }
 
    # A tag support
    # href="" attribute auto-adds http://
    s = s.gsub(/&lt;a.+?href\s*=\s*['"](.+?)["'].*?&gt;(.+?)&lt;\/a&gt;/im) { |x|
            '<a href="' + ($1.index('://') ? $1 : 'http://'+$1) + "\">" + $2 + "</a>"
          }
 
    # replacing newlines to <br> ans <p> tags
    # wrapping text into paragraph
    s = "<p>" + s.gsub(/\n\n+/, "</p>\n\n<p>").
            gsub(/([^\n]\n)(?=[^\n])/, '\1<br />') + "</p>"
 
    s      
  end
  
  # This method takes a comma seperated list of tags (where multiple words don't need to be in quote marks)
  # and formats it into a new comma seperated list where multiple words ARE in quote marks.
  # (Note: it will actually put quote marks around all the words and then out commas).
  # eg: 
  #    this, is a, tag
  #        becomes:
  #    "this","is a","tag"
  #
  # This is so we can map the tags entered in by users to the format required by the act_as_taggable_redux gem.
  def convert_tags_to_gem_format(tags_string)
    list = parse_comma_seperated_string(tags_string)
    converted = '' 
    
    list.each do |s|
      converted = converted + '"' + s.strip + '",'
    end
    
    return converted
  end
  
  helper_method :ae_some_html
  
  # This method converts a comma seperated string of values into a collection of those values.
  # Note: currently does not cater for values in quotation marks and does not remove empty values
  # (although it does ignore a trailing comma)
  def parse_comma_seperated_string(s)
    list = s.split(',')
  end

  def update_policy(contributable, params)
    logger.debug('params RECV: '+YAML::dump(params))
    # this method will return an error message is something goes wrong (empty string in case of success)
    error_msg = ""
    

    # BEGIN validation and initialisation
    
    # This variable will hold current settings of the policy in case something
    # goes wrong and a revert would be needed at some point
    last_saved_policy = nil
    
    return if params[:sharing].nil? or params[:sharing][:class_id].blank?
    
    sharing_class  = params[:sharing][:class_id]
    updating_class = (params[:updating] and !params[:updating][:class_id].blank?) ? params[:updating][:class_id] : "6"
    
    # Check allowed sharing_class values
    return unless [ "0", "1", "2", "3", "4", "7" ].include? sharing_class
    
    # Check allowed updating_class values
    return unless [ "0", "1", "5", "6" ].include? updating_class
    
    view_protected     = 0
    view_public        = 0
    download_protected = 0
    download_public    = 0
    edit_protected     = 0
    edit_public        = 0
    
    # BEGIN initialisation and validation

    unless contributable.contribution.policy
      last_saved_policy = Policy._default(current_user, nil) # second parameter ensures that this policy is not applied anywhere
      
      policy = Policy.new(:name => 'auto',
          :contributor_type => 'User', :contributor_id => current_user.id,
          :share_mode         => sharing_class,
          :update_mode        => updating_class)
      contributable.contribution.policy = policy  # by doing this the new policy object is saved implicitly too
      contributable.contribution.save
    else
       policy = contributable.contribution.policy
       last_saved_policy = policy.clone # clone required, not 'dup' (which still works through reference, so the values in both get changed anyway - which is not what's needed here)
       
       policy.share_mode = sharing_class
       policy.update_mode = updating_class
       policy.save
    end


    # Process 'update' permissions for "Some of my Friends"

    if updating_class == "5"
      if params[:updating_somefriends]
        # Delete old User permissions
        policy.delete_all_user_permissions
        
        # Now create new User permissions, if required
        params[:updating_somefriends].each do |f|
          Permission.new(:policy => policy,
              :contributor => (User.find f[1].to_i),
              :view => 1, :download => 1, :edit => 1).save
        end
      else # none of the 'some of my friends' were selected, error
        # revert changes made to policy (however any permissions updated will preserve the state)
        policy.copy_values_from( last_saved_policy )
        policy.save
        error_msg += "You have selected to set 'update' permissions for 'Some of your Friends', but didn't select any from the list.</br>Previous (if any) or default sharing permissions have been set."
        return error_msg
      end
    else
      # Delete all User permissions - as this isn't mode 5 (i.e. the mode has changed),
      # where some explicit permissions to friends are set
      policy.delete_all_user_permissions
    end
    
    
    # Process explicit Group permissions now
    if params[:group_sharing]
      
      # First delete any Permission objects that don't have a checked entry in the form
      policy.permissions.each do |p|
        params[:group_sharing].each do |n|
          # If a hash value with key 'id' wasn't returned then that means the checkbox was unchecked.
          unless n[1][:id]
            if p.contributor_type == 'Network' and p.contributor_id == n[0].to_i
              p.destroy
            end
          end
        end
      end
    
      # Now create or update Permissions
      params[:group_sharing].each do |n|
        
        # Note: n[1] is used because n is an array and n[1] returns it's value (which in turn is a hash)
        # In this hash, is a value with key 'id' is present then the checkbox for that group was checked.
        if n[1][:id]
          
          n_id = n[1][:id].to_i
          level = n[1][:level]
          
          unless (perm = Permission.find(:first, :conditions => ["policy_id = ? AND contributor_type = ? AND contributor_id = ?", policy.id, 'Network', n_id]))
            # Only create new Permission if it doesn't already exist
            p = Permission.new(:policy => policy, :contributor => (Network.find(n_id)))
            p.set_level!(level) if level
          else
            # Update the 'level' on the existing permission
            perm.set_level!(level) if level
          end
          
        else
          
          n_id = n[0].to_i
          
          # Delete permission if it exists (because this one is unchecked)
          if (perm = Permission.find(:first, :conditions => ["policy_id = ? AND contributor_type = ? AND contributor_id = ?", policy.id, 'Network', n_id]))
            perm.destroy
          end
          
        end
      
      end
    end

    logger.debug("------ Workflow create summary ------------------------------------")
    logger.debug("current_user   = #{current_user.id}")
    logger.debug("updating_class = #{updating_class}")
    logger.debug("sharing_class  = #{sharing_class}")
    logger.debug("policy         = #{policy}")
    logger.debug("group_sharing  = #{params[:group_sharing]}")
    logger.debug("-------------------------------------------------------------------")

    # returns some message in case of errors (or empty string in case of success)
    return error_msg
  end

  def update_credits(creditable, params)
    
    # First delete old creditations:
    creditable.creditors.each do |c|
      c.destroy
    end
    
    # Then create new creditations:
    
    # Current user
    if (params[:credits_me].downcase == 'true')
      c = Creditation.new(:creditor_type => 'User', :creditor_id => current_user.id, :creditable_type => creditable.class.to_s, :creditable_id => creditable.id)
      c.save
    end
    
    # Friends + other users
    user_ids = parse_comma_seperated_string(params[:credits_users])
    user_ids.each do |id|
      c = Creditation.new(:creditor_type => 'User', :creditor_id => id, :creditable_type => creditable.class.to_s, :creditable_id => creditable.id)
      c.save
    end
    
    # Networks (aka Groups)
    network_ids = parse_comma_seperated_string(params[:credits_groups])
    network_ids.each do |id|
      c = Creditation.new(:creditor_type => 'Network', :creditor_id => id, :creditable_type => creditable.class.to_s, :creditable_id => creditable.id)
      c.save
    end
    
  end
  
  def update_attributions(attributable, params)
    
    # First delete old attributions:
    attributable.attributors.each do |a|
      a.destroy
    end
    
    # Then create new attributions:
    
    # Workflows
    attributor_workflow_ids = parse_comma_seperated_string(params[:attributions_workflows])
    attributor_type = 'Workflow'
    attributor_workflow_ids.each do |id|
      a = Attribution.new(:attributor_type => attributor_type, :attributor_id => id, :attributable_type => attributable.class.to_s, :attributable_id  => attributable.id)
      a.save
    end
    
    # Files
    attributor_file_ids = parse_comma_seperated_string(params[:attributions_files])
    attributor_type = 'Blob'
    attributor_file_ids.each do |id|
      a = Attribution.new(:attributor_type => attributor_type, :attributor_id => id, :attributable_type => attributable.class.to_s, :attributable_id  => attributable.id)
      a.save
    end
    
  end
 
  # helper function to determine the context of a polymorphic nested resource

  def extract_resource_context(params)
    (Conf.contributor_models + Conf.contributable_models).each do |model_name|
      id_param = "#{Conf.to_visible(model_name.underscore)}_id"
      return Object.const_get(model_name).find_by_id(params[id_param]) if params[id_param]
    end

    nil
  end 
end
