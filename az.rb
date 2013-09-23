require 'sequel'

$db = Sequel.connect('jdbc:sqlite:az.db')

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

  include Math

  def initialize(nick, interface = nil, db = nil)
    @@db = db unless db.nil?

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
    @won = false
    choose_winning_word
    set_lower_bound(@dictionary.first_word)
    set_upper_bound(@dictionary.last_word)

    save_game_to_db

    #debug
    say @winning_word

    @interface.notify 'AZ started! New range: ' + range_to_s
  end

  def save_game_to_db
    @id = (@@db[:az_game].max(:id).to_i+1) unless @@db.nil?
    @@db[:az_game].insert(:id => @id, :started_at => @started_at, :started_by => @started_by.to_s,
                        :winning_word => @winning_word, :channel => 'N/A')
  end

  def finalize_game_in_db
    @@db[:az_game].where(:id => @id).update(:finished_at => @finished_at, :finished_by => @finished_by.to_s, :points => @points, :won => @won)
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


  def save_attempt_to_db(word, nick)
    @@db[:az_guess].insert(:nick => nick, :guess => word, :time => Time.now, :game => @id) unless @@db.nil?
  end


  def attempt(word, nick)
    if is_within_bounds(word)
      player = find_player(nick)

      player.tries += 1
      @total_guesses += 1

      save_attempt_to_db(word, nick)


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


  def prepare_end(player)
    @finished_at = Time.now
    @finished_by = player.to_s
  end


  def win(player)
    prepare_end(player)
    @points = score
    @won = true
    say("Hurray! #{player.to_s} has won for #{@points} points after #{player.tries} tries and #{@total_guesses} total tries")
    finalize_game_in_db
  end


  def cancel(player)
    prepare_end(player)
    say "Game canceled by #{player.to_s} after #{@total_guesses} total tries."
    finalize_game_in_db
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
    @interface.notify(text) unless @interface.nil?
  end


  def score
    n = @total_guesses
    p = @players.length
    t = (100*exp(-(n-1)**2/50**2)).ceil + p
    return t
  end

end

class AzInterface
  @@game = nil
  @@db = $db


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
      @@game = AzGame.new(nick, self, @@db)
    else
      self.notify('Game has already been started. ' + @@game.range.to_s)
    end
  end


  def cancel(nick)
    player = find_player(nick)
    @@game.cancel(player)
  end
end

nick = 'kx'
AzInterface.start(nick)
while true
  AzInterface.try(gets.strip, nick)
end
