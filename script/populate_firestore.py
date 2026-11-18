#!/usr/bin/env python3
"""Wipe (everything except `facilities`) and repopulate the CampusArena Firestore
with data covering every terminal state the app can render.

Centered on three real accounts:
  DbEaSiUX8bWxChZPMJhZwMHyCyH3  -> Christian Prend  (@prend)
  bd7AhtjP03ebvSNdC4YxhXEPYKN2  -> Mirko Pica       (@m1rk0)
  QvL36MnJrKfixRviqgWj3X6FcyN2  -> abd             (@abd)

Facility documents are seeded from the real, hand-verified campus data pulled
from production (FACILITIES below): coordinates, QR codes, fallbackCodes and
`isOutdoor` flags are authoritative — do not invent values. The docs are
overwritten each run; their `queue` subcollections are cleared on wipe. The
facility docs themselves are never deleted (only overwritten), so their stable
IDs keep every match/tournament FK valid.

Facility statuses are mixed so the map and both flagship Assistant queries show
variety. Exactly two tables are busy; every other table stays `free` (so the
"what tables are empty?" query returns a rich list):
  * one `occupied` table — the facility hosting the active tournament's live
    semifinal (currentMatchId -> that `occupied` match). It reads busy because a
    tournament match is in progress, so the walk-up play demo simply avoids it.
  * one `queued` table — a walk-up `occupied` match between two synthetic
    players with a two-person waiting queue behind it (currentMatchId + a `queue`
    subcollection + queueTailPosition), demonstrating the queued state without
    involving any real account.

Every other seeded match is terminal (confirmed / disputed / unconfirmed /
abandoned). Un-played tournament bracket slots carry no match doc and are
derived from participants by the bracket engine.

Ground truth: brain/firestore_schema.md and app/lib/core/constants.dart. Field
keys/defaults mirror the six models in app/lib/models/ exactly.

Usage (from script/):
    python populate_firestore.py            # wipe + repopulate
    python populate_firestore.py --verify   # print per-collection / per-state counts
"""

from __future__ import annotations

import os
import sys
from datetime import datetime, timedelta, timezone

import firebase_admin
from firebase_admin import credentials, firestore

# --------------------------------------------------------------------------- #
# Constants — mirror app/lib/core/constants.dart                              #
# --------------------------------------------------------------------------- #

HERE = os.path.dirname(os.path.abspath(__file__))
KEY_PATH = os.path.join(HERE, "campus-arena-app-firebase-adminsdk-fbsvc-39490391ad.json")

# FirestoreCollections
C_USERS = "users"
C_USERNAMES = "usernames"
C_RATINGS = "ratings"
C_FACILITIES = "facilities"
C_MATCHES = "matches"
C_TOURNAMENTS = "tournaments"
C_CHALLENGES = "challenges"
C_ACHIEVEMENT_DEFS = "achievementDefs"
SUB_PARTICIPANTS = "participants"
SUB_QUEUE = "queue"

# Everything we own and rebuild. NOTE: facilities deliberately excluded.
OWNED_COLLECTIONS = [
    C_USERS,
    C_USERNAMES,
    C_RATINGS,
    C_MATCHES,
    C_TOURNAMENTS,
    C_CHALLENGES,
    C_ACHIEVEMENT_DEFS,
]

# SportIds
PING_PONG = "ping_pong"
FOOSBALL = "foosball"

# MatchStates
S_OCCUPIED = "occupied"
S_AWAITING = "awaitingConfirmation"
S_CONFIRMED = "confirmed"
S_DISPUTED = "disputed"
S_UNCONFIRMED = "unconfirmed"
S_ABANDONED = "abandoned"

# FacilityStatus (app/lib/core/constants.dart)
FS_FREE = "free"
FS_OCCUPIED = "occupied"
FS_QUEUED = "queued"

# TournamentStatus
T_REGISTERING = "registering"
T_SEEDED = "seeded"
T_ACTIVE = "active"
T_COMPLETED = "completed"
T_CANCELLED = "cancelled"

# ChallengeStatus
CH_PENDING = "pending"
CH_ACCEPTED = "accepted"
CH_DECLINED = "declined"
CH_EXPIRED = "expired"

# OwnerType
OWNER_USER = "user"
OWNER_PAIR = "pair"

# EliminationReason
ELIM_FORFEIT = "forfeit"
ELIM_ADVANCED = "advanced"

INITIAL_ELO = 1200

DEGREE_CS = "Computer Science and Engineering"
DEGREE_BIO = "Biomedical Engineering"

# Spread of kDegreePrograms (app/lib/core/degree_programs.dart) for filler users.
DEGREES = [
    DEGREE_CS,
    DEGREE_BIO,
    "Mechanical Engineering",
    "Management Engineering",
    "Electronic Engineering",
    "Mathematical Engineering",
    "Design",
    "Aerospace Engineering",
    "Energy Engineering",
]

# The three real accounts (identities are authoritative — given by the user).
UID_CHRISTIAN = "DbEaSiUX8bWxChZPMJhZwMHyCyH3"
UID_MIRKO = "bd7AhtjP03ebvSNdC4YxhXEPYKN2"
UID_ABD = "QvL36MnJrKfixRviqgWj3X6FcyN2"

REAL_USERS = {
    UID_CHRISTIAN: {
        "name": "Christian Prend",
        "username": "prend",
        "email": "ch@pr.it",
        "degreeProgram": DEGREE_CS,
    },
    UID_MIRKO: {
        "name": "Mirko Pica",
        "username": "m1rk0",
        "email": "gas@gas.it",
        "degreeProgram": DEGREE_CS,
    },
    UID_ABD: {
        "name": "abd",
        "username": "abd",
        "email": "boodysaeed10@gmail.com",
        "degreeProgram": DEGREE_BIO,
    },
}

# Real campus facilities — hand-verified data pulled from production. Every value
# is authoritative (coordinates / fallbackCode); all current tables are outdoor.
# The app's map pin, weather card, QR scanner and manual-entry code all read
# these. qrCode always follows campusarena://play/facility/{id}.
# Tuple: (id, name, sportId, lat, lng, fallbackCode)
FACILITIES = [
    ("bov_durando_fb_1", "Foosball — Bovisa Durando", FOOSBALL, 45.5045, 9.1591, "BOV-FB-2"),
    ("bov_durando_pp_1", "Ping Pong — Bovisa Durando", PING_PONG, 45.5045, 9.159, "BOV-PP-2"),
    ("bov_lamasa_fb_1", "Foosball 1 — Bovisa La Masa", FOOSBALL, 45.5033, 9.1562, "BOV-FB-1"),
    ("bov_lamasa_pp_1", "Ping Pong 1 — Bovisa La Masa", PING_PONG, 45.5033, 9.1561, "BOV-PP-1"),
    ("leo_gardella_fb_1", "Foosball 1 — Terrazza Gardella (Leonardo)", FOOSBALL, 45.478680, 9.228088, "LEO-FB-1"),
    ("leo_gardella_pp_1", "Ping Pong 1 — Terrazza Gardella (Leonardo)", PING_PONG, 45.478746, 9.227974, "LEO-PP-1"),
    ("leo_gardella_pp_2", "Ping Pong 2 — Terrazza Gardella (Leonardo)", PING_PONG, 45.478746, 9.228091, "LEO-PP-2"),
    ("leo_gardella_fb_2", "Foosball 2 — Terrazza Gardella (Leonardo)", FOOSBALL, 45.478597, 9.228005, "LEO-FB-2"),
    ("leo_smerlo_pp_1", "Ping Pong — Parchetto Smerlo (Leonardo)", PING_PONG, 45.478742, 9.230304, "LEO-PP-3"),
]

