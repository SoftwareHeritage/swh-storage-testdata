--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.4
-- Dumped by pg_dump version 9.6.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: task_policy; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE task_policy AS ENUM (
    'recurring',
    'oneshot'
);


--
-- Name: TYPE task_policy; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE task_policy IS 'Recurrence policy of the given task';


--
-- Name: task_run_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE task_run_status AS ENUM (
    'scheduled',
    'started',
    'eventful',
    'uneventful',
    'failed',
    'permfailed',
    'lost'
);


--
-- Name: TYPE task_run_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE task_run_status IS 'Status of a given task run';


--
-- Name: task_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE task_status AS ENUM (
    'next_run_not_scheduled',
    'next_run_scheduled',
    'completed',
    'disabled'
);


--
-- Name: TYPE task_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE task_status IS 'Status of a given task';


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: task; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE task (
    id bigint NOT NULL,
    type text NOT NULL,
    arguments jsonb NOT NULL,
    next_run timestamp with time zone NOT NULL,
    current_interval interval,
    status task_status NOT NULL,
    policy task_policy DEFAULT 'recurring'::task_policy NOT NULL,
    retries_left bigint DEFAULT 0 NOT NULL,
    CONSTRAINT task_check CHECK (((policy <> 'recurring'::task_policy) OR (current_interval IS NOT NULL)))
);


--
-- Name: TABLE task; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE task IS 'Schedule of recurring tasks';


--
-- Name: COLUMN task.arguments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task.arguments IS 'Arguments passed to the underlying job scheduler. Contains two keys, ''args'' (list) and ''kwargs'' (object).';


--
-- Name: COLUMN task.next_run; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task.next_run IS 'The next run of this task should be run on or after that time';


--
-- Name: COLUMN task.current_interval; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task.current_interval IS 'The interval between two runs of this task, taking into account the backoff factor';


--
-- Name: COLUMN task.policy; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task.policy IS 'Whether the task is one-shot or recurring';


--
-- Name: COLUMN task.retries_left; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task.retries_left IS 'The number of "short delay" retries of the task in case of transient failure';


--
-- Name: swh_scheduler_create_tasks_from_temp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_create_tasks_from_temp() RETURNS SETOF task
    LANGUAGE plpgsql
    AS $$
begin
  return query
  insert into task (type, arguments, next_run, status, current_interval, policy, retries_left)
    select type, arguments, next_run, 'next_run_not_scheduled',
           (select default_interval from task_type tt where tt.type = tmp_task.type),
           coalesce(policy, 'recurring'),
           coalesce(retries_left, (select num_retries from task_type tt where tt.type = tmp_task.type), 0)
      from tmp_task
  returning task.*;
end;
$$;


