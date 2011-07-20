require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Mongo::Voteable, "Dynamic fields" do
  before :all do
    Mongoid.master.collections.select {|c| c.name !~ /system/ }.each(&:drop) if defined? Mongoid
    @user = User.create!
    @dynamic_doc = @user.dynamic_docs.create!
    @video = @dynamic_doc.videos.create!
    @post1 = Post.create!(:title => 'post1')
    @user2 = User.create!
    
  end
  
  describe "Post using default voting_field" do
    context 'user1 vote up post1 the first time' do
      before :all do
        @post = @post1.set_vote(:voter_id => @user.id, :value => :up)
      end

      it 'returns valid document' do
        @post.should be_is_a Post
        @post.should_not be_new_record

        @post.votes.should == {
          'up' => [@user.id],
          'down' => [],
          'faceless_up_count' => 0,
          'faceless_down_count' => 0,
          'up_count' => 1,
          'down_count' => 0,
          'total_up_count' => 1,
          'total_down_count' => 0,
          'count' => 1,
          'point' => 1,
          'ratio' => 1,
          'ip' => []
        }
      end

      it 'stats' do
        stats_for(@post1, [1,0,0,0,1,0,1,1])
      end
      
      it "post1 votes ratio is 1" do
        @post1.votes_ratio.should == 1
      end

      it 'has voter stats' do
        @post1.vote_value(@user).should == :up
        @post1.should be_voted_by(@user)
        @post1.up_voters(User).to_a.should == [ @user ]
        @post1.voters(User).to_a.should == [ @user ]
        @post1.down_voters(User).should be_empty
      end

      it "has scopes" do
        Post.voted_by(@user).to_a.should == [ @post1 ]
      end
    end
  end
  
  describe "DynamicDoc using Moderations" do
    context "when initializing" do
      it "defines dynamic field" do
        @dynamic_doc.should respond_to :moderations
      end
      it "does not respond to fields defined for parents" do
        @dynamic_doc.should_not respond_to :points
      end
      it "dynamic fields initialized with default valued" do
        stats_for(@dynamic_doc, [0,0,0,0,0,0,0,0], "moderations")
      end
      it 'has empty up_voter_ids, down_voter_ids ' do
        @dynamic_doc.up_voter_ids("moderations").should be_empty
        @dynamic_doc.down_voter_ids("moderations").should be_empty
      end
    
      it 'voted by voter is empty' do
        DynamicDoc.voted_by(@user, "moderations").should be_empty
      end
    end
  
    # Last stats:
    #   @dynamic_doc(moderations)      [0,0,0,0,0,0,0,0]
    #   @user(moderations)             [0,0,0,0,0,0,0,0]
    context 'user votes up dynamic_doc the first time' do
      before :all do
        @doc = @dynamic_doc.set_vote(:voter_id => @user.id, :value => :up, :voting_field => "moderations")
      end
    
      it 'returns valid document' do
        @doc.should be_is_a DynamicDoc
        @doc.should_not be_new_record

        @doc.moderations.should == {
          'up' => [@user.id],
          'down' => [],
          'faceless_up_count' => 0,
          'faceless_down_count' => 0,
          'up_count' => 1,
          'down_count' => 0,
          'total_up_count' => 1,
          'total_down_count' => 0,
          'count' => 1,
          'point' => 1,
          'ratio' => 1,          
          'ip' => []
        }
      end
    
      it 'dynamic_doc stats' do
        stats_for(@dynamic_doc, [1,0,0,0,1,0,1,1], "moderations")
      end
      
      it "dynamic_doc votes ratio is 1" do
        @dynamic_doc.votes_ratio("moderations").should == 1
      end
    
      it 'has voter stats' do
        @dynamic_doc.vote_value(@user, "moderations").should == :up
        @dynamic_doc.should be_voted_by(@user, "moderations")
        @dynamic_doc.up_voters(User, "moderations").to_a.should == [ @user ]
        @dynamic_doc.voters(User, "moderations").to_a.should == [ @user ]
        @dynamic_doc.down_voters(User, "moderations").should be_empty
      end
    
      it "has scopes" do
        DynamicDoc.voted_by(@user, "moderations").to_a.should == [ @dynamic_doc ]
      end
      
      it "User stats" do
        stats_for(@user, [1,0,0,0,1,0,1,5], "points")
      end
    end
    # Last Stats
    #   @dynamic_field      [1,0,0,0,1,0,1,1]
    # 
    context "user1 vote post1 for the second time" do
      it "has no effect" do
        DynamicDoc.set_vote(:revote => false, :votee_id => @dynamic_doc.id, :voter_id => @user.id, :value => :up, :voting_field => "moderations")

        stats_for(@dynamic_doc, [1,0,0,0,1,0,1,1], 'moderations')
        @dynamic_doc.vote_value(@user.id, 'moderations').should == :up
      end
    end
    
    # Last Stats
    #   @dynamic_doc(moderations)      [1,0,0,0,1,0,1,1]
    #   @user(likes)                   [1,0,0,0,1,0,1,5]
    context 'user2 vote down post1 the first time' do
      before :all do
        DynamicDoc.set_vote(:votee_id => @dynamic_doc.id, :voter_id => @user2.id, :value => :down, :voting_field => "moderations")
      end

      it "stats" do
        stats_for(@dynamic_doc, [1,1,0,0,1,1,2,0], "moderations")
      end
      
      it "dynamic_doc votes ratio is 0.5" do
        @dynamic_doc.votes_ratio("moderations").should == 0.5
      end

      it 'has voters' do
        @dynamic_doc.vote_value(@user.id, "moderations").should == :up
        @dynamic_doc.vote_value(@user2.id, "moderations").should == :down
        @dynamic_doc.up_voters(User, "moderations").to_a.should == [ @user ]
        @dynamic_doc.down_voters(User, "moderations").to_a.should == [ @user2 ]
        @dynamic_doc.voters(User, "moderations").to_a.should == [ @user, @user2 ]
      end

      it 'has scopes' do
        DynamicDoc.voted_by(@user, "moderations").to_a.should == [ @dynamic_doc ]
        DynamicDoc.voted_by(@user2, "moderations").to_a.should == [ @dynamic_doc ]
      end
      it "User stats" do
        stats_for(@user, [1,1,0,0,1,1,2,0], "points")
      end
    end
    # Last Stats
    #   @dynamic_doc(moderations)      [1,1,0,0,1,1,2,0]
    #   @user(likes)                   [1,1,0,0,1,1,2,0]
    context 'user change vote on dynamic_doc from up to down' do
      before :all do
        DynamicDoc.set_vote(:revote => true, :votee_id => @dynamic_doc.id, :voter_id => @user.id, :value => :down, :voting_field => "moderations")
      end

      it 'stats' do
        stats_for(@dynamic_doc, [0,2,0,0,0,2,2,-2], "moderations")
      end
      
      it "dynamic_doc votes ratio is 0" do
        @dynamic_doc.votes_ratio("moderations").should == 0
      end
      
      it 'changes user1 vote' do
        @dynamic_doc.vote_value(@user.id, "moderations").should == :down
      end

      it "has scopes" do
        DynamicDoc.voted_by(@user, "moderations").to_a.should == [ @dynamic_doc ]
        DynamicDoc.voted_by(@user2, "moderations").to_a.should == [ @dynamic_doc ]
      end
      it "User stats" do
        stats_for(@user, [0,2,0,0,0,2,2,-10], "points")
      end
    end
    
    # Last stats:
    #   @dynamic_doc(moderations) [0,2,0,0,0,2,2,-2]
    #   @user(moderations)        [0,2,0,0,0,2,2,-10]
    # 
    context "user unvote on dynamic_doc" do
      before(:all) do
        @dynamic_doc.set_vote(:voter_id => @user.id, :votee_id => @dynamic_doc.id, :unvote => true, :voting_field => "moderations")
      end

      it 'dynamic moderations stats' do
        stats_for(@dynamic_doc, [0,1,0,0,0,1,1,-1], "moderations")
      end
      
      it "dynamic_doc votes ratio is 0" do
        @dynamic_doc.votes_ratio("moderations").should == 0
      end

      it 'removes user1 from voters' do
        @dynamic_doc.vote_value(@user.id, "moderations").should be_nil
        DynamicDoc.voted_by(@user, "moderations").to_a.should_not include(@dynamic_doc)
      end 
      it "User points stats" do
        stats_for(@user, [0,1,0,0,0,1,1,-5], "points")
      end     
    end
  end
  describe "DynamicDoc using likes" do
    context "when initializing" do
      it "defines dynamic field" do
        @dynamic_doc.should respond_to :likes
      end
      it "dynamic fields initialized with default valued" do
        stats_for(@dynamic_doc, [0,0,0,0,0,0,0,0], "likes")
      end
      it "dynamic_doc votes on likes ratio is 0" do
        @dynamic_doc.votes_ratio("likes").should == 0
      end
      it 'has empty up_voter_ids, down_voter_ids ' do
        @dynamic_doc.up_voter_ids("likes").should be_empty
        @dynamic_doc.down_voter_ids("likes").should be_empty
      end
    
      it 'voted by voter is empty' do
        DynamicDoc.voted_by(@user, "likes").should be_empty
      end
    end
  
    # Last stats:
    #   @dynamic_doc(likes)      [0,0,0,0,0,0,0,0]
    #   @user(points)            [0,1,0,0,0,1,1,-5]
    context 'user votes up dynamic_doc the first time' do
      before :all do
        @doc = @dynamic_doc.set_vote(:voter_id => @user.id, :value => :up, :voting_field => "likes")
      end
    
      it 'returns valid document' do
        @doc.should be_is_a DynamicDoc
        @doc.should_not be_new_record

        @doc.likes.should == {
          'up' => [@user.id],
          'down' => [],
          'faceless_up_count' => 0,
          'faceless_down_count' => 0,
          'up_count' => 1,
          'down_count' => 0,
          'total_up_count' => 1,
          'total_down_count' => 0,
          'count' => 1,
          'point' => 2,
          'ratio' => 1,
          'ip' => []
        }
      end
    
      it 'dynamic like stats' do
        stats_for(@dynamic_doc, [1,0,0,0,1,0,1,2], "likes")
      end
      
      it "dynamic_doc votes on likes ratio is 1" do
        @dynamic_doc.votes_ratio("likes").should == 1
      end
    
      it 'has voter stats' do
        @dynamic_doc.vote_value(@user, "likes").should == :up
        @dynamic_doc.should be_voted_by(@user, "likes")
        @dynamic_doc.up_voters(User, "likes").to_a.should == [ @user ]
        @dynamic_doc.voters(User, "likes").to_a.should == [ @user ]
        @dynamic_doc.down_voters(User, "likes").should be_empty
      end
    
      it "has scopes" do
        DynamicDoc.voted_by(@user, "likes").to_a.should == [ @dynamic_doc ]
      end
      it "user points stats is the same" do
        stats_for(@user, [1,1,0,0,1,1,2,0], "points")
      end
    end
  end
  describe "Embedded operations" do
    context "video just created" do
      it "responds to dynamic field" do
        @video.should respond_to :reviews
      end
      it 'video stats' do
        stats_for(@video, [0,0,0,0,0,0,0,0], "reviews")
      end
      it "video votes on reviews ratio is 0" do
        @video.votes_ratio("reviews").should == 0
      end
      it "responds to embedded doc" do
        @dynamic_doc.should respond_to :videos
      end

      it 'up_voter_ids, down_voter_ids should be empty' do
        @video.up_voter_ids("reviews").should be_empty
        @video.down_voter_ids("reviews").should be_empty
        @video.up_voter_ids("reviews").should be_empty
        @video.down_voter_ids("reviews").should be_empty
      end
    end
    
    # Last stats:
    #   @video                         [0,0,0,0,0,0,0,0]
    #   @dynamic_doc(moderations)      [0,1,0,0,0,1,1,-1]
    #   @dynamic_doc(likes)            [1,0,0,0,1,0,1,2]
    # 
    context 'user1 vote up video the first time' do
      before :all do
        @doc = @video.set_vote(:voter_id => @user.id, :value => :up, :voting_field => "reviews")
      end

      it 'returns valid document' do
        @doc.should be_is_a Video
        @doc.should_not be_new_record
        @doc.save
        @doc.reviews.should == {
          'up' => [@user.id],
          'down' => [],
          'faceless_up_count' => 0,
          'faceless_down_count' => 0,
          'up_count' => 1,
          'down_count' => 0,
          'total_up_count' => 1,
          'total_down_count' => 0,
          'count' => 1,
          'point' => 1,
          'ratio' => 1,
          'ip' => []
        }
      end

      it 'video stats' do
        stats_for(@video, [1,0,0,0,1,0,1,1], "reviews")
      end
      it "video votes ratio on likes is 1" do
        @video.votes_ratio("reviews").should == 1
      end
      
      it 'has voter stats' do
        @video.vote_value(@user, "reviews").should == :up
        @video.should be_voted_by(@user, "reviews")
        @video.up_voters(User, "reviews").to_a.should == [ @user ]
        @video.voters(User, "reviews").to_a.should == [ @user ]
        @video.down_voters(User, "reviews").should be_empty
      end
      
      it "dynamicdoc moderation stats" do
        stats_for(@dynamic_doc, [1,1,0,0,1,1,2,1], "moderations")
      end
      
      it "video votes ratio on moderations is 0.5" do
        @dynamic_doc.votes_ratio("moderations").should == 0.5
      end
      
      it "does not update likes stats" do
        stats_for(@dynamic_doc, [1,0,0,0,1,0,1,2], "likes")
      end
      
      it "dynamic_doc votes ratio on likes is 1" do
        @dynamic_doc.votes_ratio("likes").should == 1
      end
    end
  end
end