# The one deliberately `queued` table (see module docstring). The `occupied`
# table is derived at seed time as fac_fb (the active tournament's facility).
FAC_QUEUED = "leo_gardella_pp_2"

NOW = datetime.now(timezone.utc)


def days_ago(n: float) -> datetime:
    return NOW - timedelta(days=n)


def days_from_now(n: float) -> datetime:
    return NOW + timedelta(days=n)


# --------------------------------------------------------------------------- #
# ID helpers — match the app's deterministic-ID conventions                   #
# --------------------------------------------------------------------------- #

def rating_id(sport_id: str, owner_id: str) -> str:
    return f"{sport_id}_{owner_id}"


def pair_id(uids) -> str:
    return "_".join(sorted(uids))


# --------------------------------------------------------------------------- #
# Batched writer — auto-flushes below Firestore's 500-op batch cap            #
# --------------------------------------------------------------------------- #

class BatchWriter:
    def __init__(self, db, cap: int = 400):
        self.db = db
        self.cap = cap
        self.batch = db.batch()
        self.count = 0
        self.total = 0

    def set(self, ref, data):
        self.batch.set(ref, data)
        self._tick()

    def update(self, ref, data):
        self.batch.update(ref, data)
        self._tick()

    def delete(self, ref):
        self.batch.delete(ref)
        self._tick()

    def _tick(self):
        self.count += 1
        self.total += 1
        if self.count >= self.cap:
            self.flush()

    def flush(self):
        if self.count:
            self.batch.commit()
            self.batch = self.db.batch()
            self.count = 0


# --------------------------------------------------------------------------- #
# Wipe                                                                         #
# --------------------------------------------------------------------------- #

def delete_collection(db, ref, page: int = 300) -> int:
    """Delete every doc in a (sub)collection, paginated. Returns count."""
    deleted = 0
    while True:
        docs = list(ref.limit(page).stream())
        if not docs:
            break
        batch = db.batch()
        for d in docs:
            batch.delete(d.reference)
        batch.commit()
        deleted += len(docs)
    return deleted


def wipe(db) -> None:
    print("Wiping owned collections (facility docs overwritten, not deleted)...")
    # Tournaments first: clear each participants subcollection, then the doc.
    for tdoc in db.collection(C_TOURNAMENTS).stream():
        delete_collection(db, tdoc.reference.collection(SUB_PARTICIPANTS))
    for col in OWNED_COLLECTIONS:
        n = delete_collection(db, db.collection(col))
        print(f"  {col}: deleted {n}")
    # Facility docs are overwritten (not deleted, to keep stable FK IDs), but
    # their queue subcollections must be cleared so a re-run doesn't accumulate
    # stale queued players on the `queued` demo table.
    for fdoc in db.collection(C_FACILITIES).stream():
        delete_collection(db, fdoc.reference.collection(SUB_QUEUE))


# --------------------------------------------------------------------------- #
# Facilities — pick one per sport for match/tournament FK references           #
# --------------------------------------------------------------------------- #

def facility_for(sport_id: str) -> str:
    """First seeded facility id for the sport (deterministic FK anchor)."""
    return next(f[0] for f in FACILITIES if f[2] == sport_id)


# --------------------------------------------------------------------------- #
# Builders                                                                     #
# --------------------------------------------------------------------------- #

def user_doc(name, username, email, degree, *, language="en",
             friend_uids=None, badges=None, onboarding=True, dispute_count=0,
             dispute_penalty_until=None, created_at=None):
    return {
        "name": name,
        "username": username,
        "email": email,
        "degreeProgram": degree,
        "language": language,
        "pushTokens": [],
        "friendUids": friend_uids or [],
        "badges": {k: v for k, v in (badges or {}).items()},
        "onboardingComplete": onboarding,
        "disputeCount": dispute_count,
        "disputePenaltyUntil": dispute_penalty_until,
        "createdAt": created_at or days_ago(120),
    }


def rating_doc(owner_type, owner_id, sport_id, elo, matches_played, last_match_at,
               *, degree=None, member_uids=None):
    return {
        "ownerType": owner_type,
        "ownerId": owner_id,
        "memberUids": member_uids,
        "sportId": sport_id,
        "degreeProgram": degree,
        "elo": elo,
        "matchesPlayed": matches_played,
        "lastMatchAt": last_match_at,
    }


def ping_pong_result(winner_ids, sets, opp_sets):
    return {"winnerIds": winner_ids, "score": {"sets": sets, "opponentSets": opp_sets}}


def foosball_result(winner_ids, goals, opp_goals):
    return {"winnerIds": winner_ids, "score": {"goals": goals, "opponentGoals": opp_goals}}


def match_doc(facility_id, sport_id, mode, player_uids, state, *, started_at,
              team1=None, team2=None, submitted_by=None, result=None,
              elo_before=None, elo_deltas=None, tournament_id=None,
              tournament_round=None, gps=None, confirmed_at=None):
    return {
        "facilityId": facility_id,
        "sportId": sport_id,
        "mode": mode,
        "playerUids": player_uids,
        "team1PairId": team1,
        "team2PairId": team2,
        "state": state,
        "submittedByUid": submitted_by,
        "result": result,
        "eloBefore": elo_before,
        "eloDeltas": elo_deltas,
        "tournamentId": tournament_id,
        "tournamentRound": tournament_round,
        "gpsDistanceMeters": gps,
        "startedAt": started_at,
        "confirmedAt": confirmed_at,
    }


def tournament_doc(name, sport_id, facility_id, organizer_id, status, *,
                   max_participants=8, participant_count=0, bracket=None,
                   winner_uid=None, elo_multiplier=1.5, registration_deadline=None,
                   scheduled_at=None, created_at=None):
    return {
        "name": name,
        "sportId": sport_id,
        "facilityId": facility_id,
        "organizerId": organizer_id,
        "maxParticipants": max_participants,
        "participantCount": participant_count,
        "status": status,
        "bracket": bracket or {},
        "winnerUid": winner_uid,
        "eloMultiplier": elo_multiplier,
        "registrationDeadline": registration_deadline or days_from_now(2),
        "scheduledAt": scheduled_at or days_from_now(3),
        "createdAt": created_at or days_ago(10),
    }


