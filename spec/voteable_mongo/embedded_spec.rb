require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Mongo::Voteable, "Embedded Documents" do

  before :all do
    Mongoid.master.collections.select {|c| c.name !~ /system/ }.each(&:drop)
    @post1 = Post.create!(:title => 'post1')
    @post2 = Post.create!(:title => 'post2')
    
    @user1 = User.create!
    @user2 = User.create!
    
    @image1 = @post1.images.create(:url => "image1") 
    @image2 = @post1.images.create(:url => "image2") 
    @image3 = @post2.images.create(:url => "image3") 
  end

  context "just created" do
    it 'image1 stats' do
      stats_for(@image1, [0,0,0,0,0,0])
    end
    it "image2 stats" do
      stats_for(@image2, [0,0,0,0,0,0])
    end
    it "post1 stats" do
      stats_for(@post1, [0,0,0,0,0,0])
    end
    it "post2 stats" do
      stats_for(@post1, [0,0,0,0,0,0])
    end
    
    it 'up_voter_ids, down_voter_ids should be empty' do
      @image1.up_voter_ids.should be_empty
      @image1.down_voter_ids.should be_empty
      @image2.up_voter_ids.should be_empty
      @image2.down_voter_ids.should be_empty
      @post1.up_voter_ids.should be_empty
      @post1.down_voter_ids.should be_empty
      @post2.up_voter_ids.should be_empty
      @post2.down_voter_ids.should be_empty
    end
  end
  context "revote post1" do
    it 'has no effect' do
      @post1.vote(:revote => true, :voter => @user1, :value => 'up')
      stats_for(@image1, [0,0,0,0,0,0])
    end
  end
  context "revote post2" do
    it 'has no effect' do
      Image.vote(:revote => true, :votee_id => @image2.id, :voter_id => @user2.id, :value => :down)
      stats_for(@image1, [0,0,0,0,0,0])
    end
  end
  
  # Last stats:
  #   @image1     [0,0,0,0,0,0]
  #   @post1      [0,0,0,0,0,0]
  #
  context 'user1 vote up image1 the first time' do
    before :all do
      @image = @image1.vote(:voter_id => @user1.id, :value => :up)
    end
    
    it 'returns valid document' do
      @image.should be_is_a Image
      @image.should_not be_new_record
      @image.save
      @image.votes.should == {
        'up' => [@user1.id],
        'down' => [],
        'faceless_up_count' => 0,
        'faceless_down_count' => 0,
        'up_count' => 1,
        'down_count' => 0,
        'count' => 1,
        'point' => 1,
        'ip' => []
      }
    end
    
    it 'image1 stats' do
      stats_for(@image1, [1,0,0,0,1,1])
    end
    it 'has voter stats' do
      @image1.vote_value(@user1).should == :up
      @image1.should be_voted_by(@user1)
      @image1.vote_value(@user2.id).should be_nil
      @image1.should_not be_voted_by(@user2.id)
      @image1.up_voters(User).to_a.should == [ @user1 ]
      @image1.voters(User).to_a.should == [ @user1 ]
      @image1.down_voters(User).should be_empty
    end
    it "post1 stats" do
      stats_for(@post1, [1,0,0,0,1,2])
    end
  end
  
  # Last stats:
  #   @image1     [1,0,0,0,1,1]
  #   @post1      [1,0,0,0,1,2]
  #
  context "user1 votes image1 again" do
    it 'has no effect' do
      Image.vote(:revote => false, :votee_id => @image1.id, :voter_id => @user1.id, :value => :up)
      stats_for(@image1, [1,0,0,0,1,1])
      stats_for(@post1, [1,0,0,0,1,2])
      @image1.vote_value(@user1.id).should == :up
    end
  end
  
  # Last stats:
  #   @image1     [1,0,0,0,1,1]
  #   @post1      [1,0,0,0,1,2]
  #
  context 'user2 vote down image1 the first time' do
     before :all do
       Image.vote(:votee_id => @image1.id, :voter_id => @user2.id, :value => :down)
     end
     
     it "image1 stats" do
       stats_for(@image1, [1,1,0,0,2,0])
     end
     it "post1 stats" do
       stats_for(@post1, [1,1,0,0,2,1])
     end

     it 'has voters' do
       @image1.vote_value(@user1.id).should == :up
       @image1.vote_value(@user2.id).should == :down
       @image1.up_voters(User).to_a.should == [ @user1 ]
       @image1.down_voters(User).to_a.should == [ @user2 ]
       @image1.voters(User).to_a.should == [ @user1, @user2 ]
     end
   end
   
   # Last Stats
   #   @image1      [1,1,0,0,2,0]
   #   @post1       [1,1,0,0,2,1]
   #
   context 'user1 change vote on image1 from up to down' do
     before :all do
       Image.vote(:revote => true, :votee_id => @image1.id, :voter_id => @user1.id, :value => :down)
     end
     it 'image1 stats' do
       stats_for(@image1, [0,2,0,0,2,-2])
     end
     it "post1 stats" do
       stats_for(@post1, [0,2,0,0,2,-2])
     end
   end
   
   # Last Stats
   #   @image2      [0,0,0,0,0,0]
   #   @post1       [0,2,0,0,2,-2]
   #
   context 'user1 vote down image2 the first time' do
     before :all do
       @image2.vote(:voter_id => @user1.id, :value => :down)
     end

     it "image2 stats" do
       stats_for(@image2, [0,1,0,0,1,-1])
     end
     
     it "post1 stats" do
       stats_for(@post1, [0,3,0,0,3,-3])
     end
   end
   
   # Last Stats
   #   @image2      [0,1,0,0,1,-1]
   #   @post1       [0,3,0,0,3,-3]
   #
   context 'user1 change vote on image2 from down to up' do
     before :all do
       Image.vote(:revote => true, :votee_id => @image2.id.to_s, :voter_id => @user1.id.to_s, :value => :up)
     end
     
     it "image2 stats" do
       stats_for(@image2, [1,0,0,0,1,1])
     end
     
     it "post1 stats" do
       stats_for(@post1, [1,2,0,0,3,0])
     end
   end
   
   # Last Stats
   #   @image3      [0,0,0,0,0,0]
   #   @post2       [0,0,0,0,0,0]
   #
   context 'user1 vote up post2 image3 the first time' do
     before :all do
       # @image3.vote(:voter_id => @user1.id, :value => :up)
       @user1.vote(@image3, :up)
     end
     it "image3 stats" do
       stats_for(@image3, [1,0,0,0,1,1])
     end
     
     it "post2 stats" do
       stats_for(@post2, [1,0,0,0,1,2])
     end
   end
   
   # Last Stats
   #   @image1      [0,2,0,0,2,-2]
   #   @post1       [1,2,0,0,3,0]
   #
   context "user1 unvote on image1" do
     before(:all) do
       @image1.vote(:voter_id => @user1.id, :votee_id => @image1.id, :unvote => true)
     end
     
     it "image1 stats" do
       stats_for(@image1, [0,1,0,0,1,-1])
     end
     
     it "post1 stats" do
       stats_for(@post1, [1,1,0,0,2,1])
     end
   end
   
   # Last Stats
   #   @image3      [1,0,0,0,1,1]
   #   @post2       [1,0,0,0,1,2]
   #
   context "user1 unvote on image3" do
     before(:all) do
       # @image3.vote(:voter_id => @user1.id, :unvote => true)
       @user1.unvote(:votee => @image3)
     end

     it "image3 stats" do      
      stats_for(@image3, [0,0,0,0,0,0])
     end
     it "post2 stats" do
       stats_for(@post2, [0,0,0,0,0,0])
     end
   end
   
   describe 'test remake stats' do
     before(:all) do
       Mongo::Voteable::Tasks.remake_stats
       [@image1, @image2, @image3, @post1, @post2].map(&:reload)
     end

     it "@image1 == last stats" do
       stats_for(@image1, [0,1,0,0,1,-1])
     end
     it "@image2 == last stats" do
       stats_for(@image2, [1,0,0,0,1,1])
     end
     it "@image3 == last stats" do
       stats_for(@image3, [0,0,0,0,0,0])
     end  
     it "@post1 == last stats" do
        stats_for(@post1, [1,1,0,0,2,1])
     end
     it "@post2 == last stats" do
        stats_for(@post2, [0,0,0,0,0,0])
     end

   end
end
