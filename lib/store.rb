module Store
  extend self

  def data 
    $args.state ||= {}
  end

  def find(query = {}, projection = {})
    query(query, projection)
  end

  def find_one(query = {}, projection = {})
    query_one(query, projection)
  end

  def insert_one(datum)
    id = datum._id || GTK.create_uuid
    datum._id = id
    
    data[id] = datum
    
    datum
  end

  def insert_many(records)
    records.each { |doc| insert_one(doc) }
    records
  end

  def update_many(query, operators, options = {})
    records = query(query)
    new_records = records.map { |record| update_record(record, query, operators, options) }
    new_records
  end

  def update_one(query, operators, options = {})
    record = query_one(query)
    return nil if !record && !options[:upsert]
    
    update_record(record, query, operators, options)
  end

  def replace_one(query, datum)
    record = query_one(query)
    return nil unless record
    
    datum._id = record._id
    data[record._id] = datum
    datum
  end

  def delete_one(query)
    record = query_one(query)
    return nil unless record
    
    data.delete(record._id)
    record
  end

  def delete_many(query)
    records = query(query)
    records.each { |record| data.delete(record._id) }
    records
  end

  private

  def query(query = {}, options = {})
    return [data[query._id]] if query._id && validate_record(query, data[query._id])
    
    result = if query.empty?
      data.values.lazy
    else
      data.values.lazy.select { |record| validate_record(query, record) }
    end

    result = project(options[:project], result) if options[:project]
    
    if options[:sort]
      result.sort! do |a, b|
        options[:sort].map { |field, direction|
          (a[field] <=> b[field]) * (direction > 0 ? 1 : -1)
        }.find { |comp| comp != 0 } || 0
      end
    end

    result = result.drop(options[:skip]) if options[:skip]
    result = result.take(options[:limit]) if options[:limit]
    
    result
  end

  def query_one(query = {}, projection = {})
    return data[query._id] if query._id
    
    record = if query.empty?
      data.values.first
    else
      data.values.find { |record| validate_record(query, record) }
    end
    
    record ? project(projection, record) : nil
  end

  def validate_record(query, record)
    return false unless record
    return false unless record.is_a?(Hash)
    
    query.all? do |field, value|
      if value.is_a?(Hash) && !value.empty?
        process_selectors(record, field, value)
      else
        traverse_field(record, field) == value
      end
    end
  end

  def traverse_field(record, field)
    field.to_s.split('.').inject(record) { |memo, part| memo && memo[fix_key(memo, part)] }
  end

  def process_selectors(record, field, selectors)
    if compound_operator?(field)
      process_compound_selector(record, field, selectors)
    else
      selectors.all? { |selector, value| process_selector(record, field, selector, value) }
    end
  end

  def compound_operator?(operator)
    [:_or, :_and, :_nor].include?(operator.to_sym)
  end

  def process_compound_selector(record, operator, operations)
    case operator.to_sym
    when :_or
      operations.any? { |expr| validate_record(expr, record) }
    when :_and
      operations.all? { |expr| validate_record(expr, record) }
    when :_nor
      !operations.any? { |expr| validate_record(expr, record) }
    end
  end

  def process_selector(record, field, selector, value)
    case selector.to_sym
    when :_eq
      traverse_field(record, field) == value
    when :_gt
      field_value = traverse_field(record, field)
      field_value && field_value > value
    when :_lt
      field_value = traverse_field(record, field)
      field_value && field_value < value
    when :_gte
      field_value = traverse_field(record, field)
      field_value && field_value >= value
    when :_lte
      field_value = traverse_field(record, field)
      field_value && field_value <= value
    when :_ne
      traverse_field(record, field) != value
    when :_in
      value.include?(traverse_field(record, field))
    when :_nin
      !value.include?(traverse_field(record, field))
    when :_exists
      (value && !traverse_field(record, field).nil?) || (!value && traverse_field(record, field).nil?)
    when :_type
      field_type = traverse_field(record, field).class.to_s.downcase
      if value.is_a?(Array)
        value.include?(field_type)
      else
        field_type == value
      end
    end
  end

  def project(projection, record_or_records)
    return record_or_records unless projection
    
    projection = projection.merge(_id: true) unless projection.key?(:_id)
    
    if record_or_records.is_a?(Array)
      record_or_records.map { |record| project_record(projection, record) }
    else
      project_record(projection, record_or_records)
    end
  end

  def project_record(projection, record)
    result = {}
    projection.each do |field, include|
      result[field] = record[field] if include
    end
    result
  end

  def update_record(record, query, operators, options)
    is_update_document = operators.values.none? { |v| v.is_a?(Hash) }
    
    if is_update_document
      id = record && record._id
      record = operators
      record._id = id
    else
      options._is_new = !record
      
      if !record && options.upsert
        record = build_record_from_query(query)
      end
      
      operators.each do |operator, fields|
        process_operator(operator, fields, record, options)
      end
    end
    
    if options[:upsert] && !record._id
      record._id = query._id || uuid
    end

    data[record._id] = record
    record
  end

  def build_record_from_query(query)
    return query unless query.is_a?(Hash)
    
    record = {}
    query.each do |k, v|
      next if k.to_s.start_with?('_')
      record[k] = build_record_from_query(v)
    end
    record
  end

  def fix_key(obj, key)
    if obj.is_a?(Array)
      key.to_i
    else
      key.to_sym
    end
  end

  def process_operator(operator, fields, record, options)
    fields.each do |field, value|
      parts = field.to_s.split('.')
      traversal = record
      
      parts[0..-2].each do |part|
        key = fix_key(traversal, part)
        traversal[key] ||= {}
        traversal = traversal[key]
      end
      
      key = fix_key(traversal, parts.last)
      
      case operator.to_sym
      when :_set
        traversal[key] = value
      when :_inc
        traversal[key] ||= 0
        traversal[key] += value
      when :_unset
        traversal.delete(key)
      when :_push
        traversal[key] ||= []
        if value.is_a?(Hash) && value[:_each]
          traversal[key].concat(value[:_each])
        else
          traversal[key] << value
        end
      when :_pull
        traversal[key]&.delete(value)
      end
    end
  end
end