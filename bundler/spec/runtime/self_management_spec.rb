# frozen_string_literal: true

RSpec.describe "Self management" do
  describe "auto switching" do
    let(:previous_minor) do
      "2.3.0"
    end

    let(:current_version) do
      "2.4.0"
    end

    before do
      build_repo4 do
        build_bundler previous_minor

        build_bundler current_version

        build_gem "myrack", "1.0.0"
      end

      gemfile <<-G
        source "https://gem.repo4"

        gem "myrack"
      G
    end

    it "installs locked version when using system path and uses it" do
      lockfile_bundled_with(previous_minor)

      bundle "config set --local path.system true"
      bundle "install", preserve_ruby_flags: true
      expect(out).to include("Bundler #{Bundler::VERSION} is running, but your lockfile was generated with #{previous_minor}. Installing Bundler #{previous_minor} and restarting using that version.")

      # It uninstalls the older system bundler
      bundle "clean --force", artifice: nil
      expect(out).to eq("Removing bundler (#{Bundler::VERSION})")

      # App now uses locked version
      bundle "-v", artifice: nil
      expect(out).to end_with(previous_minor[0] == "2" ? "Bundler version #{previous_minor}" : previous_minor)

      # ruby-core test setup has always "lib" in $LOAD_PATH so `require "bundler/setup"` always activate the local version rather than using RubyGems gem activation stuff
      unless ruby_core?
        # App now uses locked version, even when not using the CLI directly
        file = bundled_app("bin/bundle_version.rb")
        create_file file, <<-RUBY
          #!#{Gem.ruby}
          require 'bundler/setup'
          puts Bundler::VERSION
        RUBY
        file.chmod(0o777)
        cmd = Gem.win_platform? ? "#{Gem.ruby} bin/bundle_version.rb" : "bin/bundle_version.rb"
        sys_exec cmd, artifice: nil
        expect(out).to eq(previous_minor)
      end

      # Subsequent installs use the locked version without reinstalling
      bundle "install --verbose", artifice: nil
      expect(out).to include("Using bundler #{previous_minor}")
      expect(out).not_to include("Bundler #{Bundler::VERSION} is running, but your lockfile was generated with #{previous_minor}. Installing Bundler #{previous_minor} and restarting using that version.")
    end

    it "installs locked version when using local path and uses it" do
      lockfile_bundled_with(previous_minor)

      bundle "config set --local path vendor/bundle"
      bundle "install", preserve_ruby_flags: true
      expect(out).to include("Bundler #{Bundler::VERSION} is running, but your lockfile was generated with #{previous_minor}. Installing Bundler #{previous_minor} and restarting using that version.")
      expect(vendored_gems("gems/bundler-#{previous_minor}")).to exist

      # It does not uninstall the locked bundler
      bundle "clean"
      expect(out).to be_empty

      # App now uses locked version
      bundle "-v"
      expect(out).to end_with(previous_minor[0] == "2" ? "Bundler version #{previous_minor}" : previous_minor)

      # ruby-core test setup has always "lib" in $LOAD_PATH so `require "bundler/setup"` always activate the local version rather than using RubyGems gem activation stuff
      unless ruby_core?
        # App now uses locked version, even when not using the CLI directly
        file = bundled_app("bin/bundle_version.rb")
        create_file file, <<-RUBY
          #!#{Gem.ruby}
          require 'bundler/setup'
          puts Bundler::VERSION
        RUBY
        file.chmod(0o777)
        cmd = Gem.win_platform? ? "#{Gem.ruby} bin/bundle_version.rb" : "bin/bundle_version.rb"
        sys_exec cmd, artifice: nil
        expect(out).to eq(previous_minor)
      end

      # Subsequent installs use the locked version without reinstalling
      bundle "install --verbose"
      expect(out).to include("Using bundler #{previous_minor}")
      expect(out).not_to include("Bundler #{Bundler::VERSION} is running, but your lockfile was generated with #{previous_minor}. Installing Bundler #{previous_minor} and restarting using that version.")
    end

    it "installs locked version when using local path, even if locked version installed globally, and uses it" do
      lockfile_bundled_with(previous_minor)
      system_gems "bundler-#{previous_minor}"

      bundle "config set --local path vendor/bundle"
      bundle "install --verbose", preserve_ruby_flags: true
      expect(out).to include("Installing bundler #{previous_minor}")
      expect(vendored_gems("gems/bundler-#{previous_minor}")).to exist

      # Uninstall the global version
      gem_command "uninstall bundler --force --executables --version #{previous_minor}"

      # App still uses locked version
      bundle "-v"
      expect(out).to end_with(previous_minor[0] == "2" ? "Bundler version #{previous_minor}" : previous_minor)

      # Subsequent installs use the locked version without reinstalling
      bundle "install --verbose"
      expect(out).to include("Using bundler #{previous_minor}")
    end

    it "installs locked version when using deployment option and uses it" do
      lockfile_bundled_with(previous_minor)

      bundle "config set --local deployment true"
      bundle "install", preserve_ruby_flags: true
      expect(out).to include("Bundler #{Bundler::VERSION} is running, but your lockfile was generated with #{previous_minor}. Installing Bundler #{previous_minor} and restarting using that version.")
      expect(vendored_gems("gems/bundler-#{previous_minor}")).to exist

      # It does not uninstall the locked bundler
      bundle "clean"
      expect(out).to be_empty

      # App now uses locked version
      bundle "-v"
      expect(out).to end_with(previous_minor[0] == "2" ? "Bundler version #{previous_minor}" : previous_minor)

      # Subsequent installs use the locked version without reinstalling
      bundle "install --verbose"
      expect(out).to include("Using bundler #{previous_minor}")
      expect(out).not_to include("Bundler #{Bundler::VERSION} is running, but your lockfile was generated with #{previous_minor}. Installing Bundler #{previous_minor} and restarting using that version.")
    end

    it "does not try to install a development version" do
      lockfile_bundled_with("#{previous_minor}.dev")

      bundle "install --verbose"
      expect(out).not_to match(/restarting using that version/)

      bundle "-v"
      expect(out).to eq(Bundler::VERSION[0] == "2" ? "Bundler version #{Bundler::VERSION}" : Bundler::VERSION)
    end

    it "does not try to install when --local is passed" do
      lockfile_bundled_with(previous_minor)
      system_gems "myrack-1.0.0", path: default_bundle_path

      bundle "install --local"
      expect(out).not_to match(/Installing Bundler/)

      bundle "-v"
      expect(out).to eq(Bundler::VERSION[0] == "2" ? "Bundler version #{Bundler::VERSION}" : Bundler::VERSION)
    end

    it "shows a discrete message if locked bundler does not exist" do
      missing_minor = "#{Bundler::VERSION[0]}.999.999"

      lockfile_bundled_with(missing_minor)

      bundle "install"
      expect(err).to eq("Your lockfile is locked to a version of bundler (#{missing_minor}) that doesn't exist at https://rubygems.org/. Going on using #{Bundler::VERSION}")

      bundle "-v"
      expect(out).to eq(Bundler::VERSION[0] == "2" ? "Bundler version #{Bundler::VERSION}" : Bundler::VERSION)
    end

    it "installs BUNDLE_VERSION version when using bundle config version x.y.z" do
      lockfile_bundled_with(current_version)

      bundle "config set --local version #{previous_minor}"
      bundle "install", preserve_ruby_flags: true
      expect(out).to include("Bundler #{Bundler::VERSION} is running, but your configuration was #{previous_minor}. Installing Bundler #{previous_minor} and restarting using that version.")

      bundle "-v"
      expect(out).to eq(previous_minor[0] == "2" ? "Bundler version #{previous_minor}" : previous_minor)
    end

    it "does not try to install when using bundle config version global" do
      lockfile_bundled_with(previous_minor)

      bundle "config set version system"
      bundle "install"
      expect(out).not_to match(/restarting using that version/)

      bundle "-v"
      expect(out).to eq(Bundler::VERSION[0] == "2" ? "Bundler version #{Bundler::VERSION}" : Bundler::VERSION)
    end

    it "does not try to install when using bundle config version <dev-version>" do
      lockfile_bundled_with(previous_minor)

      bundle "config set version #{previous_minor}.dev"
      bundle "install"
      expect(out).not_to match(/restarting using that version/)

      bundle "-v"
      expect(out).to eq(Bundler::VERSION[0] == "2" ? "Bundler version #{Bundler::VERSION}" : Bundler::VERSION)
    end

    it "ignores malformed lockfile version" do
      lockfile_bundled_with("2.3.")

      bundle "install --verbose"
      expect(out).to include("Using bundler #{Bundler::VERSION}")
    end

    private

    def lockfile_bundled_with(version)
      lockfile <<~L
        GEM
          remote: https://gem.repo4/
          specs:
            myrack (1.0.0)

        PLATFORMS
          #{lockfile_platforms}

        DEPENDENCIES
          myrack

        BUNDLED WITH
           #{version}
      L
    end
  end
end
