#!ruby
module Kambi::Models
  # include Kambi::Helpers
  # include Kambi::Controllers
  # include Kambi::Views
    class Page < Base
      has_many :references, :foreign_key => "page_id"
      has_many :clips, :through => :references
      validates_presence_of :title, :nickname
      validates_uniqueness_of :nickname
      validates_length_of :nickname, :minimum =>4, :too_short=>"please enter at least %d character"
      has_many :taggings, :as => :taggable
      has_many :tags, :through => :taggings
      
      def to_s
      	title
      end
    end
      
    class Post < Base
      has_many :comments, :order => 'created_at ASC'
      has_many :references, :foreign_key => "post_id"
      has_many :clips, :through => :references#, :source => :clip
      validates_presence_of :title, :nickname
      validates_uniqueness_of :nickname
      validates_length_of :nickname, :minimum =>4, :too_short=>"please enter at least %d character"
      has_many :taggings, :as => :taggable
      has_many :tags, :through => :taggings
      has_many :authorships, :foreign_key => "post_id"
      has_many :authors, :through => :authorships
      
      def pretty_time
        self.created_at.strftime("%A %B %d, %Y at %I %p")
      end
      
      def to_s
      	title
      end
    end
  
    class Clip < Base
      has_many :references, :foreign_key => "clip_id"
      has_many :posts, :through => :references#, :source => :post
      has_many :pages, :through => :references
      validates_presence_of :url, :nickname
      validates_uniqueness_of :nickname
      validates_length_of :nickname, :minimum =>4, :too_short=>"please enter at least %d character"
      has_many :taggings, :as => :taggable
      has_many :tags, :through => :taggings
      
      def to_s
      	nickname
      end
    end
    
    class Reference < Base
      belongs_to :clip, :class_name => "Clip",    :foreign_key => "clip_id"
      belongs_to :post, :class_name => "Post",    :foreign_key => "post_id"
      belongs_to :page, :class_name => "Page",    :foreign_key => "page_id"
    end
  
    class Comment < Base
      validates_presence_of :username
      validates_length_of :body, :within => 1..3000
      belongs_to :post
      
      def pretty_time
        self.created_at.strftime("%A %B %d, %Y at %I:%M %p")
      end
    end
    
    class Tagging < Base
      belongs_to :tag
      belongs_to :taggable, :polymorphic => true
      belongs_to :clip,   :class_name => "Clip",    :foreign_key => "taggable_id"
      belongs_to :post,   :class_name => "Post",    :foreign_key => "taggable_id"
      belongs_to :page,   :class_name => "Page",    :foreign_key => "taggable_id"
      belongs_to :author, :class_name => "Author",  :foreign_key => "taggable_id"
    end

    class Tag < Base
      validates_presence_of :name
      has_many :taggings
      has_many :clips,    :through => :taggings, :source => :clip,    :conditions => "kambi_taggings.taggable_type = 'Clip'"
      has_many :posts,    :through => :taggings, :source => :post,    :conditions => "kambi_taggings.taggable_type = 'Post'"
      has_many :pages,    :through => :taggings, :source => :page,    :conditions => "kambi_taggings.taggable_type = 'Page'"
      has_many :authors,  :through => :taggings, :source => :author,  :conditions => "kambi_taggings.taggable_type = 'Author'"
      
      def taggables
        self.taggings.collect{|t| t.taggable}
      end
      
      def to_s
      	name
      end
    end
    
    class Author < Base
      validates_presence_of :first, :last, :bio
      has_many :authorships, :foreign_key => "author_id"
      has_many :posts, :through => :authorships#, :source => :post
      has_many :taggings, :as => :taggable
      has_many :tags, :through => :taggings
      
      def name
      	# return nil for new authors, full name for existing
      	(self.id.nil?) ? nil : self.first + " " + self.last
      end
      
      def to_s
      	name
      end
    end
    
    class Authorship < Base
      belongs_to :author, :class_name => "Author",    :foreign_key => "author_id"
      belongs_to :post, :foreign_key => "post_id"#:class_name => "Post",
    end
    
    class User < Base; end

    class CreateTheBasics < V 1.7
      def self.up
        create_table :kambi_authors, :force => true do |table|
          table.string :first, :last, :url, :photo_url, :org, :org_url
          table.text :bio
        end
        
        create_table :kambi_authorships, :force => true do |table|
          table.integer :author_id
          table.integer :post_id
        end
        
        create_table :kambi_users, :force => true do |table|
          table.string :username, :password
        end
        User.create :username => 'camper', :password => 'mepemepe'
        
        create_table :kambi_pages, :force => true do |table|
          table.string :title, :nickname
          table.text :body
        end
        
        create_table :kambi_posts, :force => true do |table|
          table.integer :user_id
          table.string :title, :nickname
          table.text :body
          table.timestamps
        end
        
        create_table :kambi_clips, :force => true do |table|
          table.string :url, :nickname, :source
          table.text :body
          table.timestamps
        end
        
        create_table :kambi_references, :force => true do |table|
          table.integer :clip_id
          table.integer :post_id
          table.integer :page_id
        end
        
        create_table :kambi_comments, :force => true do |table|
          table.integer :post_id
          table.string :username
          table.text :body
          table.datetime :created_at
        end
        
        create_table :kambi_tags, :force => true do |table|
          table.string :name
        end
        
        create_table :kambi_taggings, :force => true do |table|
          table.integer :tag_id
          table.integer :taggable_id
          table.string :taggable_type
        end
        
      end
    end
end

