import os
from collections import deque
from datetime import datetime, timedelta
from twilio.rest import Client


def _normalize_number(num: str) -> str:
    if not num:
        return ''
    digits = ''.join(ch for ch in str(num) if ch.isdigit())
    # Keep last 10 digits (US local without country code) for simple matching
    if len(digits) > 10:
        digits = digits[-10:]
    return digits


class SpamService:
    """Lightweight spam detection with optional Twilio Lookups reputation.

    Features:
    - Allowlist/Blocklist from env (comma-separated phone numbers)
    - Simple rate-limit heuristic per number (X calls in Y seconds)
    - Optional Twilio Lookups v2 reputation check (paid lookup)
    - Returns an action: allow | challenge | block
    """

    def __init__(self):
        # Behavior toggles
        self.enabled = os.getenv('ENABLE_SPAM_DETECTION', 'True').lower() == 'true'
        self.lookup_enabled = os.getenv('SPAM_LOOKUP_ENABLED', 'False').lower() == 'true'
        self.challenge_digit = os.getenv('SPAM_CHALLENGE_DIGIT', '1')
        self.lookup_action = os.getenv('SPAM_LOOKUP_ACTION', 'challenge')  # challenge|block|allow

        # Rate limit config
        self.rate_calls = int(os.getenv('SPAM_RATE_LIMIT_CALLS', 3))
        self.rate_window_secs = int(os.getenv('SPAM_RATE_LIMIT_WINDOW', 600))  # 10 minutes
        self.rate_action = os.getenv('SPAM_RATE_ACTION', 'challenge')  # challenge|block

        # Reputation threshold
        # If Twilio Lookups returns reputation.level in {low, medium, high}
        # take action when level >= threshold_level
        self.reputation_threshold = os.getenv('SPAM_REPUTATION_THRESHOLD', 'high').lower()

        # Lists
        self.allowlist = {
            _normalize_number(n)
            for n in (os.getenv('ALLOWLIST_NUMBERS', '') or '').split(',') if n.strip()
        }
        self.blocklist = {
            _normalize_number(n)
            for n in (os.getenv('BLOCKLIST_NUMBERS', '') or '').split(',') if n.strip()
        }

        # Recent call tracker: map normalized number -> deque[timestamps]
        self.recent_calls = {}

        # Twilio client (for Lookups) if enabled
        self.client = None
        if self.lookup_enabled:
            try:
                self.client = Client(os.getenv('TWILIO_ACCOUNT_SID'), os.getenv('TWILIO_AUTH_TOKEN'))
            except Exception:
                self.client = None

    def record_call(self, phone: str):
        num = _normalize_number(phone)
        if not num:
            return
        dq = self.recent_calls.setdefault(num, deque())
        now = datetime.utcnow()
        dq.append(now)
        # prune old
        cutoff = now - timedelta(seconds=self.rate_window_secs)
        while dq and dq[0] < cutoff:
            dq.popleft()

    def _rate_limit_exceeded(self, phone: str) -> bool:
        num = _normalize_number(phone)
        if not num:
            return False
        dq = self.recent_calls.get(num) or deque()
        # recent deque is pruned in record_call; ensure prune here too
        now = datetime.utcnow()
        cutoff = now - timedelta(seconds=self.rate_window_secs)
        dq = deque(t for t in dq if t >= cutoff)
        self.recent_calls[num] = dq
        return len(dq) >= self.rate_calls

    def _lookup_reputation(self, phone: str):
        if not (self.lookup_enabled and self.client):
            return None
        try:
            resp = self.client.lookups.v2.phone_numbers(phone).fetch(fields="reputation,caller_name")
            # Twilio SDK returns attributes: reputation.level, reputation.score when available
            rep = getattr(resp, 'reputation', None)
            if rep is None:
                return None
            level = getattr(rep, 'level', None)  # low|medium|high
            score = getattr(rep, 'score', None)
            return {'level': str(level).lower() if level else None, 'score': score}
        except Exception:
            return None

    def evaluate_call(self, phone: str):
        """Return dict: { action: allow|challenge|block, reason: str, details: dict }
        Honor allowlist first, then blocklist, then rate-limit, then lookup.
        """
        if not self.enabled:
            return {'action': 'allow', 'reason': 'disabled', 'details': {}}

        normalized = _normalize_number(phone)
        if normalized in self.allowlist:
            return {'action': 'allow', 'reason': 'allowlist', 'details': {}}
        if normalized in self.blocklist:
            return {'action': 'block', 'reason': 'blocklist', 'details': {}}

        # Rate limit heuristic
        if self._rate_limit_exceeded(phone):
            return {'action': self.rate_action, 'reason': 'rate_limit', 'details': {}}

        # Twilio Lookups reputation
        rep = self._lookup_reputation(phone)
        if rep and rep.get('level'):
            levels = ['low', 'medium', 'high']
            try:
                if levels.index(rep['level']) >= levels.index(self.reputation_threshold):
                    return {'action': self.lookup_action, 'reason': f"reputation:{rep['level']}", 'details': rep}
            except Exception:
                pass

        return {'action': 'allow', 'reason': 'default', 'details': rep or {}}
