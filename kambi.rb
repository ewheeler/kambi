#!/usr/bin/env ruby

# This is a RESTful extension of the Camping-based Blokk project:
# http://murfy.de/read/blokk
#
# The original Camping-based Blog can be found here: 
# http://code.whytheluckystiff.net/camping/browser/trunk/examples/blog.rb
#
# Borrows from RESTstop's adaptation: http://reststop.rubyforge.org/classes/Camping.html
#
# Tag cloud courtesy of: http://whomwah.com/2006/07/06/another-tag-cloud-script-for-ruby-on-rails/

# TODO: photo/file uploads?
require 'rubygems'

gem 'camping', '~> 1.5'
gem 'reststop', '~> 0.2'

require 'camping'
#require 'yaml'
require 'camping/db'
require 'camping/session'

begin
  # try to use local copy of library
  require '../lib/reststop'
rescue LoadError
  # ... otherwise default to rubygem
  require 'reststop'
end
  
Camping.goes :Kambi

module Kambi
    include Camping::Session
end

module Kambi::Models
    class Page < Base
      has_many :references, :foreign_key => "page_id"
      has_many :clips, :through => :references
      validates_presence_of :title, :nickname
      validates_uniqueness_of :nickname
      has_many :taggings, :as => :taggable
      has_many :tags, :through => :taggings
    end
      
    class Post < Base
      has_many :comments, :order => 'created_at ASC'
      has_many :references, :foreign_key => "post_id"
      has_many :clips, :through => :references#, :source => :clip
      validates_presence_of :title, :nickname
      validates_uniqueness_of :nickname
      has_many :taggings, :as => :taggable
      has_many :tags, :through => :taggings
      has_many :authorships, :foreign_key => "post_id"
      has_many :authors, :through => :authorships
      
      def pretty_time
        self.created_at.strftime("%A %B %d, %Y at %I %p")
      end
    end
  
    class Clip < Base
      has_many :references, :foreign_key => "clip_id"
      has_many :posts, :through => :references#, :source => :post
      has_many :pages, :through => :references
      validates_presence_of :url, :nickname
      validates_uniqueness_of :nickname
      has_many :taggings, :as => :taggable
      has_many :tags, :through => :taggings
    end
    
    class Reference < Base
      belongs_to :clip, :class_name => "Clip"
      belongs_to :post, :class_name => "Post"
      belongs_to :page, :class_name => "Page"
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
      belongs_to :clip, :class_name => "Clip", :foreign_key => "taggable_id"
      belongs_to :post, :class_name => "Post", :foreign_key => "taggable_id"
      belongs_to :page, :class_name => "Page", :foreign_key => "taggable_id"
      belongs_to :author, :class_name => "Author", :foreign_key => "taggable_id"
    end

    class Tag < Base
      validates_presence_of :name
      has_many :taggings
      has_many :clips, :through => :taggings, :source => :clip, :conditions => "kambi_taggings.taggable_type = 'Clip'"
      has_many :posts, :through => :taggings, :source => :post, :conditions => "kambi_taggings.taggable_type = 'Post'"
      has_many :pages, :through => :taggings, :source => :page, :conditions => "kambi_taggings.taggable_type = 'Page'"
      has_many :authors, :through => :taggings, :source => :author, :conditions => "kambi_taggings.taggable_type = 'Author'"
      
      def taggables
        self.taggings.collect{|t| t.taggable}
      end  
    end
    
    class Author < Base
      validates_presence_of :first, :last, :bio
      has_many :authorships, :foreign_key => "author_id"
      has_many :posts, :through => :authorships#, :source => :post
      has_many :taggings, :as => :taggable
      has_many :tags, :through => :taggings
    end
    
    class Authorship < Base
      belongs_to :author, :class_name => "Author"
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
          table.string :url, :nickname
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

def Kambi.create
    Camping::Models::Session.create_schema
    Kambi::Models.create_schema
end

