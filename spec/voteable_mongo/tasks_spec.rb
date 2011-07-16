require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Mongo::Voteable::Tasks do
  before :all do
    @post1 = Post.create!(:title => 'post1')
    @post2 = Post.create!(:title => 'post2')
    @post3 = Post.create!(:title => 'post3')
    @image1 = @post1.images.create!
    @image2 = @post2.images.create!
  end

  it 'after create votes has default value' do
    @post1.votes.should == ::Mongo::Voteable::DEFAULT_VOTES
    @post2.votes.should == ::Mongo::Voteable::DEFAULT_VOTES
    @post3.votes.should == ::Mongo::Voteable::DEFAULT_VOTES
    @image1.votes.should == ::Mongo::Voteable::DEFAULT_VOTES
    @image2.votes.should == ::Mongo::Voteable::DEFAULT_VOTES
  end
  
  it 'changes data' do
    @post1.votes = nil
    @post1.save
    
    @post2.votes = nil
    @post2.save
    
    @post3.vote(:value => :up)
    
    @image1.votes = nil
    @image1.save
    
    @image2.vote(:value => :down)
  end
  
  describe ".init_stats" do
    before(:all) do
      ::Mongo::Voteable::Tasks.init_stats
    end
    it 'init_stats recover votes default value' do
      @post1.reload
      @post2.reload
      @image1.reload
      @post1.votes.should == ::Mongo::Voteable::DEFAULT_VOTES
      @post2.votes.should == ::Mongo::Voteable::DEFAULT_VOTES
      @image1.votes.should == ::Mongo::Voteable::DEFAULT_VOTES
    end
    it "does preserves votes" do
      @post3.reload
      @post3.votes.should_not == ::Mongo::Voteable::DEFAULT_VOTES
      @image2.reload
      @image2.votes.should_not == ::Mongo::Voteable::DEFAULT_VOTES
    end
  end
  describe ".reset_stats" do
    before(:all) do
      @image1.votes = nil
      @image1.save
      ::Mongo::Voteable::Tasks.reset_stats(Image)
    end
    it 'recover votes default value for all documents' do
      @image1.reload; @image2.reload;@post2.reload;
      @post2.votes.should == ::Mongo::Voteable::DEFAULT_VOTES
      @image1.votes.should == ::Mongo::Voteable::DEFAULT_VOTES
      @image2.votes.should == ::Mongo::Voteable::DEFAULT_VOTES
    end
  end
end
