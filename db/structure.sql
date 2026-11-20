SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: reject_session_frame_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_session_frame_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'session frames are append-only';
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: auth_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_identities (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    issuer character varying NOT NULL,
    subject character varying NOT NULL,
    evidence_reference character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    revoked_at timestamp(6) without time zone
);


--
-- Name: auth_identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.auth_identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: auth_identities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.auth_identities_id_seq OWNED BY public.auth_identities.id;


--
-- Name: auth_identity_decisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_identity_decisions (
    id bigint NOT NULL,
    auth_identity_id bigint NOT NULL,
    action character varying NOT NULL,
    evidence_reference character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: auth_identity_decisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.auth_identity_decisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: auth_identity_decisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.auth_identity_decisions_id_seq OWNED BY public.auth_identity_decisions.id;


--
-- Name: auth_logins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_logins (
    id bigint NOT NULL,
    auth_identity_id bigint NOT NULL,
    assurance character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: auth_logins_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.auth_logins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: auth_logins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.auth_logins_id_seq OWNED BY public.auth_logins.id;


--
-- Name: badges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.badges (
    id bigint NOT NULL,
    color character varying,
    created_at timestamp(6) without time zone NOT NULL,
    display_int boolean DEFAULT false,
    game_id bigint,
    hideable boolean DEFAULT true,
    icon_class character varying,
    name character varying,
    sort_order integer,
    symbol character varying,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: badges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.badges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: badges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.badges_id_seq OWNED BY public.badges.id;


--
-- Name: cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cards (
    id bigint NOT NULL,
    color character varying,
    created_at timestamp(6) without time zone NOT NULL,
    game_id integer,
    icon_class character varying,
    key character varying,
    name character varying,
    name_sort integer,
    updated_at timestamp(6) without time zone NOT NULL,
    value character varying,
    value_sort integer
);


--
-- Name: cards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cards_id_seq OWNED BY public.cards.id;


--
-- Name: dummy_accesses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dummy_accesses (
    id bigint NOT NULL,
    player_id bigint NOT NULL,
    credential_digest character varying,
    browser_digest character varying,
    expires_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: dummy_accesses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dummy_accesses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dummy_accesses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dummy_accesses_id_seq OWNED BY public.dummy_accesses.id;


--
-- Name: game_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.game_sessions (
    id bigint NOT NULL,
    completed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    current_player_id integer,
    game_id integer,
    special_game_phase character varying,
    special_game_phase_timer integer DEFAULT 0,
    started_at timestamp(6) without time zone,
    state character varying,
    uid character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    experimental boolean DEFAULT false NOT NULL,
    experiment_owner_id bigint,
    parent_session_id bigint,
    fork_frame_id bigint,
    branch_rules_version integer,
    CONSTRAINT game_sessions_complete_branch_lineage CHECK ((((parent_session_id IS NULL) AND (fork_frame_id IS NULL) AND (branch_rules_version IS NULL)) OR (experimental AND (parent_session_id IS NOT NULL) AND (parent_session_id <> id) AND (fork_frame_id IS NOT NULL) AND (branch_rules_version IS NOT NULL) AND (branch_rules_version > 0)))),
    CONSTRAINT game_sessions_experiment_owner CHECK ((experimental = (experiment_owner_id IS NOT NULL)))
);


--
-- Name: game_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.game_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: game_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.game_sessions_id_seq OWNED BY public.game_sessions.id;


--
-- Name: games; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.games (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    key character varying,
    max_players integer,
    min_players integer,
    name character varying,
    slug character varying,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: games_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.games_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: games_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.games_id_seq OWNED BY public.games.id;


--
-- Name: players; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.players (
    id bigint NOT NULL,
    action_phase character varying,
    action_phase_revert character varying,
    created_at timestamp(6) without time zone NOT NULL,
    game_id integer,
    game_session_id integer,
    moderator boolean DEFAULT false,
    next_player_id integer,
    removed_at timestamp(6) without time zone,
    role_id integer,
    score integer,
    turn_order integer,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id integer,
    winner boolean DEFAULT false,
    table_captain boolean DEFAULT false NOT NULL
);


--
-- Name: players_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.players_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: players_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.players_id_seq OWNED BY public.players.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id bigint NOT NULL,
    color character varying,
    created_at timestamp(6) without time zone NOT NULL,
    game_id bigint,
    icon_class character varying,
    name character varying,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: session_cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.session_cards (
    id bigint NOT NULL,
    card_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    dealt_at timestamp(6) without time zone,
    discarded_at timestamp(6) without time zone,
    game_session_id integer,
    played_at timestamp(6) without time zone,
    player_id integer,
    session_deck_id integer,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: session_cards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.session_cards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: session_cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.session_cards_id_seq OWNED BY public.session_cards.id;


--
-- Name: session_decks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.session_decks (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    game_session_id integer,
    key character varying,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: session_decks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.session_decks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: session_decks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.session_decks_id_seq OWNED BY public.session_decks.id;


--
-- Name: session_frames; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.session_frames (
    id bigint NOT NULL,
    acting_player_id integer,
    action character varying,
    affected_player_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    game_session_id integer,
    previous_frame_id integer,
    result character varying,
    state character varying,
    subject_id integer,
    subject_type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    value integer,
    sequence bigint,
    format_version integer,
    kind character varying,
    game_key character varying,
    payload jsonb,
    occurred_at timestamp(6) without time zone,
    context_frame_id bigint,
    corrects_frame_id bigint,
    actor_kind character varying
);


--
-- Name: session_frames_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.session_frames_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: session_frames_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.session_frames_id_seq OWNED BY public.session_frames.id;


--
-- Name: user_badges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_badges (
    id bigint NOT NULL,
    active boolean DEFAULT true,
    as_of_session_id bigint,
    badge_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint,
    value numeric
);


--
-- Name: user_badges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_badges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_badges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_badges_id_seq OWNED BY public.user_badges.id;


--
-- Name: user_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_configs (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    show_all_badges boolean DEFAULT true,
    show_badge_values boolean DEFAULT true,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint
);


--
-- Name: user_configs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_configs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_configs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_configs_id_seq OWNED BY public.user_configs.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    name character varying,
    remember_created_at timestamp(6) without time zone,
    reset_password_sent_at timestamp(6) without time zone,
    reset_password_token character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    username character varying DEFAULT ''::character varying NOT NULL,
    dummy boolean DEFAULT false NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: auth_identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_identities ALTER COLUMN id SET DEFAULT nextval('public.auth_identities_id_seq'::regclass);


--
-- Name: auth_identity_decisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_identity_decisions ALTER COLUMN id SET DEFAULT nextval('public.auth_identity_decisions_id_seq'::regclass);


--
-- Name: auth_logins id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_logins ALTER COLUMN id SET DEFAULT nextval('public.auth_logins_id_seq'::regclass);


--
-- Name: badges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badges ALTER COLUMN id SET DEFAULT nextval('public.badges_id_seq'::regclass);


--
-- Name: cards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards ALTER COLUMN id SET DEFAULT nextval('public.cards_id_seq'::regclass);


--
-- Name: dummy_accesses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dummy_accesses ALTER COLUMN id SET DEFAULT nextval('public.dummy_accesses_id_seq'::regclass);


--
-- Name: game_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.game_sessions ALTER COLUMN id SET DEFAULT nextval('public.game_sessions_id_seq'::regclass);


--
-- Name: games id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.games ALTER COLUMN id SET DEFAULT nextval('public.games_id_seq'::regclass);


--
-- Name: players id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.players ALTER COLUMN id SET DEFAULT nextval('public.players_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: session_cards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_cards ALTER COLUMN id SET DEFAULT nextval('public.session_cards_id_seq'::regclass);


--
-- Name: session_decks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_decks ALTER COLUMN id SET DEFAULT nextval('public.session_decks_id_seq'::regclass);


--
-- Name: session_frames id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_frames ALTER COLUMN id SET DEFAULT nextval('public.session_frames_id_seq'::regclass);


--
-- Name: user_badges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_badges ALTER COLUMN id SET DEFAULT nextval('public.user_badges_id_seq'::regclass);


--
-- Name: user_configs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_configs ALTER COLUMN id SET DEFAULT nextval('public.user_configs_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: auth_identities auth_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_identities
    ADD CONSTRAINT auth_identities_pkey PRIMARY KEY (id);


--
-- Name: auth_identity_decisions auth_identity_decisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_identity_decisions
    ADD CONSTRAINT auth_identity_decisions_pkey PRIMARY KEY (id);


--
-- Name: auth_logins auth_logins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_logins
    ADD CONSTRAINT auth_logins_pkey PRIMARY KEY (id);


--
-- Name: badges badges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badges
    ADD CONSTRAINT badges_pkey PRIMARY KEY (id);


--
-- Name: cards cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_pkey PRIMARY KEY (id);


--
-- Name: dummy_accesses dummy_accesses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dummy_accesses
    ADD CONSTRAINT dummy_accesses_pkey PRIMARY KEY (id);


--
-- Name: game_sessions game_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.game_sessions
    ADD CONSTRAINT game_sessions_pkey PRIMARY KEY (id);


--
-- Name: games games_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.games
    ADD CONSTRAINT games_pkey PRIMARY KEY (id);


--
-- Name: players players_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.players
    ADD CONSTRAINT players_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: session_cards session_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_cards
    ADD CONSTRAINT session_cards_pkey PRIMARY KEY (id);


--
-- Name: session_decks session_decks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_decks
    ADD CONSTRAINT session_decks_pkey PRIMARY KEY (id);


--
-- Name: session_frames session_frames_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_frames
    ADD CONSTRAINT session_frames_pkey PRIMARY KEY (id);


--
-- Name: user_badges user_badges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_badges
    ADD CONSTRAINT user_badges_pkey PRIMARY KEY (id);


--
-- Name: user_configs user_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_configs
    ADD CONSTRAINT user_configs_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_auth_identities_on_issuer_and_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_auth_identities_on_issuer_and_subject ON public.auth_identities USING btree (issuer, subject);


--
-- Name: index_auth_identities_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_auth_identities_on_user_id ON public.auth_identities USING btree (user_id);


--
-- Name: index_auth_identity_decisions_on_auth_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_auth_identity_decisions_on_auth_identity_id ON public.auth_identity_decisions USING btree (auth_identity_id);


--
-- Name: index_auth_logins_on_auth_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_auth_logins_on_auth_identity_id ON public.auth_logins USING btree (auth_identity_id);


--
-- Name: index_badges_on_game_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_badges_on_game_id ON public.badges USING btree (game_id);


--
-- Name: index_cards_on_game_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cards_on_game_id ON public.cards USING btree (game_id);


--
-- Name: index_dummy_accesses_on_credential_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_dummy_accesses_on_credential_digest ON public.dummy_accesses USING btree (credential_digest);


--
-- Name: index_dummy_accesses_on_player_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_dummy_accesses_on_player_id ON public.dummy_accesses USING btree (player_id);


--
-- Name: index_game_sessions_on_current_player_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_game_sessions_on_current_player_id ON public.game_sessions USING btree (current_player_id);


--
-- Name: index_game_sessions_on_experiment_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_game_sessions_on_experiment_owner_id ON public.game_sessions USING btree (experiment_owner_id);


--
-- Name: index_game_sessions_on_fork_frame_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_game_sessions_on_fork_frame_id ON public.game_sessions USING btree (fork_frame_id);


--
-- Name: index_game_sessions_on_game_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_game_sessions_on_game_id ON public.game_sessions USING btree (game_id);


--
-- Name: index_game_sessions_on_parent_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_game_sessions_on_parent_session_id ON public.game_sessions USING btree (parent_session_id);


--
-- Name: index_game_sessions_on_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_game_sessions_on_uid ON public.game_sessions USING btree (uid);


--
-- Name: index_games_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_games_on_key ON public.games USING btree (key);


--
-- Name: index_games_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_games_on_slug ON public.games USING btree (slug);


--
-- Name: index_players_on_game_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_players_on_game_id ON public.players USING btree (game_id);


--
-- Name: index_players_on_game_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_players_on_game_session_id ON public.players USING btree (game_session_id);


--
-- Name: index_players_on_game_session_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_players_on_game_session_id_and_user_id ON public.players USING btree (game_session_id, user_id);


--
-- Name: index_players_on_next_player_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_players_on_next_player_id ON public.players USING btree (next_player_id);


--
-- Name: index_players_on_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_players_on_role_id ON public.players USING btree (role_id);


--
-- Name: index_players_on_session_captain; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_players_on_session_captain ON public.players USING btree (game_session_id) WHERE table_captain;


--
-- Name: index_players_on_turn_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_players_on_turn_order ON public.players USING btree (turn_order);


--
-- Name: index_players_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_players_on_user_id ON public.players USING btree (user_id);


--
-- Name: index_roles_on_game_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_roles_on_game_id ON public.roles USING btree (game_id);


--
-- Name: index_session_cards_on_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_cards_on_card_id ON public.session_cards USING btree (card_id);


--
-- Name: index_session_cards_on_game_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_cards_on_game_session_id ON public.session_cards USING btree (game_session_id);


--
-- Name: index_session_cards_on_game_session_id_and_session_deck_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_cards_on_game_session_id_and_session_deck_id ON public.session_cards USING btree (game_session_id, session_deck_id);


--
-- Name: index_session_cards_on_player_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_cards_on_player_id ON public.session_cards USING btree (player_id);


--
-- Name: index_session_cards_on_player_id_and_game_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_cards_on_player_id_and_game_session_id ON public.session_cards USING btree (player_id, game_session_id);


--
-- Name: index_session_cards_on_player_id_and_session_deck_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_cards_on_player_id_and_session_deck_id ON public.session_cards USING btree (player_id, session_deck_id);


--
-- Name: index_session_cards_on_session_deck_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_cards_on_session_deck_id ON public.session_cards USING btree (session_deck_id);


--
-- Name: index_session_decks_on_game_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_decks_on_game_session_id ON public.session_decks USING btree (game_session_id);


--
-- Name: index_session_decks_on_game_session_id_and_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_session_decks_on_game_session_id_and_key ON public.session_decks USING btree (game_session_id, key);


--
-- Name: index_session_frames_on_acting_player_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_frames_on_acting_player_id ON public.session_frames USING btree (acting_player_id);


--
-- Name: index_session_frames_on_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_frames_on_action ON public.session_frames USING btree (action);


--
-- Name: index_session_frames_on_affected_player_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_frames_on_affected_player_id ON public.session_frames USING btree (affected_player_id);


--
-- Name: index_session_frames_on_corrects_frame_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_session_frames_on_corrects_frame_id ON public.session_frames USING btree (corrects_frame_id);


--
-- Name: index_session_frames_on_game_key_and_kind_and_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_frames_on_game_key_and_kind_and_action ON public.session_frames USING btree (game_key, kind, action);


--
-- Name: index_session_frames_on_game_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_frames_on_game_session_id ON public.session_frames USING btree (game_session_id);


--
-- Name: index_session_frames_on_game_session_id_and_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_frames_on_game_session_id_and_action ON public.session_frames USING btree (game_session_id, action);


--
-- Name: index_session_frames_on_game_session_id_and_sequence; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_session_frames_on_game_session_id_and_sequence ON public.session_frames USING btree (game_session_id, sequence);


--
-- Name: index_session_frames_on_previous_frame_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_frames_on_previous_frame_id ON public.session_frames USING btree (previous_frame_id);


--
-- Name: index_session_frames_on_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_frames_on_state ON public.session_frames USING btree (state);


--
-- Name: index_session_frames_on_subject_id_and_subject_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_frames_on_subject_id_and_subject_type ON public.session_frames USING btree (subject_id, subject_type);


--
-- Name: index_user_badges_on_as_of_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_badges_on_as_of_session_id ON public.user_badges USING btree (as_of_session_id);


--
-- Name: index_user_badges_on_badge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_badges_on_badge_id ON public.user_badges USING btree (badge_id);


--
-- Name: index_user_badges_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_badges_on_user_id ON public.user_badges USING btree (user_id);


--
-- Name: index_user_configs_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_configs_on_user_id ON public.user_configs USING btree (user_id);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_users_on_username; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_username ON public.users USING btree (username);


--
-- Name: session_frames immutable_session_frames; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER immutable_session_frames BEFORE DELETE OR UPDATE ON public.session_frames FOR EACH ROW EXECUTE FUNCTION public.reject_session_frame_change();


--
-- Name: game_sessions fk_rails_13247b6d37; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.game_sessions
    ADD CONSTRAINT fk_rails_13247b6d37 FOREIGN KEY (experiment_owner_id) REFERENCES public.users(id);


--
-- Name: auth_identity_decisions fk_rails_1c69998cb0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_identity_decisions
    ADD CONSTRAINT fk_rails_1c69998cb0 FOREIGN KEY (auth_identity_id) REFERENCES public.auth_identities(id);


--
-- Name: game_sessions fk_rails_1f938de3bb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.game_sessions
    ADD CONSTRAINT fk_rails_1f938de3bb FOREIGN KEY (fork_frame_id) REFERENCES public.session_frames(id);


--
-- Name: dummy_accesses fk_rails_3f5b8a6547; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dummy_accesses
    ADD CONSTRAINT fk_rails_3f5b8a6547 FOREIGN KEY (player_id) REFERENCES public.players(id);


--
-- Name: auth_logins fk_rails_5d881b1336; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_logins
    ADD CONSTRAINT fk_rails_5d881b1336 FOREIGN KEY (auth_identity_id) REFERENCES public.auth_identities(id) ON DELETE CASCADE;


--
-- Name: game_sessions fk_rails_cd41ca6570; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.game_sessions
    ADD CONSTRAINT fk_rails_cd41ca6570 FOREIGN KEY (parent_session_id) REFERENCES public.game_sessions(id);


--
-- Name: auth_identities fk_rails_fe3bac40a1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_identities
    ADD CONSTRAINT fk_rails_fe3bac40a1 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261120000001'),
('20261119000003'),
('20261119000002'),
('20261119000001'),
('20260312000000'),
('20260311205209'),
('20260311205208'),
('20260309171831');