--
-- Name: FUNCTION swh_scheduler_create_tasks_from_temp(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_scheduler_create_tasks_from_temp() IS 'Create tasks in bulk from the temporary table';


--
-- Name: task_run; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE task_run (
    id bigint NOT NULL,
    task bigint NOT NULL,
    backend_id text,
    scheduled timestamp with time zone,
    started timestamp with time zone,
    ended timestamp with time zone,
    metadata jsonb,
    status task_run_status DEFAULT 'scheduled'::task_run_status NOT NULL
);


--
-- Name: TABLE task_run; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE task_run IS 'History of task runs sent to the job-running backend';


--
-- Name: COLUMN task_run.backend_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_run.backend_id IS 'id of the task run in the job-running backend';


--
-- Name: COLUMN task_run.metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_run.metadata IS 'Useful metadata for the given task run. For instance, the worker that took on the job, or the logs for the run.';


--
-- Name: swh_scheduler_end_task_run(text, task_run_status, jsonb, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_end_task_run(backend_id text, status task_run_status, metadata jsonb DEFAULT '{}'::jsonb, ts timestamp with time zone DEFAULT now()) RETURNS task_run
    LANGUAGE sql
    AS $$
  update task_run
    set ended = ts,
        status = swh_scheduler_end_task_run.status,
        metadata = coalesce(task_run.metadata, '{}'::jsonb) || swh_scheduler_end_task_run.metadata
    where task_run.backend_id = swh_scheduler_end_task_run.backend_id
  returning *;
$$;


--
-- Name: swh_scheduler_grab_ready_tasks(text, timestamp with time zone, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_grab_ready_tasks(task_type text, ts timestamp with time zone DEFAULT now(), num_tasks bigint DEFAULT NULL::bigint) RETURNS SETOF task
    LANGUAGE sql
    AS $$
  update task
    set status='next_run_scheduled'
    from (
      select id from task
        where next_run <= ts
              and type = task_type
              and status='next_run_not_scheduled'
        order by next_run
        limit num_tasks
        for update skip locked
    ) next_tasks
    where task.id = next_tasks.id
  returning task.*;
$$;


--
-- Name: swh_scheduler_mktemp_task(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_mktemp_task() RETURNS void
    LANGUAGE sql
    AS $$
  create temporary table tmp_task (
    like task excluding indexes
  ) on commit drop;
  alter table tmp_task
    drop column id,
    drop column current_interval,
    drop column status,
    alter column policy drop not null,
    alter column retries_left drop not null;
$$;


--
-- Name: FUNCTION swh_scheduler_mktemp_task(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_scheduler_mktemp_task() IS 'Create a temporary table for bulk task creation';


--
-- Name: swh_scheduler_mktemp_task_run(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_mktemp_task_run() RETURNS void
    LANGUAGE sql
    AS $$
  create temporary table tmp_task_run (
    like task_run excluding indexes
  ) on commit drop;
  alter table tmp_task_run
    drop column id,
    drop column status;
$$;


--
-- Name: FUNCTION swh_scheduler_mktemp_task_run(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_scheduler_mktemp_task_run() IS 'Create a temporary table for bulk task run scheduling';


--
-- Name: swh_scheduler_peek_ready_tasks(text, timestamp with time zone, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_peek_ready_tasks(task_type text, ts timestamp with time zone DEFAULT now(), num_tasks bigint DEFAULT NULL::bigint) RETURNS SETOF task
    LANGUAGE sql STABLE
    AS $$
select * from task
  where next_run <= ts
        and type = task_type
        and status = 'next_run_not_scheduled'
  order by next_run
  limit num_tasks;
$$;


--
-- Name: swh_scheduler_schedule_task_run(bigint, text, jsonb, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_schedule_task_run(task_id bigint, backend_id text, metadata jsonb DEFAULT '{}'::jsonb, ts timestamp with time zone DEFAULT now()) RETURNS task_run
    LANGUAGE sql
    AS $$
  insert into task_run (task, backend_id, metadata, scheduled, status)
    values (task_id, backend_id, metadata, ts, 'scheduled')
  returning *;
$$;


--
-- Name: swh_scheduler_schedule_task_run_from_temp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_schedule_task_run_from_temp() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  insert into task_run (task, backend_id, metadata, scheduled, status)
    select task, backend_id, metadata, scheduled, 'scheduled'
      from tmp_task_run;
  return;
end;
$$;


--
-- Name: swh_scheduler_start_task_run(text, jsonb, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_start_task_run(backend_id text, metadata jsonb DEFAULT '{}'::jsonb, ts timestamp with time zone DEFAULT now()) RETURNS task_run
    LANGUAGE sql
    AS $$
  update task_run
    set started = ts,
        status = 'started',
        metadata = coalesce(task_run.metadata, '{}'::jsonb) || swh_scheduler_start_task_run.metadata
    where task_run.backend_id = swh_scheduler_start_task_run.backend_id
  returning *;
$$;


--
-- Name: swh_scheduler_update_task_on_task_end(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_update_task_on_task_end() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  cur_task task%rowtype;
  cur_task_type task_type%rowtype;
  adjustment_factor float;
  new_interval interval;
begin
  select * from task where id = new.task into cur_task;
  select * from task_type where type = cur_task.type into cur_task_type;

  case
    when new.status = 'permfailed' then
      update task
        set status = 'disabled'
        where id = cur_task.id;
    when new.status in ('eventful', 'uneventful') then
      case
        when cur_task.policy = 'oneshot' then
          update task
            set status = 'completed'
            where id = cur_task.id;
        when cur_task.policy = 'recurring' then
          if new.status = 'uneventful' then
            adjustment_factor := 1/cur_task_type.backoff_factor;
          else
            adjustment_factor := 1/cur_task_type.backoff_factor;
          end if;
          new_interval := greatest(
            cur_task_type.min_interval,
            least(
              cur_task_type.max_interval,
              adjustment_factor * cur_task.current_interval));
          update task
            set status = 'next_run_not_scheduled',
                next_run = now() + new_interval,
                current_interval = new_interval,
                retries_left = coalesce(cur_task_type.num_retries, 0)
            where id = cur_task.id;
      end case;
    else -- new.status in 'failed', 'lost'
      if cur_task.retries_left > 0 then
        update task
          set status = 'next_run_not_scheduled',
              next_run = now() + cur_task_type.retry_delay,
              retries_left = cur_task.retries_left - 1
          where id = cur_task.id;
      else -- no retries left
        case
          when cur_task.policy = 'oneshot' then
            update task
              set status = 'disabled'
              where id = cur_task.id;
          when cur_task.policy = 'recurring' then
            update task
              set status = 'next_run_not_scheduled',
                  next_run = now() + cur_task.current_interval,
                  retries_left = coalesce(cur_task_type.num_retries, 0)
              where id = cur_task.id;
        end case;
      end if; -- retries
  end case;
  return null;
end;
$$;


--
-- Name: dbversion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE dbversion (
    version integer NOT NULL,
    release timestamp with time zone NOT NULL,
    description text NOT NULL
);


--
-- Name: TABLE dbversion; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE dbversion IS 'Schema update tracking';


--
-- Name: task_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE task_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE task_id_seq OWNED BY task.id;


--
-- Name: task_run_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE task_run_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_run_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE task_run_id_seq OWNED BY task_run.id;


--
-- Name: task_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE task_type (
    type text NOT NULL,
    description text NOT NULL,
    backend_name text NOT NULL,
    default_interval interval,
    min_interval interval,
    max_interval interval,
    backoff_factor double precision,
    max_queue_length bigint,
    num_retries bigint,
    retry_delay interval
);


--
-- Name: TABLE task_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE task_type IS 'Types of schedulable tasks';


--
-- Name: COLUMN task_type.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_type.type IS 'Short identifier for the task type';


--
-- Name: COLUMN task_type.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_type.description IS 'Human-readable task description';


--
-- Name: COLUMN task_type.backend_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_type.backend_name IS 'Name of the task in the job-running backend';


--
-- Name: COLUMN task_type.default_interval; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_type.default_interval IS 'Default interval for newly scheduled tasks';


--
-- Name: COLUMN task_type.min_interval; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_type.min_interval IS 'Minimum interval between two runs of a task';


--
-- Name: COLUMN task_type.max_interval; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_type.max_interval IS 'Maximum interval between two runs of a task';


--
-- Name: COLUMN task_type.backoff_factor; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_type.backoff_factor IS 'Adjustment factor for the backoff between two task runs';


--
-- Name: COLUMN task_type.max_queue_length; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_type.max_queue_length IS 'Maximum length of the queue for this type of tasks';


--
-- Name: COLUMN task_type.num_retries; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_type.num_retries IS 'Default number of retries on transient failures';


--
-- Name: COLUMN task_type.retry_delay; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_type.retry_delay IS 'Retry delay for the task';


--
-- Name: task id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY task ALTER COLUMN id SET DEFAULT nextval('task_id_seq'::regclass);


--
-- Name: task_run id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY task_run ALTER COLUMN id SET DEFAULT nextval('task_run_id_seq'::regclass);


--
-- Data for Name: dbversion; Type: TABLE DATA; Schema: public; Owner: -
--

COPY dbversion (version, release, description) FROM stdin;
6	2017-12-07 00:16:55.264123+01	Work In Progress
\.


--
-- Data for Name: task; Type: TABLE DATA; Schema: public; Owner: -
--

COPY task (id, type, arguments, next_run, current_interval, status, policy, retries_left) FROM stdin;
\.


--
-- Name: task_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('task_id_seq', 1, false);


--
-- Data for Name: task_run; Type: TABLE DATA; Schema: public; Owner: -
--

COPY task_run (id, task, backend_id, scheduled, started, ended, metadata, status) FROM stdin;
\.


--
-- Name: task_run_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('task_run_id_seq', 1, false);


--
-- Data for Name: task_type; Type: TABLE DATA; Schema: public; Owner: -
--

COPY task_type (type, description, backend_name, default_interval, min_interval, max_interval, backoff_factor, max_queue_length, num_retries, retry_delay) FROM stdin;
\.


--
-- Name: dbversion dbversion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dbversion
    ADD CONSTRAINT dbversion_pkey PRIMARY KEY (version);


--
-- Name: task task_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY task
    ADD CONSTRAINT task_pkey PRIMARY KEY (id);


--
-- Name: task_run task_run_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY task_run
    ADD CONSTRAINT task_run_pkey PRIMARY KEY (id);


--
-- Name: task_type task_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY task_type
    ADD CONSTRAINT task_type_pkey PRIMARY KEY (type);


--
-- Name: task_args; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_args ON task USING btree (((arguments -> 'args'::text)));


--
-- Name: task_kwargs; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_kwargs ON task USING gin (((arguments -> 'kwargs'::text)));


--
-- Name: task_next_run_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_next_run_idx ON task USING btree (next_run);


--
-- Name: task_run_backend_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_run_backend_id_idx ON task_run USING btree (backend_id);


--
-- Name: task_run_task_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_run_task_idx ON task_run USING btree (task);


--
-- Name: task_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_type_idx ON task USING btree (type);


--
-- Name: task_run update_task_on_task_end; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_task_on_task_end AFTER UPDATE OF status ON task_run FOR EACH ROW WHEN ((new.status <> ALL (ARRAY['scheduled'::task_run_status, 'started'::task_run_status]))) EXECUTE PROCEDURE swh_scheduler_update_task_on_task_end();


--
-- Name: task_run task_run_task_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY task_run
    ADD CONSTRAINT task_run_task_fkey FOREIGN KEY (task) REFERENCES task(id);


--
-- Name: task task_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY task
    ADD CONSTRAINT task_type_fkey FOREIGN KEY (type) REFERENCES task_type(type);


--
-- PostgreSQL database dump complete
--