module Kambi::Helpers
  
  def font_size_for_tag_cloud( total, lowest, highest, options={} )
   return nil if total.nil? or highest.nil? or lowest.nil?
   #
   # options
   maxf = options.delete( :max_font_size ) || 24
   minf = options.delete( :min_font_size ) || 10
   maxc = options.delete( :max_color ) || [ 0, 0, 0 ]
   minc = options.delete( :min_color ) || [ 156, 156, 156 ]
   hide_sizes = options.delete( :hide_sizes )
   hide_colours = options.delete( :hide_colours )
   #
   # function to work out rgb values
   def rgb_color( a, b, i, x)
    return nil if i <= 1 or x <= 1
    if a > b
     a-(Math.log(i)*(a-b)/Math.log(x)).floor
    else
     (Math.log(i)*(b-a)/Math.log(x)+a).floor
    end
   end
   #
   # work out colours
   c = []
   (0..2).each { |i| c << rgb_color( minc[i], maxc[i], total, highest ) || nil }
   colors = c.compact.empty? ? minc.join(',') : c.join(',')
   #
   # work out the font size
   spread = highest.to_f - lowest.to_f
   spread = 1.to_f if spread <= 0
   fontspread = maxf.to_f - minf.to_f
   fontstep = spread / fontspread
   size = ( minf + ( total.to_f / fontstep ) ).to_i
   size = maxf if size > maxf
   #
   # display the results
   size_txt = "font-size:#{ size.to_s }px;" unless hide_sizes
   color_txt = "color:rgb(#{ colors });" unless hide_colours
   return [ size_txt, color_txt ].join
  end

  # # menu bar
  # def menu target = nil
  #   if target
  #     args = target.is_a?(Symbol) ? [] : [target]
  #     for role, submenu in menu[target].sort_by { |k, v| [:visitor, :user].index k }
  #       ul.menu.send(role) do
  #         submenu.each do |x|
  #           li { x[/\A\w+\z/] ? a(x, :href => R(Controllers.const_get(x), *args)) : x }
  #         end
  #       end unless submenu.empty?
  #     end
  #   else
  #     @menu ||= Hash.new { |h, k| h[k] = { :visitor => [], :user => [] } }
  #   end
  # end
  # 
  # # shortcut for error-aware labels
  # def label_for name, record = nil, attr = name, options = {}
  #   errors = record && !record.body.blank? && !record.valid? && record.errors.on(attr)
  #   label name.to_s, { :for => name }, options.merge(errors ? { :class => :error } : {})
  # end
  
end

# beautiful XHTML 11
class Mab
  def initialize(assigns = {}, helpers = nil, &block)
    super(assigns.merge({:indent => 2}), helpers, &block)
  end
  def xhtml11(&block)
    self.tagset = Markaby::XHTMLStrict
    declare! :DOCTYPE, :html, :PUBLIC, '-//W3C//DTD XHTML 1.1//EN', 'http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd'
    tag!(:html, :xmlns => 'http://www.w3.org/1999/xhtml', 'xml:lang' => 'en', &block)
    self
  end
end

