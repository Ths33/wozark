--
-- PostgreSQL database dump
--

\restrict wlGLwM4dH2uaESSGP9P5VuyFHG2RBWMmUbx4cLYVuSxla0w53BuqfmiupKfoFMe

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
-- Name: buffer_snapshots; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.buffer_snapshots (
    station character varying(4) NOT NULL,
    snapshot jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.buffer_snapshots OWNER TO postgres;

--
-- Name: day_sessions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.day_sessions (
    id integer NOT NULL,
    station character varying(4) NOT NULL,
    date date NOT NULL,
    dawn_bucket character varying(20),
    dawn_confidence real,
    dawn_reasoning text,
    current_bucket character varying(20),
    current_confidence real,
    current_reasoning text,
    status character varying(10) DEFAULT 'active'::character varying,
    forecast_max real,
    created_at timestamp with time zone DEFAULT now(),
    locked_at timestamp with time zone,
    resolved_at timestamp with time zone,
    timing character varying(10) DEFAULT 'WAIT'::character varying,
    range_prob real
);


ALTER TABLE public.day_sessions OWNER TO postgres;

--
-- Name: day_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.day_sessions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.day_sessions_id_seq OWNER TO postgres;

--
-- Name: day_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.day_sessions_id_seq OWNED BY public.day_sessions.id;


--
-- Name: forecast_snapshots; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.forecast_snapshots (
    id integer NOT NULL,
    station character varying(4) NOT NULL,
    target_date date NOT NULL,
    generated_at timestamp with time zone DEFAULT now(),
    forecast_peak_raw real,
    predicted_peak real,
    confidence real,
    rag_samples integer,
    source character varying(30),
    rationale text,
    forecast_conditions jsonb,
    market_event_slug character varying(200),
    legs jsonb,
    legs_total_price real,
    actual_max_c real,
    actual_bucket character varying(20),
    resolved_at timestamp with time zone
);


ALTER TABLE public.forecast_snapshots OWNER TO postgres;

--
-- Name: forecast_snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.forecast_snapshots_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.forecast_snapshots_id_seq OWNER TO postgres;

--
-- Name: forecast_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.forecast_snapshots_id_seq OWNED BY public.forecast_snapshots.id;


--
-- Name: learning_outcomes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.learning_outcomes (
    id integer NOT NULL,
    station character varying(4) NOT NULL,
    date date NOT NULL,
    actual_max_c real,
    actual_bucket character varying(20),
    dawn_bucket character varying(20),
    final_bucket character varying(20),
    was_correct boolean,
    error_value real,
    market_favorite_bucket character varying(20),
    market_was_correct boolean,
    jonah_beat_market boolean,
    sources_accuracy jsonb,
    conditions jsonb,
    evolution jsonb,
    created_at timestamp with time zone DEFAULT now(),
    pws_metrics jsonb,
    pre_metar_accuracy jsonb,
    intraday_accuracy jsonb,
    intraday_drift jsonb,
    synoptic_accuracy jsonb
);


ALTER TABLE public.learning_outcomes OWNER TO postgres;

--
-- Name: learning_outcomes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.learning_outcomes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.learning_outcomes_id_seq OWNER TO postgres;

--
-- Name: learning_outcomes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.learning_outcomes_id_seq OWNED BY public.learning_outcomes.id;


--
-- Name: metar_readings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.metar_readings (
    id integer NOT NULL,
    station character varying(4) NOT NULL,
    temp_c real,
    dewpoint_c real,
    humidity_pct smallint,
    wind_deg smallint,
    wind_kt smallint,
    gust_kt smallint,
    visibility_m integer,
    cloud_layers jsonb,
    pressure_hpa real,
    metar_raw text,
    max_temp_c_6h real,
    valid_utc timestamp with time zone,
    captured_at timestamp with time zone DEFAULT now(),
    ceiling_ft integer,
    wx_string text,
    altimeter_hpa real,
    source character varying(20),
    synoptic_lag_s integer,
    sea_level_pressure_hpa real,
    auto_station boolean,
    metar_type character varying(10),
    temp_precise boolean
);


ALTER TABLE public.metar_readings OWNER TO postgres;

--
-- Name: metar_readings_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.metar_readings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.metar_readings_id_seq OWNER TO postgres;

--
-- Name: metar_readings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.metar_readings_id_seq OWNED BY public.metar_readings.id;


--
-- Name: pws_readings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pws_readings (
    id integer NOT NULL,
    station character varying(4) NOT NULL,
    median_c real,
    reading_count smallint,
    solar_radiation real,
    uv real,
    raw_readings jsonb,
    captured_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.pws_readings OWNER TO postgres;

--
-- Name: pws_readings_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pws_readings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pws_readings_id_seq OWNER TO postgres;

--
-- Name: pws_readings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pws_readings_id_seq OWNED BY public.pws_readings.id;


--
-- Name: session_updates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.session_updates (
    id integer NOT NULL,
    session_id integer,
    phase character varying(10) NOT NULL,
    bucket character varying(20),
    confidence real,
    reasoning text,
    sources jsonb,
    market_snapshot jsonb,
    metar_at_update real,
    pws_at_update real,
    created_at timestamp with time zone DEFAULT now(),
    timing character varying(10)
);


ALTER TABLE public.session_updates OWNER TO postgres;

--
-- Name: session_updates_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.session_updates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.session_updates_id_seq OWNER TO postgres;

--
-- Name: session_updates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.session_updates_id_seq OWNED BY public.session_updates.id;


--
-- Name: trigger_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trigger_history (
    id integer NOT NULL,
    station character varying(4) NOT NULL,
    bucket character varying(20) NOT NULL,
    range_prob real NOT NULL,
    signal character varying(10) NOT NULL,
    outcome character varying(20),
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.trigger_history OWNER TO postgres;

--
-- Name: trigger_history_archived_20260417; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trigger_history_archived_20260417 (
    id integer NOT NULL,
    station character varying(4) NOT NULL,
    bucket character varying(20) NOT NULL,
    range_prob real NOT NULL,
    signal character varying(10) NOT NULL,
    outcome character varying(20),
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.trigger_history_archived_20260417 OWNER TO postgres;

--
-- Name: trigger_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.trigger_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.trigger_history_id_seq OWNER TO postgres;

--
-- Name: trigger_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.trigger_history_id_seq OWNED BY public.trigger_history_archived_20260417.id;


--
-- Name: trigger_history_id_seq1; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.trigger_history_id_seq1
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.trigger_history_id_seq1 OWNER TO postgres;

--
-- Name: trigger_history_id_seq1; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.trigger_history_id_seq1 OWNED BY public.trigger_history.id;


--
-- Name: day_sessions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.day_sessions ALTER COLUMN id SET DEFAULT nextval('public.day_sessions_id_seq'::regclass);


--
-- Name: forecast_snapshots id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.forecast_snapshots ALTER COLUMN id SET DEFAULT nextval('public.forecast_snapshots_id_seq'::regclass);


--
-- Name: learning_outcomes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.learning_outcomes ALTER COLUMN id SET DEFAULT nextval('public.learning_outcomes_id_seq'::regclass);


--
-- Name: metar_readings id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.metar_readings ALTER COLUMN id SET DEFAULT nextval('public.metar_readings_id_seq'::regclass);


--
-- Name: pws_readings id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pws_readings ALTER COLUMN id SET DEFAULT nextval('public.pws_readings_id_seq'::regclass);


--
-- Name: session_updates id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_updates ALTER COLUMN id SET DEFAULT nextval('public.session_updates_id_seq'::regclass);


--
-- Name: trigger_history id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trigger_history ALTER COLUMN id SET DEFAULT nextval('public.trigger_history_id_seq1'::regclass);


--
-- Name: trigger_history_archived_20260417 id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trigger_history_archived_20260417 ALTER COLUMN id SET DEFAULT nextval('public.trigger_history_id_seq'::regclass);


--
-- Name: buffer_snapshots buffer_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buffer_snapshots
    ADD CONSTRAINT buffer_snapshots_pkey PRIMARY KEY (station);


--
-- Name: day_sessions day_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.day_sessions
    ADD CONSTRAINT day_sessions_pkey PRIMARY KEY (id);


--
-- Name: day_sessions day_sessions_station_date_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.day_sessions
    ADD CONSTRAINT day_sessions_station_date_key UNIQUE (station, date);


--
-- Name: forecast_snapshots forecast_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.forecast_snapshots
    ADD CONSTRAINT forecast_snapshots_pkey PRIMARY KEY (id);


--
-- Name: forecast_snapshots forecast_snapshots_station_target_date_generated_at_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.forecast_snapshots
    ADD CONSTRAINT forecast_snapshots_station_target_date_generated_at_key UNIQUE (station, target_date, generated_at);


--
-- Name: learning_outcomes learning_outcomes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.learning_outcomes
    ADD CONSTRAINT learning_outcomes_pkey PRIMARY KEY (id);


--
-- Name: learning_outcomes learning_outcomes_station_date_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.learning_outcomes
    ADD CONSTRAINT learning_outcomes_station_date_key UNIQUE (station, date);


--
-- Name: metar_readings metar_readings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.metar_readings
    ADD CONSTRAINT metar_readings_pkey PRIMARY KEY (id);


--
-- Name: pws_readings pws_readings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pws_readings
    ADD CONSTRAINT pws_readings_pkey PRIMARY KEY (id);


--
-- Name: session_updates session_updates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_updates
    ADD CONSTRAINT session_updates_pkey PRIMARY KEY (id);


--
-- Name: trigger_history_archived_20260417 trigger_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trigger_history_archived_20260417
    ADD CONSTRAINT trigger_history_pkey PRIMARY KEY (id);


--
-- Name: trigger_history trigger_history_pkey1; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trigger_history
    ADD CONSTRAINT trigger_history_pkey1 PRIMARY KEY (id);


--
-- Name: idx_forecast_snapshots_target; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_forecast_snapshots_target ON public.forecast_snapshots USING btree (target_date);


--
-- Name: idx_forecast_snapshots_unresolved; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_forecast_snapshots_unresolved ON public.forecast_snapshots USING btree (target_date, resolved_at) WHERE (resolved_at IS NULL);


--
-- Name: idx_metar_station_captured; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_metar_station_captured ON public.metar_readings USING btree (station, captured_at);


--
-- Name: idx_pws_station_captured; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pws_station_captured ON public.pws_readings USING btree (station, captured_at);


--
-- Name: session_updates session_updates_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_updates
    ADD CONSTRAINT session_updates_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.day_sessions(id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

\unrestrict wlGLwM4dH2uaESSGP9P5VuyFHG2RBWMmUbx4cLYVuSxla0w53BuqfmiupKfoFMe

