class SearchController < ApplicationController
  def show

    if params[:query].nil? or params[:query] == ''
      flash[:error] = 'Missing search query';
      redirect_to url_for(:controller => "home")
      return
    end

    @type = params[:type].to_s.downcase
    
    # Hacks for 'Groups' --> 'Networks' and 'Files' --> 'Blobs' renames
    @type = 'networks' if @type == 'groups'
    @type = 'blobs' if @type == 'files'
    
    unless @@valid_types.include? @type
      error(@type)
      return false
    end
    
    if @type == "all"
      search_all
    else
      redirect_to :controller => params[:type], :action => "search", :query => params[:query]
    end
  end
  
  def open_search_beta

    def time_string(time)
      time.strftime("%a, %d %b %Y %I:%H:%S %Z")
    end

    def file_column_url(ob, field)

      fields = (field.split('/').map do |f| "'#{f}'" end).join(', ')

      path = eval("ActionView::Base.new.url_for_file_column(ob, #{fields})")

      "#{request.protocol}#{request.host_with_port}#{path}"
    end

    def render_user(u)

      markup = ""

      markup += "<item>";
      markup += "<title>" + u.name + "</title>";
      markup += "<link>" + user_url(u) + "</link>";
      markup += "<description>" + sanitize(u.profile.body_html) + "</description>";
      markup += "<pubDate>" + time_string(u.created_at) + "</pubDate>";
      markup += "<media:thumbnail url=\"" + user_picture_url(u, u.profile.picture.id) + "\"/>";
#markup += "height=\"120\" width=\"160\"/>";

      markup += "</item>";

      markup
    end

    def sanitize(str)
      str = str.gsub('<[^>]*>', '')
      str = str.gsub('&', '')
      str
    end

    def render_workflow(w)

      markup = ""

      markup += "<item>";
      markup += "<title>" + w.title + "</title>";
      markup += "<link>" + workflow_url(w) + "</link>";
      markup += "<description>" + sanitize(w.body_html) + "</description>";
      markup += "<pubDate>" + time_string(w.created_at) + "</pubDate>";
      markup += "<media:content url=\"" + w.named_download_url + "\"";
      markup += " fileSize=\"" + w.content_blob.data.length.to_s + "\"" +
                " type=\"" + w.content_type + "\"/>";
      markup += "<media:thumbnail url=\"" + file_column_url(w, "image/thumb") +
          "\"/>";
#markup += "height=\"120\" width=\"160\"/>";

      w.tags.each do |t|
        markup += "<category>#{t.name}</category>"
      end

      markup += "<author>#{w.contributor.name}</author>"

      markup += "</item>";

      markup
    end

    markup = ""

    markup += "<rss version=\"2.0\" xmlns:media=\"http://search.yahoo.com/mrss/\" ";
    markup += "xmlns:example=\"http://example.com/namespace\">";
    markup += "<channel>";
    markup += "<title>Search Results</title>";

    if (params["q"] != "*")
      workflows = Workflow.find_by_solr(params["q"])
      users     = User.find_by_solr(params["q"])

      workflows.results.each do |w|
        markup += render_workflow(w)
      end

      users.results.each do |u|
        markup += render_user(u)
      end
    end

    markup += "</channel>";
    markup += "</rss>";

    response.content_type = "application/rss+xml"

    render :text => markup
  end

private

  @@valid_types = ["all", "workflows", "users", "networks", "blobs", "packs"]

  def error(type)
    flash[:error] = "'#{type}' is an invalid search type"
    
    respond_to do |format|
      format.html { redirect_to url_for(:controller => "home") }
    end
  end

  def search_all
    @query = params[:query] || ''
    @query.strip!

    @results = []

    if SOLR_ENABLE && !@query.blank?
      @results = User.multi_solr_search(@query, :limit => 100,
          :models => [User, Workflow, Blob, Network, Pack]).results
      
      @users_found_total_count = User.count_by_solr(@query)
      @workflows_found_total_count = Workflow.count_by_solr(@query)
      @blobs_found_total_count = Blob.count_by_solr(@query)
      @networks_found_total_count = Network.count_by_solr(@query)
      @packs_found_total_count = Pack.count_by_solr(@query)
    end

    @users     = @results.select do |r| r.instance_of?(User)     end
    @workflows = @results.select do |r| r.instance_of?(Workflow) end
    @blobs     = @results.select do |r| r.instance_of?(Blob)     end
    @networks  = @results.select do |r| r.instance_of?(Network)  end
    @packs     = @results.select do |r| r.instance_of?(Pack)     end

    respond_to do |format|
      format.html # search.rhtml
    end
  end
end