def participant_doc(seed, eliminated, *, elimination_reason=None):
    d = {"seed": seed, "eliminated": eliminated}
    if elimination_reason is not None:
        d["eliminationReason"] = elimination_reason
    return d


def challenge_doc(from_uid, to_uid, sport_id, status, *, created_at,
                  match_id=None, responded_at=None):
    return {
        "fromUserId": from_uid,
        "toUserId": to_uid,
        "sportId": sport_id,
        "status": status,
        "matchId": match_id,
        "createdAt": created_at,
        "respondedAt": responded_at,
    }


def facility_doc(fac_id, name, sport_id, lat, lng, fallback, *,
                 status=FS_FREE, current_match_id=None, queue_tail=0):
    return {
        "name": name,
        "sportId": sport_id,
        "coordinates": firestore.GeoPoint(lat, lng),
        "qrCode": f"campusarena://play/facility/{fac_id}",
        "fallbackCode": fallback,
        "isOutdoor": True,
        "status": status,
        "currentMatchId": current_match_id,
        "kingOfTableUid": None,
        "kingOfTableWins": 0,
        "queueTailPosition": queue_tail,
        "freedAt": None,
    }


def queue_entry_doc(uid, position, joined_at):
    # Mirrors QueueEntryModel.toMap: uid -> userId, plus position + joinedAt.
    return {"userId": uid, "position": position, "joinedAt": joined_at}


# --------------------------------------------------------------------------- #
# Seed                                                                         #
# --------------------------------------------------------------------------- #

