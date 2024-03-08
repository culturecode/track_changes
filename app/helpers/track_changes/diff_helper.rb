module TrackChanges
  module DiffHelper
    def diff_action(diff)
      case diff.action
      when 'create'
        'added'
      when 'update'
        'updated'
      when 'destroy'
        'deleted'
      end
    end

    #
    # Generate a human readable sentence for a change in a TrackChanges::Diff
    #
    # diff        - a TrackChanges::Diff object
    # field       - the specific field of the diff (e.g. collection_id)
    # changes     - an array of the previous and current value for the field
    # link_models - an array of classes of models that should generate as in-sentence links
    #
    def diff_change_sentence(diff, field, changes, link_models = [])
      from, to = changes.is_a?(Array) ? changes : [nil, changes]

      from.reject!(&:blank?) if from.is_a?(Array)
      to.reject!(&:blank?) if to.is_a?(Array)

      return if from.blank? && to.blank?

      if record = diff.record
        field_name = diff.record.class.human_attribute_name(field)
        reflection = diff.record.class.reflect_on_association(field) # Look up association by name, e.g. users for has_many :users
        reflection ||= diff.record.class.reflections.values.detect {|ref| ref.foreign_key == field.to_s } # Detect association by foreign key, e.g. user_id for belongs_to :user
      end

      if reflection
        primary_key = reflection.options.fetch(:primary_key, :id)
        from = reflection.klass.where(primary_key => from) || content_tag(:span, 'DELETED', :class => 'deleted', :title => "This #{field_name} has been deleted") if from.present?
        to   = reflection.klass.where(primary_key => to)   || content_tag(:span, 'DELETED', :class => 'deleted', :title => "This #{field_name} has been deleted") if to.present?
      end

      if from.blank?
        content_tag(:span, field_name, :class => 'field_name') + " set to " + content_tag(:span, link_diff_field_value(to, link_models), :class => 'field_value')
      elsif to.blank?
        content_tag(:span, field_name, :class => 'field_name') + " removed"
      else
        content_tag(:span, field_name, :class => 'field_name') + " changed from " + content_tag(:span, link_diff_field_value(from, link_models), :class => 'field_value') + " to " + content_tag(:span, link_diff_field_value(to, link_models), :class => 'field_value')
      end
    end

    def link_diff_field_value(value, link_models = [])
      case value
      when Array, ActiveRecord::Relation
        value.collect{|v| link_diff_field_value(v, link_models) }.to_sentence.html_safe
      when *link_models
        link_to(value.to_s, value)
      else
        value
      end
    end
  end
end
