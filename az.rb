class AzPlayer
  attr_reader :nick, :joined
  attr_accessor :tries
  def initialize(nick)
    @nick = nick
    @joined = Time.now
    @tries = 0
  end

  def to_s
    @nick
  end

end

class AzDictionary
  attr_reader :size
  def initialize(path)
    @dictionary_array = IO.read(path).split
    @dictionary = Hash[ @dictionary_array.map { |element| [element, 1] } ]
    @size = @dictionary_array.size
  end

  def word_at(number)
    @dictionary_array[number]
  end

  def random_word
    word_number = rand(@size)
    word_at(word_number)
  end

  def is_a_valid_word?(word)
    @dictionary.fetch(word, 0) == 1
  end

  def first_word
    word_at(0)
  end

  def last_word
    word_at(@size - 1)
  end
end

class AzGame
  #class instance variables are specific to only that class



  def initialize(nick, interface = nil)
    @dictionary = AzDictionary.new('en_dict.txt')

    @interface = interface
    player = AzPlayer.new(nick)
    @started_by = AzPlayer.new(nick)
    @started_at = Time.now

    @number_of_words = @dictionary.size

    @players = [player]
    @total_guesses = 0

    setup
  end

  def setup
    choose_winning_word
    set_lower_bound(@dictionary.first_word)
    set_upper_bound(@dictionary.last_word)
    say @winning_word
    @interface.notify 'AZ started! New range: ' + range_to_s
  end

  def choose_winning_word
    @winning_word = @dictionary.random_word
  end

  def range_to_s
    @lower_bound.to_s + ' - ' + @upper_bound.to_s
  end


  def set_lower_bound(word)
    @lower_bound = word
  end

  def set_upper_bound(word)
    @upper_bound = word
  end

  def is_within_bounds(word)
    @dictionary.is_a_valid_word?(word) and word > @lower_bound and word < @upper_bound
  end

  def attempt(word, nick)
    if is_within_bounds(word)
      player = find_player(nick)
      player.tries += 1
      @total_guesses += 1

      if word < @winning_word
        @lower_bound = word
        say(range_to_s)
      elsif word > @winning_word
        @upper_bound = word
        say(range_to_s)
      else
        win(player)
      end

    end
  end

  def win(player)
    say("Hurray! #{player.to_s} has won after #{player.tries} tries and #{@total_guesses} total tries")
  end

  def add_player(nick)
    player = AzPlayer.new(nick)
    @players << player
    return player
  end

  def find_player(nick)
    player = @players.find { |player| player.nick == nick }
    player ||= add_player(nick)
    return player
  end

  def say(text)
    @interface.notify(text)
  end


end

class AzInterface
  @@game = nil

  def self.notify(msg)
    puts msg
  end

  def self.try(msg, nick)
    @@game.attempt(msg, nick)
  end

  def self.game_state
    if @@game.nil?
      return 0
    end
    return 1
  end

  def self.start(nick)
    if self.game_state == 0
      @@game = AzGame.new(nick, self)
    else
      self.notify('Game has already been started. ' + @@game.range.to_s)
    end
  end
end

nick = 'kx'
AzInterface.start(nick)
while true
  AzInterface.try(gets.strip, nick)
end