def seed(db) -> None:
    fac_pp = facility_for(PING_PONG)
    fac_fb = facility_for(FOOSBALL)

    w = BatchWriter(db)

    # --- achievementDefs (canonical 6) ------------------------------------- #
    defs = [
        ("first_victory", "first_victory", None),
        ("streak_5", "win_streak", 5),
        ("giant_slayer", "giant_slayer", 200),
        ("explorer", "explorer", None),
        ("tournament_champion", "tournament_champion", None),
        ("workaholic", "monthly_count", 15),
    ]
    for ach_id, condition, threshold in defs:
        w.set(db.collection(C_ACHIEVEMENT_DEFS).document(ach_id), {
            "nameKey": f"achievement_{ach_id}_name",
            "descriptionKey": f"achievement_{ach_id}_desc",
            "iconAsset": f"assets/badges/{ach_id}.png",
            "condition": condition,
            "threshold": threshold,
        })

    # --- synthetic users u01..u25 ------------------------------------------ #
    synth_uids: list[str] = []
    for i in range(1, 26):
        uid = f"u{i:02d}"
        synth_uids.append(uid)
        degree = DEGREES[i % len(DEGREES)]
        language = "it" if i % 3 == 0 else "en"

        dispute_count = 0
        dispute_until = None
        if i == 7:  # near-penalty
            dispute_count = 2
        elif i == 8:  # actively penalized
            dispute_until = days_from_now(5)
        elif i == 9:  # expired penalty
            dispute_until = days_ago(3)

        w.set(db.collection(C_USERS).document(uid), user_doc(
            name=f"Player {i:02d}",
            username=f"player{i:02d}",
            email=f"player{i:02d}@campus.test",
            degree=degree,
            language=language,
            friend_uids=[],  # finalized below
            dispute_count=dispute_count,
            dispute_penalty_until=dispute_until,
            created_at=days_ago(150 - i * 4),
        ))
        w.set(db.collection(C_USERNAMES).document(f"player{i:02d}"), {"uid": uid})

    # A friend graph among synthetic users (chain + a hub).
    synth_friends: dict[str, set] = {u: set() for u in synth_uids}
    for a, b in zip(synth_uids, synth_uids[1:]):
        synth_friends[a].add(b)
        synth_friends[b].add(a)
    hub = synth_uids[0]
    for u in synth_uids[1:6]:
        synth_friends[hub].add(u)
        synth_friends[u].add(hub)

    # --- ELO ladder for synthetic users ------------------------------------ #
    # Spread 900..1950 so leaderboards and course-rivalry populate.
    for idx, uid in enumerate(synth_uids):
        degree = DEGREES[(idx + 1) % len(DEGREES)]
        base = 900 + idx * 42  # 900..1908
        # ping_pong for all
        mp = 0 if idx == 24 else (5 if idx % 2 else 18)
        last = days_ago(90) if idx == 23 else days_ago(idx % 14)
        elo = INITIAL_ELO if idx == 24 else base
        w.set(
            db.collection(C_RATINGS).document(rating_id(PING_PONG, uid)),
            rating_doc(OWNER_USER, uid, PING_PONG, elo, mp, last, degree=degree),
        )
        # foosball for all
        w.set(
            db.collection(C_RATINGS).document(rating_id(FOOSBALL, uid)),
            rating_doc(OWNER_USER, uid, FOOSBALL, 1000 + (idx * 30) % 900,
                       (idx % 12) + 1, days_ago((idx * 2) % 20), degree=degree),
        )

    # --- real users' ratings (finalized friend/badges written at the end) -- #
    # Christian: veteran ping_pong (K=16, high elo), fresh-ish foosball.
    w.set(db.collection(C_RATINGS).document(rating_id(PING_PONG, UID_CHRISTIAN)),
          rating_doc(OWNER_USER, UID_CHRISTIAN, PING_PONG, 1720, 24, days_ago(1),
                     degree=DEGREE_CS))
    w.set(db.collection(C_RATINGS).document(rating_id(FOOSBALL, UID_CHRISTIAN)),
          rating_doc(OWNER_USER, UID_CHRISTIAN, FOOSBALL, 1180, 6, days_ago(4),
                     degree=DEGREE_CS))
    # Mirko: strong foosball, mid ping_pong.
    w.set(db.collection(C_RATINGS).document(rating_id(PING_PONG, UID_MIRKO)),
          rating_doc(OWNER_USER, UID_MIRKO, PING_PONG, 1480, 15, days_ago(2),
                     degree=DEGREE_CS))
    w.set(db.collection(C_RATINGS).document(rating_id(FOOSBALL, UID_MIRKO)),
          rating_doc(OWNER_USER, UID_MIRKO, FOOSBALL, 1610, 21, days_ago(1),
                     degree=DEGREE_CS))
    # abd: Biomedical, mid ping_pong, decent foosball.
    w.set(db.collection(C_RATINGS).document(rating_id(PING_PONG, UID_ABD)),
          rating_doc(OWNER_USER, UID_ABD, PING_PONG, 1355, 13, days_ago(3),
                     degree=DEGREE_BIO))
    w.set(db.collection(C_RATINGS).document(rating_id(FOOSBALL, UID_ABD)),
          rating_doc(OWNER_USER, UID_ABD, FOOSBALL, 1290, 9, days_ago(1),
                     degree=DEGREE_BIO))

    # --- pair ratings (doubles) -------------------------------------------- #
    # cm is the flagship real+real team; rated across every sport so their team
    # profile shows a full per-sport spread and they anchor each doubles board.
    cm = [UID_CHRISTIAN, UID_MIRKO]
    pairs = [
        (cm, FOOSBALL, 1490, 9),                               # real + real
        (cm, PING_PONG, 1445, 7),                              # real + real
        # Each real user's alternate team (paired with a synthetic partner).
        ([UID_CHRISTIAN, synth_uids[0]], FOOSBALL, 1420, 8),   # Christian + synth
        ([UID_CHRISTIAN, synth_uids[2]], PING_PONG, 1330, 4),  # Christian + synth
        ([UID_MIRKO, synth_uids[1]], PING_PONG, 1360, 6),      # Mirko + synth
        ([UID_MIRKO, synth_uids[3]], FOOSBALL, 1400, 5),       # Mirko + synth
        # Opponent + filler synthetic pairs so each doubles board has depth.
        ([synth_uids[10], synth_uids[11]], FOOSBALL, 1350, 7),
        ([synth_uids[12], synth_uids[13]], PING_PONG, 1300, 6),
        ([synth_uids[6], synth_uids[7]], FOOSBALL, 1290, 5),
        # abd's teams: a steady synth partner across both sports, plus one
        # real+real team with each of the other two accounts.
        ([UID_ABD, synth_uids[16]], FOOSBALL, 1380, 8),        # abd + synth
        ([UID_ABD, synth_uids[16]], PING_PONG, 1350, 6),       # abd + synth
        ([UID_ABD, UID_CHRISTIAN], PING_PONG, 1400, 5),        # abd + real
        ([UID_ABD, UID_MIRKO], FOOSBALL, 1430, 6),             # abd + real
        ([synth_uids[14], synth_uids[15]], FOOSBALL, 1280, 5), # abd's opponents
        ([synth_uids[17], synth_uids[10]], PING_PONG, 1270, 5),
    ]
    for members, sport, elo, mp in pairs:
        pid = pair_id(members)
        w.set(db.collection(C_RATINGS).document(rating_id(sport, pid)),
              rating_doc(OWNER_PAIR, pid, sport, elo, mp, days_ago(mp),
                         member_uids=sorted(members)))

    # --- matches: every state x mode x sport ------------------------------- #
    match_ids: dict[str, str] = {}  # label -> id

    def add_match(label, doc):
        ref = db.collection(C_MATCHES).document()
        match_ids[label] = ref.id
        w.set(ref, doc)
        return ref.id

    o1, o2, o3 = synth_uids[10], synth_uids[11], synth_uids[12]

    # singles ping_pong — confirmed, Mirko wins (giant-slayer: beats higher elo)
    add_match("pp_confirmed_giantslayer", match_doc(
        fac_pp, PING_PONG, "singles", [UID_MIRKO, o1], S_CONFIRMED,
        started_at=days_ago(3), submitted_by=UID_MIRKO,
        result=ping_pong_result([UID_MIRKO], [11, 11], [8, 9]),
        elo_before={UID_MIRKO: 1450, o1: 1690},
        elo_deltas={UID_MIRKO: 30, o1: -30},
        gps=4.2, confirmed_at=days_ago(3)))

    # singles ping_pong — Christian win streak (3 confirmed wins), all vs o1 so
    # o1 also becomes his Favorite Victim (3 wins clears kFunStatMinMatchups=3).
    for k in range(3):
        add_match(f"pp_streak_{k}", match_doc(
            fac_pp, PING_PONG, "singles", [UID_CHRISTIAN, o1], S_CONFIRMED,
            started_at=days_ago(9 - k), submitted_by=UID_CHRISTIAN,
            result=ping_pong_result([UID_CHRISTIAN], [11, 7, 11], [6, 11, 8]),
            elo_before={UID_CHRISTIAN: 1680 + k * 12, o1: 1500},
            elo_deltas={UID_CHRISTIAN: 12, o1: -12},
            gps=6.1, confirmed_at=days_ago(9 - k)))

    # singles ping_pong — Christian's Black Beast: two older losses vs o2 which,
    # with pp_confirmed_loss below, give o2 three losses (clears the fun-stat
    # gate). Placed oldest so the 3-win run above stays the best streak.
    for k in range(2):
        add_match(f"pp_blackbeast_{k}", match_doc(
            fac_pp, PING_PONG, "singles", [UID_CHRISTIAN, o2], S_CONFIRMED,
            started_at=days_ago(12 - k), submitted_by=o2,
            result=ping_pong_result([o2], [11, 11], [7, 9]),
            elo_before={UID_CHRISTIAN: 1660 - k * 8, o2: 1600},
            elo_deltas={UID_CHRISTIAN: -13, o2: 13},
            gps=None, confirmed_at=days_ago(12 - k)))

    # singles ping_pong — Christian loss (confirmed), third loss vs o2.
    add_match("pp_confirmed_loss", match_doc(
        fac_pp, PING_PONG, "singles", [UID_CHRISTIAN, o2], S_CONFIRMED,
        started_at=days_ago(2), submitted_by=o2,
        result=ping_pong_result([o2], [11, 11], [7, 9]),
        elo_before={UID_CHRISTIAN: 1732, o2: 1600},
        elo_deltas={UID_CHRISTIAN: -14, o2: 14},
        gps=None, confirmed_at=days_ago(2)))

    # singles foosball — disputed
    add_match("fb_disputed", match_doc(
        fac_fb, FOOSBALL, "singles", [UID_MIRKO, o1], S_DISPUTED,
        started_at=days_ago(1), submitted_by=o1,
        result=foosball_result([o1], 10, 8), gps=5.5))

    # singles foosball — confirmed, Mirko wins
    add_match("fb_confirmed", match_doc(
        fac_fb, FOOSBALL, "singles", [UID_MIRKO, o2], S_CONFIRMED,
        started_at=days_ago(5), submitted_by=UID_MIRKO,
        result=foosball_result([UID_MIRKO], 10, 6),
        elo_before={UID_MIRKO: 1590, o2: 1520},
        elo_deltas={UID_MIRKO: 16, o2: -16},
        gps=2.1, confirmed_at=days_ago(5)))

    # singles ping_pong — unconfirmed (timed out awaiting)
    add_match("pp_unconfirmed", match_doc(
        fac_pp, PING_PONG, "singles", [UID_CHRISTIAN, o3], S_UNCONFIRMED,
        started_at=days_ago(4), submitted_by=UID_CHRISTIAN,
        result=ping_pong_result([UID_CHRISTIAN], [11, 11], [5, 7])))

    # singles foosball — abandoned (never submitted)
    add_match("fb_abandoned", match_doc(
        fac_fb, FOOSBALL, "singles", [o1, o2], S_ABANDONED,
        started_at=days_ago(6)))

    # --- doubles matches, centred on the Christian+Mirko pair ------------- #
    # Their team profile (per-sport stats + history) and every doubles board
    # read these; the pair plays across all three sports with wins, losses and
    # in-flight states so nothing renders empty. Opponent pairs reuse the synth
    # teams that carry their own pair ratings above.
    cm_pair = pair_id(cm)                      # Christian + Mirko
    opp_fb = [synth_uids[10], synth_uids[11]]  # rated foosball pair
    opp_pp = [synth_uids[12], synth_uids[13]]  # rated ping_pong pair

    def doubles(label, facility, sport, result_fn, opp, state, *, cm_wins,
                started_at, submitted_by, elo_before=None, elo_deltas=None,
                gps=None, confirmed_at=None):
        """A doubles match with cm on team 1 and [opp] on team 2."""
        winners = cm if cm_wins else opp
        return add_match(label, match_doc(
            facility, sport, "doubles", cm + opp, state,
            team1=cm_pair, team2=pair_id(opp),
            started_at=started_at, submitted_by=submitted_by,
            result=result_fn(winners),
            elo_before=elo_before, elo_deltas=elo_deltas,
            gps=gps, confirmed_at=confirmed_at))

    # foosball — confirmed win
    doubles("fb_doubles_confirmed", fac_fb, FOOSBALL,
            lambda w: foosball_result(w, 10, 4), opp_fb, S_CONFIRMED,
            cm_wins=True, started_at=days_ago(7), submitted_by=UID_CHRISTIAN,
            elo_before={cm_pair: 1472, pair_id(opp_fb): 1368},
            elo_deltas={cm_pair: 18, pair_id(opp_fb): -18},
            gps=3.3, confirmed_at=days_ago(7))

    # foosball — confirmed loss
    doubles("fb_doubles_loss", fac_fb, FOOSBALL,
            lambda w: foosball_result(w, 10, 7), opp_fb, S_CONFIRMED,
            cm_wins=False, started_at=days_ago(14), submitted_by=synth_uids[10],
            elo_before={cm_pair: 1486, pair_id(opp_fb): 1354},
            elo_deltas={cm_pair: -14, pair_id(opp_fb): 14},
            gps=5.0, confirmed_at=days_ago(14))

    # ping_pong — confirmed win
    doubles("pp_doubles_confirmed", fac_pp, PING_PONG,
            lambda w: ping_pong_result(w, [11, 9, 11], [7, 11, 6]), opp_pp,
            S_CONFIRMED, cm_wins=True, started_at=days_ago(5),
            submitted_by=UID_MIRKO,
            elo_before={cm_pair: 1427, pair_id(opp_pp): 1318},
            elo_deltas={cm_pair: 18, pair_id(opp_pp): -18},
            gps=2.4, confirmed_at=days_ago(5))

    # ping_pong — disputed (opponent submitted a contested result)
    doubles("pp_doubles_disputed", fac_pp, PING_PONG,
            lambda w: ping_pong_result(w, [11, 11], [8, 9]), opp_pp,
            S_DISPUTED, cm_wins=False, started_at=days_ago(1),
            submitted_by=synth_uids[12], gps=6.5)

    # --- doubles for each real user's alternate (real+synth) team --------- #
    # foosball — confirmed win (Christian + synth partner)
    team_e = [UID_CHRISTIAN, synth_uids[0]]
    team_f = [synth_uids[6], synth_uids[7]]
    add_match("fb_doubles_christian_confirmed", match_doc(
        fac_fb, FOOSBALL, "doubles", team_e + team_f, S_CONFIRMED,
        team1=pair_id(team_e), team2=pair_id(team_f),
        started_at=days_ago(8), submitted_by=UID_CHRISTIAN,
        result=foosball_result([UID_CHRISTIAN, synth_uids[0]], 10, 8),
        elo_before={pair_id(team_e): 1406, pair_id(team_f): 1304},
        elo_deltas={pair_id(team_e): 14, pair_id(team_f): -14},
        gps=4.1, confirmed_at=days_ago(8)))

    # --- abd: full spread of states x mode x sport ------------------------- #
    # Every match state for the third real account, plus fun-stat gates
    # (favorite victim / black beast clear kFunStatMinMatchups=3) so nothing on
    # his profile renders empty.
    av = synth_uids[14]              # abd's favorite victim (3 wins)
    ab = synth_uids[15]              # abd's black beast (3 losses)
    ax, ay = synth_uids[16], synth_uids[17]

    # singles ping_pong — confirmed giant-slayer win (beats +235 elo)
    add_match("abd_pp_giantslayer", match_doc(
        fac_pp, PING_PONG, "singles", [UID_ABD, ax], S_CONFIRMED,
        started_at=days_ago(3), submitted_by=UID_ABD,
        result=ping_pong_result([UID_ABD], [11, 11], [7, 9]),
        elo_before={UID_ABD: 1310, ax: 1545},
        elo_deltas={UID_ABD: 29, ax: -29},
        gps=3.7, confirmed_at=days_ago(3)))

    # singles ping_pong — favorite victim: 3 confirmed wins vs av
    for k in range(3):
        add_match(f"abd_pp_victim_{k}", match_doc(
            fac_pp, PING_PONG, "singles", [UID_ABD, av], S_CONFIRMED,
            started_at=days_ago(10 - k), submitted_by=UID_ABD,
            result=ping_pong_result([UID_ABD], [11, 9, 11], [7, 11, 8]),
            elo_before={UID_ABD: 1300 + k * 10, av: 1420},
            elo_deltas={UID_ABD: 11, av: -11},
            gps=5.0, confirmed_at=days_ago(10 - k)))

    # singles ping_pong — black beast: 3 confirmed losses vs ab
    for k in range(3):
        add_match(f"abd_pp_blackbeast_{k}", match_doc(
            fac_pp, PING_PONG, "singles", [UID_ABD, ab], S_CONFIRMED,
            started_at=days_ago(15 - k), submitted_by=ab,
            result=ping_pong_result([ab], [11, 11], [8, 6]),
            elo_before={UID_ABD: 1340 - k * 6, ab: 1500},
            elo_deltas={UID_ABD: -12, ab: 12},
            gps=None, confirmed_at=days_ago(15 - k)))

    # singles ping_pong — unconfirmed (timed out awaiting)
    add_match("abd_pp_unconfirmed", match_doc(
        fac_pp, PING_PONG, "singles", [UID_ABD, ax], S_UNCONFIRMED,
        started_at=days_ago(4), submitted_by=UID_ABD,
        result=ping_pong_result([UID_ABD], [11, 11], [6, 8])))

    # singles foosball — confirmed win
    add_match("abd_fb_confirmed", match_doc(
        fac_fb, FOOSBALL, "singles", [UID_ABD, ay], S_CONFIRMED,
        started_at=days_ago(5), submitted_by=UID_ABD,
        result=foosball_result([UID_ABD], 10, 7),
        elo_before={UID_ABD: 1360, ay: 1300},
        elo_deltas={UID_ABD: 15, ay: -15},
        gps=2.6, confirmed_at=days_ago(5)))

    # singles foosball — disputed (opponent submitted)
    add_match("abd_fb_disputed", match_doc(
        fac_fb, FOOSBALL, "singles", [UID_ABD, ax], S_DISPUTED,
        started_at=days_ago(1), submitted_by=ax,
        result=foosball_result([ax], 10, 8), gps=4.4))

    # singles foosball — abandoned (never submitted)
    add_match("abd_fb_abandoned", match_doc(
        fac_fb, FOOSBALL, "singles", [UID_ABD, ab], S_ABANDONED,
        started_at=days_ago(6)))

    # --- abd doubles: synth partner + one real+real team per other account -- #
    abd_team = [UID_ABD, ax]         # abd + synth partner (rated above)
    abd_opp_fb = [av, ab]
    abd_opp_pp = [ay, o1]

    # foosball — confirmed win (abd + synth)
    add_match("abd_fb_doubles_confirmed", match_doc(
        fac_fb, FOOSBALL, "doubles", abd_team + abd_opp_fb, S_CONFIRMED,
        team1=pair_id(abd_team), team2=pair_id(abd_opp_fb),
        started_at=days_ago(7), submitted_by=UID_ABD,
        result=foosball_result([UID_ABD, ax], 10, 5),
        elo_before={pair_id(abd_team): 1380, pair_id(abd_opp_fb): 1300},
        elo_deltas={pair_id(abd_team): 16, pair_id(abd_opp_fb): -16},
        gps=3.1, confirmed_at=days_ago(7)))

    # ping_pong — confirmed loss (abd + synth)
    add_match("abd_pp_doubles_loss", match_doc(
        fac_pp, PING_PONG, "doubles", abd_team + abd_opp_pp, S_CONFIRMED,
        team1=pair_id(abd_team), team2=pair_id(abd_opp_pp),
        started_at=days_ago(11), submitted_by=ay,
        result=ping_pong_result([ay, o1], [11, 11], [8, 9]),
        elo_before={pair_id(abd_team): 1350, pair_id(abd_opp_pp): 1290},
        elo_deltas={pair_id(abd_team): -13, pair_id(abd_opp_pp): 13},
        gps=4.8, confirmed_at=days_ago(11)))

    # foosball — disputed (abd + Mirko, real+real pair)
    abd_mm = [UID_ABD, UID_MIRKO]
    add_match("abd_fb_doubles_disputed", match_doc(
        fac_fb, FOOSBALL, "doubles", abd_mm + abd_opp_fb, S_DISPUTED,
        team1=pair_id(abd_mm), team2=pair_id(abd_opp_fb),
        started_at=days_ago(1), submitted_by=av,
        result=foosball_result([av, ab], 10, 9), gps=6.0))

    # --- tournaments: one per status --------------------------------------- #
    # registering
    t_reg = db.collection(C_TOURNAMENTS).document()
    w.set(t_reg, tournament_doc(
        "Spring Ping Pong Open", PING_PONG, fac_pp, UID_CHRISTIAN, T_REGISTERING,
        max_participants=8, participant_count=4,
        registration_deadline=days_from_now(4), scheduled_at=days_from_now(6),
        created_at=days_ago(2)))
    for seed_n, uid in enumerate(
            [UID_CHRISTIAN, UID_ABD, synth_uids[0], synth_uids[1]], start=1):
        w.set(t_reg.collection(SUB_PARTICIPANTS).document(uid),
              participant_doc(seed_n, False))

    # registering — organized by abd (covers the organizer case, no bracket)
    t_reg_abd = db.collection(C_TOURNAMENTS).document()
    w.set(t_reg_abd, tournament_doc(
        "Biomed Foosball Cup", FOOSBALL, fac_fb, UID_ABD, T_REGISTERING,
        max_participants=8, participant_count=3,
        registration_deadline=days_from_now(5), scheduled_at=days_from_now(7),
        created_at=days_ago(1)))
    for seed_n, uid in enumerate([UID_ABD, synth_uids[16], synth_uids[17]], start=1):
        w.set(t_reg_abd.collection(SUB_PARTICIPANTS).document(uid),
              participant_doc(seed_n, False))

    # cancelled (under-filled)
    t_cancel = db.collection(C_TOURNAMENTS).document()
    w.set(t_cancel, tournament_doc(
        "Foosball Friday (cancelled)", FOOSBALL, fac_fb, synth_uids[3], T_CANCELLED,
        max_participants=8, participant_count=2,
        registration_deadline=days_ago(3), scheduled_at=days_ago(1),
        created_at=days_ago(9)))
    for seed_n, uid in enumerate([synth_uids[3], synth_uids[4]], start=1):
        w.set(t_cancel.collection(SUB_PARTICIPANTS).document(uid),
              participant_doc(seed_n, False))

    # seeded (bracket built, no matches played yet) — today's tournament.
    # No QF match docs: an un-played bracket slot carries no match (seeding one
    # `occupied` would falsely occupy fac_pp). The bracket engine derives the QF
    # pairings from the 8 seeded participants and renders them all playable.
    t_seed = db.collection(C_TOURNAMENTS).document()
    seeded_players = [UID_MIRKO, UID_CHRISTIAN] + synth_uids[0:6]  # 8
    w.set(t_seed, tournament_doc(
        "Campus Cup (today)", PING_PONG, fac_pp, UID_MIRKO, T_SEEDED,
        max_participants=8, participant_count=8,
        bracket={},
        registration_deadline=days_ago(0.5), scheduled_at=NOW.replace(hour=18, minute=0),
        created_at=days_ago(6)))
    for seed_n, uid in enumerate(seeded_players, start=1):
        w.set(t_seed.collection(SUB_PARTICIPANTS).document(uid),
              participant_doc(seed_n, False))

    # active (QFs played, SFs pending; some eliminated)
    t_active = db.collection(C_TOURNAMENTS).document()
    active_players = [UID_CHRISTIAN, UID_MIRKO] + synth_uids[6:12]  # 8
    a_qf = []
    for m in range(4):
        a = active_players[m]
        b = active_players[7 - m]
        mid = add_match(f"active_qf_{m}", match_doc(
            fac_fb, FOOSBALL, "singles", [a, b], S_CONFIRMED,
            started_at=days_ago(1), submitted_by=a,
            result=foosball_result([a], 10, 7),
            elo_before={a: 1500, b: 1480}, elo_deltas={a: 15, b: -15},
            tournament_id=t_active.id, tournament_round="quarterfinal",
            confirmed_at=days_ago(1)))
        a_qf.append(mid)
    # One semifinal is live (in progress): a single `occupied` match between two
    # QF winners (Christian vs Mirko), so the demo shows one occupied table driven
    # by an ongoing tournament. started_at is recent so it reads as genuinely live
    # and stays inside MatchRepository.occupiedTimeout (4h) rather than being
    # auto-resolved as stale. Safe despite fac_fb's own status staying `free`:
    # joinMatch gates on facility.status, so no walk-up can attach (see docstring).
    a_sf_live = add_match("active_sf_live", match_doc(
        fac_fb, FOOSBALL, "singles", [UID_CHRISTIAN, UID_MIRKO], S_OCCUPIED,
        started_at=NOW - timedelta(minutes=20),
        tournament_id=t_active.id, tournament_round="semifinal"))
    # The other semifinal is still pending (not checked in): no match doc, so the
    # bracket engine feeds the remaining two QF winners into that SF slot.
    w.set(t_active, tournament_doc(
        "Engineering Foosball League", FOOSBALL, fac_fb, synth_uids[6], T_ACTIVE,
        max_participants=8, participant_count=8,
        bracket={"quarterfinal": a_qf, "semifinal": [a_sf_live]},
        registration_deadline=days_ago(3), scheduled_at=days_ago(1),
        created_at=days_ago(12)))
    for seed_n, uid in enumerate(active_players, start=1):
        # QF losers (seeds 5..8, i.e. active_players[4:]) eliminated via match.
        eliminated = uid in active_players[4:]
        w.set(t_active.collection(SUB_PARTICIPANTS).document(uid),
              participant_doc(seed_n, eliminated))

    # completed — Mirko is champion (justifies tournament_champion badge)
    t_done = db.collection(C_TOURNAMENTS).document()
    done_players = [UID_MIRKO, UID_CHRISTIAN] + synth_uids[0:6]  # 8
    d_qf, d_sf = [], []
    for m in range(4):
        a = done_players[m]
        b = done_players[7 - m]
        mid = add_match(f"done_qf_{m}", match_doc(
            fac_pp, PING_PONG, "singles", [a, b], S_CONFIRMED,
            started_at=days_ago(20), submitted_by=a,
            result=ping_pong_result([a], [11, 11], [6, 8]),
            elo_before={a: 1600, b: 1550}, elo_deltas={a: 14, b: -14},
            tournament_id=t_done.id, tournament_round="quarterfinal",
            confirmed_at=days_ago(20)))
        d_qf.append(mid)
    for m in range(2):
        a = done_players[m]
        b = done_players[3 - m]
        mid = add_match(f"done_sf_{m}", match_doc(
            fac_pp, PING_PONG, "singles", [a, b], S_CONFIRMED,
            started_at=days_ago(19), submitted_by=a,
            result=ping_pong_result([a], [11, 9, 11], [7, 11, 5]),
            elo_before={a: 1620, b: 1580}, elo_deltas={a: 16, b: -16},
            tournament_id=t_done.id, tournament_round="semifinal",
            confirmed_at=days_ago(19)))
        d_sf.append(mid)
    d_final = add_match("done_final", match_doc(
        fac_pp, PING_PONG, "singles", [UID_MIRKO, UID_CHRISTIAN], S_CONFIRMED,
        started_at=days_ago(18), submitted_by=UID_MIRKO,
        result=ping_pong_result([UID_MIRKO], [11, 8, 11], [9, 11, 7]),
        elo_before={UID_MIRKO: 1650, UID_CHRISTIAN: 1700},
        elo_deltas={UID_MIRKO: 22, UID_CHRISTIAN: -22},
        tournament_id=t_done.id, tournament_round="final",
        confirmed_at=days_ago(18)))
    w.set(t_done, tournament_doc(
        "Winter Champions Cup", PING_PONG, fac_pp, UID_CHRISTIAN, T_COMPLETED,
        max_participants=8, participant_count=8,
        bracket={"quarterfinal": d_qf, "semifinal": d_sf, "final": [d_final]},
        winner_uid=UID_MIRKO,
        registration_deadline=days_ago(25), scheduled_at=days_ago(21),
        created_at=days_ago(30)))
    # Participant elimination states: mix of derived, forfeit, advanced.
    done_elim = {
        UID_MIRKO: (1, False, None),                    # champion
        UID_CHRISTIAN: (2, True, None),                 # lost final (derived)
        synth_uids[0]: (3, True, None),                 # derived
        synth_uids[1]: (4, True, ELIM_FORFEIT),         # organizer: no-show
        synth_uids[2]: (5, True, ELIM_ADVANCED),        # organizer: declared loss
        synth_uids[3]: (6, True, None),
        synth_uids[4]: (7, True, None),
        synth_uids[5]: (8, True, None),
    }
    for uid, (seed_n, elim, reason) in done_elim.items():
        w.set(t_done.collection(SUB_PARTICIPANTS).document(uid),
              participant_doc(seed_n, elim, elimination_reason=reason))

    # --- finalize real users' friends + badges ----------------------------- #
    christian_friends = [UID_MIRKO, UID_ABD] + synth_uids[0:6]
    mirko_friends = [UID_CHRISTIAN, UID_ABD] + synth_uids[3:9]
    abd_friends = [UID_CHRISTIAN, UID_MIRKO] + synth_uids[14:20]

    # Badges spread so between them all 6 defs are covered, consistent w/ history.
    christian_badges = {
        "first_victory": days_ago(9),
        "streak_5": days_ago(1),         # 3-win streak seeded; badge for demo
        "explorer": days_ago(15),
    }
    mirko_badges = {
        "first_victory": days_ago(20),
        "giant_slayer": days_ago(3),     # beat +240 elo opponent (pp_confirmed_giantslayer)
        "tournament_champion": days_ago(18),  # Winter Champions Cup winner
        "workaholic": days_ago(2),
    }
    # abd: all six badges for full-coverage demo (giant_slayer justified by
    # abd_pp_giantslayer above; the rest seeded for the badge showcase).
    abd_badges = {
        "first_victory": days_ago(10),
        "streak_5": days_ago(2),
        "giant_slayer": days_ago(3),
        "explorer": days_ago(12),
        "tournament_champion": days_ago(1),
        "workaholic": days_ago(2),
    }

    w.set(db.collection(C_USERS).document(UID_CHRISTIAN), user_doc(
        name=REAL_USERS[UID_CHRISTIAN]["name"],
        username=REAL_USERS[UID_CHRISTIAN]["username"],
        email=REAL_USERS[UID_CHRISTIAN]["email"],
        degree=REAL_USERS[UID_CHRISTIAN]["degreeProgram"],
        language="en",
        friend_uids=christian_friends, badges=christian_badges,
        onboarding=True, created_at=days_ago(200)))
    w.set(db.collection(C_USERNAMES).document("prend"), {"uid": UID_CHRISTIAN})

    w.set(db.collection(C_USERS).document(UID_MIRKO), user_doc(
        name=REAL_USERS[UID_MIRKO]["name"],
        username=REAL_USERS[UID_MIRKO]["username"],
        email=REAL_USERS[UID_MIRKO]["email"],
        degree=REAL_USERS[UID_MIRKO]["degreeProgram"],
        language="it",
        friend_uids=mirko_friends, badges=mirko_badges,
        onboarding=True, created_at=days_ago(200)))
    w.set(db.collection(C_USERNAMES).document("m1rk0"), {"uid": UID_MIRKO})

    w.set(db.collection(C_USERS).document(UID_ABD), user_doc(
        name=REAL_USERS[UID_ABD]["name"],
        username=REAL_USERS[UID_ABD]["username"],
        email=REAL_USERS[UID_ABD]["email"],
        degree=REAL_USERS[UID_ABD]["degreeProgram"],
        language="en",
        friend_uids=abd_friends, badges=abd_badges,
        onboarding=True, created_at=days_ago(200)))
    w.set(db.collection(C_USERNAMES).document("abd"), {"uid": UID_ABD})

    # Wire the synthetic side of the friendships back to the real users so the
    # friends-only challenge rule stays consistent both directions.
    for u in set(christian_friends) & set(synth_uids):
        synth_friends[u].add(UID_CHRISTIAN)
    for u in set(mirko_friends) & set(synth_uids):
        synth_friends[u].add(UID_MIRKO)
    for u in set(abd_friends) & set(synth_uids):
        synth_friends[u].add(UID_ABD)
    for uid in synth_uids:
        w.update(db.collection(C_USERS).document(uid),
                 {"friendUids": sorted(synth_friends[uid])})

    # --- challenges: every status, both directions ------------------------- #
    challenges = [
        # pending
        challenge_doc(UID_CHRISTIAN, UID_MIRKO, PING_PONG, CH_PENDING,
                      created_at=days_ago(0.1)),
        challenge_doc(synth_uids[0], UID_CHRISTIAN, FOOSBALL, CH_PENDING,
                      created_at=days_ago(0.3)),
        challenge_doc(UID_MIRKO, synth_uids[4], FOOSBALL, CH_PENDING,
                      created_at=days_ago(0.05)),
        # accepted (checked-in -> matchId set; points at the played, now-confirmed match)
        challenge_doc(UID_MIRKO, UID_CHRISTIAN, PING_PONG, CH_ACCEPTED,
                      created_at=days_ago(0.4), responded_at=days_ago(0.2),
                      match_id=match_ids["pp_confirmed_giantslayer"]),
        challenge_doc(synth_uids[3], UID_MIRKO, FOOSBALL, CH_ACCEPTED,
                      created_at=days_ago(6), responded_at=days_ago(5),
                      match_id=match_ids["fb_confirmed"]),
        # declined
        challenge_doc(UID_CHRISTIAN, synth_uids[1], PING_PONG, CH_DECLINED,
                      created_at=days_ago(2), responded_at=days_ago(2)),
        # expired
        challenge_doc(synth_uids[5], UID_CHRISTIAN, FOOSBALL, CH_EXPIRED,
                      created_at=days_ago(10)),
        # abd — every status, both directions
        challenge_doc(UID_ABD, UID_MIRKO, PING_PONG, CH_PENDING,
                      created_at=days_ago(0.1)),
        challenge_doc(UID_CHRISTIAN, UID_ABD, FOOSBALL, CH_PENDING,
                      created_at=days_ago(0.2)),
        challenge_doc(UID_ABD, UID_CHRISTIAN, PING_PONG, CH_ACCEPTED,
                      created_at=days_ago(0.4), responded_at=days_ago(0.3),
                      match_id=match_ids["abd_pp_giantslayer"]),
        challenge_doc(UID_ABD, synth_uids[14], PING_PONG, CH_DECLINED,
                      created_at=days_ago(2), responded_at=days_ago(2)),
        challenge_doc(synth_uids[15], UID_ABD, FOOSBALL, CH_EXPIRED,
                      created_at=days_ago(10)),
    ]
    for ch in challenges:
        w.set(db.collection(C_CHALLENGES).document(), ch)

    # --- facilities: real campus data + mixed live statuses ---------------- #
    # A walk-up occupant (two synthetic players) with a two-person waiting queue
    # on the designated `queued` table. Synthetic-only so no real account is
    # entangled and the play demo stays clear of it.
    q_a, q_b = synth_uids[20], synth_uids[21]
    q_waiters = [synth_uids[22], synth_uids[18]]
    q_match = add_match("queued_walkup", match_doc(
        FAC_QUEUED, PING_PONG, "singles", [q_a, q_b], S_OCCUPIED,
        started_at=NOW - timedelta(minutes=15)))
    for pos, uid in enumerate(q_waiters, start=1):
        w.set(db.collection(C_FACILITIES).document(FAC_QUEUED)
              .collection(SUB_QUEUE).document(uid),
              queue_entry_doc(uid, pos, NOW - timedelta(minutes=12 - pos)))

    # Two busy tables; every other facility stays `free`. The occupied one hosts
    # the active tournament's live semifinal (active_sf_live); the queued one has
    # the walk-up match + queue seeded just above.
    busy = {
        fac_fb: (FS_OCCUPIED, match_ids["active_sf_live"], 0),
        FAC_QUEUED: (FS_QUEUED, q_match, len(q_waiters)),
    }
    for fac_id, name, sport_id, lat, lng, fallback in FACILITIES:
        status, cur, tail = busy.get(fac_id, (FS_FREE, None, 0))
        w.set(db.collection(C_FACILITIES).document(fac_id),
              facility_doc(fac_id, name, sport_id, lat, lng, fallback,
                           status=status, current_match_id=cur, queue_tail=tail))

    w.flush()
    print(f"Seed complete. Total writes: {w.total}")


