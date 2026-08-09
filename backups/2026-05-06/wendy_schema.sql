--
-- PostgreSQL database dump
--

\restrict 9jCoD4KF2K5MTwUnJPAIKyQ2l37yf3v0xjBX3QbUDwdzZAFh3ytRBHgcF3PcQLx

-- Dumped from database version 14.5 (Debian 14.5-2.pgdg110+2)
-- Dumped by pg_dump version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)

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
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: app_config; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.app_config (
    key character varying(50) NOT NULL,
    value text NOT NULL,
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.app_config OWNER TO postgres;

--
-- Name: auth_sessions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.auth_sessions (
    id integer NOT NULL,
    token_hash character varying(128) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    revoked boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.auth_sessions OWNER TO postgres;

--
-- Name: auth_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.auth_sessions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.auth_sessions_id_seq OWNER TO postgres;

--
-- Name: auth_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.auth_sessions_id_seq OWNED BY public.auth_sessions.id;


--
-- Name: jonah_triggers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.jonah_triggers (
    id integer NOT NULL,
    station character varying(4) NOT NULL,
    bucket character varying(20) NOT NULL,
    confidence real NOT NULL,
    timing character varying(10),
    reasoning text,
    current_temp_f real,
    outcome character varying(20) NOT NULL,
    block_reason character varying(30),
    trade_action character varying(10),
    order_id character varying(128),
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.jonah_triggers OWNER TO postgres;

--
-- Name: jonah_triggers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.jonah_triggers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.jonah_triggers_id_seq OWNER TO postgres;

--
-- Name: jonah_triggers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.jonah_triggers_id_seq OWNED BY public.jonah_triggers.id;


--
-- Name: logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.logs (
    id integer NOT NULL,
    trace_id character varying(64),
    service character varying(10) NOT NULL,
    station character varying(4),
    level character varying(10) NOT NULL,
    category character varying(20),
    message text NOT NULL,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.logs OWNER TO postgres;

--
-- Name: logs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.logs_id_seq OWNER TO postgres;

--
-- Name: logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.logs_id_seq OWNED BY public.logs.id;


--
-- Name: metar_observations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.metar_observations (
    id integer NOT NULL,
    station character varying(4) NOT NULL,
    temp_c real NOT NULL,
    dewpoint_c real,
    humidity_pct smallint,
    wind_deg smallint,
    wind_kt smallint,
    gust_kt smallint,
    visibility_m integer,
    cloud_layers jsonb,
    pressure_hpa real,
    max_temp_c_6h real,
    metar_raw text NOT NULL,
    valid_utc timestamp with time zone NOT NULL,
    captured_at timestamp with time zone NOT NULL,
    trace_id character varying(64) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    min_temp_c_6h real,
    sea_level_pressure_hpa real,
    wx_string text,
    auto_station boolean,
    metar_type character varying(5),
    ceiling_ft integer,
    source character varying(20),
    temp_precise boolean
);


ALTER TABLE public.metar_observations OWNER TO postgres;

--
-- Name: metar_observations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.metar_observations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.metar_observations_id_seq OWNER TO postgres;

--
-- Name: metar_observations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.metar_observations_id_seq OWNED BY public.metar_observations.id;


--
-- Name: polymarket_market_trades; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.polymarket_market_trades (
    condition_id character varying(100) NOT NULL,
    trade_ts bigint NOT NULL,
    price numeric(10,6) NOT NULL,
    side character varying(8),
    size numeric(20,6),
    captured_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.polymarket_market_trades OWNER TO postgres;

--
-- Name: pws_observations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pws_observations (
    id integer NOT NULL,
    station character varying(4) NOT NULL,
    median_temp_c real NOT NULL,
    reading_count smallint NOT NULL,
    readings jsonb,
    trace_id character varying(64) NOT NULL,
    captured_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.pws_observations OWNER TO postgres;

--
-- Name: pws_observations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pws_observations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pws_observations_id_seq OWNER TO postgres;

--
-- Name: pws_observations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pws_observations_id_seq OWNED BY public.pws_observations.id;


--
-- Name: shadow_trades; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.shadow_trades (
    id integer NOT NULL,
    rule_set_version character varying(40) NOT NULL,
    action character varying(20) NOT NULL,
    station character varying(4) NOT NULL,
    bucket character varying(40) NOT NULL,
    token_id character varying(100),
    entry_price real,
    exit_price real,
    shares real,
    usd_amount real,
    pnl real,
    bankroll_after real NOT NULL,
    signal_trace_id character varying(100),
    entered_at timestamp with time zone,
    resolved_at timestamp with time zone,
    outcome character varying(20),
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.shadow_trades OWNER TO postgres;

--
-- Name: shadow_trades_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.shadow_trades_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.shadow_trades_id_seq OWNER TO postgres;

--
-- Name: shadow_trades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.shadow_trades_id_seq OWNED BY public.shadow_trades.id;


--
-- Name: spread_shadow_trades; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.spread_shadow_trades (
    id integer NOT NULL,
    rule_set_version character varying(40) NOT NULL,
    cohort_id character varying(64) NOT NULL,
    station character varying(4) NOT NULL,
    target_date date NOT NULL,
    bucket_label character varying(40) NOT NULL,
    bucket_lower_f real NOT NULL,
    bucket_upper_f real NOT NULL,
    bucket_index smallint NOT NULL,
    token_id character varying(100) NOT NULL,
    condition_id character varying(100),
    forecast_mean_f real NOT NULL,
    forecast_std_f real,
    forecast_bucket_prob real,
    forecast_sources_json jsonb,
    entry_price real,
    entry_book_json jsonb,
    price_path jsonb DEFAULT '[]'::jsonb NOT NULL,
    status character varying(20) DEFAULT 'open'::character varying NOT NULL,
    skip_reason character varying(60),
    exit_a_price real,
    exit_a_ts timestamp with time zone,
    exit_b_price real,
    exit_b_ts timestamp with time zone,
    exit_b_reason character varying(30),
    exit_c_price real,
    exit_c_ts timestamp with time zone,
    actual_max_f real,
    actual_bucket_label character varying(40),
    was_winner boolean,
    pnl_a real,
    pnl_b real,
    pnl_c real,
    trace_id character varying(100),
    created_at timestamp with time zone DEFAULT now(),
    resolved_at timestamp with time zone
);


ALTER TABLE public.spread_shadow_trades OWNER TO postgres;

--
-- Name: spread_shadow_trades_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.spread_shadow_trades_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.spread_shadow_trades_id_seq OWNER TO postgres;

--
-- Name: spread_shadow_trades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.spread_shadow_trades_id_seq OWNED BY public.spread_shadow_trades.id;


--
-- Name: trades; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trades (
    id integer NOT NULL,
    trace_id character varying(64) NOT NULL,
    station character varying(4) NOT NULL,
    action character varying(10) NOT NULL,
    side character varying(3) NOT NULL,
    bucket character varying(20) NOT NULL,
    token_id character varying(128),
    amount real,
    shares real,
    price real,
    order_id character varying(128),
    fill_status character varying(10),
    signal_type character varying(20) NOT NULL,
    market_snapshot jsonb,
    dry_run boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    target_date character varying(10)
);


ALTER TABLE public.trades OWNER TO postgres;

--
-- Name: trades_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.trades_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.trades_id_seq OWNER TO postgres;

--
-- Name: trades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.trades_id_seq OWNED BY public.trades.id;


--
-- Name: auth_sessions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_sessions ALTER COLUMN id SET DEFAULT nextval('public.auth_sessions_id_seq'::regclass);


--
-- Name: jonah_triggers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jonah_triggers ALTER COLUMN id SET DEFAULT nextval('public.jonah_triggers_id_seq'::regclass);


--
-- Name: logs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.logs ALTER COLUMN id SET DEFAULT nextval('public.logs_id_seq'::regclass);


--
-- Name: metar_observations id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.metar_observations ALTER COLUMN id SET DEFAULT nextval('public.metar_observations_id_seq'::regclass);


--
-- Name: pws_observations id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pws_observations ALTER COLUMN id SET DEFAULT nextval('public.pws_observations_id_seq'::regclass);


--
-- Name: shadow_trades id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shadow_trades ALTER COLUMN id SET DEFAULT nextval('public.shadow_trades_id_seq'::regclass);


--
-- Name: spread_shadow_trades id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.spread_shadow_trades ALTER COLUMN id SET DEFAULT nextval('public.spread_shadow_trades_id_seq'::regclass);


--
-- Name: trades id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trades ALTER COLUMN id SET DEFAULT nextval('public.trades_id_seq'::regclass);


--
-- Name: app_config app_config_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.app_config
    ADD CONSTRAINT app_config_pkey PRIMARY KEY (key);


--
-- Name: auth_sessions auth_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_sessions
    ADD CONSTRAINT auth_sessions_pkey PRIMARY KEY (id);


--
-- Name: jonah_triggers jonah_triggers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jonah_triggers
    ADD CONSTRAINT jonah_triggers_pkey PRIMARY KEY (id);


--
-- Name: logs logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.logs
    ADD CONSTRAINT logs_pkey PRIMARY KEY (id);


--
-- Name: metar_observations metar_observations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.metar_observations
    ADD CONSTRAINT metar_observations_pkey PRIMARY KEY (id);


--
-- Name: polymarket_market_trades polymarket_market_trades_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.polymarket_market_trades
    ADD CONSTRAINT polymarket_market_trades_pkey PRIMARY KEY (condition_id, trade_ts, price);


--
-- Name: pws_observations pws_observations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pws_observations
    ADD CONSTRAINT pws_observations_pkey PRIMARY KEY (id);


--
-- Name: shadow_trades shadow_trades_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shadow_trades
    ADD CONSTRAINT shadow_trades_pkey PRIMARY KEY (id);


--
-- Name: spread_shadow_trades spread_shadow_trades_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.spread_shadow_trades
    ADD CONSTRAINT spread_shadow_trades_pkey PRIMARY KEY (id);


--
-- Name: trades trades_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trades
    ADD CONSTRAINT trades_pkey PRIMARY KEY (id);


--
-- Name: idx_jonah_triggers_station_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_jonah_triggers_station_date ON public.jonah_triggers USING btree (station, created_at);


--
-- Name: idx_logs_service_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_logs_service_date ON public.logs USING btree (service, created_at);


--
-- Name: idx_logs_station_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_logs_station_date ON public.logs USING btree (station, created_at);


--
-- Name: idx_logs_trace; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_logs_trace ON public.logs USING btree (trace_id);


--
-- Name: idx_market_trades_cond_ts; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_market_trades_cond_ts ON public.polymarket_market_trades USING btree (condition_id, trade_ts);


--
-- Name: idx_metar_station_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_metar_station_date ON public.metar_observations USING btree (station, valid_utc);


--
-- Name: idx_pws_station_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pws_station_date ON public.pws_observations USING btree (station, captured_at);


--
-- Name: idx_shadow_trades_station_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_shadow_trades_station_date ON public.shadow_trades USING btree (station, created_at);


--
-- Name: idx_spread_cohort; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_spread_cohort ON public.spread_shadow_trades USING btree (cohort_id);


--
-- Name: idx_spread_station_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_spread_station_date ON public.spread_shadow_trades USING btree (station, target_date);


--
-- Name: idx_spread_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_spread_status ON public.spread_shadow_trades USING btree (status);


--
-- Name: idx_trades_station; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_trades_station ON public.trades USING btree (station, created_at);


--
-- Name: idx_trades_target_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_trades_target_date ON public.trades USING btree (target_date, station);


--
-- Name: idx_trades_trace; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_trades_trace ON public.trades USING btree (trace_id);


--
-- Name: uq_metar_station_valid_raw; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX uq_metar_station_valid_raw ON public.metar_observations USING btree (station, valid_utc, metar_raw);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

\unrestrict 9jCoD4KF2K5MTwUnJPAIKyQ2l37yf3v0xjBX3QbUDwdzZAFh3ytRBHgcF3PcQLx

