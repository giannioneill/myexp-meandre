# myExperiment: test/functional/tags_controller_test.rb
#
# Copyright (c) 2007 University of Manchester and the University of Southampton.
# See license.txt for details.

require File.dirname(__FILE__) + '/../test_helper'
require 'tags_controller'

# Re-raise errors caught by the controller.
class TagsController; def rescue_action(e) raise e end; end

class TagsControllerTest < Test::Unit::TestCase
  def setup
    @controller = TagsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
