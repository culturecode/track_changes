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

    def diff_change_sentence(diff, field, changes, link_models = [])
      from, to = changes.is_a?(Array) ? changes : [nil, changes]
      # return if diff.action == 'destroy'
      return if from.blank? && to.blank?

      if record = diff.record
        field_name = diff.record.class.human_attribute_name(field)
        reflection = diff.record.class.reflections.values.detect {|reflection| reflection.foreign_key == field.to_s }
      end

      if reflection
        from = reflection.klass.find(from) if from.present?
        to   = reflection.klass.find(to)   if to.present?
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
      when Array
        value.collect{|v| link_diff_field_value(v, link_models) }.to_sentence.html_safe
      when *link_models
        link_to(value.to_s, value)
      else
        value
      end
    end
  end
end
