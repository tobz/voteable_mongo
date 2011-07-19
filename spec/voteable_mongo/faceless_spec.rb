require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Mongo::Voteable, "Anonymous support" do
  before(:all) do
    Mongoid.master.collections.select {|c| c.name !~ /system/ }.each(&:drop)
    # for anonymous voting tests
    @category1 = Category.create!(:name => '123')
    @category2 = Category.create!(:name => '456')
    @post1 = Post.create!(:title => 'post11')
    @post2 = Post.create!(:title => 'post21')
    @post1.category_ids = [@category1.id, @category2.id]
    @post1.save!
    @comment = @post2.comments.create!
    @user1 = User.create
  end
  
  context 'anonymous vote up post1 the first time' do
     before :all do
       @post = @post1.set_vote(:value => :up, :ip => "200")
     end
     it 'validates return post' do
       @post.should be_is_a Post
       @post.should_not be_new_record
   
       @post.votes.should == {
         'up' => [],
         'down' => [],
         'faceless_up_count' => 1,
         'faceless_down_count' => 0,
         'up_count' => 0,
         'down_count' => 0,
         'total_up_count' => 1,
         'total_down_count' => 0,
         'count' => 1,
         'point' => 1,
         'ip' => ["200"]
       }
     end
     it 'post1 stats' do
       stats_for(@post1, [0,0,1,0,1,0,1,1])
     end
     
     it "post1 votes ratio is 1" do
       @post1.votes_ratio.should == 1
     end
     
     it "validates voters stats" do
       @post1.up_voters(User).to_a.should be_empty
       @post1.voters(User).to_a.should be_empty
       @post1.down_voters(User).should be_empty
     end
     
     it "category1 stats" do
       stats_for(@category1, [0,0,0,0,0,0,0,3])
     end
     
     it "category2 stats" do
       stats_for(@category2, [0,0,0,0,0,0,0,3])
     end
   end
   
   context "anonymous user voting in @post1 with same IP" do
     before(:all) do
       @post = @post1.set_vote(:value => :up, :ip => "200")
     end
     it "does not have any effect on @post1" do
       stats_for(@post1, [0,0,1,0,1,0,1,1])
     end
     it "does not have any effect on @category1" do
       stats_for(@category1, [0,0,0,0,0,0,0,3])
     end
     it "does not have any effect on @category2" do
       stats_for(@category2, [0,0,0,0,0,0,0,3])
     end
   end
   
   # Last stats:
   #   @post1      [0,0,1,0,1,0,1,1]
   #   @category1  [0,0,0,0,0,0,0,3]
   #   @category2  [0,0,0,0,0,0,0,3]
   #
   context "anonymous votes down post1 the first time" do
     before :all do
       Post.set_vote(:votee_id => @post1.id, :value => :down, :ip => "201")
     end
     
     it "post1 stats" do
       stats_for(@post1, [0,0,1,1,1,1,2,0])
     end
     
     it "post1 votes ratio is 0.5" do
       @post1.votes_ratio.should == 0.5
     end
     
     it "category1 stats" do
       stats_for(@category1, [0,0,0,0,0,0,0,-2])
     end
     
     it "category2 stats" do
       stats_for(@category1, [0,0,0,0,0,0,0,-2])
     end
   end
   
   # Last stats:
   #   @post1      [0,0,1,1,1,1,2,0]
   #   @category1  [0,0,0,0,0,0,0,-2]
   #   @category2  [0,0,0,0,0,0,0,-2]
   #
   context "user1 votes down post1 the first time" do
     before :all do
       @user1.vote(@post1, :down)
     end
     
     it "post1 stats" do
       stats_for(@post1, [0,1,1,1,1,2,3,-1])
     end
     
     it "post1 votes ratio is 0.3" do
       @post1.votes_ratio.should be_within(0.1).of(0.3)
     end
     
     it "category1 stats" do
       stats_for(@category1, [0,0,0,0,0,0,0,-7])
     end
     
     it "category2 stats" do
       stats_for(@category1, [0,0,0,0,0,0,0,-7])
     end
   end
   # Last stats:
   #   @post1      [0,1,1,1,1,2,3,-1]
   #   @category1  [0,0,0,0,0,0,0,-7]
   #   @category2  [0,0,0,0,0,0,0,-7]
   #
   context "user1 changes vote on post1 from down to up" do
     before :all do
       Post.set_vote(:votee_id => @post1.id, :voter_id => @user1.id, :value => :up, :revote => true)
     end
     
     it "post1 stats" do
       stats_for(@post1, [1,0,1,1,2,1,3,1])
     end
     
     it "post1 votes ratio is 0.7" do
       @post1.votes_ratio.should be_within(0.1).of(0.7)
     end
     
     it "category1 stats" do
       stats_for(@category1, [0,0,0,0,0,0,0,1])
     end
     
     it "category2 stats" do
       stats_for(@category1, [0,0,0,0,0,0,0,1])
     end
   end
   
   # Last stats:
   #   @post2      [0,0,0,0,0,0,0,0]
   #   @comment    [0,0,0,0,0,0,0,0]
   #   @category2  [0,0,0,0,0,0,0,3]
   #
   context 'anonymous vote up for comment the first time' do
     before :all do
       @comment.set_vote(:value => :up)
     end
     its "post2 stats" do
       stats_for(@post2, [0,0,1,0,1,0,1,2])
     end
     it "comment stats" do
       stats_for(@comment, [0,0,1,0,1,0,1,1])
     end
   end
end