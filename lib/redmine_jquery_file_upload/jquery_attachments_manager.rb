if RUBY_VERSION < '1.9.2'
  require 'json'
end


module RedmineJqueryFileUpload

  module JqueryAttachmentsManager
    def self.included(base)
      base.extend ClassMethods
      base.send(:include, InstanceMethods)
    end

    module ClassMethods
      def loads_jquery_attachments_before(*actions)
        before_filter :load_jquery_attachments, :only => actions
        after_filter :delete_tempfolder, :only => actions
      end
    end

    module InstanceMethods

      private

      def load_jquery_attachments
        folder_name = RedmineJqueryFileUpload::JqueryFilesManager.sanitize_filename(params[:tempFolderName])
        return if folder_name.blank?
        @temp_folder = File.join(RedmineJqueryFileUpload.tmpdir, folder_name)
        return unless File.exist?(@temp_folder)
        file, tempfile = nil
        params[:attachments] && params[:attachments].each do |order, attachment|
          begin
            tempfile = File.open(File.join(@temp_folder, "#{order}.data"), 'rb')

            File.open(File.join(@temp_folder, "#{order}.metadata"), 'rb') do |f|
              opts = JSON::parse(f.read).symbolize_keys
              # for compatibility with ruby < 1.9.2 (instance of File does not have method #size)
              if RUBY_VERSION < "1.9.2"
                tempfile.instance_eval do
                  @size ||= opts[:size]
                  def size; @size end
                end
              end

              # add to tempfile some methods of Tempfile instance
              tempfile.instance_eval do |f|
                alias :length :size
                alias :close! :close
                def delete
                  File.delete self.path
                end
                alias :unlink :delete
              end

              opts.merge!(:tempfile => tempfile)
              opts[:filename] = attachment[:name] if attachment[:name]
              file = ActionDispatch::Http::UploadedFile.new opts
            end
          rescue Errno::ENOENT
          end
          attachment[:file] = file
        end
      end

      def delete_tempfolder
        FileUtils.rm_rf @temp_folder if @temp_folder && File.exist?(@temp_folder)
      end

    end

  end

end
