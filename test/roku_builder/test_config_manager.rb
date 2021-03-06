# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

class ConfigManagerTest < Minitest::Test

  def test_config_manager_read_config
    logger = Logger.new("/dev/null")
    config_path = "config/file/path"
    io = Minitest::Mock.new
    io.expect(:read, good_config.to_json)
    config = nil
    File.stub(:open, io) do
      config = RokuBuilder::ConfigManager.get_config(config: config_path, logger: logger)
    end
    io.verify
    assert_equal :roku,  config[:devices][:default], :roku
    assert_equal :project1, config[:projects][:default], :project1
  end

  def test_config_manager_read_config_parent
    logger = Logger.new("/dev/null")
    config_path = "config/file/path"
    io = Minitest::Mock.new
    parent_config = good_config
    parent_config[:projects].delete(:project1)
    parent_config[:projects].delete(:project2)
    child_config = good_config
    child_config.delete(:devices)
    child_config.delete(:keys)
    child_config.delete(:input_mapping)
    child_config[:parent_config] = "config/file/path"
    io.expect(:read, child_config.to_json)
    io.expect(:read, parent_config.to_json)
    config = nil
    File.stub(:open, io) do
      config = RokuBuilder::ConfigManager.get_config(config: config_path, logger: logger)
    end
    io.verify
    assert_equal "user",  config[:devices][:roku][:user]
    assert_equal "<app name>", config[:projects][:project1][:app_name]
  end

  def test_config_manager_read_config_parent_too_deep
    logger = Logger.new("/dev/null")
    config_path = "config/file/path"
    io = Minitest::Mock.new
    parent_config = good_config
    parent_config[:parent_config] = "config/file/path"
    10.times {|_i| io.expect(:read, parent_config.to_json)}
    config = nil
    File.stub(:open, io) do
      config = RokuBuilder::ConfigManager.get_config(config: config_path, logger: logger)
    end
    io.verify
    assert_nil config
  end

  def test_config_manger_load_config
    logger = Logger.new("/dev/null")
    target_config = File.join(File.dirname(__FILE__), "test_files", "controller_test", "configure_test.json")
    File.delete(target_config) if File.exist?(target_config)

    code = nil
    config = nil
    configs = nil
    # Test Missing Config
    options = {validate: true, config: target_config}
    code = RokuBuilder::ConfigManager.load_config(options: options, logger: logger)
    assert_equal RokuBuilder::MISSING_CONFIG, code

    FileUtils.cp(File.join(File.dirname(target_config), "valid_config.json"), target_config)

    # Test Invalid config json
    options = {validate: true, config: target_config}
    RokuBuilder::ConfigManager.stub(:get_config, nil) do
      code = RokuBuilder::ConfigManager.load_config(options: options, logger: logger)
    end
    assert_equal RokuBuilder::INVALID_CONFIG, code
    assert_nil config
    assert_nil configs

    # Test Invalid config
    options = {validate: true, config: target_config}
    RokuBuilder::ConfigValidator.stub(:validate_config, [1]) do
      code, config, configs = RokuBuilder::ConfigManager.load_config(options: options, logger: logger)
    end
    assert_equal RokuBuilder::INVALID_CONFIG, code
    assert_nil config
    assert_nil configs

    # Test Unknown Device
    options = {validate: true, device: :bad, config: target_config}
    code, config, configs = RokuBuilder::ConfigManager.load_config(options: options, logger: logger)
    assert_equal RokuBuilder::UNKNOWN_DEVICE, code
    assert_nil config
    assert_nil configs

    # Test Depricated Config
    options = {validate: true, stage: 'production', config: target_config}
    RokuBuilder::ConfigValidator.stub(:validate_config, [-1]) do
      code, config, configs = RokuBuilder::ConfigManager.load_config(options: options, logger: logger)
    end
    assert_equal RokuBuilder::DEPRICATED_CONFIG, code
    assert_equal Hash, config.class
    assert_equal Hash, configs.class

    # Test valid Config
    options = {validate: true, stage: 'production', config: target_config}
    RokuBuilder::ConfigValidator.stub(:validate_config, [0]) do
      code, config, configs = RokuBuilder::ConfigManager.load_config(options: options, logger: logger)
    end
    assert_equal RokuBuilder::SUCCESS, code
    assert_equal Hash, config.class
    assert_equal Hash, configs.class

    # Test valid config in pwd
    options = {validate: true, stage: 'production', config: target_config}
    RokuBuilder::ConfigValidator.stub(:validate_config, [0]) do
      RokuBuilder::Controller.stub(:system, "/dev/null/test") do
        code, config, configs = RokuBuilder::ConfigManager.load_config(options: options, logger: logger)
      end
    end
    assert_equal RokuBuilder::SUCCESS, code
    assert_equal Hash, config.class
    assert_equal Hash, configs.class

    File.delete(target_config) if File.exist?(target_config)
  end

  def test_config_manager_read_invalid_config
    logger = Logger.new("/dev/null")
    config_path = "config/file/path"
    io = Minitest::Mock.new
    io.expect(:read, good_config.to_json+"}}}}}")
    config = nil
    File.stub(:open, io) do
      config = RokuBuilder::ConfigManager.get_config(config: config_path, logger: logger)
    end
    io.verify
    assert_nil config
  end

  def test_config_manager_edit_ip
    logger = Logger.new("/dev/null")
    config_path = "config/file/path"
    args = {
      config: config_path,
      options: {edit_params: "ip:192.168.0.200",
        device: :roku,
      },
      logger: logger
    }
    new_config = good_config
    new_config[:devices][:roku][:ip] = "192.168.0.200"

    io = Minitest::Mock.new
    io.expect(:read, good_config.to_json)
    io.expect(:write, nil, [JSON.pretty_generate(new_config)])
    io.expect(:close, nil)
    File.stub(:open, io) do
      RokuBuilder::ConfigManager.edit_config(**args)
    end
    io.verify
  end

  def test_config_manager_edit_user
    logger = Logger.new("/dev/null")
    config_path = "config/file/path"
    args = {
      config: config_path,
      options: {edit_params: "user:new_user"},
      logger: logger
    }
    new_config = good_config
    new_config[:devices][:roku][:user] = "new_user"

    io = Minitest::Mock.new
    io.expect(:read, good_config.to_json)
    io.expect(:write, nil, [JSON.pretty_generate(new_config)])
    io.expect(:close, nil)
    File.stub(:open, io) do
      RokuBuilder::ConfigManager.edit_config(**args)
    end
    io.verify
  end

  def test_config_manager_edit_password
    logger = Logger.new("/dev/null")
    config_path = "config/file/path"
    args = {
      config: config_path,
      options: {edit_params: "password:new_password"},
      logger: logger
    }
    new_config = good_config
    new_config[:devices][:roku][:password] = "new_password"

    io = Minitest::Mock.new
    io.expect(:read, good_config.to_json)
    io.expect(:write, nil, [JSON.pretty_generate(new_config)])
    io.expect(:close, nil)
    File.stub(:open, io) do
      RokuBuilder::ConfigManager.edit_config(**args)
    end
    io.verify
  end

  def test_config_manager_edit_app_name
    logger = Logger.new("/dev/null")
    config_path = "config/file/path"
    args = {
      config: config_path,
      options: {edit_params: "app_name:new name",
        project: :project1
      },
      logger: logger
    }
    new_config = good_config
    new_config[:projects][:project1][:app_name] = "new name"

    io = Minitest::Mock.new
    io.expect(:read, good_config.to_json)
    io.expect(:write, nil, [JSON.pretty_generate(new_config)])
    io.expect(:close, nil)
    File.stub(:open, io) do
      RokuBuilder::ConfigManager.edit_config(**args)
    end
    io.verify
  end

  def test_config_manager_edit_directory
    logger = Logger.new("/dev/null")
    config_path = "config/file/path"
    args = {
      config: config_path,
      options: {edit_params: "directory:new/directory/path",
        project: :project1
      },
      logger: logger
    }
    new_config = good_config
    new_config[:projects][:project1][:directory] = "new/directory/path"

    io = Minitest::Mock.new
    io.expect(:read, good_config.to_json)
    io.expect(:write, nil, [JSON.pretty_generate(new_config)])
    io.expect(:close, nil)
    File.stub(:open, io) do
      RokuBuilder::ConfigManager.edit_config(**args)
    end
    io.verify
  end

  def test_config_manager_edit_branch
    logger = Logger.new("/dev/null")
    config_path = "config/file/path"
    args = {
      config: config_path,
      options: {edit_params: "branch:new-branch",
        stage: :production
      },
      logger: logger
    }
    new_config = good_config
    new_config[:projects][:project1][:stages][:production][:branch] = "new-branch"

    io = Minitest::Mock.new
    io.expect(:read, good_config.to_json)
    io.expect(:write, nil, [JSON.pretty_generate(new_config)])
    io.expect(:close, nil)
    File.stub(:open, io) do
      RokuBuilder::ConfigManager.edit_config(**args)
    end
    io.verify
  end

  def test_config_manager_edit_default_stage
    logger = Logger.new("/dev/null")
    config_path = "config/file/path"
    args = {
      config: config_path,
      options: {edit_params: "branch:new-branch"},
      logger: logger
    }
    new_config = good_config
    new_config[:projects][:project1][:stages][:production][:branch] = "new-branch"

    io = Minitest::Mock.new
    io.expect(:read, good_config.to_json)
    io.expect(:write, nil, [JSON.pretty_generate(new_config)])
    io.expect(:close, nil)
    File.stub(:open, io) do
      RokuBuilder::ConfigManager.edit_config(**args)
    end
    io.verify
  end

  def test_config_manager_parent_config
    logger = Logger.new("/dev/null")
    target_config = File.join(File.dirname(__FILE__), "test_files", "controller_test", "configure_test.json")
    File.delete(target_config) if File.exist?(target_config)
    FileUtils.cp(File.join(File.dirname(target_config), "parent_config.json"), target_config)

    options = {validate: true, config: target_config, stage: :production}
    code, config, _configs = RokuBuilder::ConfigManager.load_config(options: options, logger: logger)
    assert_equal RokuBuilder::SUCCESS, code
    assert_equal "app2", config[:projects][:p2][:app_name]
    assert_equal "/dev/null", config[:projects][:p2][:directory]
    assert_equal 2, config[:projects][:p2][:files].count
    assert_equal 2, config[:projects][:p2][:folders].count
    File.delete(target_config) if File.exist?(target_config)
  end

  def test_config_manager_update_configs
    configs = {
      project_config: { app_name: "<app_name>" },
      package_config: {},
      stage: "<stage>",
      out: { file: nil, folder: "/tmp" }
    }
    options = {
      build_version: "<build_version>"
    }
    configs = RokuBuilder::ConfigManager.update_configs(configs: configs, options: options)
    assert_equal "<app_name> - <stage> - <build_version>", configs[:package_config][:app_name_version]
    assert_equal "<app_name>_<stage>_<build_version>", configs[:out][:file]
    assert_equal "/tmp/<app_name>_<stage>_<build_version>", configs[:package_config][:out_file]

    configs = {
      project_config: { app_name: "<app_name>" },
      package_config: {},
      stage: "<stage>",
      out: { file: "file.pkg", folder: "/home/user" }
    }
    options = {
      build_version: "<build_version>"
    }
    configs = RokuBuilder::ConfigManager.update_configs(configs: configs, options: options)
    assert_equal "<app_name> - <stage> - <build_version>", configs[:package_config][:app_name_version]
    assert_equal "file.pkg", configs[:out][:file]
    assert_equal "/home/user/file.pkg", configs[:package_config][:out_file]

    configs = {
      project_config: { app_name: "<app_name>" },
      build_config: {},
      stage: "<stage>",
      out: { file: nil, folder: "/tmp" }
    }
    options = {
      build_version: "<build_version>"
    }
    configs = RokuBuilder::ConfigManager.update_configs(configs: configs, options: options)
    assert_equal "<app_name>_<stage>_<build_version>", configs[:out][:file]
    assert_equal "/tmp/<app_name>_<stage>_<build_version>", configs[:build_config][:out_file]

    configs = {
      project_config: { app_name: "<app_name>" },
      inspect_config: {},
      package_config: {},
      stage: "<stage>",
      out: { file: nil, folder: "/tmp" }
    }
    options = {
      build_version: "<build_version>"
    }
    configs = RokuBuilder::ConfigManager.update_configs(configs: configs, options: options)
    assert_equal "<app_name>_<stage>_<build_version>", configs[:out][:file]
    assert_equal "/tmp/<app_name>_<stage>_<build_version>", configs[:package_config][:out_file]
    assert_equal "/tmp/<app_name>_<stage>_<build_version>", configs[:inspect_config][:pkg]
  end
end
