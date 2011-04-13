require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Mongoid::Voteable::Tasks do
  describe 'Mongoid::Voteable::Tasks.init_stats' do
    before :all do
      @post1 = Post.create!
      @post2 = Post.create!
    end

    it 'after create votes has default value' do
      @post1.votes.should == Mongoid::Voteable::Votes::DEFAULT_ATTRIBUTES
      @post2.votes.should == Mongoid::Voteable::Votes::DEFAULT_ATTRIBUTES
    end
    
    it 'reset votes data' do
      @post1.votes = nil
      @post1.save

      @post2.votes = nil
      @post2.save
    end
    
    it 'init_stats recover votes default value' do
      Mongoid::Voteable::Tasks.init_stats

      @post1.reload
      @post2.reload
    
      @post1.votes.should == Mongoid::Voteable::Votes::DEFAULT_ATTRIBUTES
      @post2.votes.should == Mongoid::Voteable::Votes::DEFAULT_ATTRIBUTES
    end
  end
end
