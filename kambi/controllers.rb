#!/usr/bin/env ruby
# vim:tabstop=2:expandtab

module Kambi::Controllers
  class Index < R "/"
    def get
      @posts = [Post.find(:first)]
      render :index
    end
  end
  
  # class PagesNicks < R '/pages/([-\D]*)'
  #   def get(nickname)
  #       @page = Page.find(:first, :conditions => ["nickname = ?", nickname])
  #       @clips = @page.clips
  #       render :view_page
  #   end
  # end
    
    class Pages < REST 'pages'      

        # POST /pages
        def create
            unless @state.user_id.blank?
                page = Page.create :title => input.page_title, :body => input.page_body, :nickname => input.page_nickname
                all_clips = Models::Clip.find :all
                all_clips.each{|c| if input.include?('clip-' + c.id.to_s); 
                    page.references<<(Reference.create :page_id => page.id, :clip_id => c.id); end; }
                all_tags = Models::Tag.find :all
                all_tags.each{|a| if input.include?('tag-' + a.id.to_s); 
                    page.taggings<<(Tagging.create( :taggable_id => page.id, :taggable_type => 'Page', :tag_id => a.id)); end; }
                redirect R(Pages, page.id)
            else
              _error("Unauthorized", 401)
            end
        end
        
        # GET /pages/1
        def read(page_id) 
            @page = Page.find page_id
            @clips = @page.clips
            render :view_page
        end
        
        # PUT /pages/1
        def update(page_id)
            unless @state.user_id.blank?
                @page = Page.find page_id
                all_clips = Models::Clip.find :all
                @page.clips.each{|d| @page.references.delete(Reference.find(:all, :conditions => ["clip_id = #{d.id}"] )) }
                all_clips.each{|c| if input.include?('clip-' + c.id.to_s); 
                    @page.references<<(Reference.create :page_id => @page.id, :clip_id => c.id); end; }
                
                all_tags = Models::Tag.find :all
                these_taggings = Array.new(@page.taggings)
                these_taggings.each{|d| @page.taggings.delete(d) }
                
                all_tags.each{|a| if input.include?('tag-' + a.id.to_s); 
                    @page.taggings<<(Tagging.create( :taggable_id => @page.id, :taggable_type => 'Page', :tag_id => a.id)); end; }
                @page.update_attributes :title => input.page_title, :body => input.page_body, :nickname => input.page_nickname
                redirect R(@page)
            else
              _error("Unauthorized", 401)
            end
        end

        # DELETE /pages/1
        def delete(page_id)
            unless @state.user_id.blank?
                @page = Page.find page_id
                if @page.destroy
                  redirect R(Pages)
                else
                  _error("Unable to delete page #{@page.id}", 500)
                end
            else
              _error("Unauthorized", 401)
            end
        end
        
        # GET /pages
        def list
            @pages = Page.find :all; @posts = Post.find :all
            render :index
        end
        
        # GET /pages/new
        def new
          require_login do
            @page = Page.new 
            @all_clips = Models::Clip.find :all
            @all_tags  = Models::Tag.find  :all
            render :add_page
          end
        end

        # GET /pages/1/edit
        def edit(page_id) 
            unless @state.user_id.blank?
                @user = User.find @state.user_id
            end
            @page = Page.find page_id
            @all_clips = Models::Clip.find :all;      @these_clips = @page.clips
            @all_tags = Models::Tag.find :all;  @these_tags = @page.tags
            render :edit_page
        end
        
    end
    
    # class PostsNicks < R '/posts/([-\D]*)'
    #   def get(nickname)
    #     @post = Post.find(:first, :conditions => ["nickname = ?", nickname])
    #     @comments = @post.comments
    #     @clips = @post.clips;       @authors = @post.authors
    #     @captcha = turing_image
    #     render :view
    #   end
    # end
    
    class Posts < REST 'posts'      

        # POST /posts
        def create
            unless @state.user_id.blank?
                post = Post.create :title => input.post_title, :body => input.post_body, :user_id => @state.user_id, :nickname => input.post_nickname                       
                all_clips = Models::Clip.find :all
                all_clips.each{|c| if input.include?('clip-' + c.id.to_s); 
                     post.references<<(Reference.create :post_id => post.id, :clip_id => c.id); end; }
                all_tags = Models::Tag.find :all
                all_tags.each{|a| if input.include?('tag-' + a.id.to_s); 
                    post.taggings<<(Tagging.create( :taggable_id => post.id, :taggable_type => 'Post', :tag_id => a.id)); end; }
                all_authors = Models::Author.find :all
                all_authors.each{|a| if input.include?('author-' + a.id.to_s); 
                    post.authorships<<(Authorship.create( :post_id => post.id, :author_id => a.id)); end; }
                redirect R(Posts, post.id)
            else
              _error("Unauthorized", 401)
            end
        end

        # GET /posts/1
        def read(post_id) 
            @post = Post.find post_id;  @comments = @post.comments
            @clips = @post.clips;       @authors = @post.authors
            @captcha = turing_image
            render :view
        end

        # PUT /posts/1
        def update(post_id)
            unless @state.user_id.blank?
                @post = Post.find post_id
                
                all_authors = Models::Author.find :all
                @post.authors.each{|d| @post.authorships.delete(Authorship.find(:all, :conditions => ["author_id = #{d.id} AND  post_id = #{@post.id}"] )) }
                all_authors.each{|a| if input.include?('author-' + a.id.to_s); 
                    @post.authorships<<(Authorship.create( :post_id => @post.id, :author_id => a.id)); end; }
                    
                all_clips = Models::Clip.find :all
                @post.clips.each{|d| @post.references.delete(Reference.find(:all, :conditions => ["clip_id = #{d.id}"] )) }
                all_clips.each{|c| if input.include?('clip-' + c.id.to_s); 
                    @post.references<<(Reference.create :post_id => @post.id, :clip_id => c.id); end; }
                
                all_tags = Models::Tag.find :all                
                these_taggings = Array.new(@post.taggings)
                these_taggings.each{|d| @post.taggings.delete(d) }
                
                all_tags.each{|a| if input.include?('tag-' + a.id.to_s); 
                    @post.taggings<<(Tagging.create( :taggable_id => @post.id, :taggable_type => 'Post', :tag_id => a.id)); end; }
                    
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
        def list
            @posts = Post.find :all; @pages = Page.find :all
            render :index
        end
              
        # GET /posts/new
        def new
            unless @state.user_id.blank?
                @user = User.find @state.user_id
                @post = Post.new;
                @all_clips = Models::Clip.find :all;      @these_clips = nil
                @all_tags = Models::Tag.find :all;  @these_tags = nil
                @all_authors = Models::Author.find :all;  @these_authors = nil
            end
            render :add_post
        end

        # GET /posts/1/edit
        def edit(post_id) 
            unless @state.user_id.blank?
                @user = User.find @state.user_id
            end
            @post = Post.find post_id
            @all_clips = Models::Clip.find :all;      @these_clips = @post.clips
            @all_tags = Models::Tag.find :all;  @these_tags = @post.tags
            @all_authors = Models::Author.find :all;  @these_authors = @post.authors
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
    
    # class ClipsNicks < R '/clips/([-\D]*)'
    #   def get(nickname)
    #     @clip = Clip.find(:first, :conditions => ["nickname = ?", nickname])
    #     @posts = @clip.posts
    #     @pages = @clip.pages
    #     render :view_clip
    #   end
    # end
    
    class Clips < REST 'clips'
        # POST /clips
        def create
            clip = Clip.create(:nickname => input.clip_nickname, :url => input.clip_url, :body => input.clip_body, :source => input.clip_source)
            all_posts = Models::Post.find :all
            all_posts.each{|p| if input.include?('post-' + p.id.to_s); 
                clip.references<<(Reference.create :post_id => p.id, :clip_id => clip.id); end; }
            all_tags = Models::Tag.find :all
            all_tags.each{|a| if input.include?('tag-' + a.id.to_s); 
                clip.taggings<<(Tagging.create(:taggable_id => clip.id, :taggable_type => 'Clip', :tag_id => a.id)); end; }
            all_pages = Models::Page.find :all
            all_pages.each{|p| if input.include?('page-' + p.id.to_s); 
                clip.references<<(Reference.create :page_id => p.id, :clip_id => clip.id); end; }
            redirect R(Posts)
        end
        
        # GET /clips/1
        def read(clip_id) 
            @clip = Clip.find clip_id;
            @posts = @clip.posts
            @pages = @clip.pages
            render :view_clip
        end
        
        # GET /clips
        def list
            @clips = Clip.find :all
            render :view_clips
        end
        
        # GET /clips/new
        def new
            unless @state.user_id.blank?
                @user = User.find @state.user_id
                @all_posts = Models::Post.find :all; @these_posts = nil
                @all_tags = Models::Tag.find :all;  @these_tags = nil
                @all_pages = Models::Page.find :all; @these_pages = nil
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
            @all_posts = Models::Post.find :all;      @these_posts = @clip.posts
            @all_tags = Models::Tag.find :all;  @these_tags = @clip.tags
            @all_pages = Models::Page.find :all; @these_pages = @clip.pages
            render :edit_clip
        end
        
        # PUT /clips/1
        def update(clip_id)
            unless @state.user_id.blank?
                clip = Clip.find clip_id
                all_tags = Models::Tag.find :all
                clip.update_attributes :url => input.clip_url, :body => input.clip_body, :nickname => input.clip_nickname, :source => input.clip_source
                
                these_taggings = Array.new(clip.taggings)
                these_taggings.each{|d| clip.taggings.delete(d) }
                
                all_tags.each{|a| if input.include?('tag-' + a.id.to_s); 
                    clip.taggings<<(Tagging.create(:taggable_id => clip.id, :taggable_type => 'Clip', :tag_id => a.id)); end; }
                
                all_posts = Models::Post.find :all
                these_clips_posts = clip.posts
                these_clips_posts.each{|d|  clip.references.delete(Reference.find(:all, :conditions => ['post_id =?', d.id])) }
                all_posts.each{|p| if input.include?('post-' + p.id.to_s); 
                    clip.references<<(Reference.create :post_id => p.id, :clip_id => clip.id); end; }
                    
                all_pages = Models::Page.find :all
                these_clips_pages = clip.pages
                these_clips_pages.each{|d|  clip.references.delete(Reference.find(:all, :conditions => ['page_id =?', d.id])) }
                all_pages.each{|p| if input.include?('page-' + p.id.to_s); 
                    clip.references<<(Reference.create :page_id => p.id, :clip_id => clip.id); end; }
            
                # all_pages = Models::Page.find :all
                # these_references = Array.new(clip.references)
                # these_references.each{|r| clip.references.delete(r)}
                # 
                # all_referables = all_posts + all_pages
                # all_referables.each{|r| 
                #     if input.include?('post-' + r.id.to_s);
                #       puts r.title;
                #       clip.references<<(Reference.create :post_id => r.id, :clip_id => clip.id); 
                #     end;
                #     if input.include?('page-' + r.id.to_s);
                #       puts r.title;
                #       clip.references<<(Reference.create :page_id => r.id, :clip_id => clip.id); 
                #     end;}
                
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
        def list
            @tags = Tag.find :all
            @taggables = @tags.collect{|t| t.taggables}.flatten
            render :view_tags
        end
        
        # GET /tags/1
        def read(tag_id) 
            @tag = Tag.find tag_id
            @tags = Tag.find :all
            @taggables = @tag.taggables
            @posts = Array.new; @clips = Array.new; @pages = Array.new; @authors = Array.new;
            @taggables.each { |t|
                if    t.instance_of?(Kambi::Models::Post);   @posts   << t; 
                elsif t.instance_of?(Kambi::Models::Clip);   @clips   << t;
                elsif t.instance_of?(Kambi::Models::Page);   @pages   << t;  
                elsif t.instance_of?(Kambi::Models::Author); @authors << t;
                end;
            }
            render :view_tags
        end
        
        # GET /tags/new
        def new
            unless @state.user_id.blank?
                @user = User.find @state.user_id
            end
            @tag = Tag.new
            render :add_tag
        end
        
        # DELETE /tags/1
        def delete(tag_id)
            unless @state.user_id.blank?
                @tag = Tag.find tag_id
                if @tag.destroy
                  redirect R(Tags)
                else
                  _error("Unable to delete tag #{@tag.id}", 500)
                end
            else
              _error("Unauthorized", 401)
            end
        end
        
        # # GET /tag/1/edit
        # def edit(tag_id) 
        #     unless @state.user_id.blank?
        #         @user = User.find @state.user_id
        #     end
        #     @tag = Tag.find tag_id
        #     render :edit_tag
        # end
        # 
        # # PUT /tags/1
        # def update(tag_id)
        #     unless @state.user_id.blank?
        #         @tag = Tag.find tag_id
        #         @tag.update_attributes :name => input.tag_name
        #         @taggables = @tag.taggables
        #         @posts = Array.new; @clips = Array.new; @pages = Array.new; @authors = Array.new;
        #         @taggables.each{|t|  if t.instance_of?(Kambi::Models::Post); @posts<<t; 
        #             elsif t.instance_of?(Kambi::Models::Clip);  @clips<<t;
        #             elsif t.instance_of?(Kambi::Models::Page); @pages<<t;  
        #             elsif t.instance_of?(Kambi::Models::Author); @authors<<t; end; }
        #         render :view_tags
        #     else
        #       _error("Unauthorized", 401)
        #     end
        # end
    end 
     
    class Comments < REST 'comments'
        # POST /comments
        def create

          if input.captcha == input.hushhush
              Models::Comment.create(:username => input.post_username,
                         :body => input.post_body, :post_id => input.post_id)
          
          end
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
        author = Models::Author.create(:first => input.author_first, :last => input.author_last,
                    :url => input.author_url, :photo_url => input.author_photo_url,
                    :org => input.author_org, :org_url => input.author_org_url,
                    :bio => input.author_bio)
        all_tags = Models::Tag.find :all
        all_tags.each{|a| if input.include?('tag-' + a.id.to_s); 
            author.taggings<<(Tagging.create(:taggable_id => author.id, :taggable_type => 'Author', :tag_id => a.id)); end; }
        all_posts = Models::Post.find :all
        all_posts.each{|p| if input.include?('post-' + p.id.to_s); 
            author.authorships<<(Authorship.create :post_id => p.id, :author_id => author.id); end; }
        redirect R(Authors, input.author_id)
      end
      
      # GET /authors
      def list
          @authors = Author.find :all
          render :view_authors
      end
      
      # GET /authors/1
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
        require_login do
          @author    = Models::Author.new; 
          @all_posts = Models::Post.find(:all)
          @all_tags  = Models::Tag.find(:all)
          render :add_author
        end
      end
      
      # GET /authors/1/edit
      def edit(author_id) 
          unless @state.user_id.blank?
              @user = User.find @state.user_id
          end
          @author = Models::Author.find author_id
          @all_posts = Models::Post.find :all;  @these_posts = @author.posts
          @all_tags = Models::Tag.find :all;    @these_tags = @author.tags
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
              
              these_taggings = Array.new(author.taggings)
              these_taggings.each{|d| author.taggings.delete(d) }
              
              all_tags.each{|a| if input.include?('tag-' + a.id.to_s); 
                  author.taggings<<(Tagging.create(:taggable_id => author.id, :taggable_type => 'Author', :tag_id => a.id)); end; }
              all_posts = Models::Post.find :all
              these_authors_posts = author.posts
              these_authors_posts.each{|d|  author.authorships.delete(Authorship.find(:all, :conditions => ['post_id =?', d.id])) }
              all_posts.each{|p| if input.include?('post-' + p.id.to_s); 
                  author.authorships<<(Authorship.create :post_id => p.id, :author_id => author.id); end; }
              redirect R(Authors)
          else
            _error("Unauthorized", 401)
          end
      end
      
    end
    
  class Sessions < REST "sessions"
    
    # POST /sessions
    def create

      # attempt to fetch the user from the
      # db; will fail if un OR pw are wrong
      @user = User.find(
        :first,
        :conditions => [
          "username=? and password=?",
          input.username,
          input.password
      ])

      if @user
        @h1    = "Login Successful"
        @msg   = "You are now logged in to the website. See the admin "   +
                 "toolbox in the top-right to add things, or hover over " +
                 "existing things to edit them."

        # log the user in with a cookie
        # (expires when browser is closed)
        @state.user_id   = @user.id
        @state.user_name = @user.username

      else
        # show an error and redirect back
        # to the login form to try again
        @redir = R(Sessions, :new)
        @h1    = "Login Failed"
        @msg   = "Your username and/or password were not correct. " +
                  "Please check them and try again."
      end

      render :msg
    end   

    # GET /sessions/new
    def new
      render :login
    end

    # DELETE /sessions
    def delete
      @state.user_id   = nil
      @state.user_name = nil
      
      # display a basic message
      @h1  = "Logged Out"
      @msg = "You have been logged out of the website. Please come again."
      render :msg
    end
  end
  
  class Static < R "/static/(.+)"
    PATH = File.expand_path(File.dirname(__FILE__) + "/..") + "/static"
    MIME_TYPES = {
      '.css' => "text/css",
      '.js'  => "text/javascript",
      '.jpg' => "image/jpeg",
      '.png' => "image/png"
    }

    def get(path)
      
      # prevent ../ attacks
      if path.include?("..")
        @status = 403
        return "Invalid Path"
      end

      file = "#{PATH}/#{path}"

      # return the file contents (x-sendfile
      # seems to be broken), or a 404 error
      if File.exists?(file)
        ext = path[/\.\w+$/, 0]
        @headers['Content-Type'] = MIME_TYPES[ext] || "text/plain"
        return File.read(file)

      else
        @status = 404
        return "Not Found"
      end
    end
  end
end

