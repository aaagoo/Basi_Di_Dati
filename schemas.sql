--
-- PostgreSQL database dump
--

-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.4

-- Started on 2025-07-16 23:10:14

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 878 (class 1247 OID 16729)
-- Name: stato_prenotazione; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.stato_prenotazione AS ENUM (
    'CONFERMATA',
    'IN_ATTESA',
    'CANCELLATA'
);


--
-- TOC entry 881 (class 1247 OID 16736)
-- Name: stato_volo; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.stato_volo AS ENUM (
    'PROGRAMMATO',
    'IN_RITARDO',
    'DECOLLATO',
    'ATTERRATO',
    'CANCELLATO'
);


--
-- TOC entry 908 (class 1247 OID 17178)
-- Name: tipo_volo; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.tipo_volo AS ENUM (
    'ARRIVO',
    'PARTENZA'
);


--
-- TOC entry 255 (class 1255 OID 16904)
-- Name: aggiorna_stato_prenotazione(character varying, character varying, character varying, public.stato_prenotazione); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.aggiorna_stato_prenotazione(IN p_admin_username character varying, IN p_admin_password character varying, IN p_numero_biglietto character varying, IN p_nuovo_stato public.stato_prenotazione)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Verifica le credenziali dell'amministratore
    IF NOT verifica_admin(p_admin_username, p_admin_password) THEN
        RAISE EXCEPTION 'Credenziali amministratore non valide';
    END IF;

    -- Verifica se la prenotazione esiste
    IF NOT EXISTS (
        SELECT 1 FROM prenotazione
        WHERE numero_biglietto = p_numero_biglietto
    ) THEN
        RAISE EXCEPTION 'Prenotazione con numero biglietto % non trovata', p_numero_biglietto;
    END IF;

    -- Aggiorna lo stato della prenotazione
    UPDATE prenotazione
    SET stato = p_nuovo_stato
    WHERE numero_biglietto = p_numero_biglietto;
END;
$$;


