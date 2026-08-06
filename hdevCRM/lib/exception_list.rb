require 'net/imap'

module ExceptionList
  SMTP_EXCEPTIONS = [
    Net::SMTPSyntaxError
  ].freeze

  IMAP_EXCEPTIONS = [
    Errno::ECONNREFUSED, Net::OpenTimeout,
    Errno::ECONNRESET, Errno::ENETUNREACH, Net::IMAP::ByeResponseError,
    SocketError
  ].freeze
end
