# encoding: utf-8

module Bionomia
   class MailWorker
      include Sidekiq::Job
      sidekiq_options queue: :critical, retry: 3
 
      def perform(opts = {})
         settings = Settings.merge!(opts)
         Pony.options = {
            charset: 'UTF-8',
            from: settings.gmail.email,
            subject: settings.subject,
            via: :smtp,
            via_options: {
               address: 'smtp.gmail.com',
               port: '587',
               enable_starttls_auto: true,
               user_name: settings.gmail.username,
               password: settings.gmail.password,
               domain: settings.gmail.domain
            }
         }
         send_message(email: settings.email, body: settings.body)
      end
 
      def send_message(email:, body:)
         Pony.mail(
            to: email,
            body: body
         )
      end

   end
 end
 