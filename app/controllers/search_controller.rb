class SearchController < ApplicationController
  require 'will_paginate/array'
  helper_method :sort_column, :sort_direction, :per_page
  include ApplicationHelper

  def label_author(value)
    value == '' ? 'empty string' : value
  end
  def label_office(value)
    value == '' ? 'empty string' : value
  end
  def label_flag_ids(value)
    # Original code:
    # Flag.find(value).label

    # TODO: Possibly find a more elegant performance optimization
    # This is an optimization because Flag.all is cached,
    # but it's not very elegant IMO. The goal is to minimize lookup
    # of flags on every search.
    Flag.label_map[value.to_s]
  end
  def label_license_id(value)
    # TODO: See label_flag_ids
    License.name_map[value.to_s]
  end
  def label_mime_type_id(value)
    MimeType.find(value).name
  end
  def label_mime_type_category_id(value)
    MimeTypeCategory.find(value).name
  end
  
  def index
    date_params = {}
    [:original_date, :created_at].each do |date_type|
      [:start_date, :end_date].each do |p|
        date_params["#{date_type}_#{p}"] = build_date_from_string_safe(params["#{date_type}_#{p}"])
      end
    end
   
    @search = Sunspot.new_search(StoredFile)
    @search.build do
      if params.has_key?(:search)
        fulltext params[:search] do
          query_phrase_slop 1 
        end
      end

      [:flag_ids, :mime_type_id, :mime_type_category_id, :license_id,
        :indexed_collection_list, :batch_id, :indexed_tag_list].each do |facet|
        if params.has_key?(facet)
          if params[facet].is_a?(Array)
            params[facet].each { |t| with facet, t }
          else
            with facet, CGI.unescape(params[facet])
          end
        end
      end

      [:copyright_holder, :author, :contributor_name].each do |text_facet|
        unless params[text_facet].blank?
          fulltext(params[text_facet], :fields => [text_facet])
        end
      end

      facet :flag_ids, :mime_hierarchy, :license_id

      [:original_date, :created_at].each do |date_type|
        if date_params["#{date_type}_start_date"]
          with(date_type).greater_than date_params["#{date_type}_start_date"].beginning_of_day 
        end
        if date_params["#{date_type}_end_date"]
          with(date_type).less_than date_params["#{date_type}_end_date"].end_of_day 
        end
      end

      order_by sort_column, sort_direction 
    end

    @search.execute!
    @hits = filter_and_paginate_search_results(@search)

    build_removeable_facets(params)

    build_searchable_facets(params)
  end

  def build_searchable_facets(params)
    @facets = {}

    links = StoredFile.tag_list.inject([]) do |arr, tag|
      if !params[:indexed_tag_list] || !params[:indexed_tag_list].include?(tag.name)
        params[:indexed_tag_list] ||= []
        arr.push({
          :label => tag.name,
          :url => url_for(params.clone.merge({ :indexed_tag_list => params[:indexed_tag_list] + [tag.name] }))
        })
      end
      arr
    end
    @facets[:indexed_tag_list] = links if links.size > 0

    [:flag_ids, :license_id].each do |facet|
      links = @search.facet(facet).rows.inject([]) do |arr, row|
        if StoredFile::FACETS_WITH_MULTIPLE.include?(facet)
          if !params[facet] || !params[facet].include?(row.value.to_s)
            params[facet] ||= []
            arr.push({
              :label => self.send("label_#{facet.to_s}", row.value),
              :url => url_for(params.clone.merge({ facet => params[facet] + [row.value] }))
            })
          end
        else
          if params[facet] != row.value.to_s
            arr.push({
              :label => self.send("label_#{facet.to_s}", row.value),
              :url => url_for(params.clone.merge({ facet => row.value }))
            })
          end
        end
        arr
      end
      @facets[facet] = links if links.size > 0
    end

    if !params.has_key?(:mime_type_id) 
      @mime_categories = []
      links = []
      @search.facet(:mime_hierarchy).rows.each do |row|
        (mime_type_category_id, mime_type_id) = row.value.split('-')

        next if !(mime_type_category_id.present? && mime_type_id.present?)
   
        if !params.has_key?(:mime_type_category_id) && !@mime_categories.include?(mime_type_category_id) 
          links.push({
            :label => self.label_mime_type_category_id(mime_type_category_id),
            :id => mime_type_category_id,
            :class => "mime_type_category_id"
          })
          @mime_categories << mime_type_category_id 
        end
        links.push({
          :label => "&nbsp;&nbsp;#{self.label_mime_type_id(mime_type_id)}",
          :id => mime_type_id,
          :class => "mime_type_id"
        })
      end
      @facets[:mime_hierarchy] = links if links.size > 0
    end
  end

  def build_removeable_facets(params)
    @removeable_facets = {}
    @hidden_facets = {}

    removed_facets = ["search", "tag",
      "created_at_start_date", "created_at_end_date",
      "original_date_start_date", "original_date_end_date",
      "flag_ids", "license_id", "mime_type_id", "mime_type_category_id",
      "indexed_collection_list", "batch_id", "indexed_tag_list", "author",
      "contributor_name", "copyright_holder"]

    params.each do |facet, value|
      if value.presence && removed_facets.include?(facet)
        @hidden_facets.merge!({ facet => value })
        @removeable_facets[facet] ||= []
        if value.is_a?(Array)
          params[facet].each do |v|
            t = params.clone
            t[facet] = t[facet].select{ |b| b != v }
            @removeable_facets[facet] << {
              :label => self.respond_to?("label_#{facet.to_s}", v) ? self.send("label_#{facet.to_s}", v) : v,
              :url => url_for(t)
            }
           end
       else
        @removeable_facets[facet] << {
          :label => self.respond_to?("label_#{facet.to_s}", value) ? self.send("label_#{facet.to_s}", value) : value,
          :url => url_for(params.clone.remove!(facet))
        }
        end
      end
    end

    label_map = {
      "search" => "Keyword",
      "indexed_tag_list" => "Tag",
      "license_id" => "License",
      "indexed_collection_list" => "Collection Name",
      "flag_ids" => "Flags",
      "batch_id" => "Batch",
      "created_at_start_date" => "Created After",
      "created_at_end_date" => "Created Before",
      "original_date_start_date" => "Original Date After",
      "original_date_end_date" => "Original Date Before",
      "mime_type_category_id" => "File Type Category",
      "mime_type_id" => "File Type",
      "contributor_name" => "Contributor",
      "copyright_holder" => "Copyright Holder"
    }
    @removeable_facets.each do |k, v|
      if(label_map[k])
        @removeable_facets[label_map[k]] = v
        @removeable_facets.delete(k)
      end
    end

    if params.has_key?(:date_type)
      @hidden_facets.merge!({ :date_type => params[:date_type] })
    end
  end

  private

  # Private method for filtering and paginating search results
  # Working directly with search.hits minimizes the requirement to access
  # stored file object, and eliminates object instantiation
  def filter_and_paginate_search_results(search)
    filtered_results = []

    open = AccessLevel.open
    search.hits.each do |hit|
      if current_user
        filtered_results << hit if User.can_view_cached?(hit.stored(:id), current_user)
      else
        filtered_results << hit if hit.stored(:access_level_id) == open.id
      end
    end

    filtered_results.paginate :page => params[:page], :per_page => per_page
  end

  def per_page
    session[:per_page] = params[:per_page] || session[:per_page] || "10"
  end

  def sort_column
    column = params[:sort_column] || session[:sort_column]
    if StoredFile.column_names.include?(column)
      session[:sort_column] = column
    else
      "created_at"
    end
  end

  def sort_direction
    direction = params[:sort_direction] || session[:sort_direction]
    if %w(asc desc).include?(direction)
      session[:sort_direction] = direction
    else
      "desc"
    end
  end
end