module Kambi::Controllers
    class Pages < REST 'pages'      

        # POST /pages
        def create
            unless @state.user_id.blank?
                page = Page.create :title => input.page_title, :body => input.page_body, :nickname => input.page_nickname
                redirect R(Pages)
            else
              _error("Unauthorized", 401)
            end
        end
        
        # GET /pages/1
        # GET /pages/1.xml
        def read(page_id) 
            @page = Page.find page_id
            clips_pages = Reference.find(:all, :conditions => ['page_id =?', @page.id])
            @clips = @page.clips
            render :view_page
        end
        
        # PUT /pages/1
        def update(page_id)
            unless @state.user_id.blank?
                @page = Page.find page_id
                all_clips = Models::Clip.find :all
                @page.clips.each{|d| @page.references.delete(Reference.find(:all, :conditions => ["clip_id = #{d.id}"]))}
                all_clips.each{|c| if input.include?(c.nickname); 
                    @page.references<<(Reference.create :page_id => @page.id, :clip_id => c.id); end; }
                
                all_tags = Models::Tag.find :all
                @page.tags.each{|d| @page.taggings.delete(Tagging.find(:all, :conditions => ["tag_id = #{d.id} AND  taggable_id = #{@page.id}"] )) }
                all_tags.each{|a| if input.include?(a.name); 
                    @page.taggings<<(Tagging.create( :taggable_id => @page.id, :taggable_type => "Page", :tag_id => a.id)); end; }
                @page.update_attributes :title => input.page_title, :body => input.page_body, :nickname => input.page_nickname
                redirect R(@page)
            else
              _error("Unauthorized", 401)
            end
        end
        
        # GET /pages
        # GET /pages.xml
        def list
            @pages = Page.find :all
            @posts = Post.find :all
            render :index
        end
        
        # GET /pages/new
        def new
            unless @state.user_id.blank?
                @user = User.find @state.user_id
                @page = Page.new
            end
            render :add_page
        end

        # GET /pages/1/edit
        def edit(page_id) 
            unless @state.user_id.blank?
                @user = User.find @state.user_id
            end
            @page = Page.find page_id
            @all_clips = Models::Clip.find :all
            @these_pages_clips = @page.clips
            @all_pages_tags = Models::Tag.find :all
            @these_pages_tags = @page.tags
            render :edit_page
        end
        
    end
    
    class Posts < REST 'posts'      

        # POST /posts
        def create
            unless @state.user_id.blank?
                post = Post.create :title => input.post_title, :body => input.post_body,
                                   :user_id => @state.user_id, :nickname => input.post_nickname
                redirect R(Posts)
            else
              _error("Unauthorized", 401)
            end
        end

        # GET /posts/1
        # GET /posts/1.xml
        def read(post_id) 
            @post = Post.find post_id
            @comments = @post.comments
            clips_posts = Reference.find(:all, :conditions => ['post_id =?', @post.id])
            @clips = @post.clips
            @authors = @post.authors
            render :view
        end

        # PUT /posts/1
        def update(post_id)
            unless @state.user_id.blank?
                @post = Post.find post_id
                
                all_authors = Models::Author.find :all
                @post.authors.each{|d| @post.authorships.delete(Authorship.find(:all, :conditions => ["author_id = #{d.id} AND  post_id = #{@post.id}"] )) }
                all_authors.each{|a| name = a.first + " " + a.last; if input.include?(name); 
                    @post.authorships<<(Authorship.create( :post_id => @post.id, :author_id => a.id)); end; }
                    
                all_clips = Models::Clip.find :all
                @post.clips.each{|d| @post.references.delete(Reference.find(:all, :conditions => ["clip_id = #{d.id}"] )) }
                all_clips.each{|c| if input.include?(c.nickname); 
                    @post.references<<(Reference.create :post_id => @post.id, :clip_id => c.id); end; }
                
                all_tags = Models::Tag.find :all
                @post.tags.each{|d| @post.taggings.delete(Tagging.find(:all, :conditions => ["tag_id = #{d.id} AND  taggable_id = #{@post.id}"] )) }
                all_tags.each{|a| if input.include?(a.name); 
                    @post.taggings<<(Tagging.create( :taggable_id => @post.id, :taggable_type => "Post", :tag_id => a.id)); end; }
                @post.update_attributes :title => input.post_title, :body => input.post_body, :nickname => input.post_nickname
                redirect R(@post)
            else
              _error("Unauthorized", 401)
            end
        end

        # DELETE /posts/1
        def delete(post_id)
            unless @state.user_id.blank?
                @post = Post.find post_id
                if @post.destroy
                  redirect R(Posts)
                else
                  _error("Unable to delete post #{@post.id}", 500)
                end
            else
              _error("Unauthorized", 401)
            end
        end

        # GET /posts
        # GET /posts.xml
        def list
            @posts = Post.find :all
            @pages = Page.find :all
            render :index
        end
              
        # GET /posts/new
        def new
            unless @state.user_id.blank?
                @user = User.find @state.user_id
                @post = Post.new
            end
            render :add_post
        end

        # GET /posts/1/edit
        def edit(post_id) 
            unless @state.user_id.blank?
                @user = User.find @state.user_id
            end
            @post = Post.find post_id
            @all_clips = Models::Clip.find :all
            @these_posts_clips = @post.clips
            @all_posts_tags = Models::Tag.find :all
            @these_posts_tags = @post.tags
            @all_authors = Models::Author.find :all
            @these_posts_authors = @post.authors
            render :edit_post
        end
        
        # GET /posts/info
        def info
            div do
                code args.inspect; br; br
                code @env.inspect; br
                code "Link: #{R(Info, 1, 2)}"
            end
        end
    end
    
    class Clips < REST 'clips'
        # POST /clips
        def create
            clip = Clip.create(:nickname => input.clip_nickname, :url => input.clip_url, :body => input.clip_body)
            all_posts = Models::Post.find :all
            all_posts.each{|p| if input.include?(p.title); 
                clip.references<<(Reference.create :post_id => p.id, :clip_id => clip.id); end; }
            redirect R(Posts)
        end
        
        # GET /clips
        # GET /clips.xml
        def list
            @clips = Clip.find :all
            render :view_clips
        end
        
        # GET /clips/new
        def new
            unless @state.user_id.blank?
                @user = User.find @state.user_id
                @all_posts = Models::Post.find :all
                @these_clips_posts = nil
                @clip = Clip.new
            end
            render :add_clip
        end     
        
        # DELETE /clips/1
        def delete(clip_id)
            unless @state.user_id.blank?
                @clip = Clip.find clip_id
                if @clip.destroy
                  redirect R(Posts)
                else
                  _error("Unable to delete clip #{@clip.id}", 500)
                end
            else
              _error("Unauthorized", 401)
            end
        end
                
        # GET /clips/1/edit
        def edit(clip_id) 
            unless @state.user_id.blank?
                @user = User.find @state.user_id
            end
            @clip = Models::Clip.find clip_id
            @all_posts = Models::Post.find :all        
            @these_clips_posts = @clip.posts
            @all_clips_tags = Models::Tag.find :all            
            @these_clips_tags = @clip.tags
            render :edit_clip
        end
        
        # PUT /clips/1
        def update(clip_id)
            unless @state.user_id.blank?
                clip = Clip.find clip_id
                all_tags = Models::Tag.find :all
                clip.update_attributes :url => input.clip_url, :body => input.clip_body, :nickname => input.clip_nickname
                these_tags = clip.tags
                these_tags.each{|d| unless input.include?(d.name); 
                    clip.taggings.delete(Tagging.find(:all, :conditions => ["tag_id = #{d.id} AND  taggable_id = #{clip.id}"] )); end; }
                not_these_tags = all_tags - these_tags
                not_these_tags.each{|a| if input.include?(a.name); 
                    clip.taggings.push(Tagging.create(:taggable_id => clip.id, :taggable_type => "Clip", :tag_id => a.id)); end; }
                all_posts = Models::Post.find :all
                these_clips_posts = clip.posts
                these_clips_posts.each{|d|  clip.references.delete(Reference.find(:all, :conditions => ['post_id =?', d.id])) }
                all_posts.each{|p| if input.include?(p.title); 
                    clip.references<<(Reference.create :post_id => p.id, :clip_id => clip.id); end; }
                redirect R(Posts)
            else
              _error("Unauthorized", 401)
            end
        end
    end
     
    class Tags < REST 'tags'
        # POST /tags
        def create
            Models::Tag.create(:name => input.tag_name)
            redirect R(Tags)
        end
        
        # GET /tags
        # GET /tags.xml
        def list
            @tags = Tag.find :all
            @taggables = @tags.collect{|t| t.taggables}.flatten
            render :view_tags
        end
        
        # GET /tags/1
        # GET /tags/1.xml
        def read(tag_id) 
            @tag = Tag.find tag_id
            @tags = Tag.find :all
            @taggables = @tag.taggables
            @posts = Array.new; @clips = Array.new; @pages = Array.new; @authors = Array.new;
            @taggables.each{|t|  if t.instance_of?(Kambi::Models::Post); @posts<<t; 
                elsif t.instance_of?(Kambi::Models::Clip);  @clips<<t;
                elsif t.instance_of?(Kambi::Models::Page); @pages<<t;  
                elsif t.instance_of?(Kambi::Models::Author); @authors<<t; end; }
            render :view_tags
        end
        
        # GET /tags/new
        def new
            unless @state.user_id.blank?
                @tag = Tag.new
            end
            render :add_tag
        end
        
        # GET /tag/1/edit
        def edit(tag_id) 
            unless @state.user_id.blank?
                @user = User.find @state.user_id
            end
            @tag = Tag.find tag_id
            render :edit_tag
        end
        
        # PUT /tags/1
        def update(tag_id)
            unless @state.user_id.blank?
                @tag = Tag.find tag_id
                @tag.update_attributes :name => input.tag_name
                render :view_tags
            else
              _error("Unauthorized", 401)
            end
        end
    end 
     
    class Comments < REST 'comments'
        # POST /comments
        def create
            Models::Comment.create(:username => input.post_username,
                       :body => input.post_body, :post_id => input.post_id)
            redirect R(Posts, input.post_id)
        end
        
        # DELETE /comments/1
        def delete(comment_id)
            unless @state.user_id.blank?
                @comment = Comment.find comment_id
                if @comment.destroy
                  redirect R(Posts)
                else
                  _error("Unable to delete comment #{@comment.id}", 500)
                end
            else
              _error("Unauthorized", 401)
            end
        end     
    end
    
    class Authors < REST 'authors'
      # POST /authors
      def create
        Models::Author.create(:first => input.author_first, :last => input.author_last,
                    :url => input.author_url, :photo_url => input.author_photo_url,
                    :org => input.author_org, :org_url => input.author_org_url,
                    :bio => input.author_bio)
        redirect R(Authors, input.author_id)
      end
      
      # GET /authors
      # GET /authors.xml
      def list
          @authors = Author.find :all
          render :view_authors
      end
      
      # GET /authors/1
      # GET /authors/1.xml
      def read(author_id) 
          @author = Author.find author_id
          @posts = @author.posts
          render :view_author
      end
      
      # DELETE /authors/1
      def delete(author_id)
          unless @state.user_id.blank?
              @author = Models::Author.find author_id
              if @author.destroy
                redirect R(Posts)
              else
                _error("Unable to delete author #{@author.id}", 500)
              end
          else
            _error("Unauthorized", 401)
          end
      end
      
      # GET /authors/new
      def new
          unless @state.user_id.blank?
              @user = User.find @state.user_id
              @author = Models::Author.new
          end
          render :add_author
      end
      
      # GET /authors/1/edit
      def edit(author_id) 
          unless @state.user_id.blank?
              @user = User.find @state.user_id
          end
          @author = Models::Author.find author_id
          @all_posts = Models::Post.find :all        
          @these_authors_posts = @author.posts
          @all_tags = Models::Tag.find :all
          @these_authors_tags = @author.tags
          render :edit_author
      end
      
      # PUT /authors/1
      def update(author_id)
          unless @state.user_id.blank?
              author = Author.find author_id
              all_tags = Models::Tag.find :all
              author.update_attributes :first => input.author_first, :last => input.author_last,
                          :url => input.author_url, :photo_url => input.author_photo_url,
                          :org => input.author_org, :org_url => input.author_org_url,
                          :bio => input.author_bio
              these_tags = author.tags
              these_tags.each{|d| unless input.include?(d.name); 
                  author.taggings.delete(Tagging.find(:all, :conditions => ["tag_id = #{d.id} AND  taggable_id = #{author.id}"] )); end; }
              not_these_tags = all_tags - these_tags
              not_these_tags.each{|a| if input.include?(a.name); 
                  author.taggings.push(Tagging.create(:taggable_id => author.id, :taggable_type => "Author", :tag_id => a.id)); end; }
              all_posts = Models::Post.find :all
              these_authors_posts = author.posts
              these_authors_posts.each{|d|  author.authorships.delete(Authorship.find(:all, :conditions => ['post_id =?', d.id])) }
              all_posts.each{|p| if input.include?(p.title); 
                  author.authorships<<(Authorship.create :post_id => p.id, :author_id => author.id); end; }
              redirect R(Authors)
          else
            _error("Unauthorized", 401)
          end
      end
      
    end
    
    class Sessions < REST 'sessions'
        # POST /sessions
        def create
            @user = User.find :first, :conditions => ['username = ? AND password = ?', input.username, input.password]
            if @user
                @login = 'login success !'
                @state.user_id = @user.id
            else
                @login = 'wrong user name or password'
            end
            render :login
        end   
        
        # GET /sessions/new
        def new
            render :edit_post
        end

        # DELETE /sessions
        def delete
            @state.user_id = nil
            render :logout
        end
    end
    
    # You can use old-fashioned Camping controllers too!
    class Style < R '/styles.css'
        def get
            @headers["Content-Type"] = "text/css; charset=utf-8"
            @body = %{
                body {
                    font-family: Georga, Utopia, serif;
                }
                h1.header {
                    background-color: #e5e5e5;
                    margin: 0; padding: 10px;
                    border-top: 8px solid #990000;
                }
                div.content {
                    padding: 10px;
                }
                div.break{
                    clear:both;
                }
                div.page{
                    font-family:georgia,"lucida bright","times new roman",serif;
                    width:50%;
                    float:left;
                    text-align:justify;
                    word-spacing:0.25em;
                    border-bottom: 8px solid #990000;
                    line-height:1.3em;
                }
                div.post {
                    font-family:georgia,"lucida bright","times new roman",serif;
                    width: 50%;
                    text-align:justify;
                    word-spacing:0.25em;
                    float:left;
                    border-bottom: 8px solid #990000;
                    line-height:1.3em;
                }
                div.clip{
                    padding: 1em;
                    border-top: 4px solid #444;
                    width:20%;
                    text-align:justify;
                    float:right;
                    clear:right;
                    margin-right:20%;
                    line-height:1.3em;
                    word-spacing:0.25em;
                    font-size:90%;
                }
                div.tags {
                    font-size: 80%;
                    color: #990000;
                    border-left: 1px solid #444;
                    padding-left:1em;
                }
                div.tags a:hover{
                    background:yellow;
                    border-bottom: 1px solid yellow;
                    color:black;
                }
                a{
                    font-family:"Helvetica Neue",Helvetica,Arial,sans-serif;
                }
                a:link,a:visited {
                    color:black;
                    border-bottom: 1px dotted #990000;
                    text-decoration:none;
                }
                a:hover {
                    color:white;
                    background:#990000;
                    text-decoration:none;
                }
                div.comments{
                    padding: 1em;
                    margin-top: 1em;
                    border-left: 4px solid #444;
                    font-family:"Helvetica Neue",Helvetica,Arial,sans-serif;
                    float:left;
                    clear:both;
                }
                div.comment{
                    padding: 1em;
                    margin-right: 4em;
                    border-left: 1px solid #444;
                }
                div.time{
                    font-size:70%;
                    color: #990000;
                    border-left: 1px solid #444;
                    padding-left:1em;
                    font-family:georgia,"lucida bright","times new roman",serif;   
                }
                div.cloud{
                    padding-left:10%;
                }
                div.cloud a:hover{
                    background:yellow;
                    border-bottom: 1px solid yellow;
                }
            }
        end
    end
