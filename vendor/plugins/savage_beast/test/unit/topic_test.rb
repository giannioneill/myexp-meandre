require File.dirname(__FILE__) + '/../test_helper'

class TopicTest < Test::Unit::TestCase
  all_fixtures

  def test_save_should_update_post_id_for_posts_belonging_to_topic
    # checking current forum_id's are in sync
    topic = topics(:pdi)
    post_forums = lambda do
      topic.posts.each { |p| assert_equal p.forum_id, topic.forum_id }
    end
    post_forums.call
    assert_equal forums(:rails).id, topic.forum_id
    
    # updating forum_id
    topic.update_attribute :forum_id, forums(:comics).id
    assert_equal forums(:comics).id, topic.reload.forum_id
    post_forums.call
  end

  def test_knows_last_post
    assert_equal posts(:pdi_rebuttal), topics(:pdi).posts.last
  end
  
  def test_should_require_title_user_and_forum
    t=Topic.new
    t.valid?
    assert t.errors.on(:title)
    assert t.errors.on(:user)
    assert t.errors.on(:forum)
    assert ! t.save
    t.user  = users(:aaron)
    t.title = "happy life"
    t.forum = forums(:rails)
    assert t.save
    assert_nil t.errors.on(:title)
    assert_nil t.errors.on(:user)
    assert_nil t.errors.on(:forum)
  end

  def test_should_add_to_user_counter_cache
    assert_difference Post, :count do
      assert_difference users(:sam).posts, :count do
        p = topics(:pdi).posts.build(:body => "I'll do it")
        p.user = users(:sam)
        p.save
      end
    end
  end
 
  def test_should_create_topic
    counts = lambda { [Topic.count, forums(:rails).topics_count] }
    old = counts.call
    t = forums(:rails).topics.build(:title => 'foo')
    t.user = users(:aaron)
    assert_valid t
    t.save
    assert_equal 0, t.sticky
    [forums(:rails), users(:aaron)].each &:reload
    assert_equal old.collect { |n| n + 1}, counts.call
  end
  
  def test_should_delete_topic
    counts = lambda { [Topic.count, Post.count, forums(:rails).topics_count, forums(:rails).posts_count,  users(:sam).posts_count] }
    old = counts.call
    topics(:ponies).destroy
    [forums(:rails), users(:sam)].each &:reload
    assert_equal old.collect { |n| n - 1}, counts.call
  end
  
  def test_hits
    hits=topics(:pdi).views
    topics(:pdi).hit!
    topics(:pdi).hit!
    assert_equal(hits+2, topics(:pdi).reload.hits)
    assert_equal(topics(:pdi).hits, topics(:pdi).views)
  end
  
  def test_replied_at_set
    t=Topic.new
    t.user=users(:aaron)
    t.title = "happy life"
    t.forum = forums(:rails)
    assert t.save
    assert_not_nil t.replied_at
    assert t.replied_at <= Time.now.utc
    assert_in_delta t.replied_at, Time.now.utc, 5.seconds
  end
  
  def test_doesnt_change_replied_at_on_save
    t=Topic.find(:first)
    old=t.replied_at
    assert t.save
    assert_equal old, t.replied_at
  end
  
end