--
-- TOC entry 258 (class 1255 OID 17206)
-- Name: aggiorna_stato_volo(character varying, character varying, character varying, public.stato_volo, integer); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.aggiorna_stato_volo(IN p_admin_username character varying, IN p_admin_password character varying, IN p_codice_volo character varying, IN p_nuovo_stato public.stato_volo, IN p_ritardo integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Verifica le credenziali dell'amministratore
    IF NOT verifica_admin(p_admin_username, p_admin_password) THEN
        RAISE EXCEPTION 'Credenziali amministratore non valide';
    END IF;

    -- Verifica se il volo esiste
    IF NOT EXISTS (
        SELECT 1 FROM volo
        WHERE codice = p_codice_volo
    ) THEN
        RAISE EXCEPTION 'Volo con codice % non trovato', p_codice_volo;
    END IF;

    -- Verifica che il ritardo non sia negativo
    IF p_ritardo < 0 THEN
        RAISE EXCEPTION 'Il ritardo non può essere negativo';
    END IF;

    -- Se c'è un ritardo maggiore di 0, forza lo stato a IN_RITARDO
    IF p_ritardo > 0 THEN
        UPDATE volo
        SET stato = 'IN_RITARDO'::stato_volo,
            ritardo = p_ritardo
        WHERE codice = p_codice_volo;
    ELSE
        UPDATE volo
        SET stato = p_nuovo_stato,
            ritardo = p_ritardo
        WHERE codice = p_codice_volo;
    END IF;
END;
$$;


--
-- TOC entry 259 (class 1255 OID 17207)
-- Name: aggiungi_volo(character varying, character varying, character varying, character varying, character varying, character varying, date, time without time zone, character varying, integer); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.aggiungi_volo(IN p_admin_username character varying, IN p_admin_password character varying, IN p_codice character varying, IN p_compagnia_aerea character varying, IN p_aeroporto_origine character varying, IN p_aeroporto_destinazione character varying, IN p_data_partenza date, IN p_orario time without time zone, IN p_tipo_volo character varying, IN p_ritardo integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Verifica le credenziali dell'amministratore
    IF NOT verifica_admin(p_admin_username, p_admin_password) THEN
        RAISE EXCEPTION 'Credenziali amministratore non valide';
    END IF;

    -- Verifica che il tipo_volo sia valido
    IF p_tipo_volo NOT IN ('ARRIVO', 'PARTENZA') THEN
        RAISE EXCEPTION 'Il tipo volo deve essere ARRIVO o PARTENZA';
    END IF;

    -- Verifica che il ritardo non sia negativo
    IF p_ritardo < 0 THEN
        RAISE EXCEPTION 'Il ritardo non può essere negativo';
    END IF;

    -- Inserimento del nuovo volo
    INSERT INTO volo (
        codice,
        compagnia_aerea,
        aeroporto_origine,
        aeroporto_destinazione,
        data_partenza,
        orario,
        tipo_volo,
        stato,
        ritardo
    ) VALUES (
        p_codice,
        p_compagnia_aerea,
        p_aeroporto_origine,
        p_aeroporto_destinazione,
        p_data_partenza,
        p_orario,
        p_tipo_volo,
        CASE
            WHEN p_ritardo > 0 THEN 'IN_RITARDO'::stato_volo
            ELSE 'PROGRAMMATO'::stato_volo
        END,
        p_ritardo
    );

END;
$$;


--
-- TOC entry 253 (class 1255 OID 16906)
-- Name: assegna_gate(character varying, character varying, character varying, integer); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.assegna_gate(IN p_admin_username character varying, IN p_admin_password character varying, IN p_codice_volo character varying, IN p_numero_gate integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_tipo_volo VARCHAR(10);
    v_stato_volo stato_volo;
    v_gate_esistente INTEGER;
BEGIN
    -- Verifica che chi sta assegnando sia un amministratore
    IF NOT verifica_admin(p_admin_username, p_admin_password) THEN
        RAISE EXCEPTION 'Non hai i permessi per assegnare gate';
    END IF;

    -- Verifica che il volo esista e ottieni informazioni
    SELECT tipo_volo, stato
    INTO v_tipo_volo, v_stato_volo
    FROM volo
    WHERE codice = p_codice_volo;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Volo % non trovato', p_codice_volo;
    END IF;

    -- Verifica che il volo sia in partenza
    IF v_tipo_volo != 'PARTENZA' THEN
        RAISE EXCEPTION 'I gate possono essere assegnati solo ai voli in partenza';
    END IF;

    -- Verifica che il volo non sia già partito o cancellato
    IF v_stato_volo IN ('DECOLLATO', 'ATTERRATO', 'CANCELLATO') THEN
        RAISE EXCEPTION 'Non è possibile assegnare un gate a un volo %', v_stato_volo;
    END IF;

    -- Verifica che il gate non sia già assegnato a questo volo
    DELETE FROM gate WHERE codice_volo = p_codice_volo;

    -- Inserisci la nuova assegnazione
    INSERT INTO gate (numero_gate, codice_volo)
    VALUES (p_numero_gate, p_codice_volo);

EXCEPTION
    WHEN check_violation THEN
        RAISE EXCEPTION 'Il numero del gate deve essere positivo';
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Il gate % è già assegnato', p_numero_gate;
    WHEN others THEN
        RAISE EXCEPTION 'Errore durante l''assegnazione del gate: %', SQLERRM;
END;
$$;


--
-- TOC entry 251 (class 1255 OID 16900)
-- Name: cerca_prenotazioni_passeggero(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cerca_prenotazioni_passeggero(p_nomeutente character varying, p_password character varying, p_nome_passeggero character varying, p_cognome_passeggero character varying) RETURNS TABLE(numero_biglietto character varying, posto_assegnato character varying, stato_prenotazione public.stato_prenotazione, codice_volo character varying, compagnia_aerea character varying, aeroporto_origine character varying, aeroporto_destinazione character varying, data_partenza date, orario time without time zone, ritardo integer, stato_volo public.stato_volo, numero_gate integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Verifica le credenziali dell'utente usando la funzione esistente
    IF NOT verifica_utente(p_nomeutente, p_password) THEN
        RAISE EXCEPTION 'Credenziali non valide';
    END IF;

    RETURN QUERY
    SELECT 
        p.numero_biglietto,
        p.posto_assegnato,
        p.stato,
        p.codice_volo,
        v.compagnia_aerea,
        v.aeroporto_origine,
        v.aeroporto_destinazione,
        v.data_partenza,
        v.orario,
        v.ritardo,
        v.stato,
        g.numero_gate
    FROM prenotazione p
    JOIN volo v ON p.codice_volo = v.codice
    LEFT JOIN gate g ON v.codice = g.codice_volo
    WHERE p.nome_passeggero = p_nome_passeggero
    AND p.cognome_passeggero = p_cognome_passeggero
    ORDER BY v.data_partenza, v.orario;
END;
$$;


--
-- TOC entry 254 (class 1255 OID 16901)
-- Name: cerca_prenotazioni_volo(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cerca_prenotazioni_volo(p_nomeutente character varying, p_password character varying, p_codice_volo character varying) RETURNS TABLE(numero_biglietto character varying, posto_assegnato character varying, stato_prenotazione public.stato_prenotazione, nome_passeggero character varying, cognome_passeggero character varying, compagnia_aerea character varying, aeroporto_origine character varying, aeroporto_destinazione character varying, data_partenza date, orario time without time zone, ritardo integer, stato_volo public.stato_volo, numero_gate integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Verifica le credenziali dell'utente usando la funzione esistente
    IF NOT verifica_utente(p_nomeutente, p_password) THEN
        RAISE EXCEPTION 'Credenziali non valide';
    END IF;

    -- Verifica che il volo esista
    IF NOT EXISTS (SELECT 1 FROM volo WHERE codice = p_codice_volo) THEN
        RAISE EXCEPTION 'Volo con codice % non trovato', p_codice_volo;
    END IF;

    RETURN QUERY
    SELECT 
        p.numero_biglietto,
        p.posto_assegnato,
        p.stato,
        p.nome_passeggero,
        p.cognome_passeggero,
        v.compagnia_aerea,
        v.aeroporto_origine,
        v.aeroporto_destinazione,
        v.data_partenza,
        v.orario,
        v.ritardo,
        v.stato,
        g.numero_gate
    FROM prenotazione p
    JOIN volo v ON p.codice_volo = v.codice
    LEFT JOIN gate g ON v.codice = g.codice_volo
    WHERE p.codice_volo = p_codice_volo
    ORDER BY p.posto_assegnato;
END;
$$;


--
-- TOC entry 257 (class 1255 OID 16828)
-- Name: check_volo_partenza_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_volo_partenza_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.codice_volo IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1
            FROM volo v
            WHERE v.codice = NEW.codice_volo
            AND v.tipo = 'PARTENZA'
        ) THEN
            RAISE EXCEPTION 'Il gate può essere assegnato solo a voli in partenza';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


--
-- TOC entry 248 (class 1255 OID 16877)
-- Name: crea_account_admin(character varying, character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.crea_account_admin(IN p_nomeutente character varying, IN p_password character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_account_id INTEGER;
BEGIN
    -- Verifica che il nome utente non esista già
    IF EXISTS (
        SELECT 1
        FROM account
        WHERE nomeutente = p_nomeutente
    ) THEN
        RAISE EXCEPTION 'Il nome utente % è già in uso', p_nomeutente;
    END IF;

    -- Inserisci il nuovo account e ottieni l'ID generato
    INSERT INTO account (nomeutente, password)
    VALUES (p_nomeutente, p_password)
    RETURNING id INTO v_account_id;

    -- Inserisci il record amministratore
    INSERT INTO amministratore (id)
    VALUES (v_account_id);

EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Errore durante la creazione dell''account amministratore: %', SQLERRM;
END;
$$;


--
-- TOC entry 247 (class 1255 OID 16876)
-- Name: crea_account_utente(character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.crea_account_utente(IN p_nomeutente character varying, IN p_password character varying, IN p_nome character varying, IN p_cognome character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_account_id INTEGER;
BEGIN
    -- Verifica che il nome utente non esista già
    IF EXISTS (
        SELECT 1 
        FROM account 
        WHERE nomeutente = p_nomeutente
    ) THEN
        RAISE EXCEPTION 'Il nome utente % è già in uso', p_nomeutente;
    END IF;

    -- Inserisci il nuovo account e ottieni l'ID generato
    INSERT INTO account (nomeutente, password)
    VALUES (p_nomeutente, p_password)
    RETURNING id INTO v_account_id;

    -- Inserisci i dati dell'utente
    INSERT INTO utente (id, nome, cognome)
    VALUES (v_account_id, p_nome, p_cognome);

EXCEPTION
    WHEN others THEN
        -- In caso di errore, annulla entrambe le operazioni
        RAISE EXCEPTION 'Errore durante la creazione dell''account';
END;
$$;


--
-- TOC entry 243 (class 1255 OID 16866)
-- Name: crea_prenotazione(character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.crea_prenotazione(IN p_nomeutente character varying, IN p_password character varying, IN p_nome_passeggero character varying, IN p_cognome_passeggero character varying, IN p_codice_volo character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_tipo_volo VARCHAR(10);
    v_stato_volo stato_volo;
BEGIN
    -- Verifica le credenziali dell'utente
    IF NOT verifica_utente(p_nomeutente, p_password) THEN
        RAISE EXCEPTION 'Credenziali non valide';
    END IF;

    -- Verifica che il volo esista e ottieni il tipo e lo stato
    SELECT tipo_volo, stato
    INTO v_tipo_volo, v_stato_volo
    FROM volo
    WHERE codice = p_codice_volo;

    -- Se il volo non esiste
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Il volo specificato non esiste';
    END IF;

    -- Verifica che sia un volo in partenza
    IF v_tipo_volo != 'PARTENZA' THEN
        RAISE EXCEPTION 'Possono essere prenotati solo voli in partenza';
    END IF;

    -- Verifica che il volo non sia già partito o cancellato
    IF v_stato_volo IN ('DECOLLATO', 'ATTERRATO', 'CANCELLATO') THEN
        RAISE EXCEPTION 'Non è possibile prenotare un volo %', v_stato_volo;
    END IF;

    -- Procedi con l'inserimento della prenotazione
    INSERT INTO prenotazione (
        numero_biglietto,
        posto_assegnato,
        stato,
        nome_passeggero,
        cognome_passeggero,
        codice_volo,
        username_prenotazione
    ) VALUES (
        genera_numero_biglietto(),
        genera_posto_casuale(p_codice_volo),
        'CONFERMATA',
        p_nome_passeggero,
        p_cognome_passeggero,
        p_codice_volo,
        p_nomeutente
    );
END;
$$;


--
-- TOC entry 250 (class 1255 OID 16903)
-- Name: elimina_admin(character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.elimina_admin(IN p_admin_username character varying, IN p_admin_password character varying, IN p_nomeutente character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    admin_id INTEGER;
    v_count INTEGER;
BEGIN
    -- Verifica che chi sta eliminando sia un amministratore
    IF NOT verifica_admin(p_admin_username, p_admin_password) THEN
        RAISE EXCEPTION 'Non hai i permessi per eliminare un amministratore';
    END IF;

    -- Verifica che l'amministratore da eliminare esista
    SELECT a.id INTO admin_id
    FROM account a
    JOIN amministratore am ON a.id = am.id
    WHERE a.nomeutente = p_nomeutente;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Amministratore % non trovato', p_nomeutente;
    END IF;

    -- Elimina il record amministratore
    DELETE FROM amministratore
    WHERE id = admin_id;

    -- Elimina l'account
    DELETE FROM account
    WHERE id = admin_id;

EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Errore durante l''eliminazione dell''amministratore: %', SQLERRM;
END;
$$;


--
-- TOC entry 252 (class 1255 OID 16907)
-- Name: elimina_prenotazione(character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.elimina_prenotazione(IN p_nomeutente character varying, IN p_password character varying, IN p_numero_biglietto character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_username_prenotazione VARCHAR(20);
    v_stato_volo stato_volo;
    v_codice_volo VARCHAR(10);
BEGIN
    -- Verifica le credenziali dell'utente
    IF NOT verifica_utente(p_nomeutente, p_password) THEN
        RAISE EXCEPTION 'Credenziali non valide';
    END IF;

    -- Verifica se la prenotazione esiste e ottiene le informazioni necessarie
    SELECT
        p.username_prenotazione,
        v.stato,
        p.codice_volo
    INTO
        v_username_prenotazione,
        v_stato_volo,
        v_codice_volo
    FROM prenotazione p
    JOIN volo v ON p.codice_volo = v.codice
    WHERE p.numero_biglietto = p_numero_biglietto;

    -- Se la prenotazione non esiste, solleva un'eccezione
    IF v_username_prenotazione IS NULL THEN
        RAISE EXCEPTION 'Prenotazione con numero biglietto % non trovata', p_numero_biglietto;
    END IF;

    -- Verifica che l'utente che sta cercando di eliminare sia il proprietario della prenotazione
    IF v_username_prenotazione != p_nomeutente THEN
        RAISE EXCEPTION 'Non hai i permessi per eliminare questa prenotazione';
    END IF;

    -- Elimina la prenotazione
    DELETE FROM prenotazione
    WHERE numero_biglietto = p_numero_biglietto;
END;
$$;


--
-- TOC entry 256 (class 1255 OID 16902)
-- Name: elimina_utente(character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.elimina_utente(IN p_username_richiedente character varying, IN p_password_richiedente character varying, IN p_nomeutente character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    user_id INTEGER;
    is_self BOOLEAN;
    is_admin BOOLEAN;
BEGIN
    -- Verifica se è una richiesta da amministratore o dall'utente stesso
    is_admin := verifica_admin(p_username_richiedente, p_password_richiedente);
    is_self := verifica_utente(p_username_richiedente, p_password_richiedente);

    -- Se né l'admin né l'utente sono autenticati, errore
    IF NOT (is_admin OR is_self) THEN
        RAISE EXCEPTION 'Credenziali non valide';
    END IF;

    -- Se non è admin, verifica che stia eliminando se stesso
    IF NOT is_admin AND p_nomeutente != p_username_richiedente THEN
        RAISE EXCEPTION 'Un utente può eliminare solo il proprio account';
    END IF;

    -- Verifica che l'account da eliminare sia effettivamente un utente
    SELECT a.id INTO user_id
    FROM account a
    JOIN utente u ON a.id = u.id
    WHERE a.nomeutente = p_nomeutente;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Utente % non trovato o non è un utente normale', p_nomeutente;
    END IF;

    -- Prima elimina tutte le prenotazioni dell'utente
    DELETE FROM prenotazione
    WHERE username_prenotazione = p_nomeutente;

    -- Poi elimina il record utente
    DELETE FROM utente
    WHERE id = user_id;

    -- Infine elimina l'account
    DELETE FROM account
    WHERE id = user_id;

EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Errore durante l''eliminazione dell''utente: %', SQLERRM;
END;
$$;


--
-- TOC entry 246 (class 1255 OID 16873)
-- Name: elimina_volo(character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.elimina_volo(IN p_admin_username character varying, IN p_admin_password character varying, IN p_codice_volo character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Verifica le credenziali dell'amministratore
    IF NOT verifica_admin(p_admin_username, p_admin_password) THEN
        RAISE EXCEPTION 'Credenziali amministratore non valide';
    END IF;

    -- Verifica che il volo esista
    IF NOT EXISTS (SELECT 1 FROM volo WHERE codice = p_codice_volo) THEN
        RAISE EXCEPTION 'Volo con codice % non trovato', p_codice_volo;
    END IF;

    -- Prima elimina eventuali riferimenti nella tabella gate
    DELETE FROM gate
    WHERE codice_volo = p_codice_volo;

    -- Poi elimina eventuali prenotazioni associate
    DELETE FROM prenotazione
    WHERE codice_volo = p_codice_volo;

    -- Infine elimina il volo
    DELETE FROM volo
    WHERE codice = p_codice_volo;

END;
$$;


--
-- TOC entry 230 (class 1255 OID 16837)
-- Name: genera_numero_biglietto(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.genera_numero_biglietto() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    ultimo_numero INTEGER;
BEGIN

    SELECT MAX(CAST(SUBSTRING(numero_biglietto FROM 4) AS INTEGER))
    INTO ultimo_numero
    FROM prenotazione
    WHERE numero_biglietto LIKE 'PRE%';

    IF ultimo_numero IS NULL THEN
        ultimo_numero := 0;
    END IF;

    ultimo_numero := ultimo_numero + 1;

    RETURN 'PRE' || LPAD(ultimo_numero::TEXT, 6, '0');
END;
$$;


--
-- TOC entry 231 (class 1255 OID 16838)
-- Name: genera_posto_casuale(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.genera_posto_casuale(p_codice_volo character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    posto VARCHAR(4);
    occupato BOOLEAN;
BEGIN
    LOOP
        -- Genera un posto casuale (fila 1-30, lettera A-F)
        posto := LPAD(FLOOR(RANDOM() * 30 + 1)::TEXT, 2, '0') ||
                 CHR(FLOOR(RANDOM() * 6 + 65)::INTEGER);

        -- Verifica se il posto è già occupato
        SELECT EXISTS(
            SELECT 1
            FROM prenotazione
            WHERE codice_volo = p_codice_volo
            AND posto_assegnato = posto
        ) INTO occupato;

        EXIT WHEN NOT occupato;
    END LOOP;

    RETURN posto;
END;
$$;


--
-- TOC entry 249 (class 1255 OID 16897)
-- Name: i_miei_voli(character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.i_miei_voli(p_nomeutente character varying, p_password character varying) RETURNS TABLE(numero_biglietto character varying, posto_assegnato character varying, stato_prenotazione public.stato_prenotazione, nome_passeggero character varying, cognome_passeggero character varying, codice_volo character varying, compagnia_aerea character varying, aeroporto_origine character varying, aeroporto_destinazione character varying, data_partenza date, orario time without time zone, ritardo integer, stato_volo public.stato_volo, numero_gate integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Verifica le credenziali dell'utente
    IF NOT verifica_utente(p_nomeutente, p_password) THEN
        RAISE EXCEPTION 'Credenziali non valide';
    END IF;

    RETURN QUERY
    SELECT 
        p.numero_biglietto,
        p.posto_assegnato,
        p.stato,
        p.nome_passeggero,
        p.cognome_passeggero,
        p.codice_volo,
        v.compagnia_aerea,
        v.aeroporto_origine,
        v.aeroporto_destinazione,
        v.data_partenza,
        v.orario,
        v.ritardo,
        v.stato,
        g.numero_gate
    FROM prenotazione p
    JOIN volo v ON p.codice_volo = v.codice
    LEFT JOIN gate g ON v.codice = g.codice_volo
    WHERE p.username_prenotazione = p_nomeutente
    ORDER BY v.data_partenza, v.orario;
END;
$$;


--
-- TOC entry 260 (class 1255 OID 17208)
-- Name: modifica_prenotazione(character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.modifica_prenotazione(IN p_nomeutente character varying, IN p_password character varying, IN p_numero_biglietto character varying, IN p_nuovo_nome character varying, IN p_nuovo_cognome character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_username_prenotazione VARCHAR(20);
    v_codice_volo VARCHAR(10);
    v_stato_volo stato_volo;
BEGIN
    -- Verifica le credenziali dell'utente
    IF NOT verifica_utente(p_nomeutente, p_password) THEN
        RAISE EXCEPTION 'Credenziali non valide';
    END IF;

    -- Verifica se la prenotazione esiste e ottiene le informazioni necessarie
    SELECT 
        p.username_prenotazione,
        p.codice_volo,
        v.stato
    INTO 
        v_username_prenotazione,
        v_codice_volo,
        v_stato_volo
    FROM prenotazione p
    JOIN volo v ON p.codice_volo = v.codice
    WHERE p.numero_biglietto = p_numero_biglietto;

    -- Se la prenotazione non esiste
    IF v_username_prenotazione IS NULL THEN
        RAISE EXCEPTION 'Prenotazione con numero biglietto % non trovata', p_numero_biglietto;
    END IF;

    -- Verifica che l'utente sia il proprietario della prenotazione
    IF v_username_prenotazione != p_nomeutente THEN
        RAISE EXCEPTION 'Non hai i permessi per modificare questa prenotazione';
    END IF;

    -- Verifica che il volo non sia già partito o cancellato
    IF v_stato_volo IN ('DECOLLATO', 'ATTERRATO', 'CANCELLATO') THEN
        RAISE EXCEPTION 'Non è possibile modificare una prenotazione per un volo %', v_stato_volo;
    END IF;

    -- Verifica che non esista già una prenotazione per lo stesso passeggero sul volo
    IF EXISTS (
        SELECT 1 
        FROM prenotazione 
        WHERE codice_volo = v_codice_volo 
        AND nome_passeggero = p_nuovo_nome 
        AND cognome_passeggero = p_nuovo_cognome
        AND numero_biglietto != p_numero_biglietto
    ) THEN
        RAISE EXCEPTION 'Esiste già una prenotazione per % % su questo volo', p_nuovo_nome, p_nuovo_cognome;
    END IF;

    -- Aggiorna i dati del passeggero
    UPDATE prenotazione
    SET nome_passeggero = p_nuovo_nome,
        cognome_passeggero = p_nuovo_cognome
    WHERE numero_biglietto = p_numero_biglietto;

END;
$$;


--
-- TOC entry 244 (class 1255 OID 16874)
-- Name: verifica_admin(character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.verifica_admin(p_nomeutente character varying, p_password character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM account a
        JOIN amministratore am ON a.id = am.id
        WHERE a.nomeutente = p_nomeutente
        AND a.password = p_password
    );
END;
$$;


--
-- TOC entry 245 (class 1255 OID 16875)
-- Name: verifica_utente(character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.verifica_utente(p_nomeutente character varying, p_password character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM account a
        JOIN utente u ON a.id = u.id
        WHERE a.nomeutente = p_nomeutente
        AND a.password = p_password
    );
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 218 (class 1259 OID 16753)
-- Name: account; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account (
    id integer NOT NULL,
    nomeutente character varying(20) NOT NULL,
    password character varying(20) NOT NULL
);


--
-- TOC entry 217 (class 1259 OID 16752)
-- Name: account_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.account_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5003 (class 0 OID 0)
-- Dependencies: 217
-- Name: account_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.account_id_seq OWNED BY public.account.id;


--
-- TOC entry 220 (class 1259 OID 16771)
-- Name: amministratore; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.amministratore (
    id integer NOT NULL
);


--
-- TOC entry 223 (class 1259 OID 16817)
-- Name: gate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gate (
    numero_gate integer NOT NULL,
    codice_volo character varying(10) NOT NULL,
    CONSTRAINT check_positive_gate CHECK ((numero_gate > 0))
);


--
-- TOC entry 222 (class 1259 OID 16795)
-- Name: prenotazione; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.prenotazione (
    numero_biglietto character varying(20) NOT NULL,
    posto_assegnato character varying(4) NOT NULL,
    stato public.stato_prenotazione DEFAULT 'CONFERMATA'::public.stato_prenotazione,
    nome_passeggero character varying(20) NOT NULL,
    cognome_passeggero character varying(20) NOT NULL,
    codice_volo character varying(10),
    username_prenotazione character varying(20)
);


--
-- TOC entry 221 (class 1259 OID 16787)
-- Name: volo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.volo (
    codice character varying(10) NOT NULL,
    compagnia_aerea character varying(20) NOT NULL,
    aeroporto_origine character varying(20) NOT NULL,
    aeroporto_destinazione character varying(20) NOT NULL,
    data_partenza date NOT NULL,
    orario time without time zone NOT NULL,
    ritardo integer DEFAULT 0,
    stato public.stato_volo DEFAULT 'PROGRAMMATO'::public.stato_volo,
    tipo public.tipo_volo NOT NULL,
    CONSTRAINT volo_tipo_volo_check CHECK (((tipo)::text = ANY (ARRAY[('ARRIVO'::character varying)::text, ('PARTENZA'::character varying)::text])))
);


--
-- TOC entry 228 (class 1259 OID 17197)
-- Name: prenotazioni; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.prenotazioni AS
 SELECT p.numero_biglietto,
    p.posto_assegnato,
    p.stato AS stato_prenotazione,
    p.nome_passeggero,
    p.cognome_passeggero,
    p.codice_volo,
    p.username_prenotazione,
    v.compagnia_aerea,
    v.aeroporto_origine,
    v.aeroporto_destinazione,
    v.data_partenza,
    v.orario,
    v.ritardo,
    v.stato AS stato_volo,
    v.tipo
   FROM ((public.prenotazione p
     JOIN public.volo v ON (((p.codice_volo)::text = (v.codice)::text)))
     JOIN public.account a ON (((p.username_prenotazione)::text = (a.nomeutente)::text)));


--
-- TOC entry 225 (class 1259 OID 16892)
-- Name: tutti_admin; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.tutti_admin AS
 SELECT a.nomeutente,
    a.password
   FROM (public.account a
     JOIN public.amministratore am ON ((a.id = am.id)))
  ORDER BY a.nomeutente;


--
-- TOC entry 219 (class 1259 OID 16761)
-- Name: utente; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.utente (
    id integer NOT NULL,
    nome character varying(20) NOT NULL,
    cognome character varying(20) NOT NULL
);


--
-- TOC entry 224 (class 1259 OID 16888)
-- Name: tutti_utenti; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.tutti_utenti AS
 SELECT a.nomeutente,
    a.password,
    u.nome,
    u.cognome
   FROM (public.account a
     JOIN public.utente u ON ((a.id = u.id)))
  ORDER BY u.cognome, u.nome;


--
-- TOC entry 229 (class 1259 OID 17202)
-- Name: tutti_voli; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.tutti_voli AS
 SELECT v.codice,
    v.compagnia_aerea,
    v.aeroporto_origine,
    v.aeroporto_destinazione,
    v.data_partenza,
    v.orario,
    v.ritardo,
    v.stato,
    v.tipo,
    g.numero_gate
   FROM (public.volo v
     LEFT JOIN public.gate g ON (((v.codice)::text = (g.codice_volo)::text)))
  ORDER BY v.data_partenza, v.orario;


--
-- TOC entry 227 (class 1259 OID 17193)
-- Name: voli_in_arrivo; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.voli_in_arrivo AS
 SELECT codice,
    compagnia_aerea,
    aeroporto_origine,
    aeroporto_destinazione,
    data_partenza,
    orario,
    ritardo,
    stato,
    tipo
   FROM public.volo
  WHERE ((tipo = 'ARRIVO'::public.tipo_volo) AND ((aeroporto_destinazione)::text = 'Napoli'::text));


--
-- TOC entry 226 (class 1259 OID 17188)
-- Name: voli_in_partenza; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.voli_in_partenza AS
 SELECT v.codice,
    v.compagnia_aerea,
    v.aeroporto_origine,
    v.aeroporto_destinazione,
    v.data_partenza,
    v.orario,
    v.ritardo,
    v.stato,
    v.tipo,
    g.numero_gate
   FROM (public.volo v
     LEFT JOIN public.gate g ON (((v.codice)::text = (g.codice_volo)::text)))
  WHERE ((v.tipo = 'PARTENZA'::public.tipo_volo) AND ((v.aeroporto_origine)::text = 'Napoli'::text));


--
-- TOC entry 4815 (class 2604 OID 16756)
-- Name: account id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account ALTER COLUMN id SET DEFAULT nextval('public.account_id_seq'::regclass);


--
-- TOC entry 4822 (class 2606 OID 16760)
-- Name: account account_nomeutente_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_nomeutente_key UNIQUE (nomeutente);


--
-- TOC entry 4824 (class 2606 OID 16758)
-- Name: account account_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_pkey PRIMARY KEY (id);


--
-- TOC entry 4828 (class 2606 OID 16775)
-- Name: amministratore amministratore_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.amministratore
    ADD CONSTRAINT amministratore_pkey PRIMARY KEY (id);


--
-- TOC entry 4838 (class 2606 OID 16822)
-- Name: gate gate_codice_volo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gate
    ADD CONSTRAINT gate_codice_volo_key UNIQUE (codice_volo);


--
-- TOC entry 4840 (class 2606 OID 16882)
-- Name: gate gate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gate
    ADD CONSTRAINT gate_pkey PRIMARY KEY (numero_gate, codice_volo);


--
-- TOC entry 4832 (class 2606 OID 16800)
-- Name: prenotazione prenotazione_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prenotazione
    ADD CONSTRAINT prenotazione_pkey PRIMARY KEY (numero_biglietto);


--
-- TOC entry 4834 (class 2606 OID 16834)
-- Name: prenotazione unique_passeggero_volo; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prenotazione
    ADD CONSTRAINT unique_passeggero_volo UNIQUE (nome_passeggero, cognome_passeggero, codice_volo);


--
-- TOC entry 4836 (class 2606 OID 16836)
-- Name: prenotazione unique_posto_volo; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prenotazione
    ADD CONSTRAINT unique_posto_volo UNIQUE (posto_assegnato, codice_volo);


--
-- TOC entry 4826 (class 2606 OID 16765)
-- Name: utente utente_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.utente
    ADD CONSTRAINT utente_pkey PRIMARY KEY (id);


--
-- TOC entry 4830 (class 2606 OID 16794)
-- Name: volo volo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.volo
    ADD CONSTRAINT volo_pkey PRIMARY KEY (codice);


--
-- TOC entry 4846 (class 2620 OID 16829)
-- Name: gate gate_volo_partenza_check; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER gate_volo_partenza_check BEFORE INSERT OR UPDATE ON public.gate FOR EACH ROW EXECUTE FUNCTION public.check_volo_partenza_trigger();


--
-- TOC entry 4842 (class 2606 OID 16776)
-- Name: amministratore amministratore_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.amministratore
    ADD CONSTRAINT amministratore_id_fkey FOREIGN KEY (id) REFERENCES public.account(id);


--
-- TOC entry 4845 (class 2606 OID 16823)
-- Name: gate gate_codice_volo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gate
    ADD CONSTRAINT gate_codice_volo_fkey FOREIGN KEY (codice_volo) REFERENCES public.volo(codice);


--
-- TOC entry 4843 (class 2606 OID 16801)
-- Name: prenotazione prenotazione_codice_volo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prenotazione
    ADD CONSTRAINT prenotazione_codice_volo_fkey FOREIGN KEY (codice_volo) REFERENCES public.volo(codice);


--
-- TOC entry 4844 (class 2606 OID 16806)
-- Name: prenotazione prenotazione_username_prenotazione_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prenotazione
    ADD CONSTRAINT prenotazione_username_prenotazione_fkey FOREIGN KEY (username_prenotazione) REFERENCES public.account(nomeutente);


--
-- TOC entry 4841 (class 2606 OID 16766)
-- Name: utente utente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.utente
    ADD CONSTRAINT utente_id_fkey FOREIGN KEY (id) REFERENCES public.account(id);


-- Completed on 2025-07-16 23:10:14

--
-- PostgreSQL database dump complete
--

