#!ruby
module Kambi::Views

    module HTML
      include Kambi::Helpers
      include Kambi::Models
      include Kambi::Controllers
        def layout
          html do
            head do
              title 'Kambi'
              link :rel => 'stylesheet', :type => 'text/css', 
                   :href => self/'/styles.css', :media => 'screen'
            end
            body do
              div.header do
                h1.header { a 'Kambi', :href => R(Posts) }
                for page in Page.find :all
                  a("Home", :href => R(Posts))
                  a(page.title, :href => R(Pages, page.id))
                  a("All Essays", :href => R(Posts))
                  a("All Resources", :href => R(Clips))
                  a("All Tags", :href => R(Tags))
                  a('Authors', :href => R(Authors))
                  if @state.user_id.blank?
                    a('Login', :href => R(Sessions, 'new'))
                  else
                    br;br
                    a(' ', :href=> '#')
                    a(' ', :href=> '#')
                    a('New Page', :href => R(Pages, 'new'))
                    a('New Essay', :href => R(Posts, 'new'))
                    a('New Resource', :href => R(Clips, 'new'))
                    a('New Tag', :href => R(Tags))
                    a('New Author', :href => R(Authors, 'new'))
                  end
                end
              end
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
          # p do 
          #   unless @state.user_id.blank?
          #     a('New Page', :href => R(Pages, 'new')); br
          #     a('New Essay', :href => R(Posts, 'new')); br
          #     a('New Resource', :href => R(Clips, 'new')); br
          #     a('New Tag', :href => R(Tags)); br
          #     a('Authors', :href => R(Authors)); br
          #     a('New Author', :href => R(Authors, 'new'))
          #   end
          # end
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
          p "Essays written by "+ author.first + " " + author.last + ":"
          for post in @posts
            a(post.title, :href => R(Posts, post.id))
          end
        end
        
        def view_clip
          div.clip do
            _clip(@clip)
          end
          div.post do
            p "Essays referring to " + @clip.nickname + " :"
            for post in @posts
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
                p "Essays tagged with " + @tag.name + ":"
                for post in @posts
                  a(post.title, :href => R(Posts, post.id)) 
                end
              end
            end
            unless @clips.empty?
              div.tags do
                p "Resources tagged with " + @tag.name + ":"
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
          unless @state.user_id.blank?
            form :action => R(Tags), :method => 'post' do
              label 'New tag', :for => 'tag_name'; br
              input :name => 'tag_name', :type => 'text'; br
              input :type => 'submit', :value => 'Submit'
            end
          end
        end
        
        def view_clips
          h2 "Resources:"
          for clip in @clips
            p do
              a(clip.nickname, :href => R(Clips, clip.id, 'edit'))
              h3 "Tagged with:"
              for tag in clip.tags
                a(tag.name, :href => R(Tags, tag.id))
              end
              p clip.body
              h3 "Referenced in:"
              for post in clip.posts
                a(post.title, :href => R(Posts, post.id))
              end
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
          h2 "Tags:"
          all_tags = Kambi::Models::Tag.find(:all)
          all_tags_items = Array.new(all_tags)
          all_tags_taggables = all_tags_items.collect!{|t| t.taggables.compact}
          tags_counts = all_tags_taggables.collect!{|g| g.length}
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
          tags = page.tags unless page.tags.nil?
          unless tags.empty?
            div.tags do
              p "tagged with:"
              for tag in tags
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
            step = 0
            p do h4 "by"
              for author in @authors
                name = author.first + " " + author.last
                  a(name, :href => R(Authors, author.id)) if step == 0
                  h4 "and " unless step == 0
                  a(name, :href => R(Authors, author.id)) unless step == 0
                  step = step.next
              end
            end
          end
          tags = post.tags unless post.tags.nil?
          unless tags.empty?
            div.tags do
              p "tagged with:"
              for tag in tags
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
              a("Edit Essay", :href => R(Posts, post.id, 'edit'))
            end
          end
        end
        
        def _clip(clip)
          a(clip.nickname, :href => clip.url)
          tags = clip.tags unless clip.tags.nil?
          unless tags.empty?
            div.tags do
              p "tagged with:"
              for tag in tags
                a(tag.name, :href => R(Tags, tag.id))
              end
            end
          end
          p clip.body
          unless @state.user_id.blank?
            p do
              a("Edit Resource", :href => R(Clips, clip.id, 'edit'))
            end
          end
        end
        
        def _author(author)
          name = author.first + " " + author.last
          a(name, :href => author.url)
          tags = author.tags unless author.tags.nil?
          unless tags.empty?
            div.tags do
              p "tagged with:"
              for tag in tags
                a(tag.name, :href => R(Tags, tag.id))
              end
            end
          end
          a(author.photo_url, :href => author.photo_url)
          p "Organization:"
          a(author.org, :href => author.org_url)
          p "Bio:"
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
          a('Delete Page', :href => R(Pages, page.id, 'delete')) unless @these_pages_tags.nil?
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
          a('Delete Essay', :href => R(Posts, post.id, 'delete')) unless @these_posts_tags.nil?
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
          a('Delete Resource', :href => R(Clips, clip.id, 'delete')) unless @these_clips_tags.nil?
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
           a('Delete Author', :href => R(Authors, author.id, 'delete')) unless @these_authors_tags.nil?
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
             label 'Organization', :for => 'author_org'; br
             input :name => 'author_org', :type => 'text', 
                   :value => author.org; br
             label 'Organization Url', :for => 'author_org_url'; br
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