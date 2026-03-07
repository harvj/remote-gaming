module Services
  Response = ImmutableStruct.new(:subject, [:errors]) do
    def success?
      errors.empty?
    end

    def error?
      errors.present?
    end

    def status
      success? ? :success : :error
    end
  end

  # ----- Services::Base

  class Base
    attr_reader :subject, :parent, :params

    def apply_post_processing
    end

    def apply_pre_processing
    end

    def target_class
      target_class_name.constantize
    end

    def target_class_name
      self.class.name.deconstantize
    end

    def child
      target_class_name.underscore
    end

    def children
      target_class_name.underscore.pluralize
    end
  end

  # ----- Services::Build

  class Build < Services::Base
    def self.call(parent, params={})
      new(parent, params).()
    end

    def initialize(parent, params={})
      @parent = parent
      @params = params
    end

    def call
      @subject = build_child
      apply_post_processing
      subject
    end

    private

    def build_child
      parent.class.reflections.include?(children) ? parent.send(children).build(params) : parent.send("build_#{child}", params)
    end
  end

  # ----- Services::Create

  class Create < Services::Base
    def self.call(parent, params={})
      new(parent, params).()
    end

    def self.!(parent, params={})
      new(parent, params).call!
    end

    def initialize(parent, params={})
      @parent = parent
      @subject = if params.class.name == target_class_name
        params
      else
        target_class::Build.(parent, params)
      end
    end

    def call
      create { subject.save }
    end

    def call!
      create { subject.save! }
    end

    private

    def create(&_block)
      apply_pre_processing
      apply_post_processing if yield

      Services::Response.new(subject: subject, errors: subject.errors)
    end
  end

  # ----- Services::Update

  class Update < Services::Base
    def self.call(subject, params={})
      new(subject, params).()
    end

    def self.!(subject, params={})
      new(subject, params).call!
    end

    def initialize(subject, params={})
      @subject = subject
      @params = params
    end

    def call
      update { subject.update(params) }
    end

    def call!
      update { subject.update!(params) }
    end

    private

    def update(&_block)
      if changed?
        apply_pre_processing
        apply_post_processing if yield
      end

      Services::Response.new(subject: subject, errors: subject.errors)
    end

    def changed?
      subject.attributes != subject.attributes.with_indifferent_access.merge(params)
    end
  end
end
