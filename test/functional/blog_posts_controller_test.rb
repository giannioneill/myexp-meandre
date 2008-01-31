# myExperiment: test/functional/blog_posts_controller_test.rb
#
# Copyright (c) 2007 University of Manchester and the University of Southampton.
# See license.txt for details.

require File.dirname(__FILE__) + '/../test_helper'
require 'blog_posts_controller'

# Re-raise errors caught by the controller.
class BlogPostsController; def rescue_action(e) raise e end; end

class BlogPostsControllerTest < Test::Unit::TestCase
  fixtures :blog_posts

  def setup
    @controller = BlogPostsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_should_get_index
    get :index
    assert_response :success
    assert assigns(:blog_posts)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end
  
  def test_should_create_blog_post
    old_count = BlogPost.count
    post :create, :blog_post => { }
    assert_equal old_count+1, BlogPost.count
    
    assert_redirected_to blog_post_path(assigns(:blog_post))
  end

  def test_should_show_blog_post
    get :show, :id => 1
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => 1
    assert_response :success
  end
  
  def test_should_update_blog_post
    put :update, :id => 1, :blog_post => { }
    assert_redirected_to blog_post_path(assigns(:blog_post))
  end
  
  def test_should_destroy_blog_post
    old_count = BlogPost.count
    delete :destroy, :id => 1
    assert_equal old_count-1, BlogPost.count
    
    assert_redirected_to blog_posts_path
  end
end
