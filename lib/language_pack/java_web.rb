require "language_pack/java"
require "language_pack/database_helpers"
require "fileutils"

# TODO logging
module LanguagePack
  class JavaWeb < Java
    include LanguagePack::DatabaseHelpers

    TOMCAT_URL =  "http://archive.apache.org/dist/tomcat/tomcat-6/v6.0.35/bin/apache-tomcat-6.0.35.tar.gz".freeze
    WEBAPP_DIR = "webapps/ROOT/".freeze

    def self.use?
      File.exists?("WEB-INF/web.xml") || File.exists?("webapps/ROOT/WEB-INF/web.xml")
    end

    def name
      "Java Web"
    end

    def compile
      Dir.chdir(build_path) do
        install_java
        install_tomcat
        remove_tomcat_files
        copy_webapp_to_tomcat
        move_tomcat_to_root
        install_database_drivers
        #install_insight
        copy_resources
        copy_droplet_yaml
        setup_profiled
      end
    end

    def install_tomcat
      FileUtils.mkdir_p tomcat_dir
      tomcat_tarball="#{tomcat_dir}/tomcat.tar.gz"

      download_tomcat tomcat_tarball

      puts "Unpacking Tomcat to #{tomcat_dir}"
      run_with_err_output("tar xzf #{tomcat_tarball} -C #{tomcat_dir} && mv #{tomcat_dir}/apache-tomcat*/* #{tomcat_dir} && " +
              "rm -rf #{tomcat_dir}/apache-tomcat*")
      FileUtils.rm_rf tomcat_tarball
      unless File.exists?("#{tomcat_dir}/bin/catalina.sh")
        puts "Unable to retrieve Tomcat"
        exit 1
      end
    end

    def download_tomcat(tomcat_tarball)
      puts "Downloading Tomcat: #{TOMCAT_URL}"
      run_with_err_output("curl --silent --location #{TOMCAT_URL} --output #{tomcat_tarball}")
    end

    def remove_tomcat_files
      %w[NOTICE RELEASE-NOTES RUNNING.txt LICENSE temp/. webapps/. work/. logs].each do |file|
        FileUtils.rm_rf("#{tomcat_dir}/#{file}")
      end
    end

    def tomcat_dir
      ".tomcat"
    end

    def copy_webapp_to_tomcat
      run_with_err_output("mkdir -p #{tomcat_dir}/webapps/ROOT && mv * #{tomcat_dir}/webapps/ROOT")
    end

    def move_tomcat_to_root
      run_with_err_output("mv #{tomcat_dir}/* . && rm -rf #{tomcat_dir}")
    end

    def copy_resources
      # Configure server.xml with variable HTTP port and context.xml with custom startup listener
      # TODO get startup listener jar from URL
      run_with_err_output("cp -r #{File.expand_path('../../../resources/tomcat', __FILE__)}/* #{build_path}")
    end

    def copy_droplet_yaml
      run_with_err_output("cp #{File.expand_path('../../../resources/droplet.yaml', __FILE__)} #{File.join(build_path, "..")}")
    end

    def java_opts
      # TODO proxy settings?
      # Don't override Tomcat's temp dir setting
      opts = super.merge({ "-Dhttp.port=" => "$VCAP_APP_PORT" })
      opts.delete("-Djava.io.tmpdir=")
      opts
    end

    def default_process_types
      {
        "web" => "./bin/catalina.sh run"
      }
    end

    def webapp_path
      File.join(build_path,"webapps","ROOT")
    end
  end
end