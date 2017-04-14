# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Navigation methods
  class Navigator < Util

    # Setup navigation commands
    def init(mappings: nil)
      @commands = {
        home: "Home",             rew: "Rev",                 ff: "Fwd",
        play: "Play",             select: "Select",           left: "Left",
        right: "Right",           down: "Down",               up: "Up",
        back: "Back",             replay: "InstantReplay",    info: "Info",
        backspace: "Backspace",   search: "Search",           enter: "Enter",
        volumedown: "VolumeDown", volumeup: "VolumeUp",       mute: "VolumeMute",
        channelup: "ChannelUp",   channeldown: "ChannelDown", tuner: "InputTuner",
        hdmi1: "InputHDMI1",      hdmi2: "InputHDMI2",        hdmi3: "InputHDMI3",
        hdmi4: "InputHDMI4",      avi: "InputAVI"
      }
      @screens = {
        platform: [:home, :home, :home, :home, :home, :ff, :play, :rew, :play, :ff],
        secret: [:home, :home, :home, :home, :home, :ff, :ff, :ff, :rew, :rew],
        secret2: [:home, :home, :home, :home, :home, :up, :right, :down, :left, :up],
        channels: [:home, :home, :home, :up, :up, :left, :right, :left, :right, :left],
        developer: [:home, :home, :home, :up, :up, :right, :left, :right, :left, :right],
        wifi: [:home, :home, :home, :home, :home, :up, :down, :up, :down, :up],
        antenna: [:home, :home, :home, :home, :home, :ff, :down, :rew, :down, :ff],
        bitrate: [:home, :home, :home, :home, :home, :rew, :rew, :rew, :ff, :ff],
        network: [:home, :home, :home, :home, :home, :right, :left, :right, :left, :right],
        reboot: [:home, :home, :home, :home, :home, :up, :rew, :rew, :ff, :ff]
      }
      @runable = [
        :secret, :channels
      ]
      mappings_init(mappings: mappings)
    end

    # Init Mappings
    def mappings_init(mappings: nil)
      @mappings = {
        "\e[1~": [ "home", "Home" ],
        "<": [ "rew", "<" ],
        ">": [ "ff", ">" ],
        "=": [ "play", "=" ],
        "\r": [ "select", "Enter" ],
        "\e[D": [ "left", "Left Arrow" ],
        "\e[C": [ "right", "Right Arrow" ],
        "\e[B": [ "down", "Down Arrow" ],
        "\e[A": [ "up", "Up Arrow" ],
        "\t": [ "back", "Tab" ],
        #"": [ "replay", "" ],
        "*": [ "info", "*" ],
        "\u007f": [ "backspace", "Backspace" ],
        "?": [ "search", "?" ],
        "\e\r": [ "enter", "Alt + Enter" ],
        "\e[5~": [ "volumeup", "Page Up" ],
        "\e[6~": [ "volumedown", "Page Down" ],
        "\e[4~": [ "mute", "End" ],
        #"": [ "channeldown", "" ],
        #"": [ "channelup", "" ],
        #"": [ "tuner", "" ],
        #"": [ "hdmi1", "" ],
        #"": [ "hdmi2", "" ],
        #"": [ "hdmi3", "" ],
        #"": [ "hdmi4", "" ],
        #"": [ "avi", "" ]
      }
      @mappings.merge!(mappings) if mappings
    end

    # Send a navigation command to the roku device
    # @param command [Symbol] The smbol of the command to send
    # @return [Boolean] Success
    def nav(commands:)
      commands.each do |command|
        if @commands.has_key?(command)
          conn = multipart_connection(port: 80)

          path = "/keypress/#{@commands[command]}"
          @logger.debug("Send Command: "+path)
          response = conn.post path
          return false unless response.success?
        else
          return false
        end
      end
      return true
    end

    # Type text on the roku device
    # @param text [String] The text to type on the device
    # @return [Boolean] Success
    def type(text:)
      conn = multipart_connection(port: 80)
      text.split(//).each do |c|
        path = "/keypress/LIT_#{CGI::escape(c)}"
        @logger.debug("Send Letter: "+path)
        response = conn.post path
        return false unless response.success?
      end
      return true
    end

    def interactive
      running = true
      @logger.info("Key Mappings:")
      @mappings.each_value {|key|
        @logger.info("#{key[1]} -> #{@commands[key[0].to_sym]}")
      }
      @logger.info("Control-C -> Exit")
      while running
        char = read_char
        @logger.debug("Char: #{char.inspect}")
        if char == "\u0003"
          running = false
        else
          Thread.new(char) {|character|
            if @mappings[character.to_sym] != nil
              nav(commands:[@mappings[character.to_sym][0].to_sym])
            elsif character.inspect.force_encoding("UTF-8").ascii_only?
              type(text: character)
            end
          }
        end
      end
    end

    # Show the commands for one of the roku secret screens
    # @param type [Symbol] The type of screen to show
    # @return [Boolean] Screen found
    def screen(type:)
      if @screens.has_key?(type)
        if @runable.include?(type)
          nav(commands: @screens[type])
        else
          @logger.unknown("Cannot run command automatically")
        end
        display, count, string = [], [], ""
        @screens[type].each do |command|
          if display.count > 0 and  display[-1] == command
            count[-1] = count[-1] + 1
          else
            display.push(command)
            count.push(1)
          end
        end
        display.each_index do |i|
          if count[i] > 1
            string = string + @commands[display[i]]+" x "+count[i].to_s+", "
          else
            string = string + @commands[display[i]]+", "
          end
        end
        if @runable.include?(type)
          @logger.info(string.strip)
        else
          @logger.unknown(string.strip)
        end
      else
        return false
      end
      true
    end

    # Show avaiable roku secret screens
    def screens
      @screens.keys.each {|screen| @logger.unknown(screen)}
    end

    def read_char
      STDIN.echo = false
      STDIN.raw!


      input = STDIN.getc.chr
      if input == "\e" then
        input << STDIN.read_nonblock(3) rescue nil
        input << STDIN.read_nonblock(2) rescue nil
      end
      input
    ensure
      STDIN.echo = true
      STDIN.cooked!
    end
  end
end
