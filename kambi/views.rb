#!/usr/bin/env ruby
# vim:tabstop=2:expandtab

module Kambi::Views
  module HTML
    include Kambi::Helpers
    include Kambi::Models
    include Kambi::Controllers

    # the markaby gem doesn't seem to provide
    # a way of switching to xhtml 1.1 strict,
    # so i've manually implemented it here.
    # TODO: is there a cleaner way to do this?
    def xhtml11(&block)
      self.tagset = Markaby::XHTMLStrict
      declare! :DOCTYPE, :html, :PUBLIC, "-//W3C//DTD XHTML 1.1//EN", "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"
      tag! :html, :xmlns => "http://www.w3.org/1999/xhtml", 'xml:lang' => "en", &block
      self
    end

    # only execute the block if the current
    # user is logged in to the website
    def when_logged_in(&block)
      if @state.user_id
        yield
      end
    end

    def render_text(text, format=:lite)
      # lite formatting escapes html entities
      # and breaks the text into paragraphs
      if format==:lite
        enc = HTMLEntities.new
        unless text.nil? or text.empty?
          text.gsub("\r","").each("") do |chunk|
            p do
              enc.encode(chunk.trim, :named)
            end
          end
        end
      
      # html formatting does NOTHING to the
      # text. watch out for XSS vulnerabilities :O
      elsif format==:html
        div do
          text
        end
      
      # what
      else
        raise(
          ArgumentError,
          "Unsupported format: #{format}")
      end
    end

    def layout
      xhtml11 do
        head do
          title "unisay"
          link( :rel => "stylesheet", :type => "text/css", :href => "/static/css/base.css",    :media => "screen")
          link( :rel => "stylesheet", :type => "text/css", :href => "/static/css/forms.css",   :media => "screen")
          link( :rel => "stylesheet", :type => "text/css", :href => "/static/css/anserai.css", :media => "screen")
          link( :rel => "shortcut icon", :href => "/static/favicon.ico" )
        end

        body do
          div.wrapper! do
            div.header! do
              h1 { a 'unisay', :href => R(Posts) }

              when_logged_in do
                div.logged_in_as! do
                    span "You are logged in as "
                    span.username(@state.user_name)
                end
              end

              ul.pages! do
                # the nav bar is hard-coded for now
                li(:class=>"n0 first") { a("Home",  :href=> "/"         )}
                li(:class=>"n1 last")  { a("About", :href=> "/pages/about" )}

