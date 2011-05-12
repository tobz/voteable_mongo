require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Mongo::Voteable::Tasks do
  describe 'Mongo::Voteable::Tasks.init_stats' do
    before :all do
      @post1 = Post.create!(:title => 'post1')
      @post2 = Post.create!(:title => 'post2')
    end

    it 'after create votes has default value' do
      @post1.votes.should == ::Mongo::Voteable::DEFAULT_VOTES
      @post2.votes.should == ::Mongo::Voteable::DEFAULT_VOTES
    end
    
    it 'reset votes data' do
      @post1.votes = nil
      @post1.save

      @post2.votes = nil
      @post2.save
    end
    
    it 'init_stats recover votes default value' do
      ::Mongo::Voteable::Tasks.init_stats
      ::Mongo::Voteable::Tasks.migrate_old_votes

      @post1.reload
      @post2.reload

      @post1.votes.should == ::Mongo::Voteable::DEFAULT_VOTES
      @post2.votes.should == ::Mongo::Voteable::DEFAULT_VOTES
    end
  end
end