end


Markaby::Builder.set(:indent, 2)

module Kambi::Views
    module HTML
        include Kambi::Controllers 
      
        def layout
          html do
            head do
              title 'Kambi'
              link :rel => 'stylesheet', :type => 'text/css', 
                   :href => self/'/styles.css', :media => 'screen'
            end
            body do
              h1.header { a 'Kambi', :href => R(Posts) }
              div.content do
                if @state.user_id.blank?
                  a('Login', :href => R(Sessions, 'new'))
                end
                self << yield
              end
            end
          end
        end
    
        def index
          if @posts.empty?
            p 'No posts found.'
          else
            for page in @pages
              a(page.title, :href => R(Pages, page.id))
            end
            for post in @posts
              div.post do
                  @authors = post.authors
                  _post(post)
                end
                clips = post.clips
                for clip in clips
                  div.clip do
                    _clip(clip)
                  end
                end
              #end
              div.break do
                p ''
              end
            end
          end
          p do 
            unless @state.user_id.blank?
              a('New Page', :href => R(Pages, 'new')); br
              a('New Post', :href => R(Posts, 'new')); br
              a('New Clip', :href => R(Clips, 'new')); br
              a('New Tag', :href => R(Tags)); br
              a('Authors', :href => R(Authors)); br
              a('New Author', :href => R(Authors, 'new'))
            end
          end
          div.cloud do
            _cloud
          end
        end   
    
        def login
          p { b @login }
          p { a 'Continue', :href => R(Posts) }
        end
    
        def logout
          p "You have been logged out."
          p { a 'Continue', :href => R(Posts) }
        end
        
        def add_author
          if @user
            _author_form(@author, :action => R(Authors))
          else
            _login
          end
        end
        
        def add_page
          if @user
            _page_form(@page, :action => R(Pages))
          else
            _login
          end
        end
    
        def add_post
          if @user
            _post_form(@post, :action => R(Posts))
          else
            _login
          end
        end
        
        def add_clip
          if @user
            _clip_form(@clip, :action => R(Clips))
          else
            _login
          end
        end
        
        def edit_author
          if @user
            _author_form(@author, :action => R(@author), :method => :put)
          else
            _login
          end
        end
        
        def edit_page
          if @user
            _page_form(@page, :action => R(@page), :method => :put)
          else
            _login
          end
        end
    
        def edit_post
          if @user
            _post_form(@post, :action => R(@post), :method => :put)
          else
            _login
          end
        end
        
        def edit_clip
          if @user
            _clip_form(@clip, :action => R(@clip), :method => :put)
          else
            _login
          end
        end
        
        def view
          div.post do
            _post(@post)
          end
            for clip in @clips
              div.clip do
                _clip(clip)
              end
            end
            div.comments do
              p "Comments:"
              for c in @comments
                div.comment do
                  h1 c.username + ' says:'
                  p c.body
                  div.time do
                    p c.pretty_time
                  end
                  unless @state.user_id.blank?
                    a('Delete', :href => R(Comments, c.id, 'delete'))
                  end
                end
              end
              form :action => R(Comments), :method => 'post' do
                label 'Name', :for => 'post_username'; br
                input :name => 'post_username', :type => 'text'; br
                label 'Comment', :for => 'post_body'; br
                textarea :name => 'post_body' do; end; br
                input :type => 'hidden', :name => 'post_id', :value => @post.id
                input :type => 'submit', :value => 'Submit'
            end
          end
        end
        
        def view_authors
          div.author do
            for author in @authors
              _author(author)
            end
          end
          a('New Author', :href => R(Authors, 'new'))
        end
        
        def view_author
          div.author do
            _author(author)
          end
          div.post do
            for post in @posts
              p "Essays: "
              a(post.title, :href => R(Posts, post.id))
            end
          end
        end
        
        def view_page
          div.page do
            _page(@page)
          end
          for clip in @clips
            div.clip do
              _clip(clip)
            end
          end
        end
        
        def view_tags
          div.cloud do
            _cloud
          end
          if @tag
            unless @posts.empty?
              div.tags do
                p "Posts tagged with " + @tag.name + ":"
                for post in @posts
                  a(post.title, :href => R(Posts, post.id)) 
                end
              end
            end
            unless @clips.empty?
              div.tags do
                p "Clips tagged with " + @tag.name + ":"
                for clip in @clips
                  a(clip.nickname, :href => R(Clips, clip.id))   
                end
              end
            end
            unless @pages.empty?
              div.tags do
                p "Pages tagged with " + @tag.name + ":"
                for page in @pages
                  a(page.nickname, :href => R(Pages, page.id))   
                end
              end
            end
            unless @authors.empty?
              div.tags do
                p "Authors tagged with " + @tag.name + ":"
                for author in @authors
                  name = author.first + " " + author.last
                  a(name, :href => R(Authors, author.id))   
                end
              end
            end
          end
          form :action => R(Tags), :method => 'post' do
            label 'New tag', :for => 'tag_name'; br
            input :name => 'tag_name', :type => 'text'; br
            input :type => 'submit', :value => 'Submit'
          end
        end
        
        def view_clips
          for clip in @clips
            p do
              a(clip.nickname, :href => R(Clips, clip.id, 'edit'))
            end
          end
        end
    
        # partials
        def _login
          form :action => R(Sessions), :method => 'post' do
            label 'Username', :for => 'username'; br
            input :name => 'username', :type => 'text'; br
    
            label 'Password', :for => 'password'; br
            input :name => 'password', :type => 'password'; br
    
            input :type => 'submit', :name => 'login', :value => 'Login'
          end
        end
        
        def _cloud
          all_tags = Kambi::Models::Tag.find(:all)
          all_tags_items = Array.new(all_tags)
          all_tags_taggables = all_tags_items.collect!{|t| t.taggables.compact}
          all_taggables = Array.new(all_tags_taggables)
          tags_counts = all_taggables.collect!{|g| g.length}
          maxtc = 0; mintc = 3
          tags_counts.each{|c| maxtc = c if c > maxtc; mintc = c if c < mintc}
          for c in all_tags
            tag_index = all_tags.index(c)
            a( c.name, :href => R(Tags, c.id), :style => font_size_for_tag_cloud( tags_counts.fetch(tag_index), mintc, maxtc) )
          end
        end
        
        def _page(page)
          h1 do
            a(page.title, :href => R(Pages, page.id))
          end
          ptags = page.tags if !page.tags.nil?
          unless ptags.empty?
            div.tags do
              p "tagged with :"
              for tag in ptags
                a(tag.name, :href => R(Tags, tag.id))
              end
            end
          end
          p page.body
          unless @state.user_id.blank?
            p do
              a("Edit Page", :href => R(Pages, page.id, 'edit'))
            end
          end
        end
        
        def _post(post)
          h1 do
            a(post.title, :href => R(Posts, post.id))
          end
          unless @authors.empty?
            for author in @authors
              name = author.first + " " + author.last
              p do 
                "by " +  a(name, :href => R(Authors, author.id))
              end
            end
          end
          ptags = post.tags if !post.tags.nil?
          unless ptags.empty?
            div.tags do
              p "tagged with :"
              for tag in ptags
                a(tag.name, :href => R(Tags, tag.id))
              end
            end
          end
          p post.body
          div.time do
            p post.pretty_time
          end
          unless @state.user_id.blank?
            p do
              a("Edit Post", :href => R(Posts, post.id, 'edit'))
            end
          end
        end
        
        def _clip(clip)
          a(clip.nickname, :href => clip.url)
          ctags = clip.tags if !clip.tags.nil?
          unless ctags.empty?
            div.tags do
              p "tagged with :"
              for tag in ctags
                a(tag.name, :href => R(Tags, tag.id))
              end
            end
          end
          p clip.body
          unless @state.user_id.blank?
            p do
              a("Edit Clip", :href => R(Clips, clip.id, 'edit'))
            end
          end
        end
        
        def _author(author)
          name = author.first + " " + author.last
          a(name, :href => author.url)
          atags = author.tags if !author.tags.nil?
          unless atags.empty?
            div.tags do
              p "tagged with :"
              for tag in atags
                a(tag.name, :href => R(Tags, tag.id))
              end
            end
          end
          a(author.photo_url, :href => author.photo_url)
          a(author.org, :href => author.org_url)
          p author.bio
          unless @state.user_id.blank?
            p do
              a("Edit Author", :href => R(Authors, author.id, 'edit'))
            end
          end
        end
        
        
        def _page_form(page, opts)
          form(:action => R(Sessions), :method => 'delete') do
          p do 
            span "You are logged in as #{@user.username}"
            span " | "
            button(:type => 'submit') {'Logout'}
          end
          a('Delete Page', :href => R(Pages, page.id, 'delete'))
          end
          form({:method => 'post'}.merge(opts)) do
            label 'Title', :for => 'page_title'; br
            input :name => 'page_title', :type => 'text', 
                  :value => page.title; br
                  
            label 'Nickname', :for => 'page_nickname'; br
            input :name => 'page_nickname', :type => 'text',
                  :value => page.nickname; br
    
            label 'Body', :for => 'page_body'; br
            textarea page.body, :name => 'page_body'; br
             
            if @all_pages_tags
              p "Tagged with:"  
              for tag in @all_pages_tags
                if @these_pages_tags.include?(tag)
                  input :type => 'checkbox', :name => tag.name, :value => tag.id, :checked => 'true'
                  label tag.name, :for => tag.name; br
                else
                  input :type => 'checkbox', :name => tag.name, :value => tag.id
                  label tag.name, :for => tag.name; br
                end
              end
            end
            if @all_clips
              p "References:"
              for clip in @all_clips
                if @these_pages_clips.include?(clip)
                  input :type => 'checkbox', :name => clip.nickname, :value => clip, :checked => 'true'
                  label clip.nickname, :for => clip.nickname; br
                else
                  input :type => 'checkbox', :name => clip.nickname, :value => clip
                  label clip.nickname, :for => clip.nickname; br
                end
              end
            end
            input :type => 'hidden', :name => 'page_id', :value => page.id
            input :type => 'submit', :value => 'Submit'
          end 
        end
      
    
        def _post_form(post, opts)
          form(:action => R(Sessions), :method => 'delete') do
          p do 
            span "You are logged in as #{@user.username}"
            span " | "
            button(:type => 'submit') {'Logout'}
          end
          a('Delete Post', :href => R(Posts, post.id, 'delete'))
          end
          form({:method => 'post'}.merge(opts)) do
            label 'Title', :for => 'post_title'; br
            input :name => 'post_title', :type => 'text', 
                  :value => post.title; br
                  
            label 'Nickname', :for => 'post_nickname'; br
            input :name => 'post_nickname', :type => 'text',
                  :value => post.nickname; br
    
            label 'Body', :for => 'post_body'; br
            textarea post.body, :name => 'post_body'; br
            
            if @all_authors
              p "Author(s):"        
              for author in @all_authors
                name = author.first + " " + author.last
                if @these_posts_authors.include?(author)
                  input :type => 'checkbox', :name => name, :value => author.id, :checked => 'true'
                  label name, :for => name; br
                else
                  input :type => 'checkbox', :name => name, :value => author.id
                  label name, :for => name; br
                end
              end
            end
             
            if @all_posts_tags
              p "Tagged with:"        
              for tag in @all_posts_tags
                if @these_posts_tags.include?(tag)
                  input :type => 'checkbox', :name => tag.name, :value => tag.id, :checked => 'true'
                  label tag.name, :for => tag.name; br
                else
                  input :type => 'checkbox', :name => tag.name, :value => tag.id
                  label tag.name, :for => tag.name; br
                end
              end
            end
            if @all_clips
              p "References:"
              for clip in @all_clips
                if @these_posts_clips.include?(clip)
                  input :type => 'checkbox', :name => clip.nickname, :value => clip, :checked => 'true'
                  label clip.nickname, :for => clip.nickname; br
                else
                  input :type => 'checkbox', :name => clip.nickname, :value => clip
                  label clip.nickname, :for => clip.nickname; br
                end
              end
            end
            input :type => 'hidden', :name => 'post_id', :value => post.id
            input :type => 'submit', :value => 'Submit'
          end 
        end
        
        
        def _clip_form(clip, opts)
          form(:action => R(Sessions), :method => 'delete') do
          p do 
            span "You are logged in as #{@user.username}"
            span " | "
            button(:type => 'submit') {'Logout'}
          end
          a('Delete Clip', :href => R(Clips, clip.id, 'delete'))
          end
          form({:method => 'post'}.merge(opts)) do
            label 'Nickname', :for => 'clip_nickname'; br
            input :name => 'clip_nickname', :type => 'text', 
                  :value => clip.nickname; br
                  
            label 'Url', :for => 'clip_url'; br
            input :name => 'clip_url', :type => 'text', 
                  :value => clip.url; br
                  
            label 'Body', :for => 'clip_body'; br
            textarea clip.body, :name => 'clip_body'; br
            
            if @all_clips_tags
              p "Tagged with:"
              for tag in @all_clips_tags
                if @these_clips_tags.include?(tag)
                  input :type => 'checkbox', :name => tag.name, :value => tag, :checked => 'true'
                  label tag.name, :for => tag.name; br
                else
                  input :type => 'checkbox', :name => tag.name, :value => tag
                  label tag.name, :for => tag.name; br
                end
              end
            end
            if @all_posts
              p "Referenced in:"
              for post in @all_posts
                if !@these_clips_posts.nil? and @these_clips_posts.include?(post)
                  input :type => 'checkbox', :name => post.title, :value => post, :checked => 'true'
                  label post.title, :for => post.title; br
                else
                  input :type => 'checkbox', :name => post.title, :value => post
                  label post.title, :for => post.title; br
                end
              end
            end
            input :type => 'hidden', :name => 'clip_id', :value => clip.id
            input :type => 'submit', :value => 'Submit'
          end
        end 
        
        def _author_form(author, opts)
           form(:action => R(Sessions), :method => 'delete') do
           p do 
             span "You are logged in as #{@user.username}"
             span " | "
             button(:type => 'submit') {'Logout'}
           end
           a('Delete Author', :href => R(Authors, author.id, 'delete'))
           end
           form({:method => 'post'}.merge(opts)) do
             label 'First Name', :for => 'author_first'; br
             input :name => 'author_first', :type => 'text', 
                   :value => author.first; br
                   
             label 'Last Name', :for => 'author_last'; br
             input :name => 'author_last', :type => 'text', 
                   :value => author.last; br

             label 'Url', :for => 'author_url'; br
             input :name => 'author_url', :type => 'text', 
                   :value => author.url; br
                   
             label 'Photo Url', :for => 'author_photo_url'; br
             input :name => 'author_photo_url', :type => 'text', 
                   :value => author.photo_url; br
                   
             label 'Organisation', :for => 'author_org'; br
             input :name => 'author_org', :type => 'text', 
                   :value => author.org; br
                   
             label 'Organisation Url', :for => 'author_org_url'; br
             input :name => 'author_org_url', :type => 'text', 
                   :value => author.org_url; br

             label 'Bio', :for => 'author_bio'; br
             textarea author.bio, :name => 'author_bio'; br
             
             if @all_tags
               p "Tagged with:"
               for tag in @all_tags
                 if @these_authors_tags.include?(tag)
                   input :type => 'checkbox', :name => tag.name, :value => tag, :checked => 'true'
                   label tag.name, :for => tag.name; br
                 else
                   input :type => 'checkbox', :name => tag.name, :value => tag
                   label tag.name, :for => tag.name; br
                 end
               end
             end
             
             if @all_posts
               p "Authorships:"
               for post in @all_posts
                 if !@these_authors_posts.nil? and @these_authors_posts.include?(post)
                   input :type => 'checkbox', :name => post.title, :value => post, :checked => 'true'
                   label post.title, :for => post.title; br
                 else
                   input :type => 'checkbox', :name => post.title, :value => post
                   label post.title, :for => post.title; br
                 end
               end
             end
             input :type => 'hidden', :name => 'author_id', :value => author.id
             input :type => 'submit', :value => 'Submit'
           end
         end
        
    end

    default_format :HTML

    module XML
      def layout
        yield
      end
      
      def index
        @posts.to_xml(:root => 'kambi')
      end
      
      def view
        @post.to_xml(:root => 'post')
      end
    end
end
 
# 
# if __FILE__ == $0
#   require 'mongrel/camping'
# 
#   Kambi::Models::Base.establish_connection :adapter => 'mysql', 
#     :database => 'kambi_dev', 
#     :username => 'root', 
#     :password => 'root'
#   Kambi::Models::Base.logger = Logger.new('kambi.log')
#   #Kambi::Models::Base.threaded_connections = false
#   Kambi.create # only if you have a .create method 
#                  # for loading the schema
# 
#   server = Mongrel::Camping::start("0.0.0.0",80,"/", Kambi)
#   puts "Kambi is running at http://localhost:80/"
#   server.run.join
# end