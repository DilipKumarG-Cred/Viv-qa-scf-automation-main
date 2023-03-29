module Utils
  module Mails
    def vendor_removed_mail(client_name)
      email = $mail_helper.fetch_mail(subject: 'You have been removed by Myntra', body: client_name)
      flag = email.include? 'Please be notified that you have been removed from the platform by Mynthra Customer user from his program'
      raise "No matching mail found with body including 'removed mail notification text'" unless flag

      flag
    end

    def rejection_mail(client_name, document_name)
      email = $mail_helper.fetch_mail({ subject: 'Rejected Document Notification', body: client_name })
      email.include? document_name
    end

    def verify_mail_present(subject:, body_content:, text:)
      email = $mail_helper.fetch_mail({ subject: subject, body: body_content }, 25)
      email.include?(text)
    end

    # Yopmail
    def fetch_yopmail(mail_box:, subject:, body:)
      count = 0
      begin
        mbox = mail_box == $conf['notification_mailbox'] ? $yopmail_helper : $yopmail_activation_helper
        mails = mbox.filter_mail_by_subject(subject)
        raise "No matching mail found with subject #{subject}" if mails.empty?

        p "#{mails.size} mails found with matching subject"
        mails_with_content = $yopmail_helper.get_ui_mail_content(mails)
        mails_with_content.each do |mail|
          body_text = body.is_a?(Array) ? body : [body]
          flag = true
          body_text.each do |text|
            flag &= mail[:mail_content].include? text
          end
          return mail if flag
        end
      rescue => e
        count += 1
        sleep 3
        retry if count < 5
        raise e
      end
      raise "No matching mail found with body including #{body}"
    end

    def yopmail_get_activation_link(email_values)
      email = fetch_yopmail(mail_box: email_values[:mail_box], subject: email_values[:subject], body: email_values[:body])
      links = []
      email[:subject_link].each do |link|
        if email_values[:link_text].nil?
          return link[:link] if link[:link].include?('set-password')
        elsif link[:link].include?(email_values[:link_text])
          links << link[:link]
        end
      end
      if links.empty?
        "No link matched #{email[:subject_link]}"
      elsif links.size == 1
        links[0]
      else
        links
      end
    end
  end
end