# --------------------------------------------------------------------------- #
# Verify                                                                       #
# --------------------------------------------------------------------------- #

def count(db, col) -> int:
    return sum(1 for _ in db.collection(col).stream())


def verify(db) -> None:
    print("\n=== VERIFY ===")
    for col in OWNED_COLLECTIONS + [C_FACILITIES]:
        print(f"  {col}: {count(db, col)}")

    def group(col, field):
        buckets: dict[str, int] = {}
        for d in db.collection(col).stream():
            buckets[(d.to_dict() or {}).get(field, "?")] = \
                buckets.get((d.to_dict() or {}).get(field, "?"), 0) + 1
        return buckets

    print(f"  facilities by status:  {group(C_FACILITIES, 'status')}")
    print(f"  matches by state:      {group(C_MATCHES, 'state')}")
    print(f"  tournaments by status: {group(C_TOURNAMENTS, 'status')}")
    print(f"  challenges by status:  {group(C_CHALLENGES, 'status')}")

    for uid, meta in REAL_USERS.items():
        doc = db.collection(C_USERS).document(uid).get()
        data = doc.to_dict() or {}
        print(f"\n  {meta['username']} ({uid}):")
        print(f"    name={data.get('name')} degree={data.get('degreeProgram')} "
              f"onboarding={data.get('onboardingComplete')}")
        print(f"    friends={len(data.get('friendUids', []))} "
              f"badges={list((data.get('badges') or {}).keys())}")
        ratings = db.collection(C_RATINGS).where(
            filter=firestore.FieldFilter("ownerId", "==", uid)).stream()
        for r in ratings:
            rd = r.to_dict() or {}
            print(f"    rating {rd.get('sportId')}: elo={rd.get('elo')} "
                  f"played={rd.get('matchesPlayed')}")


# --------------------------------------------------------------------------- #

def main() -> None:
    cred = credentials.Certificate(KEY_PATH)
    firebase_admin.initialize_app(cred)
    db = firestore.client()

    if "--verify" in sys.argv:
        verify(db)
        return

    wipe(db)
    seed(db)
    verify(db)


if __name__ == "__main__":
    main()