#                Page.find(:all).each_with_css do |page,klass|
#                  li(:class=>klass) { a(page.title, :href => R(Pages, page.id)) }
#                end
              end


              ul.places! do
                # the top-right "places" nav
                li.p1 { a("All Essays",    :href => R(Posts)   )}
                li.p2 { a("All Resources", :href => R(Clips)   )}
                li.p3 { a("All Tags",      :href => R(Tags)    )}
                #li.p4 { a("All Authors",   :href => R(Authors) )}
              end

              div.clear_hack ""
            end

            # wrapped for css hackery
            div.content_wrap! do
              div.content! do
                self << yield
              end
            end

            div.footer! do
              div do
                p.links do
                  a( "Disclaimer",  :href=> "/pages/disclaimer" ); span { "&bull;" }
                  a( "About",       :href=> "/pages/about" ); span { "&bull;" }
                  a( "Legal",       :href=> "/pages/legal" ); span { "&bull;" }
                  a( "Login",       :href=>R(Sessions, :new) )
                end
                p.rights "Copyright United Nations 2008. All Rights Reserved."
              end
            end

            # the floaty admin navigation
            # only appears when logged in
            when_logged_in do
              div.admin_toolbox! do
                h3 "Admin Toolbox"
                ul do
                  li { a("New Page",     :href => R(Pages,   "new")) }
                  li { a("New Essay",    :href => R(Posts,   "new")) }
                  li { a("New Resource", :href => R(Clips,   "new")) }
                  li { a("New Tag",      :href => R(Tags,    "new")) }
                  li { a("New Author",   :href => R(Authors, "new")) }

                  # requires class for css hackery (ie<7 compat)
                  li.last { a( "Log out", :href => R(Sessions, :delete)) }
                end
              end
            end
          end
        end
      end
    end

    def index
      unless @posts.empty?
        @posts.each_with_css("post") do |post,klass|
          div(:class=>klass) do
            _post(post)
          end
        end

      else
        p "No posts found."
      end
      
      # tag cloud
      div.cloud do
        _cloud
      end
    end

    # show a generic message (this
    # used to be the "logged in" page
    def msg
      h1(@h1) if @h1
      p(@msg) if @msg

      # show a link to continue to
      # the next page, or back home
      p do
        a(:href=>(@redir || "/")) do
          "Continue &raquo;"
        end
      end
    end

    # display the login form
    # (no longer a partial)
    def login

      form(:action=>R(Sessions), :method=>"post") do
        fieldset do
          div do
            label "Username", :for=>"fm-username"
            input :id=>"fm-username", :name=>"username", :type=>"text"
          end
          div do
            label "Password", :for=>"fm-password"
            input :id=>"fm-password", :name=>"password", :type=>"password"
          end

          div do
            button "Login"
          end
        end
      end
    end

    def add_author
      when_logged_in do
        _author_form(@author, :action => R(Authors))
      end
    end

    def add_page
      when_logged_in do
        _page_form(@page, :action => R(Pages))
      end
    end

    def add_post
      when_logged_in do
        _post_form(@post, :action => R(Posts))
      end
    end

    def add_clip
      when_logged_in do
        _clip_form(@clip, :action => R(Clips))
      end
    end

    def add_tag
      when_logged_in do
        _tag_form(@tag, :action => R(Tags))
      end
    end

    def edit_author
      when_logged_in do
        _author_form(@author, :action => R(@author), :method => :put)
      end
    end

    def edit_page
      when_logged_in do
        _page_form(@page, :action => R(@page), :method => :put)
      end
    end

    def edit_post
      when_logged_in do
        _post_form(@post, :action => R(@post), :method => :put)
      end
    end

    def edit_clip
      when_logged_in do
        _clip_form(@clip, :action => R(@clip), :method => :put)
      end
    end

    # def edit_tag
    #   if @user
    #     _tag_form(@tag, :action => R(@tag), :method => :put)
    #   else
    #     _login
    #   end
    # end

    def view
      # only one on page, both first and last
      # add classes to recycle css styles
      div( :class=>"post n1 first last" ) do
        _post(@post)
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
            src = @captcha[:filename]
            hush = @captcha[:hushhush]
            img :src => "/static/" + src; br
            label 'Please enter the above number', :for => 'captcha'; br
            input :name => 'captcha', :type => 'text'; br

            label 'Name', :for => 'post_username'; br
            input :name => 'post_username', :type => 'text'; br
            label 'Comment', :for => 'post_body'; br
            textarea :name => 'post_body' do; end; br
            input :type => 'hidden', :name => 'post_id', :value => @post.id
            input :type => 'hidden', :name => 'hushhush', :value => hush
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
    end

    def view_author
      div.author do
        _author(author)
      end
      p "Essays written by "+ author.name + ":"
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
      div.page do
        p "Pages referring to " + @clip.nickname + " :"
        for page in @pages
          a(page.title, :href => R(Pages, page.id))
        end
      end
    end

    def view_page
      div.page do
        _page(@page)
      end
      pc = page.clips
      unless pc.empty?
        div.clips do
          h3 "References"
          pc.each_with_index do |clip,i|
            tag_names = clip.tags.collect{|t| t.name}
            tag_names.to_s
            if tag_names.include?('project')
                div.project do
                  _clip(clip)
                end
            else
              div.clip do
                _clip(clip)
              end
            end
          end
        end
      end
    end

    def view_tags
      div.cloud do
        _cloud
      end
      if @tag
        h3 @tag.name
        unless @posts.nil? or @posts.empty?
          div.tags do
            p "Essays tagged with " + @tag.name + ":"
            for post in @posts
              a(post.title, :href => R(Posts, post.id))
            end
          end
        end
        unless @clips.nil? or @clips.empty?
          div.tags do
            p "Resources tagged with " + @tag.name + ":"
            for clip in @clips
              a(clip.nickname, :href => R(Clips, clip.id))
            end
          end
        end
        unless @pages.nil? or @pages.empty?
          div.tags do
            p "Pages tagged with " + @tag.name + ":"
            for page in @pages
              a(page.nickname, :href => R(Pages, page.id))
            end
          end
        end
        unless @authors.nil? or @authors.empty?
          div.tags do
            p "Authors tagged with " + @tag.name + ":"
            for author in @authors
              a(author.name, :href => R(Authors, author.id))
            end
          end
        end
        unless @state.user_id.blank?
          _tag(@tag)
        end
      end
    end

    def view_clips
      h2 "Resources:"
      for clip in @clips
        div.clip do
          a(clip.nickname, :href => R(Clips, clip.id, 'edit'))
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
          h3 "Referenced in:" unless clip.references.empty?
          for post in clip.posts
            a(post.title, :href => R(Posts, post.id))
          end
          for page in clip.pages
            a(page.title, :href => R(Pages, page.id))
          end
        end
      end
    end

    # partials

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

    def _tag(tag)
      a('Delete ' + tag.name, :href => R(Tags, tag.id, 'delete'))
    end

    def _tagged_with(tags)

      # ignore invalid arguments
      unless(tags.nil? or tags.empty?)
        p.tags do
          span "Tags:"
          tags.each do |tag|
            a(tag.name, :href => R(Tags, tag.id))
          end
        end
      end
    end

    def _page(page)
      h1 { a(page.title, :href => R(Pages, page.id)) }
      when_logged_in {
        a( "Edit this Page",
           :class => "edit ed-page",
           :href  => R(Pages, page.id, 'edit'))
      }

      _tagged_with(page.tags)
      render_text(page.body, :html)
    end

    def _post( post,summary=false )
      full = R(Posts, post.id)
      h1 { a(post.title, :href => full) }

      # the date in human readable
      # format: March 11th 2008
      p.date do
        day = post.created_at.mday
        ord = (day < 10 or day > 20)\
            ? %w{th st nd rd th th th th th th}[day % 10]\
            : "th" # all the teens are "th"

        # display the day including the ordinal
        span post.created_at.strftime("%B #{day}#{ord} %Y")
      end

      # the authors that produced this
      # post: Tom, Dick and Harry
      pa = post.authors
      unless pa.empty?
        p.authors do
          span "By"
          pa.each_with_index do |author,i|

            # capture the link as text, and add a join (COMMA or AND)
            link = capture { a(author.name, :href => R(Authors, author.id)) }
            join = (i < (pa.length-1)) ? (i < (pa.length-2) ? "," : " and ") : ""
            text link.trim + join + "\n"
          end
        end
      end

      when_logged_in do
        a( "Edit this Essay",
           :class => "edit ed-post",
           :href  => R(Posts, post.id, 'edit'))
      end

      _tagged_with(post.tags)

      div.body do
        # abridge the essay (first paragraph only)
        post.body.gsub!(%r|\n+.*|, "") if summary
        
        # posts are supplied as raw html, for now
        render_text(post.body, :html)
        
        # link to the full essay, if this is not it
        p { a.complete("View Complete Essay", :href=>full) } if summary
      end
      
      unless summary
        clips = {
          :projects   => [],
          :references => [] }
        
        # section headers
        titles = {
          :projects   => "Related Projects",
          :references => "References" }
        
        # iterate all of this post's clips,
        # sort them into "project" and "not
        # project" (reference) arrays
        post.clips.each do |clip|
          type = clip.has_tag?("project") ? (:projects) : (:references)
          clips[type].push clip
        end
        
        # iterate each 'type' of clip, and create
        # div + h3 + (all clips of type)
        clips.each_key do |type|
          unless clips[type].empty?
            div.clips do
              h3 titles[type]
              
              # all clips of this type,
              # via the _clip partial
              clips[type].each do |clip|
                div.clip do
                  _clip clip
                end
              end
            end
          end
        end
      end

      # css hack for ie < 7
      div.clear_hack ""
    end

    def _clip(clip)
      blockquote do
        render_text clip.body
      end

      div.source do
        a(clip.nickname, :href => clip.url)
        cite clip.source
      end
      tags = clip.tags unless clip.tags.nil?
      unless tags.empty?
        div.tags do
          p "tagged with:"
          for tag in tags
            a(tag.name, :href => R(Tags, tag.id))
          end
        end
      end

      when_logged_in do
        a( "Edit this Clip",
           :class => "edit ed-clip",
           :href  => R(Clips, clip.id, 'edit'))
      end
    end

    def _author(author)
      a(author.name, :href => author.url)
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
      form({:method => 'post'}.merge(opts)) do
        
        # this partial serves new
        # pages and existing pages
        if page.title.nil?
          h1 "Creating a New Page"
        else
          h1 "Editing: " + page.title.to_s
          a("Delete", :class=>"edit del", :href=>R(Pages, page.id, "delete"))
        end
        
        # form fields
        fieldset do
          div.first do
            label "Title", :for=>"page_title"
            input :name=>"page_title", :value=>page.title
          end

          div do
            label "Nickname", :for=>"page_nickname"
            input :name=>"page_nickname", :value=>page.nickname
          end

          div do
            label "Body", :for=>"page_body"
            textarea page.body, :name=>"page_body"
          end
        end
        
        # relationships as check boxes
        _checks(@all_tags,    @these_tags,    "Tags:")
        _checks(@all_clips,   @these_clips,   "References:")
        
        input :type=>"hidden", :name=>"post_id", :value=>post.id
        button "Submit"
      end
    end


    def _post_form(post, opts)
      form({:method => 'post'}.merge(opts)) do
        
        # this partial serves new
        # posts and existing posts
        if post.title.nil?
          h1 "Creating a New Essay"
        else
          h1 "Editing: " + post.title.to_s
          a("Delete", :class=>"edit del", :href=>R(Posts, post.id, "delete"))
        end
        
        # form fields
        fieldset do
          div.first do
            label "Title", :for=>"post_title"
            input :name=>"post_title", :value=>post.title
          end

          div do
            label "Nickname", :for=>"post_nickname"
            input :name=>"post_nickname", :value=>post.nickname
          end

          div do
            label "Body", :for=>"post_body"
            textarea post.body, :name=>"post_body"
          end
        end
        
        # relationships as check boxes
        _checks(@all_authors, @these_authors, "Authors:")
        _checks(@all_tags,    @these_tags,    "Tags:")
        _checks(@all_clips,   @these_clips,   "References:")
        
        input :type=>"hidden", :name=>"post_id", :value=>post.id
        button "Submit"
      end
    end


    def _clip_form(clip, opts)
      form({:method=>"post"}.merge(opts)) do
        
        # this partial serves new
        # clips and existing clips
        if clip.nickname.nil?
          h1 "Creating a New Resource"
        else
          h1 "Editing: " + clip.nickname.to_s
          a("Delete", :class=>"edit del", :href=>R(Clips, clip.id, "delete"))
        end

        # form fields
        fieldset do
          div.first do
            label "Nickname", :for=>"fm-clip-nickname"
            input :id=>"fm-clip-nickname", :name=>"clip_nickname", :value=>clip.nickname
          end
          
          div do
            label "Url", :for=>"fm-clip-url"
            input :id=>"fm-clip-url", :name=>"clip_url", :type=>"text", :value=>clip.url
          end
          
          div do
            label "Source", :for=>"fm-clip-source"
            input :id=>"fm-clip-source", :name=>"clip_source", :value=>clip.source
          end
          
          div do
            label "Body", :for=>"fm-clip-body"
            div.hint "It's probably a better idea to edit this part in an external text editor and paste it in here."
            textarea clip.body, :id=>"fm-clip-body", :name=>"clip_body"
          end
        end
        
        # relationships as check boxes
        _checks(@all_tags,  @these_tags,  "Tagged with:")
        _checks(@all_posts, @these_posts, "Referenced by Posts:")
        _checks(@all_pages, @these_pages, "Referenced by Pages:")
        
        input :type=>"hidden", :name=>"clip_id", :value=>clip.id
        button "Submit"
      end
    end

    def _author_form(author, opts)
      form({:method=>"post"}.merge(opts)) do
        
        # this partial serves new
        # authors and existing authors
        if author.name.nil?
          h1 "Creating a New Resource"
        else
          h1 "Editing: " + author.name.to_s
          a("Delete", :class=>"edit del", :href=>R(Authors, author.id, "delete"))
        end

        # form fields
        fieldset do
          div.first do
            label "First Name", :for=>"fm-author-first"
            input :id=>"fm-author-first", :name=>"author_first", :value=>author.first
          end
          
          div do
            label "Last Name", :for=>"fm-author-last"
            input :id=>"fm-author-last", :name=>"author_last", :value=>author.last
          end
          
          div do
            label "URL", :for=>"fm-author-url"
            input :id=>"fm-author-url", :name=>"author_url", :value=>author.url
          end
          
          div do
            label "Photo Url", :for=>"fm-author-photo"
            input :id=>"fm-author-photo", :name=>"author_photo_url", :value=>author.photo_url
          end
          
          div do
            label "Organization", :for=>"fm-author-org"
            input :id=>"fm-author-org", :name=>"author_org", :value=>author.org
          end
          
          div do
            label "Organization URL", :for=>"fm-author-org-url"
            input :id=>"fm-author-org-url", :name=>"author_org_url", :value=>author.org_url
          end
          
          div do
            label "Bio", :for=>"fm-author-bio"
            textarea author.bio, :id=>"fm-author-bio", :name=>"author_bio"
          end
        end
        
        # relationships as check boxes
        _checks(@all_tags,  @these_tags,  "Tagged with:")
        _checks(@all_posts, @these_posts, "Credited by Posts:")
        
        input :type=>"hidden", :name=>"author_id", :value=>author.id
        button "Submit"
       end
    end

    def _tag_form(tag, opts)
      form({:method => 'post'}.merge(opts)) do
        
        # this partial is wired up to edit tags,
        # but currently, there is no controller
        # route to it. todo?
        if tag.name.nil?
          h1 "Creating a New Tag"
        else
          h1 "Editing: " + tag.name.to_s
          a("Delete", :class=>"edit del", :href=>R(Tags, tag.id, "delete"))
        end
        
        # form fields
        fieldset do
          div.first do
            label "Name", :for=>"tag_name"
            input :name=>"tag_name", :value=>tag.name
          end
        end
        
        # no check boxes to link this tag to pages, essays, etc
        
        input :type=>"hidden", :name=>"tag_id", :value=>tag.id
        button "Submit"
      end
    end

    def _checks(all_things, these_things, caption=nil)
      if all_things
        
        # optionally, label these check boxes
        h3.checks(caption)\
          unless caption.nil?
        
        # iterate all "things"
        fieldset.checks do
          all_things.each_with_index do |thing,n|

            # auto figure-out what sort of things we are
            # checking off. "Kambi::Models::Post" becomes "post"
            name = thing.class.to_s.gsub("Kambi::Models::", "").downcase
            checked = (!these_things.nil? && these_things.include?(thing))
            chk_hash = checked ? { :checked=>"checked" } : {}

            div(:class=>( n==0 ? "first" : "")) do
              # the [x] label pair
              # (inlined via css)
              
              input(chk_hash.merge({:type=>"checkbox", :id=>"fm-#{name}-#{thing.id}", :name=>"#{name}-#{thing.id}"}))
              label thing.to_s, :for => "fm-#{name}-#{thing.id}"
            end
          end
        end
      end
    end
  end
  
  # TODO: what is this?
  default_format :HTML
end

