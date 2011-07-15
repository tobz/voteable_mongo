require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

# Comment
#   voteable self, :up => +1, :down => -3
#   voteable Post, :up => +2, :down => -1
# 
# Post
#   voteable self, :up => +1, :down => -1, :index => true
#   voteable Category, :up => +3, :down => -5, :update_counters => false
# 
# Category
#   voteable self, :index => true

describe Mongo::Voteable do
  
  context 'when :index is passed as an argument' do
    before do
      Post.collection.drop_indexes
      Category.collection.drop_indexes
      
      Post.create_voteable_indexes
      Category.create_voteable_indexes
    end
  
    it 'defines indexes' do
      [Post, Category].each do |klass|
        [ 'votes.up_1__id_1',
          'votes.down_1__id_1'
        ].each { |index_key|
          klass.collection.index_information.should have_key index_key
          klass.collection.index_information[index_key]['unique'].should be_true
        }
  
        [ 'votes.count_-1',
          'votes.up_count_-1',
          'votes.down_count_-1',
          'votes.point_-1'
        ].each { |index_key|
          klass.collection.index_information.should have_key index_key
        }
      end
    end
  end
  
  before :all do
    Mongoid.master.collections.select {|c| c.name !~ /system/ }.each(&:drop)
    @category1 = Category.create!(:name => 'xyz')
    @category2 = Category.create!(:name => 'abc')
    
    @post1 = Post.create!(:title => 'post1')
    @post2 = Post.create!(:title => 'post2')

    @post1.category_ids = [@category1.id, @category2.id]
    @post1.save!

    @comment = @post2.comments.create!
    
    @user1 = User.create!
    @user2 = User.create!
  end
  
  it "cannot vote for unexisting post" do
    @user1.vote(:votee_class => Post, :votee_id => BSON::ObjectId.new, :value => :up).should == false
  end
  

  
  context "just created" do
    it 'up_votes_count, down_votes_count, faceless_up_count, faceless_down_count, votes_count, votes_point' do
      stats_for(@category1, [0,0,0,0,0,0])
      stats_for(@category2, [0,0,0,0,0,0])
      stats_for(@post1, [0,0,0,0,0,0])
      stats_for(@post2, [0,0,0,0,0,0])
      stats_for(@comment, [0,0,0,0,0,0])
    end
    
    it 'up_voter_ids, down_voter_ids should be empty' do
      @category1.up_voter_ids.should be_empty
      @category1.down_voter_ids.should be_empty

      @category2.up_voter_ids.should be_empty
      @category2.down_voter_ids.should be_empty

      @post1.up_voter_ids.should be_empty
      @post1.down_voter_ids.should be_empty

      @post2.up_voter_ids.should be_empty
      @post2.down_voter_ids.should be_empty

      @comment.up_voter_ids.should be_empty
      @comment.down_voter_ids.should be_empty
    end
    
    it 'voted by voter should be empty' do
      Category.voted_by(@user1).should be_empty
      Category.voted_by(@user2).should be_empty

      Post.voted_by(@user1).should be_empty
      Post.voted_by(@user2).should be_empty
      
      Comment.voted_by(@user1).should be_empty
      Comment.voted_by(@user2).should be_empty
    end
        
    it 'revote post1 has no effect' do
      @post1.vote(:revote => true, :voter => @user1, :value => 'up')
      stats_for(@post1, [0,0,0,0,0,0])
    end
    
    it 'revote post2 has no effect' do
      Post.vote(:revote => true, :votee_id => @post2.id, :voter_id => @user2.id, :value => :down)
      stats_for(@post2, [0,0,0,0,0,0])
    end
  end

  # Last stats:
  #   @post1      [0,0,0,0,0,0]
  #   @category1  [0,0,0,0,0,0]
  #   @category2  [0,0,0,0,0,0]
  # 
  context 'user1 vote up post1 the first time' do
    before :all do
      @post = @post1.vote(:voter_id => @user1.id, :value => :up)
    end
    
    it 'returns valid document' do
      @post.should be_is_a Post
      @post.should_not be_new_record

      @post.votes.should == {
        'up' => [@user1.id],
        'down' => [],
        'faceless_up_count' => 0,
        'faceless_down_count' => 0,
        'up_count' => 1,
        'down_count' => 0,
        'count' => 1,
        'point' => 1
      }
    end
    
    it 'stats' do
      stats_for(@post1, [1,0,0,0,1,1])
    end
    
    it 'has voter stats' do
      @post1.vote_value(@user1).should == :up
      @post1.should be_voted_by(@user1)
      @post1.vote_value(@user2.id).should be_nil
      @post1.should_not be_voted_by(@user2.id)
      @post1.up_voters(User).to_a.should == [ @user1 ]
      @post1.voters(User).to_a.should == [ @user1 ]
      @post1.down_voters(User).should be_empty
    end
    
    it "has scopes" do
      Post.voted_by(@user1).to_a.should == [ @post1 ]
      Post.voted_by(@user2).to_a.should be_empty
    end
    
    it "category1 stats" do
      stats_for(@category1, [0,0,0,0,0,3])
    end
    
    it "category2 stats" do
      stats_for(@category2, [0,0,0,0,0,3])
    end
  end
  
  # Last Stats
  #   @post1      [1,0,0,0,1,1]
  #   @category1  [0,0,0,0,0,3]
  #   @category2  [0,0,0,0,0,3]
  # 
  context "user1 vote post1 for the second time" do
    it "has no effect" do
      Post.vote(:revote => false, :votee_id => @post1.id, :voter_id => @user1.id, :value => :up)
      
      stats_for(@post1, [1,0,0,0,1,1])
      @post1.vote_value(@user1.id).should == :up
    end
  end 
  
  # Last Stats
  #   @post1      [1,0,0,0,1,1]
  #   @category1  [0,0,0,0,0,3]
  #   @category2  [0,0,0,0,0,3]
  #
  
  context 'user2 vote down post1 the first time' do
    before :all do
      Post.vote(:votee_id => @post1.id, :voter_id => @user2.id, :value => :down)
      @post1.reload
    end
    
    it "stats" do
      stats_for(@post1, [1,1,0,0,2,0])
    end

    it 'has voters' do
      @post1.vote_value(@user1.id).should == :up
      @post1.vote_value(@user2.id).should == :down
      @post1.up_voters(User).to_a.should == [ @user1 ]
      @post1.down_voters(User).to_a.should == [ @user2 ]
      @post1.voters(User).to_a.should == [ @user1, @user2 ]
    end

    it 'has scopes' do
      Post.voted_by(@user1).to_a.should == [ @post1 ]
      Post.voted_by(@user2).to_a.should == [ @post1 ]
    end
    
    it 'category1 stats' do
      stats_for(@category1, [0,0,0,0,0,-2])
    end
    
    it "category2 stats" do
      stats_for(@category2, [0,0,0,0,0,-2])
    end
  end
  
  # Last Stats
  #   @post1      [1,1,0,0,2,0]
  #   @category1  [0,0,0,0,0,-2]
  #   @category2  [0,0,0,0,0,-2]
  #
  context 'user1 change vote on post1 from up to down' do
    before :all do
      Post.vote(:revote => true, :votee_id => @post1.id, :voter_id => @user1.id, :value => :down)
    end
    
    it 'stats' do
      stats_for(@post1, [0,2,0,0,2,-2])
    end
    
    it 'category1 stats' do
      stats_for(@category1, [0,0,0,0,0,-10])
    end
    
    it 'category2 stats' do
      stats_for(@category2, [0,0,0,0,0,-10])
    end
    
    it 'changes user1 vote' do
      @post1.vote_value(@user1.id).should == :down
    end
    
    it "has scopes" do
      Post.voted_by(@user1).to_a.should == [ @post1 ]
      Post.voted_by(@user2).to_a.should == [ @post1 ]
    end
  end
  
  # Last Stats
  #   @post2      [0,0,0,0,0,0]
  context 'user1 vote down post2 the first time' do
    before :all do
      @post2.vote(:voter_id => @user1.id, :value => :down)
    end
    
    it 'stats' do
      stats_for(@post2, [0,1,0,0,1,-1])
    end
    it "has user1 vote" do
      @post2.vote_value(@user1.id).should == :down
    end
    it "user1 voted for post1 and post2" do
      Post.voted_by(@user1).to_a.should == [ @post1, @post2 ]
    end
  end
  
  # Last stats:
  #   @post2 [0,1,0,0,1,-1]
  #
  context 'user1 change vote on post2 from down to up' do
    before :all do
      Post.vote(:revote => true, :votee_id => @post2.id.to_s, :voter_id => @user1.id.to_s, :value => :up)
    end
    it 'stats' do
      stats_for(@post2, [1,0,0,0,1,1])
    end
    it "changes user1 vote" do
      @post2.vote_value(@user1.id).should == :up
    end
  end
  
  # Last stats:
  #   @post2    [1,0,0,0,1,1]
  #   @comment  [0,0,0,0,0,0]
  # 
  context 'user1 vote up post2 comment the first time' do
    before :all do
      @comment.vote(:voter_id => @user1.id, :value => :up)
    end
    
    it 'post2 stats' do
      stats_for(@post2, [2,0,0,0,2,3])
    end
    
    it 'comment stats' do
      stats_for(@comment, [1,0,0,0,1,1])
    end
  end
  
  # Last stats:
  #   @post2    [2,0,0,0,2,3]
  #   @comment  [1,0,0,0,1,1]
  #
  context 'user1 revote post2 comment from up to down' do
    before :all do
      @user1.vote(:votee => @comment, :value => :down)
      @comment.reload
      @post2.reload
    end
    
    it 'post2 stats' do
      stats_for(@post2, [1,1,0,0,2,0])
    end
    it 'comment stats' do
      stats_for(@comment, [0,1,0,0,1,-3])
    end
  end
  
  # Last stats:
  #   @post2    [1,1,0,0,2,0]
  #   @comment  [0,1,0,0,1,-3]
  #
  context "user1 revotes comment with same vote" do
    it 'has no effect' do
      stats_for(@post2, [1,1,0,0,2,0])
      stats_for(@comment, [0,1,0,0,1,-3])
    end
  end
  
  # Last stats:
  #   @post1, [0,2,0,0,2,-2]
  #
  context "user1 unvote on post1" do
    before(:all) do
      @post1.vote(:voter_id => @user1.id, :votee_id => @post1.id, :unvote => true)
    end
    
    it 'stats' do
      stats_for(@post1, [0,1,0,0,1,-1])
    end
    
    it 'removes user1 from voters' do
      @post1.vote_value(@user1.id).should be_nil
      Post.voted_by(@user1).to_a.should_not include(@post1)
    end      
  end
  
  # Last stats:
  #   @post2    [1,1,0,0,2,0]
  #   @comment  [0,1,0,0,1,-3]
  #
  context "user1 unvote on comment" do
    before(:all) do
      @user1.unvote(@comment)
    end
    
    it "comment stats" do      
      stats_for(@comment, [0,0,0,0,0,0])
    end
    it "post2 stats" do
      stats_for(@post2, [1,0,0,0,1,1])
    end
  end
  
  # Last stats:
  #   @post1    [0,1,0,0,1,-1]
  #   @post2    [1,0,0,0,1,1]
  #   @comment  [0,0,0,0,0,0]
  #
  describe 'test remake stats' do
    before(:all) do
      # Mongo::Voteable::Tasks.remake_stats
    end
    it "@post1 == last stats" do
      stats_for(@post1, [0,1,0,0,1,-1])
    end
    it "@post2 == last stats" do
      stats_for(@post2, [1,0,0,0,1,1])
    end
    it "@comment == last stats" do
      stats_for(@comment, [0,0,0,0,0,0])
    end  
  end
end
