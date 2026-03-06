# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_03_22_201950) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "badges", force: :cascade do |t|
    t.string "name"
    t.string "icon_class"
    t.string "color"
    t.bigint "game_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "symbol"
    t.boolean "display_int", default: false
    t.integer "sort_order"
    t.boolean "hideable", default: true
    t.index ["game_id"], name: "index_badges_on_game_id"
  end

  create_table "cards", force: :cascade do |t|
    t.integer "game_id"
    t.string "name"
    t.string "value"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "color"
    t.string "icon_class"
    t.integer "name_sort"
    t.integer "value_sort"
    t.string "key"
    t.index ["game_id"], name: "index_cards_on_game_id"
  end

  create_table "game_sessions", force: :cascade do |t|
    t.integer "game_id"
    t.string "uid"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.string "state"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "current_player_id"
    t.string "special_game_phase"
    t.integer "special_game_phase_timer", default: 0
    t.index ["current_player_id"], name: "index_game_sessions_on_current_player_id"
    t.index ["game_id"], name: "index_game_sessions_on_game_id"
    t.index ["uid"], name: "index_game_sessions_on_uid", unique: true
  end

  create_table "games", force: :cascade do |t|
    t.string "name"
    t.string "key"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "min_players"
    t.integer "max_players"
    t.index ["key"], name: "index_games_on_key", unique: true
  end

  create_table "players", force: :cascade do |t|
    t.integer "user_id"
    t.integer "game_session_id"
    t.boolean "moderator", default: false
    t.integer "score"
    t.integer "turn_order"
    t.integer "next_player_id"
    t.boolean "winner", default: false
    t.integer "role_id"
    t.string "action_phase"
    t.string "action_phase_revert"
    t.integer "game_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["game_id"], name: "index_players_on_game_id"
    t.index ["game_session_id", "user_id"], name: "index_players_on_game_session_id_and_user_id", unique: true
    t.index ["game_session_id"], name: "index_players_on_game_session_id"
    t.index ["next_player_id"], name: "index_players_on_next_player_id"
    t.index ["role_id"], name: "index_players_on_role_id"
    t.index ["turn_order"], name: "index_players_on_turn_order"
    t.index ["user_id"], name: "index_players_on_user_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name"
    t.bigint "game_id"
    t.string "icon_class"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "color"
    t.index ["game_id"], name: "index_roles_on_game_id"
  end

  create_table "session_cards", force: :cascade do |t|
    t.integer "session_deck_id"
    t.integer "card_id"
    t.integer "player_id"
    t.datetime "played_at"
    t.datetime "discarded_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.datetime "dealt_at"
    t.integer "game_session_id"
    t.index ["card_id"], name: "index_session_cards_on_card_id"
    t.index ["game_session_id", "session_deck_id"], name: "index_session_cards_on_game_session_id_and_session_deck_id"
    t.index ["game_session_id"], name: "index_session_cards_on_game_session_id"
    t.index ["player_id", "game_session_id"], name: "index_session_cards_on_player_id_and_game_session_id"
    t.index ["player_id", "session_deck_id"], name: "index_session_cards_on_player_id_and_session_deck_id"
    t.index ["player_id"], name: "index_session_cards_on_player_id"
    t.index ["session_deck_id"], name: "index_session_cards_on_session_deck_id"
  end

  create_table "session_decks", force: :cascade do |t|
    t.integer "game_session_id"
    t.string "key"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["game_session_id", "key"], name: "index_session_decks_on_game_session_id_and_key", unique: true
    t.index ["game_session_id"], name: "index_session_decks_on_game_session_id"
  end

  create_table "session_frames", force: :cascade do |t|
    t.integer "game_session_id"
    t.string "action"
    t.integer "acting_player_id"
    t.integer "affected_player_id"
    t.integer "value"
    t.string "result"
    t.integer "subject_id"
    t.string "subject_type"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "previous_frame_id"
    t.string "state"
    t.index ["acting_player_id"], name: "index_session_frames_on_acting_player_id"
    t.index ["action"], name: "index_session_frames_on_action"
    t.index ["affected_player_id"], name: "index_session_frames_on_affected_player_id"
    t.index ["game_session_id", "action"], name: "index_session_frames_on_game_session_id_and_action"
    t.index ["game_session_id"], name: "index_session_frames_on_game_session_id"
    t.index ["previous_frame_id"], name: "index_session_frames_on_previous_frame_id"
    t.index ["state"], name: "index_session_frames_on_state"
    t.index ["subject_id", "subject_type"], name: "index_session_frames_on_subject_id_and_subject_type"
  end

  create_table "user_badges", force: :cascade do |t|
    t.decimal "value"
    t.bigint "as_of_session_id"
    t.bigint "badge_id"
    t.bigint "user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "active", default: true
    t.index ["as_of_session_id"], name: "index_user_badges_on_as_of_session_id"
    t.index ["badge_id"], name: "index_user_badges_on_badge_id"
    t.index ["user_id"], name: "index_user_badges_on_user_id"
  end

  create_table "user_configs", force: :cascade do |t|
    t.boolean "show_badge_values", default: true
    t.boolean "show_all_badges", default: true
    t.bigint "user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_user_configs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "username", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "name"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

end
