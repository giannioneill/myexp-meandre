require 'md5'

module ApplicationHelper
  def last_active
    session[:last_active] ||= Time.now.utc
  end
    
  def submit_tag(value = "Save Changes", options={} )
    or_option = options.delete(:or)
    return super + "<span class='button_or'>or " + or_option + "</span>" if or_option
    super
  end

  def ajax_spinner_for(id, spinner="spinner.gif")
    "<img src='/images/#{spinner}' style='display:none; vertical-align:middle;' id='#{id.to_s}_spinner'> "
  end

  def avatar_for(user, size='50')
    #image_tag "http://www.gravatar.com/avatar.php?gravatar_id=#{MD5.md5(user.email)}&rating=PG&size=#{size}", :size => "#{size}x#{size}", :class => 'photo'
    avatar(user, size)
  end

  # Update 2008-01-28 [Jits]: Moved to main application_helper
  #def feed_icon_tag(title, url)
  #  (@feed_icons ||= []) << { :url => url, :title => title }
  #  link_to image_tag('feed-icon.png', :size => '14x14', :alt => "Subscribe to #{title}"), url
  #end

  def search_posts_title
    returning(params[:q].blank? ? 'Recent Posts' : "Searching for '#{h params[:q]}'") do |title|
      title << " by #{h User.find(params[:user_id]).display_name}" if params[:user_id]
      title << " in #{h Forum.find(params[:forum_id]).name}"       if params[:forum_id]
    end
  end

  def search_posts_path(rss = false)
    options = params[:q].blank? ? {} : {:q => params[:q]}
    prefix = rss ? 'formatted_' : ''
    options[:format] = 'rss' if rss
    [[:user, :user_id], [:forum, :forum_id]].each do |(route_key, param_key)|
      return send("#{prefix}#{route_key}_posts_path", options.update(param_key => params[param_key])) if params[param_key]
    end
    options[:q] ? all_search_posts_path(options) : send("#{prefix}all_posts_path", options)
  end

  def distance_of_time_in_words(from_time, to_time = 0, include_seconds = false)
    from_time = from_time.to_time if from_time.respond_to?(:to_time)
    to_time = to_time.to_time if to_time.respond_to?(:to_time)
    distance_in_minutes = (((to_time - from_time).abs)/60).round
  
    case distance_in_minutes
      when 0..1           then (distance_in_minutes==0) ? 'a few seconds ago' : '1 minute ago'
      when 2..59          then "#{distance_in_minutes} minutes ago"
      when 60..90         then "1 hour ago"
      when 90..1440       then "#{(distance_in_minutes.to_f / 60.0).round} hours ago"
      when 1440..2160     then '1 day ago' # 1 day to 1.5 days
      when 2160..2880     then "#{(distance_in_minutes.to_f / 1440.0).round} days ago" # 1.5 days to 2 days
      else from_time.strftime("%b %e, %Y  %l:%M%p").gsub(/([AP]M)/) { |x| x.downcase }
    end
  end
end
