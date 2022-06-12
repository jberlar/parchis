# An instance of this class keeps the game updated.
class GameStateUpdater

  UPDATE_INTERVAL = 2.75 # seconds

  # @param match_id [String]
  # @param player_id [Integer]
  # @param board [Board]
  # @param dice [Dice]
  # @param players [Array<Player>]
  # Constructor.
  def initialize(match_id:, player_id:, board:, dice:, players:)
    @events_processed = {}
    @match_id = match_id
    @last_update = Time.now
    @board = board
    @dice = dice
    @players = players
  end

  # @param event_id [Integer]
  # @param event [String, nil] event in the coded form, i.e.: "rA3t"
  def event_processed(event_id:, event: nil)
    @events_processed[event_id] = (event || true)
  end

  def leave_game
    HTTPClient.post_match_quit(match_id: @match_id, player_id: @player_id)
  end

  # @return [Boolean] false if couldn't update, true otherwise.
  # Called 60 times per second.
  def update
    if((Time.now - @last_update) > UPDATE_INTERVAL)
      @last_update = Time.now
      # retrieve last game events
      if(last_events = HTTPClient.get_game_last_events(match_id: @match_id))
        last_events.each do |event|
          # each event looks like {'ev' => 'dr4', 'id' => 51}
          if(!@event_processed.has_key?(event['id']))
            # process this event now
            code = event['ev'] #: String
            case code[0..1]
              when 'dr'
                # dice roll event
                @rolling_dice_sfx.play()
                roll_value = code[-1].to_i
                @dice.force_last_roll(value: roll_value)
                @board.dice_rolled(result: roll_value)
              when 'tm'
                # token moved event
                player = nil
                @players.each do |_player|
                  next if !_player
                  if(_player.color.to_s.[](1) == code[2])
                    player = _player
                    break
                  end
                end
                @board.perform_move(token_label: code[3], cells_to_move: code[4].to_i, player: player)
              when 'pq'
                # player quitted event
                @board.player_quitted(code[-1].to_i)
            end
            # register that this event was processed
            event_processed(event_id: event['id'], event: code)
          end
        end
      else
        false
      end
    end
  rescue => e
    warn("Error: #{e.class}.")
    warn("Message: #{e.message}.")
    false
  end
end
