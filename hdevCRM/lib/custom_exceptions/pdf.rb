module CustomExceptions::Pdf
  class UploadError < CustomExceptions::Base
    def initialize(message = I18n.t('errors.api.pdf.upload_failed'))
      super(message)
    end
  end

  class ValidationError < CustomExceptions::Base
    def initialize(message = I18n.t('errors.api.pdf.validation_failed'))
      super(message)
    end
  end

  class FaqGenerationError < CustomExceptions::Base
    def initialize(message = I18n.t('errors.api.pdf.faq_generation_failed'))
      super(message)
    end
  end
end
