#!/usr/bin/env ruby

# This is a RESTful adaptation of the Camping-based Blokk application:
# http://murfy.de/read/blokk
#
# The original Camping-based Blog can be found here: 
# http://code.whytheluckystiff.net/camping/browser/trunk/examples/blog.rb
#
# Borrows from RESTstop's version: http://reststop.rubyforge.org/classes/Camping.html
#
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
    class Post < Base
      has_many :comments, :order => 'created_at ASC'
      has_many :references, :foreign_key => "post_id"
      has_many :clips, :through => :references#, :source => :clip
      validates_presence_of :title, :nickname
      validates_uniqueness_of :nickname
      has_many :taggings, :as => :taggable
      has_many :tags, :through => :taggings
    end
  
    class Clip < Base
      has_many :references, :foreign_key => "clip_id"
      has_many :posts, :through => :references#, :source => :post
      validates_presence_of :url, :nickname
      validates_uniqueness_of :nickname
      has_many :taggings, :as => :taggable
      has_many :tags, :through => :taggings
    end
    
    class Reference < Base
      belongs_to :clip, :class_name => "Clip"
      belongs_to :post, :class_name => "Post"
    end
  
    class Comment < Base
      validates_presence_of :username
      validates_length_of :body, :within => 1..3000
      belongs_to :post
    end
    
    class Tagging < Base
      belongs_to :tag
      belongs_to :taggable, :polymorphic => true
      belongs_to :clip, :class_name => "Clip", :foreign_key => "taggable_id"
      belongs_to :post, :class_name => "Post", :foreign_key => "taggable_id"
    end

    class Tag < Base
      validates_presence_of :name
      has_many :taggings
      has_many :clips, :through => :taggings, :source => :clip, :conditions => "kambi_taggings.taggable_type = 'Clip'"
      has_many :posts, :through => :taggings, :source => :post, :conditions => "kambi_taggings.taggable_type = 'Post'"
      
      def taggables
        self.taggings.collect{|t| t.taggable}
      end  
    end
    
    
    class User < Base; end

    class CreateTheBasics < V 1.5
      def self.up
        create_table :kambi_users, :force => true do |table|
          table.string :username, :password
        end
        User.create :username => 'camper', :password => 'mepemepe'
        
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
  
  # menu bar
  def menu target = nil
    if target
      args = target.is_a?(Symbol) ? [] : [target]
      for role, submenu in menu[target].sort_by { |k, v| [:visitor, :user].index k }
        ul.menu.send(role) do
          submenu.each do |x|
            li { x[/\A\w+\z/] ? a(x, :href => R(Controllers.const_get(x), *args)) : x }
          end
        end unless submenu.empty?
      end
    else
      @menu ||= Hash.new { |h, k| h[k] = { :visitor => [], :user => [] } }
    end
  end
  
  # shortcut for error-aware labels
  def label_for name, record = nil, attr = name, options = {}
    errors = record && !record.body.blank? && !record.valid? && record.errors.on(attr)
    label name.to_s, { :for => name }, options.merge(errors ? { :class => :error } : {})
  end
  
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
            render :view
        end

        # PUT /posts/1
        def update(post_id)
            unless @state.user_id.blank?
                @post = Post.find post_id
                all_tags = Models::Tag.find :all
                @post.tags.each{|d| @post.taggings.delete(Tagging.find(:all, :conditions => ["tag_id = #{d.id} AND  taggable_id = #{@post.id}"] )) }
                all_tags.each{|a| if input.include?(a.name); @post.taggings<<(Tagging.create( :taggable_id => @post.id, :taggable_type => "Post", :tag_id => a.id)); end; }
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
            @all_posts_tags = Models::Tag.find :all
            @these_posts_tags = @post.tags
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
            clip = Clip.create(:nickname => input.clip_nickname,
                        :url => input.clip_url,
                       :body => input.clip_body)
            all_posts = Models::Post.find :all
            all_posts.each{|p| if input.include?(p.title); clip.references<<(Reference.create :post_id => p.id, :clip_id => clip.id); end; }
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
                these_tags.each{|d| unless input.include?(d.name); clip.taggings.delete(Tagging.find(:all, :conditions => ["tag_id = #{d.id} AND  taggable_id = #{clip.id}"] )); end; }
                not_these_tags = all_tags - these_tags
                not_these_tags.each{|a| if input.include?(a.name); clip.taggings.push(Tagging.create(:taggable_id => clip.id, :taggable_type => "Clip", :tag_id => a.id)); end; }
                all_posts = Models::Post.find :all
                these_clips_posts = clip.posts
                these_clips_posts.each{|d|  clip.references.delete(Reference.find(:all, :conditions => ['post_id =?', d.id])) }
                all_posts.each{|p| if input.include?(p.title); clip.references<<(Reference.create :post_id => p.id, :clip_id => clip.id); end; }
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
            puts @tag.name
            @tags = Tag.find :all
            @taggables = @tag.taggables.flatten.compact.uniq
            @posts = Array.new
            @clips = Array.new
            @taggables.each{|t|  if t.instance_of?(Kambi::Models::Post); @posts<<t; elsif t.instance_of?(Kambi::Models::Clip);  @clips<<t;  end; }
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
                }
                div.content {
                    padding: 10px;
                }
                div.post {
                    padding: 1em;
                    border-bottom: 8px solid #444;
                    padding-right:2%;
                    padding-bottom:2%;
                    font-family:georgia,"lucida bright","times new roman",serif;
                    width: 40%;
                    text-align:justify;
                    word-spacing:0.25em;
                }
                div.clip{
                    padding: 1em;
                    border-top: 4px solid #444;
                    width:20em;
                    margin-top:2%;
                    text-align:justify;
                    margin-left:80%;
                }
                div.tags {
                    font-size: 80%;
                    color: #990000;
                    border-left: 1px dotted #444;
                    padding-left:1em;
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
                    border: 1px solid black;
                    font-family:"Helvetica Neue",Helvetica,Arial,sans-serif;
                }
                div.comment{
                    padding: 1em;
                    margin-right: 4em;
                    border-left: 1px dotted #444;
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
                self << yield
              end
            end
          end
        end
    
        def index
          if @posts.empty?
            p 'No posts found.'
          else
            for post in @posts
              div.post do
                _post(post)
                clips = post.clips
                for clip in clips
                  div.clip do
                    _clip(clip)
                  end
                end
              end
            end
          
          end
          p { a 'New Post', :href => R(Posts, 'new') }
          
        end
    
        def login
          p { b @login }
          p { a 'Continue', :href => R(Posts, 'new') }
        end
    
        def logout
          p "You have been logged out."
          p { a 'Continue', :href => R(Posts) }
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
                    p c.created_at
                  end
                end
                form :action => R(Comments), :method => 'post' do
                  label 'Name', :for => 'post_username'; br
                  input :name => 'post_username', :type => 'text'; br
                  label 'Comment', :for => 'post_body'; br
                  textarea :name => 'post_body' do; end; br
                  input :type => 'hidden', :name => 'post_id', :value => @post.id
                  input :type => 'submit'
              end
            end
          end
        end
        
        def view_tags
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
          end
          div.tags do
            p "All tags:"
            for tag in @tags
              a(tag.name, :href => R(Tags, tag.id)) 
            end
          end
          form :action => R(Tags), :method => 'post' do
            label 'New tag', :for => 'tag_name'; br
            input :name => 'tag_name', :type => 'text'; br
            input :type => 'submit'
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
    
        def _post(post)
          h1 do
            a(post.title, :href => R(Posts, post.id))
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
          p do
            a("Edit Post", :href => R(Posts, post.id, 'edit'))
          end
          p { a 'Add Clip', :href => R(Clips, 'new')}
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
          p do
            a("Edit Clip", :href => R(Clips, clip.id, 'edit'))
          end
        end
      
    
        def _post_form(post, opts)
          form(:action => R(Sessions), :method => 'delete') do
          p do 
            span "You are logged in as #{@user.username}"
            span " | "
            button(:type => 'submit') {'Logout'}
          end
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
             
            if @all_posts_tags            
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
            input :type => 'hidden', :name => 'post_id', :value => post.id
            input :type => 'submit'
          end 
        end
        
        def _clip_form(clip, opts)
          form(:action => R(Sessions), :method => 'delete') do
          p do 
            span "You are logged in as #{@user.username}"
            span " | "
            button(:type => 'submit') {'Logout'}
          end
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
            input :type => 'submit'
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
